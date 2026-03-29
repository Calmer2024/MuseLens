"""
社区服务。
"""

from __future__ import annotations

from typing import Dict, List, Optional

from sqlalchemy.orm import Session

from app.models.community_models import (
    Comment,
    CommentLike,
    Post,
    PostFavorite,
    PostImage,
    PostLike,
    PostTag,
    Tag,
)
from app.models.user_models import User


def get_post(db: Session, post_id: int) -> Optional[Post]:
    return db.query(Post).filter(Post.post_id == post_id).first()


def get_comment(db: Session, comment_id: int) -> Optional[Comment]:
    return db.query(Comment).filter(Comment.comment_id == comment_id).first()


def get_tag_by_name(db: Session, name: str) -> Optional[Tag]:
    return db.query(Tag).filter(Tag.name == name).first()


def _normalize_tag_names(tag_names: List[str]) -> List[str]:
    result: List[str] = []
    seen = set()
    for raw in tag_names:
        name = raw.strip().lstrip("#")
        if not name or name in seen:
            continue
        seen.add(name)
        result.append(name)
    return result


def _get_or_create_tags(db: Session, tag_names: List[str]) -> List[Tag]:
    tags: List[Tag] = []
    for name in _normalize_tag_names(tag_names):
        tag = get_tag_by_name(db, name)
        if not tag:
            tag = Tag(name=name, description="")
            db.add(tag)
            db.flush()
        tags.append(tag)
    return tags


def create_post(
    db: Session,
    *,
    user_id: int,
    title: str | None,
    content: str,
    is_public: bool,
    images: List[Dict],
    tag_names: List[str],
) -> Post:
    user = db.query(User).filter(User.user_id == user_id).first()
    if not user:
        raise ValueError(f"用户不存在：{user_id}")

    post = Post(
        user_id=user_id,
        title=title,
        content=content,
        is_public=is_public,
        audit_status="pending",
    )
    db.add(post)
    db.flush()

    for item in images:
        db.add(
            PostImage(
                post_id=post.post_id,
                asset_node_id=item.get("asset_node_id"),
                image_url=item["image_url"],
                thumbnail_url=item.get("thumbnail_url"),
                width=item.get("width"),
                height=item.get("height"),
                order_index=item.get("order_index", 0),
            )
        )

    for tag in _get_or_create_tags(db, tag_names):
        existing = db.query(PostTag).filter(PostTag.post_id == post.post_id, PostTag.tag_id == tag.tag_id).first()
        if existing:
            continue
        db.add(PostTag(post_id=post.post_id, tag_id=tag.tag_id))
        tag.post_count += 1

    db.commit()
    db.refresh(post)
    return post


def list_posts(
    db: Session,
    *,
    user_id: int | None = None,
    tag_name: str | None = None,
    only_public: bool = True,
) -> List[Post]:
    query = db.query(Post)
    if only_public:
        query = query.filter(Post.is_public.is_(True))
    if user_id is not None:
        query = query.filter(Post.user_id == user_id)
    if tag_name:
        query = (
            query.join(PostTag, PostTag.post_id == Post.post_id)
            .join(Tag, Tag.tag_id == PostTag.tag_id)
            .filter(Tag.name == tag_name)
        )
    return query.order_by(Post.created_at.desc()).all()


def list_post_images(db: Session, post_id: int) -> List[PostImage]:
    return (
        db.query(PostImage)
        .filter(PostImage.post_id == post_id)
        .order_by(PostImage.order_index.asc(), PostImage.image_id.asc())
        .all()
    )


def list_post_tags(db: Session, post_id: int) -> List[Tag]:
    return (
        db.query(Tag)
        .join(PostTag, PostTag.tag_id == Tag.tag_id)
        .filter(PostTag.post_id == post_id)
        .order_by(Tag.name.asc())
        .all()
    )


def get_post_detail(db: Session, post_id: int, *, increment_view: bool = True) -> Optional[Post]:
    post = get_post(db, post_id)
    if not post:
        return None
    if increment_view:
        post.view_count += 1
        db.commit()
        db.refresh(post)
    return post


