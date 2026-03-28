"""ORM model for registered lenses."""

from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import Column, DateTime, String, Text, func

from app.core.db_base import Base
from app.models.sql_types import JSON_DOC


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class LensRecord(Base):
    __tablename__ = "lenses"

    lens_id = Column(String(100), primary_key=True, index=True, comment="Lens ID")
    layer = Column(String(8), nullable=False, comment="Lens layer A1-A5")
    description = Column(Text, default="", nullable=False, comment="Lens description")
    workflow_file_path = Column(
        String(500),
        nullable=False,
        comment="Absolute workflow path or file name under backend/lens",
    )

    inputs = Column(JSON_DOC, default=list, nullable=False, comment="Input slots")
    outputs = Column(JSON_DOC, default=list, nullable=False, comment="Output slots")
    params = Column(JSON_DOC, default=list, nullable=False, comment="Parameter slots")

    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=_utcnow,
        nullable=False,
    )

    def __repr__(self) -> str:
        return f"<LensRecord lens_id={self.lens_id!r} layer={self.layer!r}>"
