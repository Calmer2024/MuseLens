import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database import Base, get_db
from app.lenses import registry
from app.main import app


@pytest.fixture(scope="function")
def test_db():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    session_local = sessionmaker(autocommit=False, autoflush=False, bind=engine)

    def override_get_db():
        db = session_local()
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[get_db] = override_get_db
    db = session_local()
    yield db
    db.close()
    engine.dispose()
    app.dependency_overrides.clear()
    registry.LENS_REGISTRY.clear()
    registry.load_builtin_lenses_into_memory()


@pytest.fixture(scope="function")
def client(test_db):
    return TestClient(app)


def _create_project_with_root(client: TestClient) -> tuple[dict, dict]:
    project_resp = client.post(
        "/api/v1/asset-tree/projects",
        json={"name": "编辑会话测试项目", "description": "用于验证编辑片段树链路"},
    )
    assert project_resp.status_code == 200
    project = project_resp.json()

    root_resp = client.post(
        f"/api/v1/asset-tree/projects/{project['project_id']}/root-node",
        json={
            "image_url": "s3://bucket/root.png",
            "thumbnail_url": "s3://bucket/root_thumb.png",
            "width": 1280,
            "height": 720,
            "format": "png",
            "metadata": {"source": "upload"},
        },
    )
    assert root_resp.status_code == 201
    return project, root_resp.json()


def _create_editor_session(client: TestClient, project_id: str) -> dict:
    session_resp = client.post(
        f"/api/v1/editor-sessions/projects/{project_id}/sessions",
        json={
            "title": "修图历史会话",
            "description": "用于记录一次完整的修图推演",
        },
    )
    assert session_resp.status_code == 201
    return session_resp.json()


def test_editor_session_asset_binding_and_lookup_flow(client: TestClient):
    project, root_node = _create_project_with_root(client)
    session = _create_editor_session(client, project["project_id"])

    assert session["base_node_id"] == root_node["node_id"]
    assert session["episode_count"] == 0
    assert session["branch_count"] == 0

    episode_resp = client.post(
        f"/api/v1/editor-sessions/sessions/{session['session_id']}/episodes",
        json={
            "source_node_id": root_node["node_id"],
            "title": "提亮天空",
            "user_intent": "把天空提亮一点，但不要过曝",
            "assistant_plan": "先压高光，再整体抬亮中间调",
            "action_summary": "准备进行一轮亮度增强",
            "tags": ["亮度", "天空"],
            "action_items": ["提高曝光", "保留层次"],
            "tool_snapshot": {"tool": "tone_curve", "strength": 0.35},
            "metadata": {"scene": "outdoor"},
            "status": "draft",
        },
    )
    assert episode_resp.status_code == 201
    episode = episode_resp.json()

    assert episode["source_node_id"] == root_node["node_id"]
    assert episode["target_node_id"] is None
    assert episode["message_count"] == 2
    assert episode["tool_snapshot"]["tool"] == "tone_curve"

    child_resp = client.post(
        f"/api/v1/asset-tree/projects/{project['project_id']}/nodes",
        json={
            "parent_node_id": root_node["node_id"],
            "episode_id": episode["episode_id"],
            "image_url": "s3://bucket/episode_result.png",
            "thumbnail_url": "s3://bucket/episode_result_thumb.png",
            "width": 1280,
            "height": 720,
            "format": "png",
            "lens_id": "lens_tone_curve",
            "lens_name": "亮度曲线",
            "user_prompt": "提亮天空但保留云层细节",
            "parameters": {"exposure": 0.3},
            "generation_params": {"exposure": 0.3},
            "metadata": {"source": "generation"},
            "status": "completed",
        },
    )
    assert child_resp.status_code == 201
    child_payload = child_resp.json()
    child_node = child_payload["node"]

    session_detail_resp = client.get(f"/api/v1/editor-sessions/sessions/{session['session_id']}")
    assert session_detail_resp.status_code == 200
    session_detail = session_detail_resp.json()
    assert session_detail["current_episode_id"] == episode["episode_id"]
    assert session_detail["episode_count"] == 1

    episode_detail_resp = client.get(f"/api/v1/editor-sessions/episodes/{episode['episode_id']}")
    assert episode_detail_resp.status_code == 200
    episode_detail = episode_detail_resp.json()
    assert episode_detail["episode"]["target_node_id"] == child_node["node_id"]
    assert episode_detail["episode"]["status"] == "completed"
    assert len(episode_detail["messages"]) == 2
    assert episode_detail["messages"][0]["message_kind"] == "intent"
    assert episode_detail["messages"][1]["message_kind"] == "plan"

    tree_resp = client.get(f"/api/v1/editor-sessions/sessions/{session['session_id']}/tree")
    assert tree_resp.status_code == 200
    tree = tree_resp.json()
    assert len(tree["episodes"]) == 1
    assert tree["edges"] == []

    lookup_resp = client.get(
        f"/api/v1/editor-sessions/episodes/by-node/{child_node['node_id']}",
        params={"session_id": session["session_id"]},
    )
    assert lookup_resp.status_code == 200
    lookup = lookup_resp.json()
    assert lookup["episode"]["episode_id"] == episode["episode_id"]
    assert lookup["session"]["session_id"] == session["session_id"]


