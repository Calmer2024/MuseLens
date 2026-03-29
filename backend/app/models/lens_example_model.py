"""ORM model for lens few-shot examples."""

from sqlalchemy import Column, DateTime, Integer, String, Text, func

from app.core.db_base import Base
from app.models.sql_types import JSON_DOC


class LensExampleRecord(Base):
    __tablename__ = "lens_examples"

    id = Column(Integer, primary_key=True, autoincrement=True)
    lens_id = Column(String(100), index=True, nullable=False, comment="Lens ID")

    nl_desc = Column(Text, default="", nullable=False, comment="Natural-language example")
    params_example = Column(
        JSON_DOC,
        default=dict,
        nullable=False,
        comment="Example params payload",
    )

    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    def __repr__(self) -> str:
        return f"<LensExampleRecord id={self.id!r} lens_id={self.lens_id!r}>"
