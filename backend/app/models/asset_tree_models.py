"""
树状资产管理 ORM 模型

对应概念（见文档《树状资产管理-完整技术方案.md》）：
  - Project    : 修图项目，是整棵树的根容器
  - AssetNode  : 资产节点，对应一个图片版本（原图/生成图）
  - AssetEdge  : 操作边，连接两个节点，记录从父到子使用的透镜与参数
  - NodeTag    : 节点标签，允许用户为重要节点打上语义标签

设计决策：
  - 主键全部使用 UUID 字符串，与 PostgreSQL 方案保持兼容
  - path_json：从根节点到当前节点的有序 ID 数组（JSON 字符串），用于 O(1) 祖先查询
  - muse_dna / parameters 等 JSONB 字段在 SQLite 中以 TEXT 存储，
    应用层负责 json.loads / json.dumps
  - 使用软删除标记（is_deleted）而非物理删除，保证历史可追溯
"""

import uuid
from datetime import datetime, timezone
from sqlalchemy import (
    Column, String, Text, Integer, BigInteger,
    DateTime, Boolean, ForeignKey, UniqueConstraint, CheckConstraint,
)
from app.core.database import Base


def _new_uuid() -> str:
    return str(uuid.uuid4())


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


# ============================================================
# Project — 修图项目
# ============================================================

class Project(Base):
    """
    修图项目表。

    一个项目对应一棵资产树。根节点（root_node_id）上传后不可更改；
    current_node_id 记录用户当前聚焦的节点，用于编辑器恢复现场。
    """
    __tablename__ = "projects"

    project_id      = Column(String(36), primary_key=True, default=_new_uuid)
    name            = Column(String(200), nullable=False, comment="项目名称")
    description     = Column(Text, default="", comment="项目描述")
    cover_url       = Column(String(500), nullable=True, comment="封面图 URL（通常为根节点图片）")

    # 树结构关键引用（延迟外键，避免循环引用问题）
    root_node_id    = Column(String(36), nullable=True,
                             comment="根节点 ID，创建项目时上传原图后赋值")
    current_node_id = Column(String(36), nullable=True,
                             comment="当前活跃节点 ID，编辑器聚焦位置")

    # 统计缓存字段（写入节点时同步更新）
    node_count      = Column(Integer, default=0, comment="总节点数")
    branch_count    = Column(Integer, default=0, comment="产生分支的节点数")

    created_at      = Column(DateTime(timezone=True), default=_utcnow)
    updated_at      = Column(DateTime(timezone=True), default=_utcnow, onupdate=_utcnow)

    def __repr__(self) -> str:
        return f"<Project id={self.project_id!r} name={self.name!r}>"


# ============================================================
# AssetNode — 资产节点
# ============================================================

