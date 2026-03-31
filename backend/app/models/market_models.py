"""
模板市场相关 ORM 模型。

当前模块虽然历史文件名仍叫 market_models，但业务语义已经切换为“模板市场”：
- 市场里的卡片本质上是用户分享的修图模板
- 模板卡片需要保存原图、结果图、作者信息、MuseDNA 与展示信息
- 模板可以按标签筛选、搜索、收藏，也可以直接应用到新的图片上

兼容性说明：
- 旧字段 `lens_id / lens_key / name` 仍保留，避免影响既有接口与测试
- 新接口会把它们解释为 `template_id / template_key / title`
"""

from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Column,
    DateTime,
    ForeignKey,
    Integer,
    Numeric,
    String,
    Text,
    UniqueConstraint,
    func,
    inspect,
    text,
)
from sqlalchemy.engine import Engine

from app.core.db_base import Base
from app.models.sql_types import BIGINT_ID, JSON_DOC, UUID_STR


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class MarketLens(Base):
    __tablename__ = "market_lenses"

    lens_id = Column(BIGINT_ID, primary_key=True, autoincrement=True)
    lens_key = Column(String(100), unique=True, nullable=False, index=True, comment="模板唯一键")
    name = Column(String(100), nullable=False, comment="模板标题")
    description = Column(Text, default="", nullable=False, comment="模板说明")
    author_id = Column(BIGINT_ID, ForeignKey("users.user_id", ondelete="SET NULL"), nullable=True, index=True)
    category = Column(String(50), nullable=True, index=True, comment="主分类")
    price = Column(Numeric(10, 2), default=0.00, nullable=False, comment="保留字段：价格")
    is_official = Column(Boolean, default=False, nullable=False, comment="是否官方模板")

    cover_image_url = Column(String(500), nullable=True, comment="模板卡片封面图，通常取结果图或其缩略图")
    preview_asset_node_id = Column(UUID_STR, nullable=True, index=True, comment="预览节点 ID，兼容旧字段")

    original_image_url = Column(String(500), nullable=True, comment="模板原图地址")
    original_thumbnail_url = Column(String(500), nullable=True, comment="模板原图缩略图")
    result_image_url = Column(String(500), nullable=True, comment="模板结果图地址")
    result_thumbnail_url = Column(String(500), nullable=True, comment="模板结果图缩略图")
    source_project_id = Column(UUID_STR, nullable=True, index=True, comment="来源项目 ID")
    source_root_node_id = Column(UUID_STR, nullable=True, index=True, comment="来源原图节点 ID")
    result_asset_node_id = Column(UUID_STR, nullable=True, index=True, comment="来源结果节点 ID")

    install_count = Column(Integer, default=0, nullable=False, comment="保留字段：安装次数")
    apply_count = Column(Integer, default=0, nullable=False, comment="模板被直接应用次数")
    favorite_count = Column(Integer, default=0, nullable=False, comment="模板被收藏次数")
    rating = Column(Numeric(3, 2), default=0.00, nullable=False, comment="平均评分")
    rating_count = Column(Integer, default=0, nullable=False, comment="评分人数")
    status = Column(String(20), default="active", nullable=False, comment="状态")
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=_utcnow,
        nullable=False,
    )

    __table_args__ = (
        CheckConstraint("status IN ('active', 'deprecated', 'removed')", name="chk_market_lens_status"),
    )


class MarketLensVersion(Base):
    __tablename__ = "market_lens_versions"

    version_id = Column(BIGINT_ID, primary_key=True, autoincrement=True)
    lens_id = Column(BIGINT_ID, ForeignKey("market_lenses.lens_id", ondelete="CASCADE"), nullable=False, index=True)
    version = Column(String(20), nullable=False, comment="版本号")

    # 兼容旧结构，保留这三块字段；新语义下主要用于前端展示与微调面板定义
    base_workflow = Column(JSON_DOC, default=dict, nullable=False, comment="旧版工作流摘要")
    parameters = Column(JSON_DOC, default=dict, nullable=False, comment="可调参数定义")
    ui_schema = Column(JSON_DOC, default=dict, nullable=False, comment="前端 UI Schema")

    blueprint = Column(JSON_DOC, nullable=True, comment="模板对应的可复用 MuseDNA / DAGBlueprint 快照")
    required_inputs = Column(JSON_DOC, default=list, nullable=False, comment="应用模板时所需的输入槽位")
    source_asset_node_id = Column(UUID_STR, nullable=True, index=True, comment="来源结果资产节点 ID")
    source_episode_id = Column(BIGINT_ID, nullable=True, index=True, comment="来源编辑片段 ID")
    published_from = Column(String(20), default="manual", nullable=False, comment="发布来源")

    changelog = Column(Text, default="", nullable=False, comment="更新日志")
    is_latest = Column(Boolean, default=False, nullable=False, comment="是否当前最新版本")
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    __table_args__ = (
        UniqueConstraint("lens_id", "version", name="uq_market_lens_version"),
        CheckConstraint(
            "published_from IN ('manual', 'asset_node', 'editor_episode', 'router_result')",
            name="chk_market_lens_version_source",
        ),
    )


