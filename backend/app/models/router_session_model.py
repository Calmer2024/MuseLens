"""ORM model for persisted router sessions."""

from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import Column, DateTime, String, Text, func

from app.core.db_base import Base
from app.models.sql_types import JSON_DOC


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class RouterSessionRecord(Base):
    __tablename__ = "router_sessions"

    session_id = Column(String(36), primary_key=True, index=True, comment="Session ID")
    user_id = Column(String(100), index=True, nullable=False, comment="User ID")

    original_prompt = Column(Text, default="", nullable=False)
    base_image = Column(Text, default="", nullable=False)
    base_image_meta = Column(JSON_DOC, default=dict, nullable=False)

    history_summary = Column(Text, default="", nullable=False)
    lens_history = Column(JSON_DOC, default=list, nullable=False)
    pending_blueprint = Column(JSON_DOC, default=None, nullable=True)
    pending_questions = Column(JSON_DOC, default=list, nullable=False)
    collected_params = Column(JSON_DOC, default=dict, nullable=False)

    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=_utcnow,
        nullable=False,
    )

    def __repr__(self) -> str:
        return f"<RouterSessionRecord session_id={self.session_id!r} user_id={self.user_id!r}>"
