"""
编辑片段树相关 Pydantic 模型。
"""

from __future__ import annotations

from datetime import datetime
from typing import Any, Dict, List, Optional

from pydantic import BaseModel, Field


class EpisodeAssetNodeRefOut(BaseModel):
    node_id: str
    project_id: str
    image_url: str
    thumbnail_url: Optional[str]
    depth: int
    status: str
    label: Optional[str]


class EditorSessionCreateRequest(BaseModel):
    title: Optional[str] = Field(default=None, max_length=120, description="编辑会话标题")
    description: str = Field(default="", max_length=2000, description="编辑会话描述")
    base_node_id: Optional[str] = Field(default=None, description="可选：指定会话起点节点")


class EditorEpisodeCreateRequest(BaseModel):
    parent_episode_id: Optional[int] = Field(default=None, description="父片段 ID")
    source_node_id: Optional[str] = Field(default=None, description="本轮编辑起点资产节点 ID")
    title: Optional[str] = Field(default=None, max_length=120, description="片段标题")
    branch_name: Optional[str] = Field(default=None, max_length=50, description="分支名称")
    user_intent: str = Field(default="", max_length=5000, description="用户本轮意图")
    assistant_plan: str = Field(default="", max_length=5000, description="AI 本轮计划")
    action_summary: str = Field(default="", max_length=5000, description="本轮结果摘要")
    tags: List[str] = Field(default_factory=list, description="片段标签")
    action_items: List[str] = Field(default_factory=list, description="动作摘要列表")
    tool_snapshot: Dict[str, Any] = Field(default_factory=dict, description="工具和参数快照")
    metadata: Dict[str, Any] = Field(default_factory=dict, description="扩展元数据")
    status: str = Field(default="draft", description="片段状态")


class EditorEpisodeMessageCreateRequest(BaseModel):
    role: str = Field(..., description="消息角色：user / assistant / system")
    content: str = Field(default="", max_length=5000, description="消息正文")
    message_kind: str = Field(default="note", description="消息类型")
    payload: Optional[Dict[str, Any]] = Field(default=None, description="结构化负载")


class EditorEpisodeBindTargetRequest(BaseModel):
    target_node_id: str = Field(..., description="结果节点 ID")
    source_node_id: Optional[str] = Field(default=None, description="可选：补充绑定本轮起点节点")
    action_summary: Optional[str] = Field(default=None, max_length=5000, description="更新结果摘要")
    status: str = Field(default="completed", description="绑定后的片段状态")


class EditorEpisodeMessageOut(BaseModel):
    message_id: int
    episode_id: int
    role: str
    message_kind: str
    content: str
    payload: Optional[Dict[str, Any]]
    created_at: datetime


class EditorSessionOut(BaseModel):
    session_id: str
    project_id: str
    title: str
    description: str
    base_node_id: Optional[str]
    current_episode_id: Optional[int]
    episode_count: int
    branch_count: int
    base_node: Optional[EpisodeAssetNodeRefOut] = None
    created_at: datetime
    updated_at: datetime


class EditorEpisodeOut(BaseModel):
    episode_id: int
    session_id: str
    parent_episode_id: Optional[int]
    source_node_id: Optional[str]
    target_node_id: Optional[str]
    round_index: int
    branch_name: str
    title: str
    user_intent: str
    assistant_plan: str
    action_summary: str
    tags: List[str] = Field(default_factory=list)
    action_items: List[str] = Field(default_factory=list)
    tool_snapshot: Dict[str, Any] = Field(default_factory=dict)
    metadata: Dict[str, Any] = Field(default_factory=dict)
    message_count: int
    status: str
    message_preview: str
    source_node: Optional[EpisodeAssetNodeRefOut] = None
    target_node: Optional[EpisodeAssetNodeRefOut] = None
    created_at: datetime
    updated_at: datetime


class EditorEpisodeEdgeOut(BaseModel):
    parent_episode_id: int
    episode_id: int


class EditorSessionTreeResponse(BaseModel):
    session: EditorSessionOut
    episodes: List[EditorEpisodeOut]
    edges: List[EditorEpisodeEdgeOut]


class EditorEpisodeDetailResponse(BaseModel):
    session: EditorSessionOut
    episode: EditorEpisodeOut
    parent_episode: Optional[EditorEpisodeOut] = None
    child_episodes: List[EditorEpisodeOut] = Field(default_factory=list)
    messages: List[EditorEpisodeMessageOut] = Field(default_factory=list)


class EditorEpisodeLookupResponse(BaseModel):
    session: EditorSessionOut
    episode: EditorEpisodeOut
