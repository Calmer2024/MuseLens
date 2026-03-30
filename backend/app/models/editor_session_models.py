"""
编辑片段树相关 ORM 模型。

本模块用于把“修图对话历史”和“资产树版本历史”融合为统一的后端数据结构：
- editor_sessions：项目级编辑会话
- editor_episodes：一轮完整的编辑片段
- editor_episode_messages：片段内的消息记录
"""

from __future__ import annotations

import uuid
from datetime import datetime, timezone

from sqlalchemy import CheckConstraint, Column, DateTime, ForeignKey, Integer, String, Text, func

from app.core.db_base import Base
from app.models.sql_types import BIGINT_ID, JSON_DOC, UUID_STR


def _new_uuid() -> str:
    return str(uuid.uuid4())


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class EditorSession(Base):
    __tablename__ = "editor_sessions"

    session_id = Column(UUID_STR, primary_key=True, default=_new_uuid)
    project_id = Column(
        UUID_STR,
        ForeignKey("projects.project_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
        comment="所属项目 ID",
    )
    title = Column(String(120), nullable=False, comment="编辑会话标题")
    description = Column(Text, default="", nullable=False, comment="编辑会话描述")
    base_node_id = Column(
        UUID_STR,
        ForeignKey("asset_nodes.node_id", ondelete="SET NULL"),
        nullable=True,
        index=True,
        comment="会话起点节点 ID",
    )
    current_episode_id = Column(BIGINT_ID, nullable=True, comment="当前焦点片段 ID")
    episode_count = Column(Integer, default=0, nullable=False, comment="片段数量")
    branch_count = Column(Integer, default=0, nullable=False, comment="分叉点数量")
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=_utcnow,
        nullable=False,
    )


class EditorEpisode(Base):
    __tablename__ = "editor_episodes"

    episode_id = Column(BIGINT_ID, primary_key=True, autoincrement=True)
    session_id = Column(
        UUID_STR,
        ForeignKey("editor_sessions.session_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
        comment="所属编辑会话 ID",
    )
    parent_episode_id = Column(
        BIGINT_ID,
        ForeignKey("editor_episodes.episode_id", ondelete="SET NULL"),
        nullable=True,
        index=True,
        comment="父片段 ID",
    )
    source_node_id = Column(
        UUID_STR,
        ForeignKey("asset_nodes.node_id", ondelete="SET NULL"),
        nullable=True,
        index=True,
        comment="本轮编辑开始时所依附的资产节点",
    )
    target_node_id = Column(
        UUID_STR,
        ForeignKey("asset_nodes.node_id", ondelete="SET NULL"),
        nullable=True,
        index=True,
        comment="本轮编辑产生的结果节点",
    )
    round_index = Column(Integer, default=1, nullable=False, comment="片段轮次")
    branch_name = Column(String(50), default="主线", nullable=False, comment="分支名称")
    title = Column(String(120), nullable=False, comment="片段标题")
    user_intent = Column(Text, default="", nullable=False, comment="用户意图")
    assistant_plan = Column(Text, default="", nullable=False, comment="AI 响应计划")
    action_summary = Column(Text, default="", nullable=False, comment="本轮结果摘要")
    tags = Column(JSON_DOC, default=list, nullable=False, comment="标签列表")
    action_items = Column(JSON_DOC, default=list, nullable=False, comment="动作摘要列表")
    tool_snapshot = Column(JSON_DOC, default=dict, nullable=False, comment="工具/参数快照")
    extra_metadata = Column("metadata", JSON_DOC, default=dict, nullable=False, comment="扩展元数据")
    message_count = Column(Integer, default=0, nullable=False, comment="片段消息数")
    status = Column(String(20), default="draft", nullable=False, comment="片段状态")
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=_utcnow,
        nullable=False,
    )

    __table_args__ = (
        CheckConstraint("status IN ('draft', 'completed', 'archived')", name="chk_editor_episode_status"),
    )


class EditorEpisodeMessage(Base):
    __tablename__ = "editor_episode_messages"

    message_id = Column(BIGINT_ID, primary_key=True, autoincrement=True)
    episode_id = Column(
        BIGINT_ID,
        ForeignKey("editor_episodes.episode_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
        comment="所属片段 ID",
    )
    role = Column(String(20), default="user", nullable=False, comment="消息角色")
    message_kind = Column(String(20), default="note", nullable=False, comment="消息类型")
    content = Column(Text, default="", nullable=False, comment="消息内容")
    payload = Column(JSON_DOC, nullable=True, comment="结构化消息负载")
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    __table_args__ = (
        CheckConstraint("role IN ('user', 'assistant', 'system')", name="chk_editor_episode_message_role"),
        CheckConstraint(
            "message_kind IN ('intent', 'plan', 'decision', 'note', 'system_event')",
            name="chk_editor_episode_message_kind",
        ),
    )
