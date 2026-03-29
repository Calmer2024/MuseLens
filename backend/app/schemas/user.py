"""
用户管理相关 Pydantic 模型。
"""

from __future__ import annotations

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field


class UserRegisterRequest(BaseModel):
    username: str = Field(..., min_length=3, max_length=50, description="用户名")
    password: str = Field(..., min_length=6, max_length=128, description="明文密码")
    nickname: str = Field(..., min_length=1, max_length=50, description="昵称")
    email: Optional[str] = Field(default=None, description="邮箱")
    bio: str = Field(default="", max_length=1000, description="个人简介")


class UserLoginRequest(BaseModel):
    username: str = Field(..., description="用户名")
    password: str = Field(..., description="明文密码")


class UserUpdateRequest(BaseModel):
    nickname: Optional[str] = Field(default=None, min_length=1, max_length=50)
    email: Optional[str] = Field(default=None)
    bio: Optional[str] = Field(default=None, max_length=1000)
    avatar_url: Optional[str] = Field(default=None, max_length=500)
    banner_url: Optional[str] = Field(default=None, max_length=500)
    member_level: Optional[str] = Field(default=None, max_length=20)
    is_verified: Optional[bool] = Field(default=None)


class FollowActionRequest(BaseModel):
    follower_id: int = Field(..., description="发起关注的用户 ID")


class UserSummary(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    user_id: int
    username: str
    nickname: str
    avatar_url: Optional[str]
    is_verified: bool


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    user_id: int
    username: str
    email: Optional[str]
    nickname: str
    bio: str
    avatar_url: Optional[str]
    banner_url: Optional[str]
    total_likes: int
    follower_count: int
    following_count: int
    member_level: str
    is_verified: bool
    created_at: datetime
    updated_at: datetime


class UserLoginResponse(BaseModel):
    message: str
    user: UserOut
