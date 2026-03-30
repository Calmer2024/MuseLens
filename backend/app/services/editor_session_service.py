"""
编辑会话与编辑片段树服务。

这一层负责把“修图对话历史”与“资产树版本历史”绑定起来：
- editor_sessions：项目级会话
- editor_episodes：一次具体的编辑片段
- editor_episode_messages：片段内部的对话与说明
"""

from __future__ import annotations

from typing import Any, Dict, List, Optional

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.asset_tree_models import AssetNode, Project
from app.models.editor_session_models import EditorEpisode, EditorEpisodeMessage, EditorSession


ALLOWED_EPISODE_STATUS = {"draft", "completed", "archived"}
ALLOWED_MESSAGE_ROLES = {"user", "assistant", "system"}
ALLOWED_MESSAGE_KINDS = {"intent", "plan", "decision", "note", "system_event"}


def _normalize_text(value: str | None) -> str:
    return (value or "").strip()


def _normalize_choice(
    name: str,
    value: str | None,
    *,
    allowed: set[str],
    default: str,
) -> str:
    normalized = _normalize_text(value) or default
    if normalized not in allowed:
        raise ValueError(f"{name} 不合法，可选值为：{', '.join(sorted(allowed))}")
    return normalized


def get_project(db: Session, project_id: str) -> Optional[Project]:
    return db.query(Project).filter(Project.project_id == project_id).first()


def get_asset_node(db: Session, node_id: str | None) -> Optional[AssetNode]:
    if not node_id:
        return None
    return db.query(AssetNode).filter(AssetNode.node_id == node_id).first()


def get_editor_session(db: Session, session_id: str) -> Optional[EditorSession]:
    return db.query(EditorSession).filter(EditorSession.session_id == session_id).first()


def get_episode(db: Session, episode_id: int) -> Optional[EditorEpisode]:
    return db.query(EditorEpisode).filter(EditorEpisode.episode_id == episode_id).first()


def _require_session(db: Session, session_id: str) -> EditorSession:
    session = get_editor_session(db, session_id)
    if not session:
        raise LookupError(f"编辑会话不存在：{session_id}")
    return session


def _require_episode(db: Session, episode_id: int) -> EditorEpisode:
    episode = get_episode(db, episode_id)
    if not episode:
        raise LookupError(f"编辑片段不存在：{episode_id}")
    return episode


def _ensure_node_in_project(db: Session, project_id: str, node_id: str | None) -> Optional[AssetNode]:
    node = get_asset_node(db, node_id)
    if node is None:
        return None
    if node.project_id != project_id:
        raise ValueError(f"节点 {node_id} 不属于项目 {project_id}")
    return node


def _serialize_node_ref(db: Session, node_id: str | None) -> Optional[Dict[str, Any]]:
    node = get_asset_node(db, node_id)
    if node is None:
        return None
    return {
        "node_id": node.node_id,
        "project_id": node.project_id,
        "image_url": node.image_url,
        "thumbnail_url": node.thumbnail_url,
        "depth": node.depth,
        "status": node.status,
        "label": node.label,
    }


def _message_preview(episode: EditorEpisode) -> str:
    for raw in (episode.user_intent, episode.assistant_plan, episode.action_summary):
        text = _normalize_text(raw)
        if text:
            return text[:80]
    return ""


def serialize_session(db: Session, session: EditorSession) -> Dict[str, Any]:
    return {
        "session_id": session.session_id,
        "project_id": session.project_id,
        "title": session.title,
        "description": session.description,
        "base_node_id": session.base_node_id,
        "current_episode_id": session.current_episode_id,
        "episode_count": session.episode_count,
        "branch_count": session.branch_count,
        "base_node": _serialize_node_ref(db, session.base_node_id),
        "created_at": session.created_at,
        "updated_at": session.updated_at,
    }


