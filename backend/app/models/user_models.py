"""
用户管理相关 ORM 模型。

本文件实现数据库设计文档中的：
- users
- follows
"""

from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import Boolean, Column, DateTime, ForeignKey, Integer, String, Text, func

from app.core.db_base import Base
from app.models.sql_types import BIGINT_ID


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class User(Base):
    __tablename__ = "users"

    user_id = Column(BIGINT_ID, primary_key=True, autoincrement=True)
    username = Column(String(50), unique=True, index=True, nullable=False, comment="用户名")
    password_hash = Column(String(255), nullable=False, comment="密码哈希")
    email = Column(String(100), unique=True, index=True, nullable=True, comment="邮箱")
    nickname = Column(String(50), nullable=False, comment="昵称")
    bio = Column(Text, default="", nullable=False, comment="个人简介")
    avatar_url = Column(String(500), nullable=True, comment="头像地址")
    banner_url = Column(String(500), nullable=True, comment="背景图地址")
    total_likes = Column(Integer, default=0, nullable=False, comment="累计获赞数")
    follower_count = Column(Integer, default=0, nullable=False, comment="粉丝数")
    following_count = Column(Integer, default=0, nullable=False, comment="关注数")
    member_level = Column(String(20), default="free", nullable=False, comment="会员等级")
    is_verified = Column(Boolean, default=False, nullable=False, comment="是否认证")
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=_utcnow,
        nullable=False,
    )

    def __repr__(self) -> str:
        return f"<User user_id={self.user_id!r} username={self.username!r}>"


class Follow(Base):
    __tablename__ = "follows"

    follower_id = Column(
        BIGINT_ID,
        ForeignKey("users.user_id", ondelete="CASCADE"),
        primary_key=True,
    )
    following_id = Column(
        BIGINT_ID,
        ForeignKey("users.user_id", ondelete="CASCADE"),
        primary_key=True,
    )
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    def __repr__(self) -> str:
        return f"<Follow follower_id={self.follower_id!r} following_id={self.following_id!r}>"
