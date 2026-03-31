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
        username="market_author",
        password="pass123456",
        nickname="市场作者",
        email="market_author@example.com",
    )
    consumer = user_service.create_user(
        test_db,
        username="market_consumer",
        password="pass123456",
        nickname="市场用户",
        email="market_consumer@example.com",
    )
    return author, consumer


def _shared_blueprint() -> dict:
    return {
        "initial_inputs": {
            "base_image": "author_source.png",
        },
        "steps": [
            {
                "step_id": "step_1_shared_edit",
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


def _create_asset_node_with_blueprint(client: TestClient) -> tuple[dict, dict, dict]:
    project_resp = client.post(
        "/api/v1/asset-tree/projects",
        json={"name": "市场发布项目", "description": "用于发布市场 preset"},
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

    blueprint = _shared_blueprint()
    preset_node_resp = client.post(
        f"/api/v1/asset-tree/projects/{project['project_id']}/nodes",
        json={
            "parent_node_id": root["node_id"],
            "image_url": "s3://bucket/shared_result.png",
            "thumbnail_url": "s3://bucket/shared_result_thumb.png",
            "width": 1200,
            "height": 800,
            "format": "png",
            "lens_id": "lens_shared_demo",
            "lens_name": "共享调色 preset",
            "user_prompt": "提升亮度并保持肤色自然",
            "parameters": {"strength": 0.45},
            "muse_dna": blueprint,
            "generation_params": {"strength": 0.45},
            "status": "completed",
            "metadata": {"source": "generation"},
        },
    )
    assert preset_node_resp.status_code == 201
    return project, root, preset_node_resp.json()["node"]


def test_market_publish_from_asset_node_install_favorite_review_flow(client, seeded_users):
    author, consumer = seeded_users
    _, _, preset_node = _create_asset_node_with_blueprint(client)

    publish_resp = client.post(
        "/api/v1/market/lenses/publish-from-node",
        json={
            "lens_key": "shared_portrait_blueprint_v1",
            "name": "人像提亮 preset",
            "description": "把作者的修图 blueprint 发布到市场",
            "author_id": author.user_id,
            "source_asset_node_id": preset_node["node_id"],
            "category": "portrait",
            "price": "0.00",
            "is_official": False,
            "status": "active",
            "version": "1.0.0",
            "changelog": "首次分享",
            "parameters": {"strength": {"type": "float"}},
            "ui_schema": {"layout": "slider"},
            "base_workflow": {"kind": "shared_blueprint"},
        },
    )
    assert publish_resp.status_code == 201
    published = publish_resp.json()
    lens = published["lens"]
    version = published["version"]

    assert lens["cover_image_url"] == preset_node["thumbnail_url"]
    assert lens["preview_asset_node_id"] == preset_node["node_id"]
    assert version["source_asset_node_id"] == preset_node["node_id"]
    assert version["required_inputs"] == ["base_image"]
    assert version["blueprint"]["initial_inputs"]["base_image"] == ""
    assert version["published_from"] == "asset_node"

    install_resp = client.post(
        f"/api/v1/market/lenses/{lens['lens_id']}/install",
        json={"user_id": consumer.user_id, "version_id": version["version_id"]},
    )
    assert install_resp.status_code == 200

    favorite_resp = client.post(
        f"/api/v1/market/lenses/{lens['lens_id']}/favorite",
        json={"user_id": consumer.user_id},
    )
    assert favorite_resp.status_code == 200

    review_resp = client.post(
        f"/api/v1/market/lenses/{lens['lens_id']}/reviews",
        json={"user_id": consumer.user_id, "rating": 5, "content": "这个 preset 可以直接复用"},
    )
    assert review_resp.status_code == 200

    detail_resp = client.get(f"/api/v1/market/lenses/{lens['lens_id']}")
    assert detail_resp.status_code == 200
    detail = detail_resp.json()
    assert detail["install_count"] == 1
    assert detail["apply_count"] == 0
    assert Decimal(detail["rating"]) == Decimal("5.00")
    assert detail["rating_count"] == 1
    assert detail["cover_image_url"] == preset_node["thumbnail_url"]
    assert detail["versions"][0]["required_inputs"] == ["base_image"]

    installed_resp = client.get(f"/api/v1/market/users/{consumer.user_id}/installed")
    assert installed_resp.status_code == 200
    assert installed_resp.json()[0]["lens_id"] == lens["lens_id"]

    favorites_resp = client.get(f"/api/v1/market/users/{consumer.user_id}/favorites")
    assert favorites_resp.status_code == 200
    assert favorites_resp.json()[0]["lens_id"] == lens["lens_id"]


def test_market_apply_blueprint_prepares_executable_blueprint(client, seeded_users):
    author, consumer = seeded_users
    create_resp = client.post(
        "/api/v1/market/lenses",
        json={
            "lens_key": "shared_apply_blueprint_v1",
            "name": "可直接应用的 preset",
            "description": "测试市场 blueprint 应用准备",
            "author_id": author.user_id,
            "category": "portrait",
            "price": "0.00",
            "is_official": False,
            "status": "active",
        },
    )
    assert create_resp.status_code == 201
    lens_id = create_resp.json()["lens_id"]

    version_resp = client.post(
        f"/api/v1/market/lenses/{lens_id}/versions",
        json={
            "version": "1.0.0",
            "blueprint": _shared_blueprint(),
            "parameters": {"strength": {"type": "float"}},
            "ui_schema": {"layout": "slider"},
            "changelog": "首次发布",
            "is_latest": True,
        },
    )
    assert version_resp.status_code == 201

    missing_resp = client.post(
        f"/api/v1/market/lenses/{lens_id}/apply",
        json={
            "user_id": consumer.user_id,
            "initial_inputs": {},
        },
    )
    assert missing_resp.status_code == 400
    assert "缺少必须的输入资源" in missing_resp.json()["detail"]

    apply_resp = client.post(
        f"/api/v1/market/lenses/{lens_id}/apply",
        json={
            "user_id": consumer.user_id,
            "initial_inputs": {
                "base_image": "consumer_upload.png",
            },
            "param_overrides": {
                "step_1_shared_edit": {
                    "strength": 0.8,
                }
            },
        },
    )
    assert apply_resp.status_code == 200
    payload = apply_resp.json()
    assert payload["executed"] is False
    assert payload["required_inputs"] == ["base_image"]
    assert payload["blueprint"]["initial_inputs"]["base_image"] == "consumer_upload.png"
    assert payload["blueprint"]["steps"][0]["params"]["strength"] == 0.8
    assert payload["lens"]["apply_count"] == 1


def test_market_apply_blueprint_can_execute_with_mocked_compiler(client, seeded_users, monkeypatch):
    author, consumer = seeded_users
    create_resp = client.post(
        "/api/v1/market/lenses",
        json={
            "lens_key": "shared_execute_blueprint_v1",
            "name": "执行型 preset",
            "description": "测试直接执行市场 blueprint",
            "author_id": author.user_id,
            "category": "portrait",
            "price": "0.00",
            "is_official": False,
            "status": "active",
        },
    )
    lens_id = create_resp.json()["lens_id"]

    client.post(
        f"/api/v1/market/lenses/{lens_id}/versions",
        json={
            "version": "1.0.0",
            "blueprint": _shared_blueprint(),
            "parameters": {},
            "ui_schema": {},
            "changelog": "首次发布",
            "is_latest": True,
        },
    )

    async def _fake_execute(blueprint, progress_callback=None, step_started_callback=None):
        return {
            "base_image": blueprint.initial_inputs["base_image"],
            "step_1_shared_edit.result_image": "market_apply_result.png",
        }

    monkeypatch.setattr(market_endpoint.compiler, "execute_blueprint", _fake_execute)

    apply_resp = client.post(
        f"/api/v1/market/lenses/{lens_id}/apply",
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
    assert payload["result_filename"] == "market_apply_result.png"
    assert payload["result_url"] is not None
    assert payload["step_results"][0]["step_id"] == "step_1_shared_edit"
    assert payload["step_results"][0]["outputs"][0]["filename"] == "market_apply_result.png"
