"""
社区相关 Pydantic 模型。
"""

from __future__ import annotations

from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, ConfigDict, Field


class PostImageCreateRequest(BaseModel):
    image_url: str = Field(..., max_length=500, description="图片地址")
    thumbnail_url: Optional[str] = Field(default=None, max_length=500, description="缩略图地址")
    width: Optional[int] = Field(default=None, ge=1)
    height: Optional[int] = Field(default=None, ge=1)
    order_index: int = Field(default=0, ge=0)
    asset_node_id: Optional[str] = Field(default=None, description="关联资产树节点 ID")


class PostCreateRequest(BaseModel):
    user_id: int = Field(..., description="发帖用户 ID")
    title: Optional[str] = Field(default=None, max_length=200)
    content: str = Field(default="", max_length=5000)
    is_public: bool = Field(default=True)
    images: List[PostImageCreateRequest] = Field(default_factory=list)
    tag_names: List[str] = Field(default_factory=list, description="标签名列表")


class CommentCreateRequest(BaseModel):
    user_id: int = Field(..., description="评论用户 ID")
    content: str = Field(..., min_length=1, max_length=3000, description="评论正文")
    parent_id: Optional[int] = Field(default=None, description="父评论 ID")


class UserActionRequest(BaseModel):
    user_id: int = Field(..., description="用户 ID")


class TagOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    tag_id: int
    name: str
    description: str
    post_count: int
    created_at: datetime


class PostImageOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    image_id: int
    image_url: str
    thumbnail_url: Optional[str]
    width: Optional[int]
    height: Optional[int]
    order_index: int
    asset_node_id: Optional[str]


class CommentOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    comment_id: int
    post_id: int
    user_id: int
    parent_id: Optional[int]
    root_id: Optional[int]
    content: str
    like_count: int
    reply_count: int
    level: int
    created_at: datetime
    updated_at: datetime


class PostOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    post_id: int
    user_id: int
    title: Optional[str]
    content: str
    like_count: int
    comment_count: int
    share_count: int
    view_count: int
    is_public: bool
    audit_status: str
    created_at: datetime
    updated_at: datetime
    images: List[PostImageOut] = Field(default_factory=list)
    tags: List[TagOut] = Field(default_factory=list)


class CommentListResponse(BaseModel):
    post_id: int
    comments: List[CommentOut]
