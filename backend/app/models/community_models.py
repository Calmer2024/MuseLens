"""
社区相关 ORM 模型。

本文件实现数据库设计文档中的：
- posts
- post_images
- comments
- post_likes
- comment_likes
- post_favorites
- tags
- post_tags
"""

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Column,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
    func,
)

from app.core.db_base import Base
from app.models.sql_types import BIGINT_ID, UUID_STR


class Post(Base):
    __tablename__ = "posts"

    post_id = Column(BIGINT_ID, primary_key=True, autoincrement=True)
    user_id = Column(BIGINT_ID, ForeignKey("users.user_id", ondelete="CASCADE"), nullable=False, index=True)
    title = Column(String(200), nullable=True, comment="帖子标题")
    content = Column(Text, default="", nullable=False, comment="帖子正文")
    like_count = Column(Integer, default=0, nullable=False, comment="点赞数")
    comment_count = Column(Integer, default=0, nullable=False, comment="评论数")
    share_count = Column(Integer, default=0, nullable=False, comment="分享数")
    view_count = Column(Integer, default=0, nullable=False, comment="浏览数")
    is_public = Column(Boolean, default=True, nullable=False, comment="是否公开")
    audit_status = Column(String(20), default="pending", nullable=False, comment="审核状态")
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class PostImage(Base):
    __tablename__ = "post_images"

    image_id = Column(BIGINT_ID, primary_key=True, autoincrement=True)
    post_id = Column(BIGINT_ID, ForeignKey("posts.post_id", ondelete="CASCADE"), nullable=False, index=True)
    asset_node_id = Column(UUID_STR, ForeignKey("asset_nodes.node_id", ondelete="SET NULL"), nullable=True)
    image_url = Column(String(500), nullable=False, comment="图片地址")
    thumbnail_url = Column(String(500), nullable=True, comment="缩略图地址")
    width = Column(Integer, nullable=True)
    height = Column(Integer, nullable=True)
    order_index = Column(Integer, default=0, nullable=False, comment="图片顺序")
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class Comment(Base):
    __tablename__ = "comments"

    comment_id = Column(BIGINT_ID, primary_key=True, autoincrement=True)
    post_id = Column(BIGINT_ID, ForeignKey("posts.post_id", ondelete="CASCADE"), nullable=False, index=True)
    user_id = Column(BIGINT_ID, ForeignKey("users.user_id", ondelete="CASCADE"), nullable=False, index=True)
    parent_id = Column(BIGINT_ID, ForeignKey("comments.comment_id", ondelete="CASCADE"), nullable=True, index=True)
    root_id = Column(BIGINT_ID, ForeignKey("comments.comment_id", ondelete="CASCADE"), nullable=True, index=True)
    content = Column(Text, nullable=False, comment="评论正文")
    like_count = Column(Integer, default=0, nullable=False, comment="点赞数")
    reply_count = Column(Integer, default=0, nullable=False, comment="回复数")
    level = Column(Integer, default=1, nullable=False, comment="评论层级")
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    __table_args__ = (
        CheckConstraint("level IN (1, 2)", name="chk_comment_level"),
    )


class PostLike(Base):
    __tablename__ = "post_likes"

    user_id = Column(BIGINT_ID, ForeignKey("users.user_id", ondelete="CASCADE"), primary_key=True)
    post_id = Column(BIGINT_ID, ForeignKey("posts.post_id", ondelete="CASCADE"), primary_key=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class CommentLike(Base):
    __tablename__ = "comment_likes"

    user_id = Column(BIGINT_ID, ForeignKey("users.user_id", ondelete="CASCADE"), primary_key=True)
    comment_id = Column(BIGINT_ID, ForeignKey("comments.comment_id", ondelete="CASCADE"), primary_key=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class PostFavorite(Base):
    __tablename__ = "post_favorites"

    user_id = Column(BIGINT_ID, ForeignKey("users.user_id", ondelete="CASCADE"), primary_key=True)
    post_id = Column(BIGINT_ID, ForeignKey("posts.post_id", ondelete="CASCADE"), primary_key=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class Tag(Base):
    __tablename__ = "tags"

    tag_id = Column(BIGINT_ID, primary_key=True, autoincrement=True)
    name = Column(String(50), unique=True, nullable=False, index=True, comment="标签名")
    description = Column(Text, default="", nullable=False, comment="标签描述")
    post_count = Column(Integer, default=0, nullable=False, comment="关联帖子数")
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class PostTag(Base):
    __tablename__ = "post_tags"

    post_id = Column(BIGINT_ID, ForeignKey("posts.post_id", ondelete="CASCADE"), primary_key=True)
    tag_id = Column(BIGINT_ID, ForeignKey("tags.tag_id", ondelete="CASCADE"), primary_key=True)

    __table_args__ = (
        UniqueConstraint("post_id", "tag_id", name="uq_post_tag"),
    )