class AssetNode(Base):
    """
    资产节点表。

    每一行代表资产树中的一个图片版本。
    树结构通过 AssetEdge 维护；path_json 作为冗余字段加速祖先查询。

    path_json 格式（JSON 字符串）：
      '["root_id", "parent_id", "this_node_id"]'
    """
    __tablename__ = "asset_nodes"

    node_id         = Column(String(36), primary_key=True, default=_new_uuid)
    project_id      = Column(
        String(36),
        ForeignKey("projects.project_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # 图片资源
    image_url       = Column(String(500), nullable=False, comment="完整图片 URL")
    thumbnail_url   = Column(String(500), nullable=True, comment="缩略图 URL")

    # 节点类型
    node_type       = Column(
        String(20), default="generated",
        comment="original=用户上传原图, generated=AI生成图, uploaded=参考图"
    )

    # 图片元信息
    width           = Column(Integer, nullable=True)
    height          = Column(Integer, nullable=True)
    file_size       = Column(BigInteger, nullable=True, comment="文件字节数")
    format          = Column(String(10), nullable=True, comment="jpg/png/webp 等")

    # AI 生成信息（JSON 字符串）
    muse_dna_json        = Column(Text, nullable=True, comment="生成该节点所用的完整 MuseDNA")
    generation_params_json = Column(Text, nullable=True, comment="具体生成参数，便于前端展示")

    # 树结构辅助字段
    depth           = Column(Integer, default=0, comment="节点深度，根节点为 0")
    path_json       = Column(
        Text, default="[]",
        comment="从根节点到本节点的有序 node_id 数组（含自身），JSON 字符串"
    )

    # 状态
    status          = Column(
        String(20), default="completed",
        comment="generating=生成中, completed=已完成, failed=失败"
    )

    # 用户可见标签（快捷备注，区别于 NodeTag 的结构化标签）
    label           = Column(String(100), nullable=True, comment="用户快捷备注，如'最终版'")

    # 其它元数据（JSON 字符串，存 EXIF、AI 分析结果等）
    metadata_json   = Column(Text, nullable=True)

    created_at      = Column(DateTime(timezone=True), default=_utcnow)

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


# ============================================================
# AssetEdge — 修图操作边
# ============================================================

class AssetEdge(Base):
    """
    操作边表。

    记录从 source_node（父图）到 target_node（子图）所使用的透镜、参数和提示词。
    与 AssetNode 共同构成有向无环图（DAG）。

    约束：
      - UNIQUE(source_node_id, target_node_id)：同一对父子节点只能有一条边
      - source_node_id != target_node_id：禁止自环
    """
    __tablename__ = "asset_edges"

    edge_id         = Column(String(36), primary_key=True, default=_new_uuid)
    project_id      = Column(
        String(36),
        ForeignKey("projects.project_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # 边的两端
    source_node_id  = Column(
        String(36),
        ForeignKey("asset_nodes.node_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    target_node_id  = Column(
        String(36),
        ForeignKey("asset_nodes.node_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # 操作信息
    lens_id         = Column(String(100), nullable=True,
                             comment="使用的透镜 ID（对应 lenses 表的 lens_id）")
    lens_name       = Column(String(100), nullable=True,
                             comment="透镜名称冗余存储，防止透镜删除后无法追溯")

    # 用户输入
    user_prompt     = Column(Text, nullable=True, comment="用户输入的自然语言指令")

    # 参数与 MuseDNA（JSON 字符串）
    parameters_json = Column(Text, default="{}", comment="具体参数值")
    muse_dna_json   = Column(Text, nullable=True, comment="完整 DAGBlueprint 快照")

    # 执行信息
    execution_time_ms = Column(Integer, nullable=True, comment="ComfyUI 执行时长（毫秒）")
    task_id           = Column(String(36), nullable=True, comment="关联的生成任务 ID")

    created_at      = Column(DateTime(timezone=True), default=_utcnow)

    __table_args__ = (
        UniqueConstraint("source_node_id", "target_node_id", name="uq_edge_endpoints"),
        CheckConstraint("source_node_id != target_node_id", name="chk_no_self_loop"),
    )

    def __repr__(self) -> str:
        return (
            f"<AssetEdge id={self.edge_id!r} "
            f"{self.source_node_id!r} → {self.target_node_id!r}>"
        )


# ============================================================
# NodeTag — 节点标签
# ============================================================

class NodeTag(Base):
    """
    节点标签表。

    允许用户为重要节点打上颜色+文字标签，例如"最终版"、"客户审核"等。
    一个节点可以有多个标签。
    """
    __tablename__ = "node_tags"

    tag_id      = Column(String(36), primary_key=True, default=_new_uuid)
    node_id     = Column(
        String(36),
        ForeignKey("asset_nodes.node_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    label       = Column(String(50), nullable=False, comment="标签文字，如'最终版'")
    color       = Column(String(7), default="#4A90E2", comment="标签颜色 HEX，如'#FF6B6B'")
    created_at  = Column(DateTime(timezone=True), default=_utcnow)

    def __repr__(self) -> str:
        return f"<NodeTag id={self.tag_id!r} node={self.node_id!r} label={self.label!r}>"
