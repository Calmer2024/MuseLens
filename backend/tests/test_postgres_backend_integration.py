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

    lens_resp = client.post(
        "/api/v1/market/lenses",
        json={
            "lens_key": "lens_pg_market_v1",
            "name": "数据库市场透镜",
            "description": "测试市场链路",
            "author_id": author["user_id"],
            "category": "integration",
            "price": "1.99",
            "is_official": False,
            "status": "active",
        },
    )
    assert lens_resp.status_code == 201
    lens = lens_resp.json()

    version_resp = client.post(
        f"/api/v1/market/lenses/{lens['lens_id']}/versions",
        json={
            "version": "1.0.0",
            "base_workflow": {"nodes": []},
            "parameters": {"strength": {"type": "float"}},
            "ui_schema": {"layout": "slider"},
            "changelog": "首次发布",
            "is_latest": True,
        },
    )
    assert version_resp.status_code == 201
    version = version_resp.json()

    install_resp = client.post(
        f"/api/v1/market/lenses/{lens['lens_id']}/install",
        json={"user_id": user["user_id"], "version_id": version["version_id"]},
    )
    assert install_resp.status_code == 200

    review_resp = client.post(
        f"/api/v1/market/lenses/{lens['lens_id']}/reviews",
        json={"user_id": user["user_id"], "rating": 4, "content": "可以正常安装使用"},
    )
    assert review_resp.status_code == 200

    installed_resp = client.get(f"/api/v1/market/users/{user['user_id']}/installed")
    assert installed_resp.status_code == 200
    assert installed_resp.json()[0]["lens_key"] == "lens_pg_market_v1"
