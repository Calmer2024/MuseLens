"""
好友聊天相关 Pydantic 模型。
"""

from __future__ import annotations

from datetime import datetime
from typing import Any, Dict, List, Optional

from pydantic import BaseModel, Field

from app.schemas.user import UserSummary


class ChatFriendOut(UserSummary):
    conversation_id: Optional[int] = Field(default=None, description="若已存在私聊会话，则返回会话 ID")
    last_message_at: Optional[datetime] = Field(default=None, description="最近一次聊天时间")


class DirectConversationRequest(BaseModel):
    user_id: int = Field(..., description="当前用户 ID")
    friend_user_id: int = Field(..., description="目标好友用户 ID")


class ChatMessageShareRequest(BaseModel):
    share_type: str = Field(..., description="分享类型：post 或 preset")
    post_id: Optional[int] = Field(default=None, description="社区帖子 ID")
    market_lens_id: Optional[int] = Field(default=None, description="透镜市场预设 ID")
    asset_node_id: Optional[str] = Field(default=None, description="资产树节点 ID，可作为个人预设分享")


class ChatMessageCreateRequest(BaseModel):
    sender_id: int = Field(..., description="发送者用户 ID")
    content: str = Field(default="", max_length=5000, description="文本消息内容")
    share: Optional[ChatMessageShareRequest] = Field(default=None, description="可选的分享内容")


class ChatMarkReadRequest(BaseModel):
    user_id: int = Field(..., description="当前用户 ID")
    last_read_message_id: Optional[int] = Field(default=None, description="指定读到的最后一条消息 ID；不传则默认标记到最新")


class ChatMessageShareOut(BaseModel):
    share_type: str
    share_source_type: str
    resource_id: str
    title: str
    summary: str
    cover_url: Optional[str]
    author_id: Optional[int]
    author_name: Optional[str]
    metadata: Dict[str, Any] = Field(default_factory=dict)


class ChatMessageOut(BaseModel):
    message_id: int
    conversation_id: int
    sender_id: int
    message_type: str
    content: str
    share: Optional[ChatMessageShareOut] = None
    created_at: datetime


class ChatMessagePreviewOut(BaseModel):
    message_id: int
    sender_id: int
    message_type: str
    content_preview: str
    share_type: Optional[str]
    created_at: datetime


class ChatConversationOut(BaseModel):
    conversation_id: int
    participant_user_ids: List[int]
    peer_user: UserSummary
    last_message: Optional[ChatMessagePreviewOut] = None
    last_message_at: Optional[datetime] = None
    unread_count: int = 0
    created_at: datetime
    updated_at: datetime


class DirectConversationOpenResponse(BaseModel):
    created: bool
    conversation: ChatConversationOut


class ChatMessageListResponse(BaseModel):
    conversation_id: int
    messages: List[ChatMessageOut]
    has_more: bool
