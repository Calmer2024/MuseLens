import json
import os
import tempfile

import pytest

from app.models.lens_model import LensRecord


@pytest.fixture(scope="function")
def temp_workflow_file():
    with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False, encoding="utf-8") as f:
        json.dump(
            {
                "1": {"inputs": {"image": "input.png"}, "class_type": "LoadImage"},
                "2": {"inputs": {"text": "prompt"}, "class_type": "CLIPTextEncode"},
            },
            f,
        )
        path = f.name
    yield path
    if os.path.exists(path):
        os.remove(path)


@pytest.mark.integration
def test_postgres_engine_and_lens_record_roundtrip(postgres_test_db):
    db = postgres_test_db["db"]
    db.add(
        LensRecord(
            lens_id="lens_pg_roundtrip",
            layer="A2",
            description="postgres lens",
            workflow_file_path="dummy.json",
            inputs=[],
            outputs=[],
            params=[{"name": "prompt", "type": "text", "mapping": {"node_id": "1", "field_name": "text"}}],
        )
    )
    db.commit()

    record = db.query(LensRecord).filter(LensRecord.lens_id == "lens_pg_roundtrip").first()
    assert record is not None
    assert record.description == "postgres lens"
    assert isinstance(record.params, list)
    assert record.params[0]["name"] == "prompt"


@pytest.mark.integration
def test_postgres_lens_api_roundtrip(client, postgres_test_db, temp_workflow_file):
    payload = {
        "lens_id": "lens_pg_api",
        "layer": "A1",
        "description": "postgres api lens",
        "workflow_file_path": temp_workflow_file,
        "inputs": [
            {"name": "base_image", "type": "image", "mapping": {"node_id": "1", "field_name": "image"}}
        ],
        "outputs": [
            {"name": "result_image", "type": "image", "mapping": {"node_id": "1", "field_name": "images"}}
        ],
        "params": [
            {"name": "prompt", "type": "text", "description": "提示词", "mapping": {"node_id": "2", "field_name": "text"}}
        ],
    }

    register_resp = client.post("/api/v1/lenses/register", json=payload)
    assert register_resp.status_code == 200
    assert register_resp.json()["lens_id"] == "lens_pg_api"

    list_resp = client.get("/api/v1/lenses/")
    assert list_resp.status_code == 200
    assert any(item["lens_id"] == "lens_pg_api" for item in list_resp.json())

    detail_resp = client.get("/api/v1/lenses/lens_pg_api")
    assert detail_resp.status_code == 200
    detail = detail_resp.json()
    assert detail["lens_id"] == "lens_pg_api"
    assert detail["params"][0]["name"] == "prompt"


@pytest.mark.integration
def test_postgres_asset_tree_api_roundtrip(client, postgres_test_db):
    project_resp = client.post(
        "/api/v1/asset-tree/projects",
        json={"name": "pg-project", "description": "postgres integration"},
    )
    assert project_resp.status_code == 200
    project = project_resp.json()
    project_id = project["project_id"]

    root_resp = client.post(
        f"/api/v1/asset-tree/projects/{project_id}/root-node",
        json={
            "image_url": "s3://bucket/root.png",
            "thumbnail_url": "s3://bucket/root_thumb.png",
            "width": 1024,
            "height": 768,
            "format": "png",
            "metadata": {"source": "upload"},
        },
    )
    assert root_resp.status_code == 201
    root_node = root_resp.json()

    child_resp = client.post(
        f"/api/v1/asset-tree/projects/{project_id}/nodes",
        json={
            "parent_node_id": root_node["node_id"],
            "image_url": "s3://bucket/child.png",
            "thumbnail_url": "s3://bucket/child_thumb.png",
            "lens_id": "lens_demo",
            "lens_name": "demo",
            "user_prompt": "make it brighter",
            "parameters": {"strength": 0.5},
            "muse_dna": {"steps": []},
            "generation_params": {"strength": 0.5},
            "status": "completed",
            "metadata": {"source": "generation"},
        },
    )
    assert child_resp.status_code == 201
    child = child_resp.json()["node"]

    tree_resp = client.get(f"/api/v1/asset-tree/projects/{project_id}/tree")
    assert tree_resp.status_code == 200
    tree = tree_resp.json()
    assert tree["project"]["current_node_id"] == child["node_id"]
    assert len(tree["nodes"]) == 2
    assert len(tree["edges"]) == 1

    ancestors_resp = client.get(f"/api/v1/asset-tree/nodes/{child['node_id']}/ancestors")
    assert ancestors_resp.status_code == 200
    ancestors = ancestors_resp.json()
    assert len(ancestors["ancestors"]) == 2
    assert len(ancestors["path_edges"]) == 1


