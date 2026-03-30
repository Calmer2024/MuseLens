"""
好友聊天 API。
"""

from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.schemas.asset_tree import MessageResponse
from app.schemas.chat import (
    ChatConversationOut,
    ChatFriendOut,
    ChatMarkReadRequest,
    ChatMessageCreateRequest,
    ChatMessageListResponse,
    ChatMessageOut,
    DirectConversationOpenResponse,
    DirectConversationRequest,
)
from app.services import chat_service as svc

router = APIRouter()


def _raise_chat_error(exc: Exception) -> None:
    if isinstance(exc, LookupError):
        raise HTTPException(status_code=404, detail=str(exc))
    if isinstance(exc, PermissionError):
        raise HTTPException(status_code=403, detail=str(exc))
    raise HTTPException(status_code=400, detail=str(exc))


@router.get("/friends/{user_id}", response_model=List[ChatFriendOut], summary="获取可私聊好友列表")
def list_chat_friends(user_id: int, db: Session = Depends(get_db)) -> List[ChatFriendOut]:
    try:
        friends = svc.list_chat_friends(db, user_id)
    except Exception as exc:
        _raise_chat_error(exc)
    return [ChatFriendOut.model_validate(item) for item in friends]


@router.post("/conversations/direct", response_model=DirectConversationOpenResponse, summary="创建或打开好友私聊")
def open_direct_conversation(
    body: DirectConversationRequest,
    db: Session = Depends(get_db),
) -> DirectConversationOpenResponse:
    try:
        conversation, created = svc.get_or_create_direct_conversation(
            db,
            user_id=body.user_id,
            friend_user_id=body.friend_user_id,
        )
        detail = svc.serialize_conversation(db, conversation, body.user_id)
    except Exception as exc:
        _raise_chat_error(exc)
    return DirectConversationOpenResponse(
        created=created,
        conversation=ChatConversationOut.model_validate(detail),
    )


@router.get("/conversations", response_model=List[ChatConversationOut], summary="获取当前用户会话列表")
def list_conversations(
    user_id: int = Query(..., description="当前用户 ID"),
    db: Session = Depends(get_db),
) -> List[ChatConversationOut]:
    try:
        conversations = svc.list_user_conversations(db, user_id)
    except Exception as exc:
        _raise_chat_error(exc)
    return [ChatConversationOut.model_validate(item) for item in conversations]


@router.get("/conversations/{conversation_id}", response_model=ChatConversationOut, summary="获取会话详情")
def get_conversation_detail(
    conversation_id: int,
    user_id: int = Query(..., description="当前用户 ID"),
    db: Session = Depends(get_db),
) -> ChatConversationOut:
    try:
        detail = svc.get_conversation_detail(db, conversation_id, user_id)
    except Exception as exc:
        _raise_chat_error(exc)
    return ChatConversationOut.model_validate(detail)


@router.get("/conversations/{conversation_id}/messages", response_model=ChatMessageListResponse, summary="获取会话消息列表")
def list_conversation_messages(
    conversation_id: int,
    user_id: int = Query(..., description="当前用户 ID"),
    limit: int = Query(default=50, ge=1, le=100, description="单次拉取消息数量"),
    before_message_id: int | None = Query(default=None, description="向上翻页时传入该消息 ID 之前的记录"),
    db: Session = Depends(get_db),
) -> ChatMessageListResponse:
    try:
        messages, has_more = svc.list_messages(
            db,
            conversation_id=conversation_id,
            user_id=user_id,
            limit=limit,
            before_message_id=before_message_id,
        )
    except Exception as exc:
        _raise_chat_error(exc)

    return ChatMessageListResponse(
        conversation_id=conversation_id,
        messages=[ChatMessageOut.model_validate(svc.serialize_message(item)) for item in messages],
        has_more=has_more,
    )


@router.post("/conversations/{conversation_id}/messages", response_model=ChatMessageOut, status_code=201, summary="发送消息或分享内容")
def send_message(
    conversation_id: int,
    body: ChatMessageCreateRequest,
    db: Session = Depends(get_db),
) -> ChatMessageOut:
    try:
        message = svc.send_message(
            db,
            conversation_id=conversation_id,
            sender_id=body.sender_id,
            content=body.content,
            share=body.share.model_dump() if body.share else None,
        )
    except Exception as exc:
        _raise_chat_error(exc)
    return ChatMessageOut.model_validate(svc.serialize_message(message))


@router.post("/conversations/{conversation_id}/read", response_model=MessageResponse, summary="标记会话已读")
def mark_conversation_read(
    conversation_id: int,
    body: ChatMarkReadRequest,
    db: Session = Depends(get_db),
) -> MessageResponse:
    try:
        svc.mark_conversation_read(
            db,
            conversation_id=conversation_id,
            user_id=body.user_id,
            last_read_message_id=body.last_read_message_id,
        )
    except Exception as exc:
        _raise_chat_error(exc)
    return MessageResponse(message="已读状态更新成功")