class UserLens(Base):
    __tablename__ = "user_lenses"

    user_id = Column(BIGINT_ID, ForeignKey("users.user_id", ondelete="CASCADE"), primary_key=True)
    lens_id = Column(BIGINT_ID, ForeignKey("market_lenses.lens_id", ondelete="CASCADE"), primary_key=True)
    version_id = Column(BIGINT_ID, ForeignKey("market_lens_versions.version_id", ondelete="CASCADE"), nullable=False)
    installed_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class LensFavorite(Base):
    __tablename__ = "lens_favorites"

    user_id = Column(BIGINT_ID, ForeignKey("users.user_id", ondelete="CASCADE"), primary_key=True)
    lens_id = Column(BIGINT_ID, ForeignKey("market_lenses.lens_id", ondelete="CASCADE"), primary_key=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class LensReview(Base):
    __tablename__ = "lens_reviews"

    review_id = Column(BIGINT_ID, primary_key=True, autoincrement=True)
    lens_id = Column(BIGINT_ID, ForeignKey("market_lenses.lens_id", ondelete="CASCADE"), nullable=False, index=True)
    user_id = Column(BIGINT_ID, ForeignKey("users.user_id", ondelete="CASCADE"), nullable=False, index=True)
    rating = Column(Integer, nullable=False, comment="评分")
    content = Column(Text, default="", nullable=False, comment="评价内容")
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    __table_args__ = (
        UniqueConstraint("lens_id", "user_id", name="uq_lens_review_user"),
        CheckConstraint("rating BETWEEN 1 AND 5", name="chk_lens_review_rating"),
    )


class MarketTag(Base):
    __tablename__ = "market_tags"

    tag_id = Column(BIGINT_ID, primary_key=True, autoincrement=True)
    name = Column(String(50), unique=True, nullable=False, index=True, comment="模板标签名")
    description = Column(Text, default="", nullable=False, comment="标签说明")
    template_count = Column(Integer, default=0, nullable=False, comment="关联模板数")
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)


class MarketLensTag(Base):
    __tablename__ = "market_lens_tags"

    lens_id = Column(BIGINT_ID, ForeignKey("market_lenses.lens_id", ondelete="CASCADE"), primary_key=True)
    tag_id = Column(BIGINT_ID, ForeignKey("market_tags.tag_id", ondelete="CASCADE"), primary_key=True)

    __table_args__ = (
        UniqueConstraint("lens_id", "tag_id", name="uq_market_lens_tag"),
    )


def ensure_market_schema(engine: Engine) -> None:
    """
    兼容已存在数据库。

    当前项目仍以 `create_all()` 为主，没有完整迁移框架，
    所以这里补一个轻量级 schema 同步，确保旧库也能补齐模板市场字段。
    """

    inspector = inspect(engine)
    tables = set(inspector.get_table_names())
    dialect = engine.dialect.name
    json_type = "JSONB" if dialect == "postgresql" else "JSON"
    bigint_type = "BIGINT" if dialect == "postgresql" else "INTEGER"

    with engine.begin() as conn:
        if "market_lenses" in tables:
            columns = {item["name"] for item in inspector.get_columns("market_lenses")}
            if "cover_image_url" not in columns:
                conn.execute(text("ALTER TABLE market_lenses ADD COLUMN cover_image_url VARCHAR(500)"))
            if "preview_asset_node_id" not in columns:
                conn.execute(text("ALTER TABLE market_lenses ADD COLUMN preview_asset_node_id VARCHAR(36)"))
            if "apply_count" not in columns:
                conn.execute(text("ALTER TABLE market_lenses ADD COLUMN apply_count INTEGER NOT NULL DEFAULT 0"))
            if "favorite_count" not in columns:
                conn.execute(text("ALTER TABLE market_lenses ADD COLUMN favorite_count INTEGER NOT NULL DEFAULT 0"))
            if "original_image_url" not in columns:
                conn.execute(text("ALTER TABLE market_lenses ADD COLUMN original_image_url VARCHAR(500)"))
            if "original_thumbnail_url" not in columns:
                conn.execute(text("ALTER TABLE market_lenses ADD COLUMN original_thumbnail_url VARCHAR(500)"))
            if "result_image_url" not in columns:
                conn.execute(text("ALTER TABLE market_lenses ADD COLUMN result_image_url VARCHAR(500)"))
            if "result_thumbnail_url" not in columns:
                conn.execute(text("ALTER TABLE market_lenses ADD COLUMN result_thumbnail_url VARCHAR(500)"))
            if "source_project_id" not in columns:
                conn.execute(text("ALTER TABLE market_lenses ADD COLUMN source_project_id VARCHAR(36)"))
            if "source_root_node_id" not in columns:
                conn.execute(text("ALTER TABLE market_lenses ADD COLUMN source_root_node_id VARCHAR(36)"))
            if "result_asset_node_id" not in columns:
                conn.execute(text("ALTER TABLE market_lenses ADD COLUMN result_asset_node_id VARCHAR(36)"))

        if "market_lens_versions" in tables:
            columns = {item["name"] for item in inspector.get_columns("market_lens_versions")}
            if "blueprint" not in columns:
                conn.execute(text(f"ALTER TABLE market_lens_versions ADD COLUMN blueprint {json_type}"))
            if "required_inputs" not in columns:
                conn.execute(text(f"ALTER TABLE market_lens_versions ADD COLUMN required_inputs {json_type}"))
            if "source_asset_node_id" not in columns:
                conn.execute(text("ALTER TABLE market_lens_versions ADD COLUMN source_asset_node_id VARCHAR(36)"))
            if "source_episode_id" not in columns:
                conn.execute(text(f"ALTER TABLE market_lens_versions ADD COLUMN source_episode_id {bigint_type}"))
            if "published_from" not in columns:
                conn.execute(
                    text(
                        "ALTER TABLE market_lens_versions "
                        "ADD COLUMN published_from VARCHAR(20) NOT NULL DEFAULT 'manual'"
                    )
                )

