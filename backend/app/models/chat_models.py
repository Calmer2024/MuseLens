"""
好友聊天相关 ORM 模型。

当前实现聚焦一对一私聊场景，核心表包括：
- chat_conversations：会话主表
- chat_conversation_states：用户在会话中的已读状态
- chat_messages：消息表，支持文本、帖子分享、预设分享
"""

from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import CheckConstraint, Column, DateTime, ForeignKey, String, Text, UniqueConstraint, func

from app.core.db_base import Base
from app.models.sql_types import BIGINT_ID, JSON_DOC


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class ChatConversation(Base):
    __tablename__ = "chat_conversations"

    conversation_id = Column(BIGINT_ID, primary_key=True, autoincrement=True)
    user_low_id = Column(
        BIGINT_ID,
        ForeignKey("users.user_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
        comment="会话参与者中较小的用户 ID",
    )
    user_high_id = Column(
        BIGINT_ID,
        ForeignKey("users.user_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
        comment="会话参与者中较大的用户 ID",
    )
    last_message_id = Column(BIGINT_ID, nullable=True, comment="最后一条消息 ID")
    last_message_at = Column(DateTime(timezone=True), nullable=True, index=True, comment="最后发言时间")
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=_utcnow,
        nullable=False,
    )

    __table_args__ = (
        UniqueConstraint("user_low_id", "user_high_id", name="uq_chat_conversation_pair"),
        CheckConstraint("user_low_id < user_high_id", name="chk_chat_conversation_pair_order"),
    )


class ChatConversationState(Base):
    __tablename__ = "chat_conversation_states"

    conversation_id = Column(
        BIGINT_ID,
        ForeignKey("chat_conversations.conversation_id", ondelete="CASCADE"),
        primary_key=True,
    )
    user_id = Column(
        BIGINT_ID,
        ForeignKey("users.user_id", ondelete="CASCADE"),
        primary_key=True,
    )
    last_read_message_id = Column(BIGINT_ID, nullable=True, comment="该用户已读到的最后一条消息 ID")
    last_read_at = Column(DateTime(timezone=True), nullable=True, comment="最近一次已读时间")
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=_utcnow,
        nullable=False,
    )


class ChatMessage(Base):
    __tablename__ = "chat_messages"

    message_id = Column(BIGINT_ID, primary_key=True, autoincrement=True)
    conversation_id = Column(
        BIGINT_ID,
        ForeignKey("chat_conversations.conversation_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    sender_id = Column(
        BIGINT_ID,
        ForeignKey("users.user_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
        comment="发送者用户 ID",
    )
    message_type = Column(String(20), default="text", nullable=False, comment="消息类型")
    content = Column(Text, default="", nullable=False, comment="文本消息内容")
    share_type = Column(String(20), nullable=True, comment="分享类型")
    share_source_type = Column(String(20), nullable=True, comment="分享来源类型")
    share_resource_id = Column(String(64), nullable=True, comment="分享资源主键")
    share_payload = Column(JSON_DOC, nullable=True, comment="分享卡片快照")
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    __table_args__ = (
        CheckConstraint(
            "message_type IN ('text', 'share', 'text_share')",
            name="chk_chat_message_type",
        ),
        CheckConstraint(
            "share_type IS NULL OR share_type IN ('post', 'preset')",
            name="chk_chat_share_type",
        ),
        CheckConstraint(
            "share_source_type IS NULL OR share_source_type IN ('community_post', 'market_lens', 'asset_node')",
            name="chk_chat_share_source_type",
        ),
        CheckConstraint(
            "("
            "share_type IS NULL AND share_source_type IS NULL AND share_resource_id IS NULL"
            ") OR ("
            "share_type IS NOT NULL AND share_source_type IS NOT NULL AND share_resource_id IS NOT NULL"
            ")",
            name="chk_chat_share_fields",
        ),
    )
