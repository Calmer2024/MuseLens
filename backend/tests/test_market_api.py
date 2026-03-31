from decimal import Decimal

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.api.v1.endpoints import market as market_endpoint
from app.core.database import Base, get_db
from app.lenses import registry
from app.main import app
from app.services import user_service


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


@pytest.fixture(scope="function")
def seeded_users(test_db):
    author = user_service.create_user(
        test_db,
        username="template_author",
        password="pass123456",
        nickname="模板作者",
        email="template_author@example.com",
    )
    consumer = user_service.create_user(
        test_db,
        username="template_consumer",
        password="pass123456",
        nickname="模板用户",
        email="template_consumer@example.com",
    )
    return author, consumer


def _shared_musedna() -> dict:
    return {
        "initial_inputs": {
            "base_image": "author_source.png",
        },
        "steps": [
            {
                "step_id": "step_1_template_edit",
                "lens_id": "lens_shared_demo",
                "input_links": {
                    "base_image": "$base_image",
                },
                "params": {
                    "prompt": "bright clean portrait look",
                    "strength": 0.45,
                },
            }
        ],
    }


def _create_asset_node_with_musedna(client: TestClient) -> tuple[dict, dict, dict]:
    project_resp = client.post(
        "/api/v1/asset-tree/projects",
        json={"name": "模板发布项目", "description": "用于模板市场测试"},
    )
    assert project_resp.status_code == 200
    project = project_resp.json()

    root_resp = client.post(
        f"/api/v1/asset-tree/projects/{project['project_id']}/root-node",
        json={
            "image_url": "s3://bucket/root.png",
            "thumbnail_url": "s3://bucket/root_thumb.png",
            "width": 1200,
            "height": 800,
            "format": "png",
            "metadata": {"source": "upload"},
        },
    )
    assert root_resp.status_code == 201
    root = root_resp.json()

    result_node_resp = client.post(
        f"/api/v1/asset-tree/projects/{project['project_id']}/nodes",
        json={
            "parent_node_id": root["node_id"],
            "image_url": "s3://bucket/template_result.png",
            "thumbnail_url": "s3://bucket/template_result_thumb.png",
            "width": 1200,
            "height": 800,
            "format": "png",
            "lens_id": "lens_shared_demo",
            "lens_name": "奶油人像模板",
            "user_prompt": "提亮并保持肤色自然",
            "parameters": {"strength": 0.45},
            "muse_dna": _shared_musedna(),
            "generation_params": {"strength": 0.45},
            "status": "completed",
            "metadata": {"source": "generation"},
        },
    )
    assert result_node_resp.status_code == 201
    return project, root, result_node_resp.json()["node"]


def test_template_publish_from_node_search_favorite_and_update_flow(client, seeded_users):
    author, consumer = seeded_users
    _, root_node, result_node = _create_asset_node_with_musedna(client)

    publish_resp = client.post(
        "/api/v1/market/templates/publish-from-node",
        json={
            "author_id": author.user_id,
            "title": "奶油人像模板",
            "description": "快速得到干净透亮的人像效果",
            "result_asset_node_id": result_node["node_id"],
            "tag_names": ["人像", "奶油肌"],
            "category": "portrait",
            "status": "active",
        },
    )
    assert publish_resp.status_code == 201
    payload = publish_resp.json()
    template = payload["template"]
    version = payload["version"]

    assert template["title"] == "奶油人像模板"
    assert template["original_image_url"] == root_node["image_url"]
    assert template["result_image_url"] == result_node["image_url"]
    assert template["result_asset_node_id"] == result_node["node_id"]
    assert sorted(template["tag_names"]) == ["人像", "奶油肌"]
    assert version["required_inputs"] == ["base_image"]
    assert version["musedna"]["initial_inputs"]["base_image"] == ""

    list_resp = client.get("/api/v1/market/templates", params={"q": "奶油"})
    assert list_resp.status_code == 200
    assert list_resp.json()[0]["template_id"] == template["template_id"]

    tag_filter_resp = client.get("/api/v1/market/templates", params={"tag_name": "人像"})
    assert tag_filter_resp.status_code == 200
    assert tag_filter_resp.json()[0]["template_id"] == template["template_id"]

    detail_resp = client.get(f"/api/v1/market/templates/{template['template_id']}")
    assert detail_resp.status_code == 200
    detail = detail_resp.json()
    assert detail["current_version"]["required_inputs"] == ["base_image"]
    assert detail["author"]["nickname"] == "模板作者"
    assert sorted(detail["tag_names"]) == ["人像", "奶油肌"]

    favorite_resp = client.post(
        f"/api/v1/market/templates/{template['template_id']}/favorite",
        json={"user_id": consumer.user_id},
    )
    assert favorite_resp.status_code == 200

    favorite_list_resp = client.get(f"/api/v1/market/users/{consumer.user_id}/templates/favorites")
    assert favorite_list_resp.status_code == 200
    assert favorite_list_resp.json()[0]["template_id"] == template["template_id"]

    published_list_resp = client.get(f"/api/v1/market/users/{author.user_id}/templates/published")
    assert published_list_resp.status_code == 200
    assert published_list_resp.json()[0]["template_id"] == template["template_id"]

    tags_resp = client.get("/api/v1/market/templates/tags")
    assert tags_resp.status_code == 200
    assert {item["name"] for item in tags_resp.json()} == {"人像", "奶油肌"}

    republish_resp = client.post(
        "/api/v1/market/templates/publish",
        json={
            "template_id": template["template_id"],
            "author_id": author.user_id,
            "title": "奶油人像模板 Pro",
            "description": "更新了一版更柔和的风格",
            "musedna": _shared_musedna(),
            "tag_names": ["人像", "柔光"],
            "category": "portrait",
            "original_image_url": root_node["image_url"],
            "result_image_url": "s3://bucket/template_result_v2.png",
            "result_thumbnail_url": "s3://bucket/template_result_v2_thumb.png",
        },
    )
    assert republish_resp.status_code == 201
    republished = republish_resp.json()
    assert republished["template"]["title"] == "奶油人像模板 Pro"
    assert republished["version"]["version"] == "1.0.1"

    updated_detail_resp = client.get(f"/api/v1/market/templates/{template['template_id']}")
    updated_detail = updated_detail_resp.json()
    assert updated_detail["current_version"]["version"] == "1.0.1"
    assert sorted(updated_detail["tag_names"]) == ["人像", "柔光"]
    assert updated_detail["favorite_count"] == 1


