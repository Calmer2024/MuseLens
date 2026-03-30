"""
树状资产管理相关的 Pydantic 模型。
"""

from __future__ import annotations

from datetime import datetime
from typing import Any, Dict, List, Optional

from pydantic import BaseModel, ConfigDict, Field


class NodeTagOut(BaseModel):
    tag_id: str
    node_id: str
    label: str
    color: str
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class ProjectCreateRequest(BaseModel):
    """创建项目请求体。"""

    name: str = Field(..., min_length=1, max_length=200, description="项目名称")
    description: Optional[str] = Field(default="", description="项目描述")


class ProjectUpdateRequest(BaseModel):
    """更新项目基础信息。"""

    name: Optional[str] = Field(default=None, max_length=200)
    description: Optional[str] = None
    cover_url: Optional[str] = None


class SwitchCurrentNodeRequest(BaseModel):
    """切换项目当前节点。"""

    node_id: str = Field(..., description="目标节点 ID")


class ProjectOut(BaseModel):
    """项目摘要响应。"""

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

    model_config = ConfigDict(from_attributes=True)


class AddRootNodeRequest(BaseModel):
    """给项目添加根节点。"""

    image_url: str = Field(..., description="原图完整 URL")
    thumbnail_url: Optional[str] = Field(default=None, description="缩略图 URL")
    width: Optional[int] = None
    height: Optional[int] = None
    file_size: Optional[int] = None
    format: Optional[str] = Field(default=None, description="图片格式，例如 jpg/png/webp")
    metadata: Optional[Dict[str, Any]] = Field(default=None, description="额外元数据，例如 EXIF")


class CreateChildNodeRequest(BaseModel):
    """
    从指定父节点生成子节点。

    如果携带 `episode_id`，后端会在创建成功后自动把新节点绑定为对应编辑片段的结果节点。
    """

    parent_node_id: str = Field(..., description="父节点 ID")
    episode_id: Optional[int] = Field(default=None, description="可选：关联的编辑片段 ID")
    image_url: str = Field(..., description="生成图完整 URL")
    thumbnail_url: Optional[str] = None

    # 图片信息
    width: Optional[int] = None
    height: Optional[int] = None
    file_size: Optional[int] = None
    format: Optional[str] = None

    # 操作信息
    lens_id: Optional[str] = Field(default=None, description="所用透镜 ID")
    lens_name: Optional[str] = Field(default=None, description="透镜名称冗余存储")
    user_prompt: Optional[str] = Field(default=None, description="用户自然语言指令")
    parameters: Optional[Dict[str, Any]] = Field(default=None, description="透镜参数字典")
    muse_dna: Optional[Dict[str, Any]] = Field(default=None, description="完整 MuseDNA 快照")
    generation_params: Optional[Dict[str, Any]] = Field(default=None, description="生成参数快照")

    # 任务追踪
    execution_time_ms: Optional[int] = Field(default=None, description="执行耗时，单位毫秒")
    task_id: Optional[str] = Field(default=None, description="关联的生成任务 ID")

    # 状态与扩展信息
    status: str = Field(default="completed", description="generating/completed/failed")
    metadata: Optional[Dict[str, Any]] = None


class UpdateNodeStatusRequest(BaseModel):
    """更新节点状态。"""

    status: str = Field(..., description="generating/completed/failed")
    image_url: Optional[str] = None
    thumbnail_url: Optional[str] = None
    execution_time_ms: Optional[int] = None


class AssetNodeOut(BaseModel):
    """节点完整响应。"""

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
    path: List[str] = Field(default_factory=list, description="从根节点到当前节点的路径，包含自身")
    status: str
    label: Optional[str]
    metadata: Optional[Dict[str, Any]]
    tags: List[NodeTagOut] = Field(default_factory=list)
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class AssetNodeSummary(BaseModel):
    """节点摘要，用于树渲染。"""

    node_id: str
    image_url: str
    thumbnail_url: Optional[str]
    node_type: str
    depth: int
    status: str
    label: Optional[str]
    tags: List[NodeTagOut] = Field(default_factory=list)
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class AssetEdgeOut(BaseModel):
    """操作边完整响应。"""

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

    model_config = ConfigDict(from_attributes=True)


class AssetEdgeSummary(BaseModel):
    """操作边摘要，用于树渲染。"""

    edge_id: str
    source_node_id: str
    target_node_id: str
    lens_id: Optional[str]
    lens_name: Optional[str]
    user_prompt: Optional[str]
    parameters: Optional[Dict[str, Any]]
    execution_time_ms: Optional[int]
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class ProjectTreeResponse(BaseModel):
    """项目完整树结构。"""

    project: ProjectOut
    nodes: List[AssetNodeSummary]
    edges: List[AssetEdgeSummary]


class AncestorPathResponse(BaseModel):
    """从根节点到目标节点的完整路径。"""

    node_id: str
    ancestors: List[AssetNodeSummary]
    path_edges: List[AssetEdgeSummary]


class DescendantsResponse(BaseModel):
    """目标节点的所有后代节点。"""

    node_id: str
    descendants: List[AssetNodeSummary]


class NodeCompareResponse(BaseModel):
    """两个节点的对比信息。"""

    node_a: AssetNodeOut
    node_b: AssetNodeOut
    edge: Optional[AssetEdgeSummary] = Field(
        default=None,
        description="连接 node_a -> node_b 的操作边，仅在二者直接相连时返回",
    )


class AddNodeTagRequest(BaseModel):
    """给节点添加标签。"""

    label: str = Field(..., min_length=1, max_length=50, description="标签文字")
    color: str = Field(default="#4A90E2", description="标签颜色 HEX")


class CreateChildNodeResponse(BaseModel):
    """创建子节点时的复合响应。"""

    node: AssetNodeOut
    edge: AssetEdgeOut


class MessageResponse(BaseModel):
    """通用消息响应。"""

    message: str