@pytest.mark.integration
def test_postgres_user_community_market_roundtrip(client, postgres_test_db):
    user_resp = client.post(
        "/api/v1/users/register",
        json={
            "username": "pg_user",
            "password": "pass123456",
            "nickname": "数据库用户",
            "email": "pg_user@example.com",
            "bio": "用于 PostgreSQL 集成测试",
        },
    )
    assert user_resp.status_code == 200
    user = user_resp.json()

    author_resp = client.post(
        "/api/v1/users/register",
        json={
            "username": "pg_author",
            "password": "pass123456",
            "nickname": "数据库作者",
            "email": "pg_author@example.com",
            "bio": "",
        },
    )
    assert author_resp.status_code == 200
    author = author_resp.json()

    post_resp = client.post(
        "/api/v1/community/posts",
        json={
            "user_id": user["user_id"],
            "title": "PostgreSQL 社区帖子",
            "content": "测试社区链路",
            "images": [],
            "tag_names": ["postgres", "integration"],
        },
    )
    assert post_resp.status_code == 201
    post = post_resp.json()

    comment_resp = client.post(
        f"/api/v1/community/posts/{post['post_id']}/comments",
        json={"user_id": author["user_id"], "content": "评论一下"},
    )
    assert comment_resp.status_code == 201

    delete_forbidden_resp = client.request(
        "DELETE",
        f"/api/v1/community/posts/{post['post_id']}",
        json={"user_id": author["user_id"]},
    )
    assert delete_forbidden_resp.status_code == 403

    delete_resp = client.request(
        "DELETE",
        f"/api/v1/community/posts/{post['post_id']}",
        json={"user_id": user["user_id"]},
    )
    assert delete_resp.status_code == 200

    deleted_detail_resp = client.get(f"/api/v1/community/posts/{post['post_id']}")
    assert deleted_detail_resp.status_code == 404

    post_resp = client.post(
        "/api/v1/community/posts",
        json={
            "user_id": user["user_id"],
            "title": "PostgreSQL 社区帖子 2",
            "content": "删除后重新创建，继续测试市场链路",
            "images": [],
            "tag_names": ["postgres", "integration"],
        },
    )
    assert post_resp.status_code == 201
    post = post_resp.json()

    project_resp = client.post(
        "/api/v1/asset-tree/projects",
        json={
            "name": "pg-market-project",
            "description": "PostgreSQL 市场集成测试项目",
        },
    )
    assert project_resp.status_code == 200
    project = project_resp.json()

    root_resp = client.post(
        f"/api/v1/asset-tree/projects/{project['project_id']}/root-node",
        json={
            "image_url": "s3://bucket/market_root.png",
            "thumbnail_url": "s3://bucket/market_root_thumb.png",
            "width": 1024,
            "height": 768,
            "format": "png",
            "metadata": {"source": "upload"},
        },
    )
    assert root_resp.status_code == 201
    root_node = root_resp.json()

    blueprint = {
        "initial_inputs": {
            "base_image": "author_source.png",
        },
        "steps": [
            {
                "step_id": "step_pg_market_edit",
                "lens_id": "lens_pg_market_demo",
                "input_links": {
                    "base_image": "$base_image",
                },
                "params": {
                    "prompt": "clean and bright portrait look",
                    "strength": 0.45,
                },
            }
        ],
    }
    child_resp = client.post(
        f"/api/v1/asset-tree/projects/{project['project_id']}/nodes",
        json={
            "parent_node_id": root_node["node_id"],
            "image_url": "s3://bucket/market_child.png",
            "thumbnail_url": "s3://bucket/market_child_thumb.png",
            "width": 1024,
            "height": 768,
            "format": "png",
            "lens_id": "lens_pg_market_demo",
            "lens_name": "市场蓝图示例",
            "user_prompt": "提亮并保留自然肤色",
            "parameters": {"strength": 0.45},
            "muse_dna": blueprint,
            "generation_params": {"strength": 0.45},
            "status": "completed",
            "metadata": {"source": "generation"},
        },
    )
    assert child_resp.status_code == 201
    asset_node = child_resp.json()["node"]

    publish_resp = client.post(
        "/api/v1/market/templates/publish-from-node",
        json={
            "author_id": author["user_id"],
            "title": "数据库模板市场蓝图",
            "description": "测试 PostgreSQL 下的模板发布与应用链路",
            "result_asset_node_id": asset_node["node_id"],
            "tag_names": ["postgres", "template"],
            "category": "integration",
            "status": "active",
        },
    )
    assert publish_resp.status_code == 201
    published = publish_resp.json()
    lens = published["template"]
    version = published["version"]

    assert lens["title"] == "数据库模板市场蓝图"
    assert lens["cover_image_url"] == asset_node["thumbnail_url"]
    assert lens["result_asset_node_id"] == asset_node["node_id"]
    assert lens["original_image_url"] == root_node["image_url"]
    assert sorted(lens["tag_names"]) == ["postgres", "template"]
    assert version["source_asset_node_id"] == asset_node["node_id"]
    assert version["required_inputs"] == ["base_image"]
    assert version["musedna"]["initial_inputs"]["base_image"] == ""
    assert version["published_from"] == "asset_node"

    favorite_resp = client.post(
        f"/api/v1/market/templates/{lens['template_id']}/favorite",
        json={"user_id": user["user_id"]},
    )
    assert favorite_resp.status_code == 200

    review_resp = client.post(
        f"/api/v1/market/lenses/{lens['template_id']}/reviews",
        json={"user_id": user["user_id"], "rating": 4, "content": "可以正常安装使用"},
    )
    assert review_resp.status_code == 200

    apply_resp = client.post(
        f"/api/v1/market/templates/{lens['template_id']}/apply",
        json={
            "user_id": user["user_id"],
            "initial_inputs": {"base_image": "consumer_upload.png"},
            "param_overrides": {
                "step_pg_market_edit": {
                    "strength": 0.7,
                }
            },
        },
    )
    assert apply_resp.status_code == 200
    apply_payload = apply_resp.json()
    assert apply_payload["executed"] is False
    assert apply_payload["required_inputs"] == ["base_image"]
    assert apply_payload["musedna"]["initial_inputs"]["base_image"] == "consumer_upload.png"
    assert apply_payload["musedna"]["steps"][0]["params"]["strength"] == 0.7
    assert apply_payload["template"]["apply_count"] == 1

    detail_resp = client.get(f"/api/v1/market/templates/{lens['template_id']}")
    assert detail_resp.status_code == 200
    detail = detail_resp.json()
    assert detail["favorite_count"] == 1
    assert detail["apply_count"] == 1
    assert detail["rating_count"] == 1
    assert detail["current_version"]["required_inputs"] == ["base_image"]

    published_resp = client.get(f"/api/v1/market/users/{author['user_id']}/templates/published")
    assert published_resp.status_code == 200
    assert published_resp.json()[0]["template_id"] == lens["template_id"]

    favorites_resp = client.get(f"/api/v1/market/users/{user['user_id']}/templates/favorites")
    assert favorites_resp.status_code == 200
    assert favorites_resp.json()[0]["template_id"] == lens["template_id"]


