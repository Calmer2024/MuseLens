"""
透镜市场相关 Pydantic 模型。
"""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import Any, Dict, List, Optional

from pydantic import BaseModel, ConfigDict, Field


class MarketLensCreateRequest(BaseModel):
    lens_key: str = Field(..., min_length=3, max_length=100, description="透镜唯一键")
    name: str = Field(..., min_length=1, max_length=100, description="透镜名称")
    description: str = Field(default="", max_length=5000)
    author_id: Optional[int] = Field(default=None, description="作者用户 ID")
    category: Optional[str] = Field(default=None, max_length=50)
    price: Decimal = Field(default=Decimal("0.00"))
    is_official: bool = Field(default=False)
    status: str = Field(default="active", max_length=20)


class MarketLensUpdateRequest(BaseModel):
    name: Optional[str] = Field(default=None, min_length=1, max_length=100)
    description: Optional[str] = Field(default=None, max_length=5000)
    category: Optional[str] = Field(default=None, max_length=50)
    price: Optional[Decimal] = Field(default=None)
    is_official: Optional[bool] = Field(default=None)
    status: Optional[str] = Field(default=None, max_length=20)


class MarketLensVersionCreateRequest(BaseModel):
    version: str = Field(..., min_length=1, max_length=20, description="版本号")
    base_workflow: Dict[str, Any] = Field(..., description="基础工作流")
    parameters: Dict[str, Any] = Field(..., description="参数定义")
    ui_schema: Dict[str, Any] = Field(..., description="前端 UI Schema")
    changelog: str = Field(default="", max_length=5000)
    is_latest: bool = Field(default=True)


class LensInstallRequest(BaseModel):
    user_id: int = Field(..., description="用户 ID")
    version_id: Optional[int] = Field(default=None, description="指定版本 ID")


class LensFavoriteRequest(BaseModel):
    user_id: int = Field(..., description="用户 ID")


class LensReviewCreateRequest(BaseModel):
    user_id: int = Field(..., description="用户 ID")
    rating: int = Field(..., ge=1, le=5, description="评分")
    content: str = Field(default="", max_length=5000, description="评价内容")


class MarketLensVersionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    version_id: int
    lens_id: int
    version: str
    base_workflow: Dict[str, Any]
    parameters: Dict[str, Any]
    ui_schema: Dict[str, Any]
    changelog: str
    is_latest: bool
    created_at: datetime


class LensReviewOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    review_id: int
    lens_id: int
    user_id: int
    rating: int
    content: str
    created_at: datetime


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
    install_count: int
    rating: Decimal
    rating_count: int
    status: str
    created_at: datetime
    updated_at: datetime


class MarketLensDetail(MarketLensOut):
    versions: List[MarketLensVersionOut] = Field(default_factory=list)
    reviews: List[LensReviewOut] = Field(default_factory=list)
