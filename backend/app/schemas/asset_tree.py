"""
树状资产管理 Pydantic 模型

分为三类：
  - Request  : 接收前端/调用方传入的数据
  - Response : 返回给前端/调用方的数据
  - Internal : 服务层内部传递使用的数据容器
"""

from __future__ import annotations

from datetime import datetime
from typing import Any, Dict, List, Optional

from pydantic import BaseModel, Field


# ============================================================
# 通用基础模型
# ============================================================

class NodeTagOut(BaseModel):
    tag_id: str
    node_id: str
    label: str
    color: str
    created_at: datetime

    class Config:
        from_attributes = True


# ============================================================
# Project 相关
# ============================================================

class ProjectCreateRequest(BaseModel):
    """创建项目请求体"""
    name: str = Field(..., min_length=1, max_length=200, description="项目名称")
    description: Optional[str] = Field(default="", description="项目描述")


class ProjectUpdateRequest(BaseModel):
    """更新项目基本信息"""
    name: Optional[str] = Field(default=None, max_length=200)
    description: Optional[str] = None
    cover_url: Optional[str] = None


class SwitchCurrentNodeRequest(BaseModel):
    """切换项目当前节点"""
    node_id: str = Field(..., description="目标节点 ID")


class ProjectOut(BaseModel):
    """项目摘要响应（不含树数据）"""
    project_id: str
    name: str
    description: str
    cover_url: Optional[str]
    root_node_id: Optional[str]
    current_node_id: Optional[str]
    node_count: int
    branch_count: int
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


# ============================================================
# AssetNode 相关
# ============================================================

class AddRootNodeRequest(BaseModel):
    """
    向项目添加根节点。
    
    通常在创建项目后、用户上传原图后调用。
    image_url 为已上传到存储后端的 URL（MinIO / 本地路径等）。
    """
    image_url: str = Field(..., description="原图完整 URL")
    thumbnail_url: Optional[str] = Field(default=None, description="缩略图 URL")
    width: Optional[int] = None
    height: Optional[int] = None
    file_size: Optional[int] = None
    format: Optional[str] = Field(default=None, description="图片格式，如 jpg/png/webp")
    metadata: Optional[Dict[str, Any]] = Field(default=None, description="额外元数据（EXIF等）")


class CreateChildNodeRequest(BaseModel):
    """
    从指定父节点生成子节点（核心操作）。

    调用方负责：
      1. 已执行 ComfyUI 工作流并将生成图上传到存储后端
      2. 将 image_url 和相关参数填入本请求
    """
    parent_node_id: str = Field(..., description="父节点 ID")
    image_url: str = Field(..., description="生成图完整 URL")
    thumbnail_url: Optional[str] = None

    # 图片信息
    width: Optional[int] = None
    height: Optional[int] = None
    file_size: Optional[int] = None
    format: Optional[str] = None

    # 操作信息（记录本次是如何从父节点生成该节点的）
    lens_id: Optional[str] = Field(default=None, description="所用透镜 ID")
    lens_name: Optional[str] = Field(default=None, description="透镜名称冗余存储")
    user_prompt: Optional[str] = Field(default=None, description="用户自然语言指令")
    parameters: Optional[Dict[str, Any]] = Field(default=None, description="透镜参数字典")
    muse_dna: Optional[Dict[str, Any]] = Field(default=None, description="完整 MuseDNA 快照")
    generation_params: Optional[Dict[str, Any]] = Field(default=None, description="生成参数快照")

    # 任务追踪
    execution_time_ms: Optional[int] = Field(default=None, description="执行耗时（毫秒）")
    task_id: Optional[str] = Field(default=None, description="关联的生成任务 ID")

    # 状态
    status: str = Field(default="completed", description="generating/completed/failed")
    metadata: Optional[Dict[str, Any]] = None


class UpdateNodeStatusRequest(BaseModel):
    """更新节点状态（如异步生成完成后回调）"""
    status: str = Field(..., description="generating/completed/failed")
    image_url: Optional[str] = None
    thumbnail_url: Optional[str] = None
    execution_time_ms: Optional[int] = None


class AssetNodeOut(BaseModel):
    """节点完整响应"""
    node_id: str
    project_id: str
    image_url: str
    thumbnail_url: Optional[str]
    node_type: str
    width: Optional[int]
    height: Optional[int]
    file_size: Optional[int]
    format: Optional[str]
    muse_dna: Optional[Dict[str, Any]]
    generation_params: Optional[Dict[str, Any]]
    depth: int
    path: List[str] = Field(description="从根节点到本节点的有序 ID 列表（含自身）")
    status: str
    label: Optional[str]
    metadata: Optional[Dict[str, Any]]
    tags: List[NodeTagOut] = []
    created_at: datetime

    class Config:
        from_attributes = True


class AssetNodeSummary(BaseModel):
    """节点摘要（用于树渲染，字段精简）"""
    node_id: str
    image_url: str
    thumbnail_url: Optional[str]
    node_type: str
    depth: int
    status: str
    label: Optional[str]
    tags: List[NodeTagOut] = []
    created_at: datetime

    class Config:
        from_attributes = True


# ============================================================
# AssetEdge 相关
# ============================================================

class AssetEdgeOut(BaseModel):
    """操作边完整响应"""
    edge_id: str
    project_id: str
    source_node_id: str
    target_node_id: str
    lens_id: Optional[str]
    lens_name: Optional[str]
    user_prompt: Optional[str]
    parameters: Optional[Dict[str, Any]]
    muse_dna: Optional[Dict[str, Any]]
    execution_time_ms: Optional[int]
    task_id: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True


class AssetEdgeSummary(BaseModel):
    """操作边摘要（用于树渲染）"""
    edge_id: str
    source_node_id: str
    target_node_id: str
    lens_id: Optional[str]
    lens_name: Optional[str]
    user_prompt: Optional[str]
    parameters: Optional[Dict[str, Any]]
    execution_time_ms: Optional[int]
    created_at: datetime

    class Config:
        from_attributes = True


# ============================================================
# 树结构查询响应
# ============================================================

class ProjectTreeResponse(BaseModel):
    """
    完整树结构响应（用于前端 D3.js / Cytoscape.js 渲染）

    nodes + edges 直接对应图的节点和边。
    前端用 node_id 与 source_node_id/target_node_id 连线。
    """
    project: ProjectOut
    nodes: List[AssetNodeSummary]
    edges: List[AssetEdgeSummary]


class AncestorPathResponse(BaseModel):
    """从根节点到目标节点的完整路径"""
    node_id: str
    ancestors: List[AssetNodeSummary]    # 按深度升序，含目标节点本身
    path_edges: List[AssetEdgeSummary]   # 路径上的操作边


class DescendantsResponse(BaseModel):
    """某节点的所有后代"""
    node_id: str
    descendants: List[AssetNodeSummary]


class NodeCompareResponse(BaseModel):
    """两个节点的对比信息"""
    node_a: AssetNodeOut
    node_b: AssetNodeOut
    edge: Optional[AssetEdgeSummary] = Field(
        default=None,
        description="连接 node_a → node_b 的操作边（若两节点直接相连）"
    )


# ============================================================
# NodeTag 相关
# ============================================================

class AddNodeTagRequest(BaseModel):
    label: str = Field(..., min_length=1, max_length=50, description="标签文字")
    color: str = Field(default="#4A90E2", description="标签颜色 HEX")


# ============================================================
# 通用操作响应
# ============================================================

class CreateChildNodeResponse(BaseModel):
    """创建子节点操作的复合响应"""
    node: AssetNodeOut
    edge: AssetEdgeOut


class MessageResponse(BaseModel):
    message: str
