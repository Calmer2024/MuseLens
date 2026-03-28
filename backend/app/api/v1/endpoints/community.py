"""
社区 API。
"""

from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.schemas.asset_tree import MessageResponse
from app.schemas.community import (
    CommentCreateRequest,
    CommentListResponse,
    CommentOut,
    PostCreateRequest,
    PostImageOut,
    PostOut,
    TagOut,
    UserActionRequest,
)
from app.services import community_service as svc

router = APIRouter()


def _post_out(db: Session, post) -> PostOut:
    return PostOut(
        post_id=post.post_id,
        user_id=post.user_id,
        title=post.title,
        content=post.content,
        like_count=post.like_count,
        comment_count=post.comment_count,
        share_count=post.share_count,
        view_count=post.view_count,
        is_public=post.is_public,
        audit_status=post.audit_status,
        created_at=post.created_at,
        updated_at=post.updated_at,
        images=[PostImageOut.model_validate(item) for item in svc.list_post_images(db, post.post_id)],
        tags=[TagOut.model_validate(item) for item in svc.list_post_tags(db, post.post_id)],
    )


@router.post("/posts", response_model=PostOut, status_code=201, summary="创建帖子")
def create_post(body: PostCreateRequest, db: Session = Depends(get_db)) -> PostOut:
    try:
        post = svc.create_post(
            db,
            user_id=body.user_id,
            title=body.title,
            content=body.content,
            is_public=body.is_public,
            images=[item.model_dump() for item in body.images],
            tag_names=body.tag_names,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    return _post_out(db, post)


@router.get("/posts", response_model=List[PostOut], summary="列出帖子")
def list_posts(
    user_id: int | None = Query(default=None),
    tag_name: str | None = Query(default=None),
    only_public: bool = Query(default=True),
    db: Session = Depends(get_db),
) -> List[PostOut]:
    posts = svc.list_posts(db, user_id=user_id, tag_name=tag_name, only_public=only_public)
    return [_post_out(db, item) for item in posts]


@router.get("/posts/{post_id}", response_model=PostOut, summary="获取帖子详情")
def get_post_detail(post_id: int, db: Session = Depends(get_db)) -> PostOut:
    post = svc.get_post_detail(db, post_id)
    if not post:
        raise HTTPException(status_code=404, detail=f"帖子不存在：{post_id}")
    return _post_out(db, post)


@router.post("/posts/{post_id}/comments", response_model=CommentOut, status_code=201, summary="发表评论")
def create_comment(post_id: int, body: CommentCreateRequest, db: Session = Depends(get_db)) -> CommentOut:
    try:
        comment = svc.create_comment(
            db,
            post_id=post_id,
            user_id=body.user_id,
            content=body.content,
            parent_id=body.parent_id,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    return CommentOut.model_validate(comment)


@router.get("/posts/{post_id}/comments", response_model=CommentListResponse, summary="获取评论列表")
def list_comments(post_id: int, db: Session = Depends(get_db)) -> CommentListResponse:
    if not svc.get_post(db, post_id):
        raise HTTPException(status_code=404, detail=f"帖子不存在：{post_id}")
    comments = svc.list_comments(db, post_id)
    return CommentListResponse(
        post_id=post_id,
        comments=[CommentOut.model_validate(item) for item in comments],
    )


@router.post("/posts/{post_id}/like", response_model=MessageResponse, summary="点赞帖子")
def like_post(post_id: int, body: UserActionRequest, db: Session = Depends(get_db)) -> MessageResponse:
    try:
        created = svc.like_post(db, post_id=post_id, user_id=body.user_id)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    return MessageResponse(message="点赞成功" if created else "已点赞，无需重复操作")


@router.delete("/posts/{post_id}/like", response_model=MessageResponse, summary="取消帖子点赞")
def unlike_post(post_id: int, body: UserActionRequest, db: Session = Depends(get_db)) -> MessageResponse:
    try:
        removed = svc.unlike_post(db, post_id=post_id, user_id=body.user_id)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    return MessageResponse(message="取消点赞成功" if removed else "点赞记录不存在")


@router.post("/posts/{post_id}/favorite", response_model=MessageResponse, summary="收藏帖子")
def favorite_post(post_id: int, body: UserActionRequest, db: Session = Depends(get_db)) -> MessageResponse:
    try:
        created = svc.favorite_post(db, post_id=post_id, user_id=body.user_id)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    return MessageResponse(message="收藏成功" if created else "已收藏，无需重复操作")


@router.delete("/posts/{post_id}/favorite", response_model=MessageResponse, summary="取消收藏帖子")
def unfavorite_post(post_id: int, body: UserActionRequest, db: Session = Depends(get_db)) -> MessageResponse:
    removed = svc.unfavorite_post(db, post_id=post_id, user_id=body.user_id)
    return MessageResponse(message="取消收藏成功" if removed else "收藏记录不存在")


@router.post("/comments/{comment_id}/like", response_model=MessageResponse, summary="点赞评论")
def like_comment(comment_id: int, body: UserActionRequest, db: Session = Depends(get_db)) -> MessageResponse:
    try:
        created = svc.like_comment(db, comment_id=comment_id, user_id=body.user_id)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    return MessageResponse(message="点赞成功" if created else "已点赞，无需重复操作")


@router.delete("/comments/{comment_id}/like", response_model=MessageResponse, summary="取消评论点赞")
def unlike_comment(comment_id: int, body: UserActionRequest, db: Session = Depends(get_db)) -> MessageResponse:
    try:
        removed = svc.unlike_comment(db, comment_id=comment_id, user_id=body.user_id)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    return MessageResponse(message="取消点赞成功" if removed else "点赞记录不存在")


@router.get("/tags", response_model=List[TagOut], summary="获取标签列表")
def list_tags(db: Session = Depends(get_db)) -> List[TagOut]:
    return [TagOut.model_validate(item) for item in svc.list_tags(db)]
