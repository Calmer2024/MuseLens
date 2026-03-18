"""
Lens 示例用法（few-shot）数据表。

每条记录描述一个典型自然语言需求与对应的参数示例，供 Planner 做 RAG few-shot。
"""

from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import Column, DateTime, Integer, String, Text
from sqlalchemy.types import JSON

from app.core.db_base import Base


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class LensExampleRecord(Base):
    __tablename__ = "lens_examples"

    id = Column(Integer, primary_key=True, autoincrement=True)
    lens_id = Column(String, index=True, nullable=False, comment="关联 lens_id")

    nl_desc = Column(Text, default="", comment="自然语言描述（示例场景）")
    params_example = Column(JSON, default=dict, comment="参数示例（JSON）")

    created_at = Column(DateTime(timezone=True), default=_utcnow)

    def __repr__(self) -> str:
        return f"<LensExampleRecord id={self.id!r} lens_id={self.lens_id!r}>"

