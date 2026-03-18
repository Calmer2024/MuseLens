"""
Router 会话状态持久化模型（SessionState）。

用于支持多轮对话、跨进程/多实例的 Router 编排。
"""

from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import Column, DateTime, String, Text
from sqlalchemy.types import JSON

from app.core.db_base import Base


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class RouterSessionRecord(Base):
    __tablename__ = "router_sessions"

    session_id = Column(String, primary_key=True, index=True, comment="Router 会话 ID")
    user_id = Column(String, index=True, nullable=False, comment="用户 ID")

    original_prompt = Column(Text, default="", comment="首轮原始需求")
    base_image = Column(Text, default="", comment="首轮 base_image（资产名/路径）")

    # 未来会扩展更丰富的图片元信息（尺寸、来源、hash 等）
    base_image_meta = Column(JSON, default=dict, comment="base_image 元信息（JSON）")

    history_summary = Column(Text, default="", comment="历史对话摘要（供检索/规划）")

    # 编排与追问相关状态（JSON）
    lens_history = Column(JSON, default=list, comment="已执行 Lens 及结果概要（JSON）")
    pending_blueprint = Column(JSON, default=None, comment="待执行/待补齐的 Blueprint（JSON）")
    pending_questions = Column(JSON, default=list, comment="待回答的追问列表（JSON）")
    collected_params = Column(JSON, default=dict, comment="已收集参数（JSON）")

    created_at = Column(DateTime(timezone=True), default=_utcnow)
    updated_at = Column(DateTime(timezone=True), default=_utcnow, onupdate=_utcnow)

    def __repr__(self) -> str:
        return f"<RouterSessionRecord session_id={self.session_id!r} user_id={self.user_id!r}>"

