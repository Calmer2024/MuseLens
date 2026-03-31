"""
模板市场相关 Pydantic 模型。

说明：
- 文件名仍沿用 market.py，避免影响现有导入路径
- 对外新增的模板市场接口会优先使用 template 命名
- 旧的 lens/preset 响应模型仍保留，用于兼容已有接口
"""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import Any, Dict, List, Optional

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.schemas.lens import DAGBlueprint


class MarketLensCreateRequest(BaseModel):
    lens_key: str = Field(..., min_length=3, max_length=100, description="模板唯一键")
    name: str = Field(..., min_length=1, max_length=100, description="模板标题")
    description: str = Field(default="", max_length=5000)
    author_id: Optional[int] = Field(default=None, description="作者用户 ID")
    category: Optional[str] = Field(default=None, max_length=50)
    price: Decimal = Field(default=Decimal("0.00"))
    is_official: bool = Field(default=False)
    cover_image_url: Optional[str] = Field(default=None, description="模板卡片封面图")
    preview_asset_node_id: Optional[str] = Field(default=None, description="预览资产节点 ID")
    original_image_url: Optional[str] = Field(default=None, description="原图地址")
    original_thumbnail_url: Optional[str] = Field(default=None, description="原图缩略图")
    result_image_url: Optional[str] = Field(default=None, description="结果图地址")
    result_thumbnail_url: Optional[str] = Field(default=None, description="结果图缩略图")
    source_project_id: Optional[str] = Field(default=None, description="来源项目 ID")
    source_root_node_id: Optional[str] = Field(default=None, description="来源原图节点 ID")
    result_asset_node_id: Optional[str] = Field(default=None, description="来源结果节点 ID")
    status: str = Field(default="active", max_length=20)


class MarketLensUpdateRequest(BaseModel):
    name: Optional[str] = Field(default=None, min_length=1, max_length=100)
    description: Optional[str] = Field(default=None, max_length=5000)
    category: Optional[str] = Field(default=None, max_length=50)
    price: Optional[Decimal] = Field(default=None)
    is_official: Optional[bool] = Field(default=None)
    cover_image_url: Optional[str] = Field(default=None)
    preview_asset_node_id: Optional[str] = Field(default=None)
    original_image_url: Optional[str] = Field(default=None)
    original_thumbnail_url: Optional[str] = Field(default=None)
    result_image_url: Optional[str] = Field(default=None)
    result_thumbnail_url: Optional[str] = Field(default=None)
    source_project_id: Optional[str] = Field(default=None)
    source_root_node_id: Optional[str] = Field(default=None)
    result_asset_node_id: Optional[str] = Field(default=None)
    status: Optional[str] = Field(default=None, max_length=20)


class MarketLensVersionCreateRequest(BaseModel):
    version: str = Field(..., min_length=1, max_length=20, description="版本号")
    base_workflow: Dict[str, Any] = Field(default_factory=dict, description="旧版工作流摘要")
    parameters: Dict[str, Any] = Field(default_factory=dict, description="可调参数定义")
    ui_schema: Dict[str, Any] = Field(default_factory=dict, description="前端 UI Schema")
    blueprint: Optional[Dict[str, Any]] = Field(default=None, description="共享的 MuseDNA / DAGBlueprint 快照")
    source_asset_node_id: Optional[str] = Field(default=None, description="可选：直接从资产节点发布")
    source_episode_id: Optional[int] = Field(default=None, description="可选：来源编辑片段 ID")
    published_from: Optional[str] = Field(default=None, description="manual / asset_node / editor_episode / router_result")
    changelog: str = Field(default="", max_length=5000)
    is_latest: bool = Field(default=True)


class MarketLensPublishFromNodeRequest(BaseModel):
    lens_key: str = Field(..., min_length=3, max_length=100, description="模板唯一键")
    name: str = Field(..., min_length=1, max_length=100, description="模板标题")
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
        description="应用模板时提供的初始输入，例如 base_image / user_base_image",
    )
    param_overrides: Dict[str, Dict[str, Any]] = Field(
        default_factory=dict,
        description="按 step_id 传入的参数覆盖字典",
    )
    execute_now: bool = Field(default=False, description="是否立即执行 MuseDNA")
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


class MarketTagOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    tag_id: int
    name: str
    description: str
    template_count: int
    created_at: datetime


class MarketAuthorOut(BaseModel):
    user_id: int
    username: str
    nickname: str
    avatar_url: Optional[str] = None
    is_verified: bool = False


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
    original_image_url: Optional[str] = None
    original_thumbnail_url: Optional[str] = None
    result_image_url: Optional[str] = None
    result_thumbnail_url: Optional[str] = None
    source_project_id: Optional[str] = None
    source_root_node_id: Optional[str] = None
    result_asset_node_id: Optional[str] = None
    install_count: int
    apply_count: int
    favorite_count: int = 0
    rating: Decimal
    rating_count: int
    status: str
    created_at: datetime
    updated_at: datetime

    @field_validator("apply_count", mode="before")
    @classmethod
    def _default_apply_count(cls, value):
        return 0 if value is None else value

    @field_validator("favorite_count", mode="before")
    @classmethod
    def _default_favorite_count(cls, value):
        return 0 if value is None else value


class MarketLensDetail(MarketLensOut):
    versions: List[MarketLensVersionOut] = Field(default_factory=list)
    reviews: List[LensReviewOut] = Field(default_factory=list)
    tags: List[MarketTagOut] = Field(default_factory=list)
    author: Optional[MarketAuthorOut] = None


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


class TemplatePublishRequest(BaseModel):
    template_id: Optional[int] = Field(default=None, description="可选：传入后表示更新已有模板卡片并新增版本")
    template_key: Optional[str] = Field(default=None, max_length=100, description="模板唯一键；新建时可不传，由后端生成")
    author_id: int = Field(..., description="作者用户 ID")
    title: str = Field(..., min_length=1, max_length=100, description="模板标题，描述想实现的效果")
    description: str = Field(default="", max_length=5000, description="模板详情说明")
    musedna: Dict[str, Any] = Field(..., description="Router 返回的 MuseDNA / DAGBlueprint")
    tag_names: List[str] = Field(default_factory=list, description="模板标签")
    category: Optional[str] = Field(default=None, max_length=50)
    is_official: bool = Field(default=False)
    status: str = Field(default="active", max_length=20)
    original_image_url: str = Field(..., max_length=500, description="原图地址")
    original_thumbnail_url: Optional[str] = Field(default=None, max_length=500, description="原图缩略图")
    result_image_url: str = Field(..., max_length=500, description="结果图地址")
    result_thumbnail_url: Optional[str] = Field(default=None, max_length=500, description="结果图缩略图")
    source_project_id: Optional[str] = Field(default=None, description="来源项目 ID")
    source_root_node_id: Optional[str] = Field(default=None, description="来源原图节点 ID")
    result_asset_node_id: Optional[str] = Field(default=None, description="来源结果节点 ID")
    version: Optional[str] = Field(default=None, max_length=20, description="可选版本号，不传则自动生成")
    changelog: str = Field(default="首次发布", max_length=5000)
    parameters: Dict[str, Any] = Field(default_factory=dict, description="前端参数定义")
    ui_schema: Dict[str, Any] = Field(default_factory=dict, description="前端 UI Schema")
    base_workflow: Dict[str, Any] = Field(default_factory=dict, description="旧版工作流摘要")