def serialize_episode(db: Session, episode: EditorEpisode) -> Dict[str, Any]:
    return {
        "episode_id": episode.episode_id,
        "session_id": episode.session_id,
        "parent_episode_id": episode.parent_episode_id,
        "source_node_id": episode.source_node_id,
        "target_node_id": episode.target_node_id,
        "round_index": episode.round_index,
        "branch_name": episode.branch_name,
        "title": episode.title,
        "user_intent": episode.user_intent,
        "assistant_plan": episode.assistant_plan,
        "action_summary": episode.action_summary,
        "tags": list(episode.tags or []),
        "action_items": list(episode.action_items or []),
        "tool_snapshot": dict(episode.tool_snapshot or {}),
        "metadata": dict(episode.extra_metadata or {}),
        "message_count": episode.message_count,
        "status": episode.status,
        "message_preview": _message_preview(episode),
        "source_node": _serialize_node_ref(db, episode.source_node_id),
        "target_node": _serialize_node_ref(db, episode.target_node_id),
        "created_at": episode.created_at,
        "updated_at": episode.updated_at,
    }


def serialize_episode_message(message: EditorEpisodeMessage) -> Dict[str, Any]:
    return {
        "message_id": message.message_id,
        "episode_id": message.episode_id,
        "role": message.role,
        "message_kind": message.message_kind,
        "content": message.content,
        "payload": message.payload,
        "created_at": message.created_at,
    }


def get_editor_session_payload(db: Session, session_id: str) -> Dict[str, Any]:
    session = _require_session(db, session_id)
    return serialize_session(db, session)


def _refresh_session_counters(db: Session, session: EditorSession) -> None:
    session.episode_count = (
        db.query(EditorEpisode)
        .filter(EditorEpisode.session_id == session.session_id)
        .count()
    )

    branching_parent_count = (
        db.query(EditorEpisode.parent_episode_id)
        .filter(
            EditorEpisode.session_id == session.session_id,
            EditorEpisode.parent_episode_id.is_not(None),
        )
        .group_by(EditorEpisode.parent_episode_id)
        .having(func.count(EditorEpisode.episode_id) >= 2)
        .count()
    )
    session.branch_count = int(branching_parent_count or 0)


def create_editor_session(
    db: Session,
    *,
    project_id: str,
    title: str | None,
    description: str,
    base_node_id: str | None = None,
) -> EditorSession:
    project = get_project(db, project_id)
    if not project:
        raise LookupError(f"项目不存在：{project_id}")

    if base_node_id is None:
        base_node_id = project.current_node_id or project.root_node_id

    if base_node_id is not None and _ensure_node_in_project(db, project_id, base_node_id) is None:
        raise LookupError(f"节点不存在：{base_node_id}")

    normalized_title = _normalize_text(title)
    if not normalized_title:
        normalized_title = f"{project.name} 编辑会话"

    session = EditorSession(
        project_id=project_id,
        title=normalized_title,
        description=_normalize_text(description),
        base_node_id=base_node_id,
        current_episode_id=None,
        episode_count=0,
        branch_count=0,
    )
    db.add(session)
    db.commit()
    db.refresh(session)
    return session


def list_project_editor_sessions(db: Session, project_id: str) -> List[EditorSession]:
    if not get_project(db, project_id):
        raise LookupError(f"项目不存在：{project_id}")
    return (
        db.query(EditorSession)
        .filter(EditorSession.project_id == project_id)
        .order_by(EditorSession.updated_at.desc(), EditorSession.created_at.desc())
        .all()
    )


def _default_episode_title(user_intent: str, assistant_plan: str, round_index: int) -> str:
    for raw in (_normalize_text(user_intent), _normalize_text(assistant_plan)):
        if raw:
            return raw[:40]
    return f"编辑片段 {round_index}"


def _append_auto_message(
    db: Session,
    *,
    episode: EditorEpisode,
    role: str,
    message_kind: str,
    content: str,
) -> None:
    normalized_content = _normalize_text(content)
    if not normalized_content:
        return

    db.add(
        EditorEpisodeMessage(
            episode_id=episode.episode_id,
            role=role,
            message_kind=message_kind,
            content=normalized_content,
            payload=None,
        )
    )
    episode.message_count += 1