@pytest.mark.integration
def test_postgres_chat_roundtrip(client, postgres_test_db):
    alice_resp = client.post(
        "/api/v1/users/register",
        json={
            "username": "pg_chat_alice",
            "password": "pass123456",
            "nickname": "聊天用户甲",
            "email": "pg_chat_alice@example.com",
            "bio": "用于聊天链路测试",
        },
    )
    assert alice_resp.status_code == 200
    alice = alice_resp.json()

    bob_resp = client.post(
        "/api/v1/users/register",
        json={
            "username": "pg_chat_bob",
            "password": "pass123456",
            "nickname": "聊天用户乙",
            "email": "pg_chat_bob@example.com",
            "bio": "用于聊天链路测试",
        },
    )
    assert bob_resp.status_code == 200
    bob = bob_resp.json()

    assert client.post(
        f"/api/v1/users/{bob['user_id']}/follow",
        json={"follower_id": alice["user_id"]},
    ).status_code == 200
    assert client.post(
        f"/api/v1/users/{alice['user_id']}/follow",
        json={"follower_id": bob["user_id"]},
    ).status_code == 200

    open_resp = client.post(
        "/api/v1/chat/conversations/direct",
        json={"user_id": alice["user_id"], "friend_user_id": bob["user_id"]},
    )
    assert open_resp.status_code == 200
    conversation = open_resp.json()["conversation"]
    conversation_id = conversation["conversation_id"]

    post_resp = client.post(
        "/api/v1/community/posts",
        json={
            "user_id": alice["user_id"],
            "title": "PostgreSQL 聊天分享帖子",
            "content": "这是一条给聊天模块做集成测试的帖子",
            "images": [],
            "tag_names": ["postgres", "chat"],
        },
    )
    assert post_resp.status_code == 201
    post = post_resp.json()

    lens_resp = client.post(
        "/api/v1/market/lenses",
        json={
            "lens_key": "lens_pg_chat_share",
            "name": "PostgreSQL 聊天预设",
            "description": "用于聊天模块分享测试",
            "author_id": bob["user_id"],
            "category": "chat",
            "price": "0.00",
            "is_official": False,
            "status": "active",
        },
    )
    assert lens_resp.status_code == 201
    lens = lens_resp.json()

    text_resp = client.post(
        f"/api/v1/chat/conversations/{conversation_id}/messages",
        json={"sender_id": alice["user_id"], "content": "PostgreSQL 文本消息"},
    )
    assert text_resp.status_code == 201

    share_post_resp = client.post(
        f"/api/v1/chat/conversations/{conversation_id}/messages",
        json={
            "sender_id": alice["user_id"],
            "content": "分享帖子给你",
            "share": {"share_type": "post", "post_id": post["post_id"]},
        },
    )
    assert share_post_resp.status_code == 201

    share_preset_resp = client.post(
        f"/api/v1/chat/conversations/{conversation_id}/messages",
        json={
            "sender_id": bob["user_id"],
            "content": "",
            "share": {"share_type": "preset", "market_lens_id": lens["lens_id"]},
        },
    )
    assert share_preset_resp.status_code == 201
    assert share_preset_resp.json()["share"]["share_source_type"] == "market_lens"

    messages_resp = client.get(
        f"/api/v1/chat/conversations/{conversation_id}/messages",
        params={"user_id": alice["user_id"], "limit": 20},
    )
    assert messages_resp.status_code == 200
    messages = messages_resp.json()["messages"]
    assert len(messages) == 3
    assert messages[1]["share"]["share_type"] == "post"
    assert messages[2]["share"]["share_type"] == "preset"

    detail_resp = client.get(
        f"/api/v1/chat/conversations/{conversation_id}",
        params={"user_id": alice["user_id"]},
    )
    assert detail_resp.status_code == 200
    assert detail_resp.json()["unread_count"] == 1

    read_resp = client.post(
        f"/api/v1/chat/conversations/{conversation_id}/read",
        json={"user_id": alice["user_id"]},
    )
    assert read_resp.status_code == 200

    detail_after_resp = client.get(
        f"/api/v1/chat/conversations/{conversation_id}",
        params={"user_id": alice["user_id"]},
    )
    assert detail_after_resp.status_code == 200
    assert detail_after_resp.json()["unread_count"] == 0