class TemplatePublishFromNodeRequest(BaseModel):
    template_id: Optional[int] = Field(default=None, description="可选：传入后表示更新已有模板卡片并新增版本")
    template_key: Optional[str] = Field(default=None, max_length=100, description="模板唯一键；新建时可不传")
    author_id: int = Field(..., description="作者用户 ID")
    title: str = Field(..., min_length=1, max_length=100, description="模板标题")
    description: str = Field(default="", max_length=5000)
    result_asset_node_id: str = Field(..., description="结果图所在资产节点 ID")
    tag_names: List[str] = Field(default_factory=list, description="模板标签")
    category: Optional[str] = Field(default=None, max_length=50)
    is_official: bool = Field(default=False)
    status: str = Field(default="active", max_length=20)
    version: Optional[str] = Field(default=None, max_length=20, description="可选版本号，不传则自动生成")
    changelog: str = Field(default="首次发布", max_length=5000)
    parameters: Dict[str, Any] = Field(default_factory=dict, description="前端参数定义")
    ui_schema: Dict[str, Any] = Field(default_factory=dict, description="前端 UI Schema")
    base_workflow: Dict[str, Any] = Field(default_factory=dict, description="旧版工作流摘要")


class TemplateUpdateRequest(BaseModel):
    title: Optional[str] = Field(default=None, min_length=1, max_length=100)
    description: Optional[str] = Field(default=None, max_length=5000)
    category: Optional[str] = Field(default=None, max_length=50)
    tag_names: Optional[List[str]] = Field(default=None, description="模板标签")
    is_official: Optional[bool] = Field(default=None)
    status: Optional[str] = Field(default=None, max_length=20)
    original_image_url: Optional[str] = Field(default=None, max_length=500)
    original_thumbnail_url: Optional[str] = Field(default=None, max_length=500)
    result_image_url: Optional[str] = Field(default=None, max_length=500)
    result_thumbnail_url: Optional[str] = Field(default=None, max_length=500)
    cover_image_url: Optional[str] = Field(default=None, max_length=500)


class TemplateVersionOut(BaseModel):
    version_id: int
    template_id: int
    version: str
    musedna: Optional[Dict[str, Any]] = None
    required_inputs: List[str] = Field(default_factory=list)
    parameters: Dict[str, Any] = Field(default_factory=dict)
    ui_schema: Dict[str, Any] = Field(default_factory=dict)
    base_workflow: Dict[str, Any] = Field(default_factory=dict)
    source_asset_node_id: Optional[str] = None
    source_episode_id: Optional[int] = None
    published_from: str
    changelog: str
    is_latest: bool
    created_at: datetime


class TemplateCardOut(BaseModel):
    template_id: int
    template_key: str
    title: str
    description: str
    author_id: Optional[int]
    author: Optional[MarketAuthorOut] = None
    category: Optional[str] = None
    is_official: bool = False
    status: str
    cover_image_url: Optional[str] = None
    original_image_url: Optional[str] = None
    original_thumbnail_url: Optional[str] = None
    result_image_url: Optional[str] = None
    result_thumbnail_url: Optional[str] = None
    source_project_id: Optional[str] = None
    source_root_node_id: Optional[str] = None
    result_asset_node_id: Optional[str] = None
    preview_asset_node_id: Optional[str] = None
    apply_count: int = 0
    favorite_count: int = 0
    install_count: int = 0
    rating: Decimal = Decimal("0.00")
    rating_count: int = 0
    tags: List[MarketTagOut] = Field(default_factory=list)
    tag_names: List[str] = Field(default_factory=list)
    created_at: datetime
    updated_at: datetime


class TemplateDetailOut(TemplateCardOut):
    current_version: Optional[TemplateVersionOut] = None
    versions: List[TemplateVersionOut] = Field(default_factory=list)
    reviews: List[LensReviewOut] = Field(default_factory=list)


class TemplatePublishResponse(BaseModel):
    template: TemplateCardOut
    version: TemplateVersionOut


class TemplateApplyRequest(MarketLensApplyRequest):
    pass


class TemplateApplyResponse(BaseModel):
    template: TemplateCardOut
    version: TemplateVersionOut
    musedna: DAGBlueprint
    required_inputs: List[str] = Field(default_factory=list)
    executed: bool = False
    execution_context: Dict[str, str] = Field(default_factory=dict)
    result_filename: Optional[str] = None
    result_url: Optional[str] = None
    execution_error: Optional[str] = None
    execution_started: bool = False
    stream_id: Optional[str] = None
    step_results: List[MarketLensApplyStepResult] = Field(default_factory=list)