def create_episode(
    db: Session,
    *,
    session_id: str,
    parent_episode_id: int | None,
    source_node_id: str | None,
    title: str | None,
    branch_name: str | None,
    user_intent: str,
    assistant_plan: str,
    action_summary: str,
    tags: List[str],
    action_items: List[str],
    tool_snapshot: Dict[str, Any],
    metadata: Dict[str, Any],
    status: str,
) -> EditorEpisode:
    session = _require_session(db, session_id)

    parent_episode = None
    if parent_episode_id is not None:
        parent_episode = get_episode(db, parent_episode_id)
        if not parent_episode or parent_episode.session_id != session_id:
            raise ValueError("父片段不存在，或不属于当前会话")

    normalized_user_intent = _normalize_text(user_intent)
    normalized_assistant_plan = _normalize_text(assistant_plan)
    if not normalized_user_intent and not normalized_assistant_plan:
        raise ValueError("user_intent 和 assistant_plan 不能同时为空")

    if source_node_id is None:
        if parent_episode and parent_episode.target_node_id:
            source_node_id = parent_episode.target_node_id
        else:
            source_node_id = session.base_node_id

    if source_node_id is not None and _ensure_node_in_project(db, session.project_id, source_node_id) is None:
        raise LookupError(f"节点不存在：{source_node_id}")

    round_index = (parent_episode.round_index + 1) if parent_episode else 1
    normalized_branch_name = _normalize_text(branch_name) or (
        parent_episode.branch_name if parent_episode else "主线"
    )
    normalized_title = _normalize_text(title) or _default_episode_title(
        normalized_user_intent,
        normalized_assistant_plan,
        round_index,
    )
    normalized_status = _normalize_choice(
        "status",
        status,
        allowed=ALLOWED_EPISODE_STATUS,
        default="draft",
    )

    episode = EditorEpisode(
        session_id=session_id,
        parent_episode_id=parent_episode_id,
        source_node_id=source_node_id,
        target_node_id=None,
        round_index=round_index,
        branch_name=normalized_branch_name,
        title=normalized_title,
        user_intent=normalized_user_intent,
        assistant_plan=normalized_assistant_plan,
        action_summary=_normalize_text(action_summary),
        tags=list(tags or []),
        action_items=list(action_items or []),
        tool_snapshot=dict(tool_snapshot or {}),
        extra_metadata=dict(metadata or {}),
        message_count=0,
        status=normalized_status,
    )
    db.add(episode)
    db.flush()

    _append_auto_message(db, episode=episode, role="user", message_kind="intent", content=normalized_user_intent)
    _append_auto_message(db, episode=episode, role="assistant", message_kind="plan", content=normalized_assistant_plan)

    session.current_episode_id = episode.episode_id
    _refresh_session_counters(db, session)
    db.commit()
    db.refresh(episode)
    return episode


def add_episode_message(
    db: Session,
    *,
    episode_id: int,
    role: str,
    message_kind: str,
    content: str,
    payload: Dict[str, Any] | None,
) -> EditorEpisodeMessage:
    episode = _require_episode(db, episode_id)
    normalized_content = _normalize_text(content)
    if not normalized_content and not payload:
        raise ValueError("content 和 payload 不能同时为空")

    normalized_role = _normalize_choice(
        "role",
        role,
        allowed=ALLOWED_MESSAGE_ROLES,
        default="user",
    )
    normalized_message_kind = _normalize_choice(
        "message_kind",
        message_kind,
        allowed=ALLOWED_MESSAGE_KINDS,
        default="note",
    )

    message = EditorEpisodeMessage(
        episode_id=episode_id,
        role=normalized_role,
        message_kind=normalized_message_kind,
        content=normalized_content,
        payload=payload,
    )
    db.add(message)
    episode.message_count += 1

    session = _require_session(db, episode.session_id)
    session.current_episode_id = episode_id
    _refresh_session_counters(db, session)

    db.commit()
    db.refresh(message)
    return message


def validate_episode_for_child_node(
    db: Session,
    *,
    episode_id: int,
    project_id: str,
    parent_node_id: str,
) -> EditorEpisode:
    episode = _require_episode(db, episode_id)
    session = _require_session(db, episode.session_id)
    if session.project_id != project_id:
        raise ValueError("编辑片段不属于当前项目")

    parent_node = _ensure_node_in_project(db, project_id, parent_node_id)
    if parent_node is None:
        raise LookupError(f"节点不存在：{parent_node_id}")

    if episode.target_node_id:
        raise ValueError("该编辑片段已经绑定了结果节点")
    if episode.source_node_id and episode.source_node_id != parent_node.node_id:
        raise ValueError("编辑片段的 source_node_id 与当前 parent_node_id 不一致")
    return episode


