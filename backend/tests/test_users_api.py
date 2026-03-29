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


def _register_user(client: TestClient, username: str, nickname: str, email: str | None = None):
    payload = {
        "username": username,
        "password": "pass123456",
        "nickname": nickname,
        "email": email,
        "bio": "",
    }
    return client.post("/api/v1/users/register", json=payload)


def test_user_register_login_update_flow(client):
    register_resp = _register_user(client, "alice", "Alice", "alice@example.com")
    assert register_resp.status_code == 200
    user = register_resp.json()
    assert user["username"] == "alice"
    user_id = user["user_id"]

    login_resp = client.post(
        "/api/v1/users/login",
        json={"username": "alice", "password": "pass123456"},
    )
    assert login_resp.status_code == 200
    assert login_resp.json()["user"]["user_id"] == user_id

    update_resp = client.patch(
        f"/api/v1/users/{user_id}",
        json={"bio": "喜欢修图", "avatar_url": "https://example.com/a.png"},
    )
    assert update_resp.status_code == 200
    updated = update_resp.json()
    assert updated["bio"] == "喜欢修图"
    assert updated["avatar_url"] == "https://example.com/a.png"


def test_user_register_duplicate_username_returns_409(client):
    assert _register_user(client, "dup_user", "Dup").status_code == 200
    second_resp = _register_user(client, "dup_user", "Dup2")
    assert second_resp.status_code == 409


def test_follow_and_unfollow_flow(client):
    user_a = _register_user(client, "follower", "Follower", "follower@example.com").json()
    user_b = _register_user(client, "following", "Following", "following@example.com").json()

    follow_resp = client.post(
        f"/api/v1/users/{user_b['user_id']}/follow",
        json={"follower_id": user_a["user_id"]},
    )
    assert follow_resp.status_code == 200

    user_a_detail = client.get(f"/api/v1/users/{user_a['user_id']}").json()
    user_b_detail = client.get(f"/api/v1/users/{user_b['user_id']}").json()
    assert user_a_detail["following_count"] == 1
    assert user_b_detail["follower_count"] == 1

    followers_resp = client.get(f"/api/v1/users/{user_b['user_id']}/followers")
    assert followers_resp.status_code == 200
    assert followers_resp.json()[0]["user_id"] == user_a["user_id"]

    following_resp = client.get(f"/api/v1/users/{user_a['user_id']}/following")
    assert following_resp.status_code == 200
    assert following_resp.json()[0]["user_id"] == user_b["user_id"]

    unfollow_resp = client.request(
        "DELETE",
        f"/api/v1/users/{user_b['user_id']}/follow",
        json={"follower_id": user_a["user_id"]},
    )
    assert unfollow_resp.status_code == 200

    user_a_detail = client.get(f"/api/v1/users/{user_a['user_id']}").json()
    user_b_detail = client.get(f"/api/v1/users/{user_b['user_id']}").json()
    assert user_a_detail["following_count"] == 0
    assert user_b_detail["follower_count"] == 0
