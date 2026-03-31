"""
透镜市场相关 Pydantic 模型。
"""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import Any, Dict, List, Optional

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.schemas.lens import DAGBlueprint


class MarketLensCreateRequest(BaseModel):
    lens_key: str = Field(..., min_length=3, max_length=100, description="市场 preset 唯一键")
    name: str = Field(..., min_length=1, max_length=100, description="preset 名称")
    description: str = Field(default="", max_length=5000)
    author_id: Optional[int] = Field(default=None, description="作者用户 ID")
    category: Optional[str] = Field(default=None, max_length=50)
    price: Decimal = Field(default=Decimal("0.00"))
    is_official: bool = Field(default=False)
    cover_image_url: Optional[str] = Field(default=None, description="市场卡片封面图")
    preview_asset_node_id: Optional[str] = Field(default=None, description="预览资产节点 ID")
    status: str = Field(default="active", max_length=20)


class MarketLensUpdateRequest(BaseModel):
    name: Optional[str] = Field(default=None, min_length=1, max_length=100)
    description: Optional[str] = Field(default=None, max_length=5000)
    category: Optional[str] = Field(default=None, max_length=50)
    price: Optional[Decimal] = Field(default=None)
    is_official: Optional[bool] = Field(default=None)
    cover_image_url: Optional[str] = Field(default=None)
    preview_asset_node_id: Optional[str] = Field(default=None)
    status: Optional[str] = Field(default=None, max_length=20)


class MarketLensVersionCreateRequest(BaseModel):
    version: str = Field(..., min_length=1, max_length=20, description="版本号")
    base_workflow: Dict[str, Any] = Field(default_factory=dict, description="旧版工作流摘要")
    parameters: Dict[str, Any] = Field(default_factory=dict, description="可调参数定义")
    ui_schema: Dict[str, Any] = Field(default_factory=dict, description="前端 UI Schema")
    blueprint: Optional[Dict[str, Any]] = Field(default=None, description="共享的 DAGBlueprint 快照")
    source_asset_node_id: Optional[str] = Field(default=None, description="可选：直接从资产节点发布")
    source_episode_id: Optional[int] = Field(default=None, description="可选：来源编辑片段 ID")
    published_from: Optional[str] = Field(default=None, description="manual / asset_node / editor_episode")
    changelog: str = Field(default="", max_length=5000)
    is_latest: bool = Field(default=True)


class MarketLensPublishFromNodeRequest(BaseModel):
    lens_key: str = Field(..., min_length=3, max_length=100, description="市场 preset 唯一键")
    name: str = Field(..., min_length=1, max_length=100, description="preset 名称")
    description: str = Field(default="", max_length=5000)
    author_id: int = Field(..., description="发布者用户 ID")
    source_asset_node_id: str = Field(..., description="来源资产节点 ID")
    source_episode_id: Optional[int] = Field(default=None, description="可选：来源编辑片段 ID")
    category: Optional[str] = Field(default=None, max_length=50)
    price: Decimal = Field(default=Decimal("0.00"))
    is_official: bool = Field(default=False)
    status: str = Field(default="active", max_length=20)
    version: str = Field(default="1.0.0", min_length=1, max_length=20)
    changelog: str = Field(default="首次发布", max_length=5000)
    parameters: Dict[str, Any] = Field(default_factory=dict, description="可调参数定义")
    ui_schema: Dict[str, Any] = Field(default_factory=dict, description="前端 UI Schema")
    base_workflow: Dict[str, Any] = Field(default_factory=dict, description="旧版工作流摘要")


class LensInstallRequest(BaseModel):
    user_id: int = Field(..., description="用户 ID")
    version_id: Optional[int] = Field(default=None, description="指定版本 ID")


class LensFavoriteRequest(BaseModel):
    user_id: int = Field(..., description="用户 ID")


class LensReviewCreateRequest(BaseModel):
    user_id: int = Field(..., description="用户 ID")
    rating: int = Field(..., ge=1, le=5, description="评分")
    content: str = Field(default="", max_length=5000, description="评价内容")


class MarketLensApplyRequest(BaseModel):
    user_id: Optional[int] = Field(default=None, description="当前用户 ID，可选，用于统计或鉴权扩展")
    version_id: Optional[int] = Field(default=None, description="指定版本 ID；不传则取最新版本")
    initial_inputs: Dict[str, str] = Field(
        default_factory=dict,
        description="应用该 preset 时提供的初始输入，例如 base_image / user_base_image",
    )
    param_overrides: Dict[str, Dict[str, Any]] = Field(
        default_factory=dict,
        description="按 step_id 传入的参数覆盖字典",
    )
    execute_now: bool = Field(default=False, description="是否立即执行 blueprint")
    async_execution: bool = Field(default=False, description="是否异步流式执行")
    stream_id: Optional[str] = Field(default=None, description="流式执行通道 ID")


class LensReviewOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    review_id: int
    lens_id: int
    user_id: int
    rating: int
    content: str
    created_at: datetime


class MarketLensVersionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    version_id: int
    lens_id: int
    version: str
    base_workflow: Dict[str, Any]
    parameters: Dict[str, Any]
    ui_schema: Dict[str, Any]
    blueprint: Optional[Dict[str, Any]]
    required_inputs: List[str] = Field(default_factory=list)
    source_asset_node_id: Optional[str]
    source_episode_id: Optional[int]
    published_from: str
    changelog: str
    is_latest: bool
    created_at: datetime

    @field_validator("required_inputs", mode="before")
    @classmethod
    def _default_required_inputs(cls, value):
        return value or []


class MarketLensOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    lens_id: int
    lens_key: str
    name: str
    description: str
    author_id: Optional[int]
    category: Optional[str]
    price: Decimal
    is_official: bool
    cover_image_url: Optional[str]
    preview_asset_node_id: Optional[str]
    install_count: int
    apply_count: int
    rating: Decimal
    rating_count: int
    status: str
    created_at: datetime
    updated_at: datetime

    @field_validator("apply_count", mode="before")
    @classmethod
    def _default_apply_count(cls, value):
        return 0 if value is None else value


class MarketLensDetail(MarketLensOut):
    versions: List[MarketLensVersionOut] = Field(default_factory=list)
    reviews: List[LensReviewOut] = Field(default_factory=list)


class MarketLensPublishResponse(BaseModel):
    lens: MarketLensOut
    version: MarketLensVersionOut


class MarketLensApplyStepOutput(BaseModel):
    output_name: str
    filename: str
    url: Optional[str] = None


class MarketLensApplyStepResult(BaseModel):
    step_id: str
    lens_id: str
    tweak_controls: List[Dict[str, Any]] = Field(default_factory=list)
    outputs: List[MarketLensApplyStepOutput] = Field(default_factory=list)


class MarketLensApplyResponse(BaseModel):
    lens: MarketLensOut
    version: MarketLensVersionOut
    blueprint: DAGBlueprint
    required_inputs: List[str] = Field(default_factory=list)
    executed: bool = False
    execution_context: Dict[str, str] = Field(default_factory=dict)
    result_filename: Optional[str] = None
    result_url: Optional[str] = None
    execution_error: Optional[str] = None
    execution_started: bool = False
    stream_id: Optional[str] = None
    step_results: List[MarketLensApplyStepResult] = Field(default_factory=list)