def bind_episode_target_node(
    db: Session,
    *,
    episode_id: int,
    target_node_id: str,
    source_node_id: str | None = None,
    action_summary: str | None = None,
    status: str = "completed",
    auto_commit: bool = True,
) -> EditorEpisode:
    episode = _require_episode(db, episode_id)
    session = _require_session(db, episode.session_id)
    normalized_status = _normalize_choice(
        "status",
        status,
        allowed=ALLOWED_EPISODE_STATUS,
        default="completed",
    )

    target_node = _ensure_node_in_project(db, session.project_id, target_node_id)
    if target_node is None:
        raise LookupError(f"节点不存在：{target_node_id}")

    duplicate_target_episode = (
        db.query(EditorEpisode)
        .filter(
            EditorEpisode.session_id == session.session_id,
            EditorEpisode.target_node_id == target_node_id,
            EditorEpisode.episode_id != episode_id,
        )
        .first()
    )
    if duplicate_target_episode:
        raise ValueError(f"结果节点 {target_node_id} 已绑定到片段 {duplicate_target_episode.episode_id}")

    if source_node_id is not None:
        source_node = _ensure_node_in_project(db, session.project_id, source_node_id)
        if source_node is None:
            raise LookupError(f"节点不存在：{source_node_id}")
        if episode.source_node_id and episode.source_node_id != source_node_id:
            raise ValueError("编辑片段已经绑定了其他 source_node_id")
        episode.source_node_id = source_node_id

    if episode.target_node_id and episode.target_node_id != target_node_id:
        raise ValueError("该编辑片段已经绑定了其他结果节点")

    episode.target_node_id = target_node_id
    if action_summary is not None:
        episode.action_summary = _normalize_text(action_summary)
    episode.status = normalized_status

    session.current_episode_id = episode.episode_id
    _refresh_session_counters(db, session)

    if auto_commit:
        db.commit()
        db.refresh(episode)
    else:
        db.flush()
    return episode


def list_episode_messages(db: Session, episode_id: int) -> List[EditorEpisodeMessage]:
    _require_episode(db, episode_id)
    return (
        db.query(EditorEpisodeMessage)
        .filter(EditorEpisodeMessage.episode_id == episode_id)
        .order_by(EditorEpisodeMessage.created_at.asc(), EditorEpisodeMessage.message_id.asc())
        .all()
    )


def get_session_tree(db: Session, session_id: str) -> Dict[str, Any]:
    session = _require_session(db, session_id)
    episodes = (
        db.query(EditorEpisode)
        .filter(EditorEpisode.session_id == session_id)
        .order_by(EditorEpisode.created_at.asc(), EditorEpisode.episode_id.asc())
        .all()
    )
    edges = [
        {"parent_episode_id": item.parent_episode_id, "episode_id": item.episode_id}
        for item in episodes
        if item.parent_episode_id is not None
    ]
    return {
        "session": serialize_session(db, session),
        "episodes": [serialize_episode(db, item) for item in episodes],
        "edges": edges,
    }


def get_episode_detail(db: Session, episode_id: int) -> Dict[str, Any]:
    episode = _require_episode(db, episode_id)
    session = _require_session(db, episode.session_id)
    parent_episode = get_episode(db, episode.parent_episode_id) if episode.parent_episode_id else None
    child_episodes = (
        db.query(EditorEpisode)
        .filter(EditorEpisode.parent_episode_id == episode.episode_id)
        .order_by(EditorEpisode.created_at.asc(), EditorEpisode.episode_id.asc())
        .all()
    )
    messages = list_episode_messages(db, episode_id)
    return {
        "session": serialize_session(db, session),
        "episode": serialize_episode(db, episode),
        "parent_episode": serialize_episode(db, parent_episode) if parent_episode else None,
        "child_episodes": [serialize_episode(db, item) for item in child_episodes],
        "messages": [serialize_episode_message(item) for item in messages],
    }


def find_episode_by_target_node(db: Session, *, session_id: str, node_id: str) -> Dict[str, Any]:
    session = _require_session(db, session_id)
    episode = (
        db.query(EditorEpisode)
        .filter(EditorEpisode.session_id == session_id, EditorEpisode.target_node_id == node_id)
        .order_by(EditorEpisode.created_at.desc(), EditorEpisode.episode_id.desc())
        .first()
    )
    if not episode:
        raise LookupError(f"节点 {node_id} 尚未绑定到任何编辑片段")
    return {
        "session": serialize_session(db, session),
        "episode": serialize_episode(db, episode),
    }
