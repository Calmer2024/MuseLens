"""ORM models for the asset tree subsystem."""

from __future__ import annotations

import uuid
from datetime import datetime, timezone

from sqlalchemy import (
    BigInteger,
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
from app.models.sql_types import JSON_DOC, UUID_ARRAY, UUID_STR


def _new_uuid() -> str:
    return str(uuid.uuid4())


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class Project(Base):
    __tablename__ = "projects"

    project_id = Column(UUID_STR, primary_key=True, default=_new_uuid)
    name = Column(String(200), nullable=False, comment="Project name")
    description = Column(Text, default="", nullable=False, comment="Project description")
    cover_url = Column(String(500), nullable=True, comment="Cover image URL")

    root_node_id = Column(UUID_STR, nullable=True, comment="Root node ID")
    current_node_id = Column(UUID_STR, nullable=True, comment="Current node ID")

    node_count = Column(Integer, default=0, nullable=False, comment="Node count")
    branch_count = Column(Integer, default=0, nullable=False, comment="Branch count")

    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=_utcnow,
        nullable=False,
    )

    def __repr__(self) -> str:
        return f"<Project id={self.project_id!r} name={self.name!r}>"


class AssetNode(Base):
    __tablename__ = "asset_nodes"

    node_id = Column(UUID_STR, primary_key=True, default=_new_uuid)
    project_id = Column(
        UUID_STR,
        ForeignKey("projects.project_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    image_url = Column(String(500), nullable=False, comment="Full image URL")
    thumbnail_url = Column(String(500), nullable=True, comment="Thumbnail URL")

    node_type = Column(String(20), default="generated", nullable=False)
    width = Column(Integer, nullable=True)
    height = Column(Integer, nullable=True)
    file_size = Column(BigInteger, nullable=True)
    format = Column(String(10), nullable=True)

    muse_dna = Column(JSON_DOC, nullable=True, comment="Stored DAG blueprint snapshot")
    generation_params = Column(JSON_DOC, nullable=True, comment="Generation parameter summary")

    depth = Column(Integer, default=0, nullable=False)
    path = Column(UUID_ARRAY, default=list, nullable=False, comment="Path from root to this node")

    status = Column(String(20), default="completed", nullable=False)
    label = Column(String(100), nullable=True)
    extra_metadata = Column("metadata", JSON_DOC, nullable=True)

    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    __table_args__ = (
        CheckConstraint(
            "node_type IN ('original', 'generated', 'uploaded')",
            name="chk_asset_node_type",
        ),
        CheckConstraint(
            "status IN ('generating', 'completed', 'failed')",
            name="chk_asset_node_status",
        ),
    )

    def __repr__(self) -> str:
        return f"<AssetNode id={self.node_id!r} type={self.node_type!r} depth={self.depth}>"


class AssetEdge(Base):
    __tablename__ = "asset_edges"

    edge_id = Column(UUID_STR, primary_key=True, default=_new_uuid)
    project_id = Column(
        UUID_STR,
        ForeignKey("projects.project_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    source_node_id = Column(
        UUID_STR,
        ForeignKey("asset_nodes.node_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    target_node_id = Column(
        UUID_STR,
        ForeignKey("asset_nodes.node_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    lens_id = Column(String(100), nullable=True)
    lens_name = Column(String(100), nullable=True)
    user_prompt = Column(Text, nullable=True)
    parameters = Column(JSON_DOC, default=dict, nullable=False)
    muse_dna = Column(JSON_DOC, nullable=True)

    execution_time_ms = Column(Integer, nullable=True)
    task_id = Column(UUID_STR, nullable=True)

    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    __table_args__ = (
        UniqueConstraint("source_node_id", "target_node_id", name="uq_edge_endpoints"),
        CheckConstraint("source_node_id != target_node_id", name="chk_no_self_loop"),
    )

    def __repr__(self) -> str:
        return f"<AssetEdge id={self.edge_id!r} {self.source_node_id!r}->{self.target_node_id!r}>"


class NodeTag(Base):
    __tablename__ = "node_tags"

    tag_id = Column(UUID_STR, primary_key=True, default=_new_uuid)
    node_id = Column(
        UUID_STR,
        ForeignKey("asset_nodes.node_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    label = Column(String(50), nullable=False)
    color = Column(String(7), default="#4A90E2", nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    def __repr__(self) -> str:
        return f"<NodeTag id={self.tag_id!r} node={self.node_id!r} label={self.label!r}>"