def create_comment(
    db: Session,
    *,
    post_id: int,
    user_id: int,
    content: str,
    parent_id: int | None = None,
) -> Comment:
    post = get_post(db, post_id)
    if not post:
        raise ValueError(f"帖子不存在：{post_id}")
    user = db.query(User).filter(User.user_id == user_id).first()
    if not user:
        raise ValueError(f"用户不存在：{user_id}")

    level = 1
    root_id = None
    parent = None
    if parent_id is not None:
        parent = get_comment(db, parent_id)
        if not parent or parent.post_id != post_id:
            raise ValueError("父评论不存在或不属于该帖子")
        if parent.level >= 2:
            raise ValueError("当前实现仅支持二级评论")
        level = 2
        root_id = parent.root_id or parent.comment_id

    comment = Comment(
        post_id=post_id,
        user_id=user_id,
        parent_id=parent_id,
        root_id=root_id,
        content=content,
        level=level,
    )
    db.add(comment)
    post.comment_count += 1
    if parent:
        parent.reply_count += 1
    db.commit()
    db.refresh(comment)
    return comment


def list_comments(db: Session, post_id: int) -> List[Comment]:
    return (
        db.query(Comment)
        .filter(Comment.post_id == post_id)
        .order_by(Comment.created_at.asc(), Comment.comment_id.asc())
        .all()
    )


def like_post(db: Session, *, post_id: int, user_id: int) -> bool:
    post = get_post(db, post_id)
    if not post:
        raise ValueError(f"帖子不存在：{post_id}")
    if not db.query(User).filter(User.user_id == user_id).first():
        raise ValueError(f"用户不存在：{user_id}")
    existing = db.query(PostLike).filter(PostLike.post_id == post_id, PostLike.user_id == user_id).first()
    if existing:
        return False
    db.add(PostLike(post_id=post_id, user_id=user_id))
    post.like_count += 1
    owner = db.query(User).filter(User.user_id == post.user_id).first()
    if owner and owner.user_id != user_id:
        owner.total_likes += 1
    db.commit()
    return True


def unlike_post(db: Session, *, post_id: int, user_id: int) -> bool:
    post = get_post(db, post_id)
    if not post:
        raise ValueError(f"帖子不存在：{post_id}")
    relation = db.query(PostLike).filter(PostLike.post_id == post_id, PostLike.user_id == user_id).first()
    if not relation:
        return False
    db.delete(relation)
    post.like_count = max(0, post.like_count - 1)
    owner = db.query(User).filter(User.user_id == post.user_id).first()
    if owner and owner.user_id != user_id:
        owner.total_likes = max(0, owner.total_likes - 1)
    db.commit()
    return True


def favorite_post(db: Session, *, post_id: int, user_id: int) -> bool:
    if not get_post(db, post_id):
        raise ValueError(f"帖子不存在：{post_id}")
    if not db.query(User).filter(User.user_id == user_id).first():
        raise ValueError(f"用户不存在：{user_id}")
    existing = db.query(PostFavorite).filter(PostFavorite.post_id == post_id, PostFavorite.user_id == user_id).first()
    if existing:
        return False
    db.add(PostFavorite(post_id=post_id, user_id=user_id))
    db.commit()
    return True


def unfavorite_post(db: Session, *, post_id: int, user_id: int) -> bool:
    relation = db.query(PostFavorite).filter(PostFavorite.post_id == post_id, PostFavorite.user_id == user_id).first()
    if not relation:
        return False
    db.delete(relation)
    db.commit()
    return True


def like_comment(db: Session, *, comment_id: int, user_id: int) -> bool:
    comment = get_comment(db, comment_id)
    if not comment:
        raise ValueError(f"评论不存在：{comment_id}")
    if not db.query(User).filter(User.user_id == user_id).first():
        raise ValueError(f"用户不存在：{user_id}")
    existing = (
        db.query(CommentLike)
        .filter(CommentLike.comment_id == comment_id, CommentLike.user_id == user_id)
        .first()
    )
    if existing:
        return False
    db.add(CommentLike(comment_id=comment_id, user_id=user_id))
    comment.like_count += 1
    owner = db.query(User).filter(User.user_id == comment.user_id).first()
    if owner and owner.user_id != user_id:
        owner.total_likes += 1
    db.commit()
    return True


def unlike_comment(db: Session, *, comment_id: int, user_id: int) -> bool:
    comment = get_comment(db, comment_id)
    if not comment:
        raise ValueError(f"评论不存在：{comment_id}")
    relation = (
        db.query(CommentLike)
        .filter(CommentLike.comment_id == comment_id, CommentLike.user_id == user_id)
        .first()
    )
    if not relation:
        return False
    db.delete(relation)
    comment.like_count = max(0, comment.like_count - 1)
    owner = db.query(User).filter(User.user_id == comment.user_id).first()
    if owner and owner.user_id != user_id:
        owner.total_likes = max(0, owner.total_likes - 1)
    db.commit()
    return True


def list_tags(db: Session) -> List[Tag]:
    return db.query(Tag).order_by(Tag.post_count.desc(), Tag.name.asc()).all()
