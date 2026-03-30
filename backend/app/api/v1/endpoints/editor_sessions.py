"""
编辑会话 / 编辑片段树接口。
"""

from __future__ import annotations

from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.schemas.editor_session import (
    EditorEpisodeBindTargetRequest,
    EditorEpisodeCreateRequest,
    EditorEpisodeDetailResponse,
    EditorEpisodeEdgeOut,
    EditorEpisodeLookupResponse,
    EditorEpisodeMessageCreateRequest,
    EditorEpisodeMessageOut,
    EditorEpisodeOut,
    EditorSessionCreateRequest,
    EditorSessionOut,
    EditorSessionTreeResponse,
)
from app.services import editor_session_service as svc

router = APIRouter()


def _raise_editor_error(exc: Exception) -> None:
    if isinstance(exc, LookupError):
        raise HTTPException(status_code=404, detail=str(exc))
    raise HTTPException(status_code=400, detail=str(exc))


def _session_out(db: Session, session) -> EditorSessionOut:
    payload = session if isinstance(session, dict) else svc.serialize_session(db, session)
    return EditorSessionOut.model_validate(payload)


def _episode_out(db: Session, episode) -> EditorEpisodeOut:
    payload = episode if isinstance(episode, dict) else svc.serialize_episode(db, episode)
    return EditorEpisodeOut.model_validate(payload)


def _message_out(message) -> EditorEpisodeMessageOut:
    payload = message if isinstance(message, dict) else svc.serialize_episode_message(message)
    return EditorEpisodeMessageOut.model_validate(payload)


@router.post(
    "/projects/{project_id}/sessions",
    response_model=EditorSessionOut,
    status_code=201,
    summary="创建编辑会话",
)
def create_editor_session(
    project_id: str,
    body: EditorSessionCreateRequest,
    db: Session = Depends(get_db),
) -> EditorSessionOut:
    try:
        session = svc.create_editor_session(
            db,
            project_id=project_id,
            title=body.title,
            description=body.description,
            base_node_id=body.base_node_id,
        )
    except Exception as exc:
        _raise_editor_error(exc)
    return _session_out(db, session)


@router.get(
    "/projects/{project_id}/sessions",
    response_model=List[EditorSessionOut],
    summary="获取项目下的编辑会话列表",
)
def list_project_editor_sessions(
    project_id: str,
    db: Session = Depends(get_db),
) -> List[EditorSessionOut]:
    try:
        sessions = svc.list_project_editor_sessions(db, project_id)
    except Exception as exc:
        _raise_editor_error(exc)
    return [_session_out(db, item) for item in sessions]


@router.get(
    "/sessions/{session_id}",
    response_model=EditorSessionOut,
    summary="获取编辑会话详情",
)
def get_editor_session_detail(
    session_id: str,
    db: Session = Depends(get_db),
) -> EditorSessionOut:
    try:
        payload = svc.get_editor_session_payload(db, session_id)
    except Exception as exc:
        _raise_editor_error(exc)
    return _session_out(db, payload)


@router.get(
    "/sessions/{session_id}/tree",
    response_model=EditorSessionTreeResponse,
    summary="获取编辑片段树",
)
def get_editor_session_tree(
    session_id: str,
    db: Session = Depends(get_db),
) -> EditorSessionTreeResponse:
    try:
        tree = svc.get_session_tree(db, session_id)
    except Exception as exc:
        _raise_editor_error(exc)

    return EditorSessionTreeResponse(
        session=_session_out(db, tree["session"]),
        episodes=[_episode_out(db, item) for item in tree["episodes"]],
        edges=[EditorEpisodeEdgeOut.model_validate(item) for item in tree["edges"]],
    )


@router.post(
    "/sessions/{session_id}/episodes",
    response_model=EditorEpisodeOut,
    status_code=201,
    summary="创建编辑片段",
)
def create_editor_episode(
    session_id: str,
    body: EditorEpisodeCreateRequest,
    db: Session = Depends(get_db),
) -> EditorEpisodeOut:
    try:
        episode = svc.create_episode(
            db,
            session_id=session_id,
            parent_episode_id=body.parent_episode_id,
            source_node_id=body.source_node_id,
            title=body.title,
            branch_name=body.branch_name,
            user_intent=body.user_intent,
            assistant_plan=body.assistant_plan,
            action_summary=body.action_summary,
            tags=body.tags,
            action_items=body.action_items,
            tool_snapshot=body.tool_snapshot,
            metadata=body.metadata,
            status=body.status,
        )
    except Exception as exc:
        _raise_editor_error(exc)
    return _episode_out(db, episode)


@router.get(
    "/episodes/by-node/{node_id}",
    response_model=EditorEpisodeLookupResponse,
    summary="通过结果节点反查编辑片段",
)
def find_episode_by_target_node(
    node_id: str,
    session_id: str = Query(..., description="编辑会话 ID"),
    db: Session = Depends(get_db),
) -> EditorEpisodeLookupResponse:
    try:
        payload = svc.find_episode_by_target_node(db, session_id=session_id, node_id=node_id)
    except Exception as exc:
        _raise_editor_error(exc)

    return EditorEpisodeLookupResponse(
        session=_session_out(db, payload["session"]),
        episode=_episode_out(db, payload["episode"]),
    )


@router.get(
    "/episodes/{episode_id}",
    response_model=EditorEpisodeDetailResponse,
    summary="获取编辑片段详情",
)
def get_editor_episode_detail(
    episode_id: int,
    db: Session = Depends(get_db),
) -> EditorEpisodeDetailResponse:
    try:
        detail = svc.get_episode_detail(db, episode_id)
    except Exception as exc:
        _raise_editor_error(exc)

    return EditorEpisodeDetailResponse(
        session=_session_out(db, detail["session"]),
        episode=_episode_out(db, detail["episode"]),
        parent_episode=_episode_out(db, detail["parent_episode"]) if detail["parent_episode"] else None,
        child_episodes=[_episode_out(db, item) for item in detail["child_episodes"]],
        messages=[_message_out(item) for item in detail["messages"]],
    )


@router.post(
    "/episodes/{episode_id}/messages",
    response_model=EditorEpisodeMessageOut,
    status_code=201,
    summary="给编辑片段追加消息",
)
def add_editor_episode_message(
    episode_id: int,
    body: EditorEpisodeMessageCreateRequest,
    db: Session = Depends(get_db),
) -> EditorEpisodeMessageOut:
    try:
        message = svc.add_episode_message(
            db,
            episode_id=episode_id,
            role=body.role,
            message_kind=body.message_kind,
            content=body.content,
            payload=body.payload,
        )
    except Exception as exc:
        _raise_editor_error(exc)
    return _message_out(message)


@router.post(
    "/episodes/{episode_id}/bind-target",
    response_model=EditorEpisodeOut,
    summary="手动绑定编辑片段结果节点",
)
def bind_editor_episode_target(
    episode_id: int,
    body: EditorEpisodeBindTargetRequest,
    db: Session = Depends(get_db),
) -> EditorEpisodeOut:
    try:
        episode = svc.bind_episode_target_node(
            db,
            episode_id=episode_id,
            target_node_id=body.target_node_id,
            source_node_id=body.source_node_id,
            action_summary=body.action_summary,
            status=body.status,
        )
    except Exception as exc:
        _raise_editor_error(exc)
    return _episode_out(db, episode)