@pytest.mark.integration
def test_postgres_editor_session_asset_tree_roundtrip(client, postgres_test_db):
    project_resp = client.post(
        "/api/v1/asset-tree/projects",
        json={"name": "pg-editor-project", "description": "editor session integration"},
    )
    assert project_resp.status_code == 200
    project = project_resp.json()

    root_resp = client.post(
        f"/api/v1/asset-tree/projects/{project['project_id']}/root-node",
        json={
            "image_url": "s3://bucket/editor_root.png",
            "thumbnail_url": "s3://bucket/editor_root_thumb.png",
            "width": 1600,
            "height": 900,
            "format": "png",
            "metadata": {"source": "upload", "stage": "root"},
        },
    )
    assert root_resp.status_code == 201
    root_node = root_resp.json()

    session_resp = client.post(
        f"/api/v1/editor-sessions/projects/{project['project_id']}/sessions",
        json={
            "title": "PostgreSQL 编辑会话",
            "description": "验证 PostgreSQL 下的编辑片段树链路",
        },
    )
    assert session_resp.status_code == 201
    session = session_resp.json()
    assert session["base_node_id"] == root_node["node_id"]

    episode_resp = client.post(
        f"/api/v1/editor-sessions/sessions/{session['session_id']}/episodes",
        json={
            "source_node_id": root_node["node_id"],
            "title": "压高光",
            "user_intent": "把天空压下来一点",
            "assistant_plan": "降低高光并保留云层边缘",
            "tool_snapshot": {"tool": "highlight_recovery", "strength": 0.42},
            "metadata": {"pipeline": "tone"},
            "status": "draft",
        },
    )
    assert episode_resp.status_code == 201
    episode = episode_resp.json()
    assert episode["tool_snapshot"]["tool"] == "highlight_recovery"

    child_resp = client.post(
        f"/api/v1/asset-tree/projects/{project['project_id']}/nodes",
        json={
            "parent_node_id": root_node["node_id"],
            "episode_id": episode["episode_id"],
            "image_url": "s3://bucket/editor_result.png",
            "thumbnail_url": "s3://bucket/editor_result_thumb.png",
            "width": 1600,
            "height": 900,
            "format": "png",
            "lens_id": "lens_highlight",
            "lens_name": "高光恢复",
            "parameters": {"highlight": -25},
            "generation_params": {"highlight": -25},
            "metadata": {"source": "generation", "engine": "postgres-test"},
            "status": "completed",
        },
    )
    assert child_resp.status_code == 201
    child_node = child_resp.json()["node"]

    detail_resp = client.get(f"/api/v1/editor-sessions/episodes/{episode['episode_id']}")
    assert detail_resp.status_code == 200
    detail = detail_resp.json()
    assert detail["episode"]["target_node_id"] == child_node["node_id"]
    assert detail["episode"]["status"] == "completed"
    assert detail["episode"]["tool_snapshot"]["strength"] == 0.42
    assert detail["episode"]["metadata"]["pipeline"] == "tone"
    assert len(detail["messages"]) == 2

    tree_resp = client.get(f"/api/v1/editor-sessions/sessions/{session['session_id']}/tree")
    assert tree_resp.status_code == 200
    tree = tree_resp.json()
    assert tree["session"]["episode_count"] == 1
    assert len(tree["episodes"]) == 1

    lookup_resp = client.get(
        f"/api/v1/editor-sessions/episodes/by-node/{child_node['node_id']}",
        params={"session_id": session["session_id"]},
    )
    assert lookup_resp.status_code == 200
    assert lookup_resp.json()["episode"]["episode_id"] == episode["episode_id"]