def test_template_publish_and_apply_flow(client, seeded_users):
    author, consumer = seeded_users
    publish_resp = client.post(
        "/api/v1/market/templates/publish",
        json={
            "author_id": author.user_id,
            "title": "青透人像模板",
            "description": "让肤色更干净通透",
            "musedna": _shared_musedna(),
            "tag_names": ["人像", "清透"],
            "category": "portrait",
            "original_image_url": "s3://bucket/original.png",
            "result_image_url": "s3://bucket/result.png",
        },
    )
    assert publish_resp.status_code == 201
    template = publish_resp.json()["template"]

    missing_resp = client.post(
        f"/api/v1/market/templates/{template['template_id']}/apply",
        json={
            "user_id": consumer.user_id,
            "initial_inputs": {},
        },
    )
    assert missing_resp.status_code == 400
    assert "缺少必须的输入资源" in missing_resp.json()["detail"]

    apply_resp = client.post(
        f"/api/v1/market/templates/{template['template_id']}/apply",
        json={
            "user_id": consumer.user_id,
            "initial_inputs": {
                "base_image": "consumer_upload.png",
            },
            "param_overrides": {
                "step_1_template_edit": {
                    "strength": 0.8,
                }
            },
        },
    )
    assert apply_resp.status_code == 200
    payload = apply_resp.json()
    assert payload["executed"] is False
    assert payload["required_inputs"] == ["base_image"]
    assert payload["musedna"]["initial_inputs"]["base_image"] == "consumer_upload.png"
    assert payload["musedna"]["steps"][0]["params"]["strength"] == 0.8
    assert payload["template"]["apply_count"] == 1


def test_template_apply_execute_with_mocked_compiler(client, seeded_users, monkeypatch):
    author, consumer = seeded_users
    publish_resp = client.post(
        "/api/v1/market/templates/publish",
        json={
            "author_id": author.user_id,
            "title": "执行型模板",
            "description": "测试直接执行模板 MuseDNA",
            "musedna": _shared_musedna(),
            "tag_names": ["测试"],
            "category": "portrait",
            "original_image_url": "s3://bucket/original.png",
            "result_image_url": "s3://bucket/result.png",
        },
    )
    assert publish_resp.status_code == 201
    template = publish_resp.json()["template"]

    async def _fake_execute(blueprint, progress_callback=None, step_started_callback=None):
        return {
            "base_image": blueprint.initial_inputs["base_image"],
            "step_1_template_edit.result_image": "template_apply_result.png",
        }

    monkeypatch.setattr(market_endpoint.compiler, "execute_blueprint", _fake_execute)

    apply_resp = client.post(
        f"/api/v1/market/templates/{template['template_id']}/apply",
        json={
            "user_id": consumer.user_id,
            "initial_inputs": {
                "base_image": "consumer_upload.png",
            },
            "execute_now": True,
        },
    )
    assert apply_resp.status_code == 200
    payload = apply_resp.json()
    assert payload["executed"] is True
    assert payload["execution_started"] is True
    assert payload["result_filename"] == "template_apply_result.png"
    assert payload["result_url"] is not None
    assert payload["step_results"][0]["step_id"] == "step_1_template_edit"
    assert payload["step_results"][0]["outputs"][0]["filename"] == "template_apply_result.png"
    assert Decimal(payload["template"]["rating"]) == Decimal("0.00")

