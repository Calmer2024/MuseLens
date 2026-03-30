"""
好友聊天服务。

当前仅支持一对一私聊，会话建立与发消息都要求双方处于互相关注状态。
消息支持：
- 纯文本
- 分享帖子
- 分享预设（透镜市场预设或资产树节点预设）
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Tuple

from sqlalchemy.orm import Session

from app.models.asset_tree_models import AssetEdge, AssetNode, Project
from app.models.chat_models import ChatConversation, ChatConversationState, ChatMessage
from app.models.community_models import Post, PostImage
from app.models.market_models import MarketLens, MarketLensVersion
from app.models.user_models import Follow, User


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _normalize_pair(user_a_id: int, user_b_id: int) -> Tuple[int, int]:
    if user_a_id == user_b_id:
        raise ValueError("不能给自己发起私聊")
    return (user_a_id, user_b_id) if user_a_id < user_b_id else (user_b_id, user_a_id)


def get_user(db: Session, user_id: int) -> Optional[User]:
    return db.query(User).filter(User.user_id == user_id).first()


def get_conversation(db: Session, conversation_id: int) -> Optional[ChatConversation]:
    return (
        db.query(ChatConversation)
        .filter(ChatConversation.conversation_id == conversation_id)
        .first()
    )


def get_message(db: Session, message_id: int) -> Optional[ChatMessage]:
    return db.query(ChatMessage).filter(ChatMessage.message_id == message_id).first()


def is_mutual_follow(db: Session, user_a_id: int, user_b_id: int) -> bool:
    follow_ab = (
        db.query(Follow)
        .filter(Follow.follower_id == user_a_id, Follow.following_id == user_b_id)
        .first()
    )
    if not follow_ab:
        return False
    follow_ba = (
        db.query(Follow)
        .filter(Follow.follower_id == user_b_id, Follow.following_id == user_a_id)
        .first()
    )
    return follow_ba is not None


def _require_existing_user(db: Session, user_id: int) -> User:
    user = get_user(db, user_id)
    if not user:
        raise LookupError(f"用户不存在：{user_id}")
    return user


def _conversation_participants(conversation: ChatConversation) -> Tuple[int, int]:
    return conversation.user_low_id, conversation.user_high_id


def _get_peer_user_id(conversation: ChatConversation, user_id: int) -> int:
    if user_id == conversation.user_low_id:
        return conversation.user_high_id
    if user_id == conversation.user_high_id:
        return conversation.user_low_id
    raise PermissionError("当前用户不在该会话中")


def _require_conversation_for_user(db: Session, conversation_id: int, user_id: int) -> ChatConversation:
    conversation = get_conversation(db, conversation_id)
    if not conversation:
        raise LookupError(f"会话不存在：{conversation_id}")
    if user_id not in _conversation_participants(conversation):
        raise PermissionError("当前用户无权访问该会话")
    return conversation


def _get_state(db: Session, conversation_id: int, user_id: int) -> Optional[ChatConversationState]:
    return (
        db.query(ChatConversationState)
        .filter(
            ChatConversationState.conversation_id == conversation_id,
            ChatConversationState.user_id == user_id,
        )
        .first()
    )


def _ensure_conversation_states(db: Session, conversation: ChatConversation) -> None:
    for user_id in _conversation_participants(conversation):
        state = _get_state(db, conversation.conversation_id, user_id)
        if state:
            continue
        db.add(
            ChatConversationState(
                conversation_id=conversation.conversation_id,
                user_id=user_id,
            )
        )


def _build_share_payload(
    db: Session,
    sender_id: int,
    share: Optional[Dict[str, Any]],
) -> Tuple[Optional[str], Optional[str], Optional[str], Optional[Dict[str, Any]]]:
    if not share:
        return None, None, None, None

    share_type = str(share.get("share_type") or "").strip().lower()
    if share_type == "post":
        post_id = share.get("post_id")
        if not post_id:
            raise ValueError("分享帖子时必须提供 post_id")

        post = db.query(Post).filter(Post.post_id == int(post_id)).first()
        if not post:
            raise ValueError(f"帖子不存在：{post_id}")
        if not post.is_public and post.user_id != sender_id:
            raise ValueError("不能分享他人的私密帖子")

        author = get_user(db, post.user_id)
        cover = (
            db.query(PostImage)
            .filter(PostImage.post_id == post.post_id)
            .order_by(PostImage.order_index.asc(), PostImage.image_id.asc())
            .first()
        )
        post.share_count += 1
        cover_url = None
        if cover:
            cover_url = cover.thumbnail_url or cover.image_url

        payload = {
            "title": post.title or f"帖子 #{post.post_id}",
            "summary": (post.content or "").strip()[:120],
            "cover_url": cover_url,
            "author_id": author.user_id if author else None,
            "author_name": author.nickname if author else None,
            "metadata": {
                "post_id": post.post_id,
                "is_public": post.is_public,
                "comment_count": post.comment_count,
                "like_count": post.like_count,
            },
        }
        return "post", "community_post", str(post.post_id), payload

    if share_type != "preset":
        raise ValueError("当前仅支持分享 post 或 preset")

    market_lens_id = share.get("market_lens_id")
    asset_node_id = share.get("asset_node_id")
    provided_count = int(bool(market_lens_id)) + int(bool(asset_node_id))
    if provided_count != 1:
        raise ValueError("分享预设时必须且只能提供 market_lens_id 或 asset_node_id 其中一个")

    if market_lens_id:
        lens = (
            db.query(MarketLens)
            .filter(MarketLens.lens_id == int(market_lens_id))
            .first()
        )
        if not lens:
            raise ValueError(f"预设不存在：{market_lens_id}")
        author = get_user(db, lens.author_id) if lens.author_id is not None else None
        latest_version = (
            db.query(MarketLensVersion)
            .filter(
                MarketLensVersion.lens_id == lens.lens_id,
                MarketLensVersion.is_latest.is_(True),
            )
            .order_by(MarketLensVersion.version_id.desc())
            .first()
        )
        if latest_version is None:
            latest_version = (
                db.query(MarketLensVersion)
                .filter(MarketLensVersion.lens_id == lens.lens_id)
                .order_by(MarketLensVersion.version_id.desc())
                .first()
            )

        payload = {
            "title": lens.name,
            "summary": (lens.description or "").strip()[:120],
            "cover_url": None,
            "author_id": author.user_id if author else lens.author_id,
            "author_name": author.nickname if author else None,
            "metadata": {
                "market_lens_id": lens.lens_id,
                "lens_key": lens.lens_key,
                "category": lens.category,
                "price": str(lens.price),
                "is_official": lens.is_official,
                "rating": str(lens.rating),
                "latest_version": latest_version.version if latest_version else None,
            },
        }
        return "preset", "market_lens", str(lens.lens_id), payload

    node = db.query(AssetNode).filter(AssetNode.node_id == str(asset_node_id)).first()
    if not node:
        raise ValueError(f"预设不存在：{asset_node_id}")
    project = db.query(Project).filter(Project.project_id == node.project_id).first()
    edge = (
        db.query(AssetEdge)
        .filter(AssetEdge.target_node_id == node.node_id)
        .order_by(AssetEdge.created_at.desc())
        .first()
    )
    payload = {
        "title": node.label or (f"{project.name} 预设" if project else f"预设 {node.node_id[:8]}"),
        "summary": (edge.user_prompt if edge and edge.user_prompt else "")[:120]
        or (edge.lens_name if edge and edge.lens_name else "来自资产树的预设分享"),
        "cover_url": node.thumbnail_url or node.image_url,
        "author_id": None,
        "author_name": None,
        "metadata": {
            "asset_node_id": node.node_id,
            "project_id": node.project_id,
            "lens_id": edge.lens_id if edge else None,
            "lens_name": edge.lens_name if edge else None,
        },
    }
    return "preset", "asset_node", str(node.node_id), payload


def _message_preview_text(message: ChatMessage) -> str:
    content = (message.content or "").strip()
    if content:
        return content[:80]

    payload = message.share_payload or {}
    title = str(payload.get("title") or "").strip()
    if message.share_type == "post":
        return f"分享了帖子：{title}" if title else "分享了帖子"
    if message.share_type == "preset":
        return f"分享了预设：{title}" if title else "分享了预设"
    return ""


def serialize_message(message: ChatMessage) -> Dict[str, Any]:
    share_payload = message.share_payload or None
    return {
        "message_id": message.message_id,
        "conversation_id": message.conversation_id,
        "sender_id": message.sender_id,
        "message_type": message.message_type,
        "content": message.content,
        "share": (
            {
                "share_type": message.share_type,
                "share_source_type": message.share_source_type,
                "resource_id": message.share_resource_id,
                "title": share_payload.get("title", ""),
                "summary": share_payload.get("summary", ""),
                "cover_url": share_payload.get("cover_url"),
                "author_id": share_payload.get("author_id"),
                "author_name": share_payload.get("author_name"),
                "metadata": share_payload.get("metadata") or {},
            }
            if share_payload
            else None
        ),
        "created_at": message.created_at,
    }


def serialize_message_preview(message: ChatMessage) -> Dict[str, Any]:
    return {
        "message_id": message.message_id,
        "sender_id": message.sender_id,
        "message_type": message.message_type,
        "content_preview": _message_preview_text(message),
        "share_type": message.share_type,
        "created_at": message.created_at,
    }


def _conversation_unread_count(db: Session, conversation_id: int, user_id: int) -> int:
    state = _get_state(db, conversation_id, user_id)
    query = (
        db.query(ChatMessage)
        .filter(
            ChatMessage.conversation_id == conversation_id,
            ChatMessage.sender_id != user_id,
        )
    )
    if state and state.last_read_message_id:
        query = query.filter(ChatMessage.message_id > state.last_read_message_id)
    return query.count()


def serialize_conversation(db: Session, conversation: ChatConversation, viewer_id: int) -> Dict[str, Any]:
    peer_user_id = _get_peer_user_id(conversation, viewer_id)
    peer_user = _require_existing_user(db, peer_user_id)
    last_message = None
    if conversation.last_message_id:
        message = get_message(db, conversation.last_message_id)
        if message and message.conversation_id == conversation.conversation_id:
            last_message = serialize_message_preview(message)

    return {
        "conversation_id": conversation.conversation_id,
        "participant_user_ids": [conversation.user_low_id, conversation.user_high_id],
        "peer_user": {
            "user_id": peer_user.user_id,
            "username": peer_user.username,
            "nickname": peer_user.nickname,
            "avatar_url": peer_user.avatar_url,
            "is_verified": peer_user.is_verified,
        },
        "last_message": last_message,
        "last_message_at": conversation.last_message_at,
        "unread_count": _conversation_unread_count(db, conversation.conversation_id, viewer_id),
        "created_at": conversation.created_at,
        "updated_at": conversation.updated_at,
    }


def list_chat_friends(db: Session, user_id: int) -> List[Dict[str, Any]]:
    _require_existing_user(db, user_id)

    following = {
        row.following_id
        for row in db.query(Follow).filter(Follow.follower_id == user_id).all()
    }
    followers = {
        row.follower_id
        for row in db.query(Follow).filter(Follow.following_id == user_id).all()
    }
    friend_ids = sorted(following & followers)

    result: List[Dict[str, Any]] = []
    for friend_id in friend_ids:
        friend = _require_existing_user(db, friend_id)
        low_id, high_id = _normalize_pair(user_id, friend_id)
        conversation = (
            db.query(ChatConversation)
            .filter(
                ChatConversation.user_low_id == low_id,
                ChatConversation.user_high_id == high_id,
            )
            .first()
        )
        result.append(
            {
                "user_id": friend.user_id,
                "username": friend.username,
                "nickname": friend.nickname,
                "avatar_url": friend.avatar_url,
                "is_verified": friend.is_verified,
                "conversation_id": conversation.conversation_id if conversation else None,
                "last_message_at": conversation.last_message_at if conversation else None,
            }
        )
    return result


def get_or_create_direct_conversation(
    db: Session,
    *,
    user_id: int,
    friend_user_id: int,
) -> Tuple[ChatConversation, bool]:
    _require_existing_user(db, user_id)
    _require_existing_user(db, friend_user_id)
    low_id, high_id = _normalize_pair(user_id, friend_user_id)

    if not is_mutual_follow(db, user_id, friend_user_id):
        raise ValueError("只有互相关注的用户才能建立私聊")

    conversation = (
        db.query(ChatConversation)
        .filter(
            ChatConversation.user_low_id == low_id,
            ChatConversation.user_high_id == high_id,
        )
        .first()
    )
    if conversation:
        _ensure_conversation_states(db, conversation)
        db.commit()
        db.refresh(conversation)
        return conversation, False

    conversation = ChatConversation(
        user_low_id=low_id,
        user_high_id=high_id,
    )
    db.add(conversation)
    db.flush()
    _ensure_conversation_states(db, conversation)
    db.commit()
    db.refresh(conversation)
    return conversation, True


def list_user_conversations(db: Session, user_id: int) -> List[Dict[str, Any]]:
    _require_existing_user(db, user_id)
    conversations = (
        db.query(ChatConversation)
        .filter(
            (ChatConversation.user_low_id == user_id)
            | (ChatConversation.user_high_id == user_id)
        )
        .order_by(ChatConversation.last_message_at.desc(), ChatConversation.conversation_id.desc())
        .all()
    )
    return [serialize_conversation(db, item, user_id) for item in conversations]


def get_conversation_detail(db: Session, conversation_id: int, user_id: int) -> Dict[str, Any]:
    conversation = _require_conversation_for_user(db, conversation_id, user_id)
    return serialize_conversation(db, conversation, user_id)


def list_messages(
    db: Session,
    *,
    conversation_id: int,
    user_id: int,
    limit: int = 50,
    before_message_id: int | None = None,
) -> Tuple[List[ChatMessage], bool]:
    if limit <= 0:
        raise ValueError("limit 必须大于 0")

    _require_conversation_for_user(db, conversation_id, user_id)
    query = db.query(ChatMessage).filter(ChatMessage.conversation_id == conversation_id)
    if before_message_id is not None:
        query = query.filter(ChatMessage.message_id < before_message_id)

    rows = (
        query.order_by(ChatMessage.message_id.desc())
        .limit(limit + 1)
        .all()
    )
    has_more = len(rows) > limit
    if has_more:
        rows = rows[:limit]
    rows.reverse()
    return rows, has_more


def send_message(
    db: Session,
    *,
    conversation_id: int,
    sender_id: int,
    content: str,
    share: Optional[Dict[str, Any]] = None,
) -> ChatMessage:
    conversation = _require_conversation_for_user(db, conversation_id, sender_id)
    peer_user_id = _get_peer_user_id(conversation, sender_id)
    if not is_mutual_follow(db, sender_id, peer_user_id):
        raise ValueError("只有互相关注的用户才能发送私信")

    cleaned_content = (content or "").strip()
    if not cleaned_content and not share:
        raise ValueError("消息内容和分享内容不能同时为空")

    share_type, share_source_type, share_resource_id, share_payload = _build_share_payload(
        db,
        sender_id,
        share,
    )
    if share_payload and cleaned_content:
        message_type = "text_share"
    elif share_payload:
        message_type = "share"
    else:
        message_type = "text"

    message = ChatMessage(
        conversation_id=conversation_id,
        sender_id=sender_id,
        message_type=message_type,
        content=cleaned_content,
        share_type=share_type,
        share_source_type=share_source_type,
        share_resource_id=share_resource_id,
        share_payload=share_payload,
    )
    db.add(message)
    db.flush()

    conversation.last_message_id = message.message_id
    conversation.last_message_at = message.created_at or _utcnow()
    conversation.updated_at = _utcnow()

    _ensure_conversation_states(db, conversation)
    sender_state = _get_state(db, conversation_id, sender_id)
    if sender_state:
        sender_state.last_read_message_id = message.message_id
        sender_state.last_read_at = _utcnow()

    db.commit()
    db.refresh(message)
    return message


def mark_conversation_read(
    db: Session,
    *,
    conversation_id: int,
    user_id: int,
    last_read_message_id: int | None = None,
) -> ChatConversationState:
    conversation = _require_conversation_for_user(db, conversation_id, user_id)
    _ensure_conversation_states(db, conversation)

    state = _get_state(db, conversation_id, user_id)
    if state is None:
        raise LookupError(f"会话状态不存在：{conversation_id}/{user_id}")

    target_message_id = last_read_message_id or conversation.last_message_id
    if target_message_id is not None:
        message = get_message(db, target_message_id)
        if not message or message.conversation_id != conversation_id:
            raise ValueError("指定的 last_read_message_id 不属于当前会话")
        if state.last_read_message_id:
            target_message_id = max(state.last_read_message_id, target_message_id)
        state.last_read_message_id = target_message_id

    state.last_read_at = _utcnow()
    db.commit()
    db.refresh(state)
    return state