def test_editor_session_branch_count_and_extra_messages(client: TestClient):
    project, root_node = _create_project_with_root(client)
    session = _create_editor_session(client, project["project_id"])

    base_episode_resp = client.post(
        f"/api/v1/editor-sessions/sessions/{session['session_id']}/episodes",
        json={
            "source_node_id": root_node["node_id"],
            "title": "基础去雾",
            "user_intent": "先把整体雾气压下去",
            "assistant_plan": "提升清晰度并轻微增加对比度",
        },
    )
    assert base_episode_resp.status_code == 201
    base_episode = base_episode_resp.json()

    bind_base_resp = client.post(
        f"/api/v1/asset-tree/projects/{project['project_id']}/nodes",
        json={
            "parent_node_id": root_node["node_id"],
            "episode_id": base_episode["episode_id"],
            "image_url": "s3://bucket/base_result.png",
            "thumbnail_url": "s3://bucket/base_result_thumb.png",
            "status": "completed",
        },
    )
    assert bind_base_resp.status_code == 201
    base_result_node = bind_base_resp.json()["node"]

    warm_episode_resp = client.post(
        f"/api/v1/editor-sessions/sessions/{session['session_id']}/episodes",
        json={
            "parent_episode_id": base_episode["episode_id"],
            "title": "暖色版本",
            "branch_name": "风格分支",
            "user_intent": "做一个偏暖色的版本",
            "assistant_plan": "提升色温并增加少量橙色氛围",
        },
    )
    assert warm_episode_resp.status_code == 201
    warm_episode = warm_episode_resp.json()
    assert warm_episode["source_node_id"] == base_result_node["node_id"]

    cool_episode_resp = client.post(
        f"/api/v1/editor-sessions/sessions/{session['session_id']}/episodes",
        json={
            "parent_episode_id": base_episode["episode_id"],
            "title": "冷色版本",
            "branch_name": "风格分支",
            "user_intent": "再做一个偏冷色的版本",
            "assistant_plan": "降低色温并保持通透感",
        },
    )
    assert cool_episode_resp.status_code == 201
    cool_episode = cool_episode_resp.json()

    assert cool_episode["round_index"] == 2
    assert cool_episode["parent_episode_id"] == base_episode["episode_id"]

    session_detail_resp = client.get(f"/api/v1/editor-sessions/sessions/{session['session_id']}")
    assert session_detail_resp.status_code == 200
    session_detail = session_detail_resp.json()
    assert session_detail["episode_count"] == 3
    assert session_detail["branch_count"] == 1
    assert session_detail["current_episode_id"] == cool_episode["episode_id"]

    add_message_resp = client.post(
        f"/api/v1/editor-sessions/episodes/{warm_episode['episode_id']}/messages",
        json={
            "role": "assistant",
            "message_kind": "note",
            "content": "这一支重点保留暖色氛围，适合黄昏题材。",
        },
    )
    assert add_message_resp.status_code == 201
    added_message = add_message_resp.json()
    assert added_message["role"] == "assistant"
    assert added_message["message_kind"] == "note"

    warm_detail_resp = client.get(f"/api/v1/editor-sessions/episodes/{warm_episode['episode_id']}")
    assert warm_detail_resp.status_code == 200
    warm_detail = warm_detail_resp.json()
    assert warm_detail["parent_episode"]["episode_id"] == base_episode["episode_id"]
    assert len(warm_detail["messages"]) == 3
    assert warm_detail["messages"][-1]["content"] == "这一支重点保留暖色氛围，适合黄昏题材。"
