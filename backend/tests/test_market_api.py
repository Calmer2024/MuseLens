from decimal import Decimal

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

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


def test_market_lens_create_version_install_review_flow(client, seeded_users):
    author, consumer = seeded_users

    create_resp = client.post(
        "/api/v1/market/lenses",
        json={
            "lens_key": "lens_market_portrait_v1",
            "name": "人像柔光镜",
            "description": "适合人像氛围增强",
            "author_id": author.user_id,
            "category": "portrait",
            "price": "9.90",
            "is_official": False,
            "status": "active",
        },
    )
    assert create_resp.status_code == 201
    lens = create_resp.json()
    lens_id = lens["lens_id"]
    assert lens["name"] == "人像柔光镜"

    version_resp = client.post(
        f"/api/v1/market/lenses/{lens_id}/versions",
        json={
            "version": "1.0.0",
            "base_workflow": {"nodes": []},
            "parameters": {"strength": {"type": "float"}},
            "ui_schema": {"layout": "slider"},
            "changelog": "初始版本",
            "is_latest": True,
        },
    )
    assert version_resp.status_code == 201
    version_id = version_resp.json()["version_id"]

    install_resp = client.post(
        f"/api/v1/market/lenses/{lens_id}/install",
        json={"user_id": consumer.user_id, "version_id": version_id},
    )
    assert install_resp.status_code == 200

    favorite_resp = client.post(
        f"/api/v1/market/lenses/{lens_id}/favorite",
        json={"user_id": consumer.user_id},
    )
    assert favorite_resp.status_code == 200

    review_resp = client.post(
        f"/api/v1/market/lenses/{lens_id}/reviews",
        json={"user_id": consumer.user_id, "rating": 5, "content": "很好用"},
    )
    assert review_resp.status_code == 200
    assert review_resp.json()["rating"] == 5

    detail_resp = client.get(f"/api/v1/market/lenses/{lens_id}")
    assert detail_resp.status_code == 200
    detail = detail_resp.json()
    assert detail["install_count"] == 1
    assert Decimal(detail["rating"]) == Decimal("5.00")
    assert detail["rating_count"] == 1
    assert len(detail["versions"]) == 1
    assert len(detail["reviews"]) == 1

    installed_resp = client.get(f"/api/v1/market/users/{consumer.user_id}/installed")
    assert installed_resp.status_code == 200
    assert installed_resp.json()[0]["lens_id"] == lens_id

    favorites_resp = client.get(f"/api/v1/market/users/{consumer.user_id}/favorites")
    assert favorites_resp.status_code == 200
    assert favorites_resp.json()[0]["lens_id"] == lens_id


def test_market_lens_update_and_uninstall_flow(client, seeded_users):
    author, consumer = seeded_users
    lens_resp = client.post(
        "/api/v1/market/lenses",
        json={
            "lens_key": "lens_market_food_v1",
            "name": "美食增强镜",
            "description": "让食物更有食欲",
            "author_id": author.user_id,
            "category": "food",
            "price": "0.00",
            "is_official": True,
            "status": "active",
        },
    )
    lens_id = lens_resp.json()["lens_id"]

    version_resp = client.post(
        f"/api/v1/market/lenses/{lens_id}/versions",
        json={
            "version": "1.0.0",
            "base_workflow": {"nodes": []},
            "parameters": {},
            "ui_schema": {},
            "changelog": "",
            "is_latest": True,
        },
    )
    version_id = version_resp.json()["version_id"]

    update_resp = client.patch(
        f"/api/v1/market/lenses/{lens_id}",
        json={"name": "美食高级增强镜", "price": "12.50"},
    )
    assert update_resp.status_code == 200
    assert update_resp.json()["name"] == "美食高级增强镜"

    client.post(
        f"/api/v1/market/lenses/{lens_id}/install",
        json={"user_id": consumer.user_id, "version_id": version_id},
    )
    uninstall_resp = client.request(
        "DELETE",
        f"/api/v1/market/lenses/{lens_id}/install",
        json={"user_id": consumer.user_id},
    )
    assert uninstall_resp.status_code == 200

    detail_resp = client.get(f"/api/v1/market/lenses/{lens_id}")
    assert detail_resp.status_code == 200
    assert detail_resp.json()["install_count"] == 0
