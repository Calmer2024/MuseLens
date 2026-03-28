"""
透镜市场相关 ORM 模型。

说明：
- 现有后端已经使用 `lenses` 表承载运行时 Lens 注册表
- 为避免与运行时编排体系冲突，这里市场模块采用独立表名

本文件实现数据库设计文档中“透镜市场”对应能力的后端落地：
- market_lenses
- market_lens_versions
- user_lenses
- lens_favorites
- lens_reviews
"""

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
)

from app.core.db_base import Base
from app.models.sql_types import BIGINT_ID, JSON_DOC


class MarketLens(Base):
    __tablename__ = "market_lenses"

    lens_id = Column(BIGINT_ID, primary_key=True, autoincrement=True)
    lens_key = Column(String(100), unique=True, nullable=False, index=True, comment="透镜唯一键")
    name = Column(String(100), nullable=False, comment="透镜名称")
    description = Column(Text, default="", nullable=False, comment="透镜描述")
    author_id = Column(BIGINT_ID, ForeignKey("users.user_id", ondelete="SET NULL"), nullable=True, index=True)
    category = Column(String(50), nullable=True, index=True, comment="透镜分类")
    price = Column(Numeric(10, 2), default=0.00, nullable=False, comment="价格")
    is_official = Column(Boolean, default=False, nullable=False, comment="是否官方透镜")
    install_count = Column(Integer, default=0, nullable=False, comment="安装次数")
    rating = Column(Numeric(3, 2), default=0.00, nullable=False, comment="平均评分")
    rating_count = Column(Integer, default=0, nullable=False, comment="评分人数")
    status = Column(String(20), default="active", nullable=False, comment="状态")
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    __table_args__ = (
        CheckConstraint("status IN ('active', 'deprecated', 'removed')", name="chk_market_lens_status"),
    )


class MarketLensVersion(Base):
    __tablename__ = "market_lens_versions"

    version_id = Column(BIGINT_ID, primary_key=True, autoincrement=True)
    lens_id = Column(BIGINT_ID, ForeignKey("market_lenses.lens_id", ondelete="CASCADE"), nullable=False, index=True)
    version = Column(String(20), nullable=False, comment="版本号")
    base_workflow = Column(JSON_DOC, nullable=False, comment="基础工作流")
    parameters = Column(JSON_DOC, nullable=False, comment="参数定义")
    ui_schema = Column(JSON_DOC, nullable=False, comment="前端 UI Schema")
    changelog = Column(Text, default="", nullable=False, comment="更新日志")
    is_latest = Column(Boolean, default=False, nullable=False, comment="是否最新版本")
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    __table_args__ = (
        UniqueConstraint("lens_id", "version", name="uq_market_lens_version"),
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
