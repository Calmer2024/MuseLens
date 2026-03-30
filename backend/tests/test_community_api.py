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
    user_a = user_service.create_user(
        test_db,
        username="community_user_a",
        password="pass123456",
        nickname="社区用户A",
        email="community_a@example.com",
    )
    user_b = user_service.create_user(
        test_db,
        username="community_user_b",
        password="pass123456",
        nickname="社区用户B",
        email="community_b@example.com",
    )
    return user_a, user_b


def test_create_post_and_list_detail_flow(client, seeded_users):
    user_a, _ = seeded_users
    create_resp = client.post(
        "/api/v1/community/posts",
        json={
            "user_id": user_a.user_id,
            "title": "第一条帖子",
            "content": "这是一条社区帖子",
            "is_public": True,
            "images": [
                {
                    "image_url": "https://example.com/post.png",
                    "thumbnail_url": "https://example.com/post_thumb.png",
                    "width": 800,
                    "height": 600,
                    "order_index": 0,
                }
            ],
            "tag_names": ["人像", "#夜景"],
        },
    )
    assert create_resp.status_code == 201
    post = create_resp.json()
    assert post["title"] == "第一条帖子"
    assert len(post["images"]) == 1
    assert {tag["name"] for tag in post["tags"]} == {"人像", "夜景"}

    list_resp = client.get("/api/v1/community/posts")
    assert list_resp.status_code == 200
    assert len(list_resp.json()) == 1

    detail_resp = client.get(f"/api/v1/community/posts/{post['post_id']}")
    assert detail_resp.status_code == 200
    detail = detail_resp.json()
    assert detail["view_count"] == 1


def test_comment_like_favorite_and_tag_flow(client, seeded_users):
    user_a, user_b = seeded_users
    post_resp = client.post(
        "/api/v1/community/posts",
        json={
            "user_id": user_a.user_id,
            "title": "互动测试",
            "content": "请大家评论点赞",
            "images": [],
            "tag_names": ["测试标签"],
        },
    )
    post_id = post_resp.json()["post_id"]

    comment_1_resp = client.post(
        f"/api/v1/community/posts/{post_id}/comments",
        json={"user_id": user_b.user_id, "content": "一级评论"},
    )
    assert comment_1_resp.status_code == 201
    comment_1 = comment_1_resp.json()
    assert comment_1["level"] == 1

    comment_2_resp = client.post(
        f"/api/v1/community/posts/{post_id}/comments",
        json={"user_id": user_a.user_id, "content": "回复评论", "parent_id": comment_1["comment_id"]},
    )
    assert comment_2_resp.status_code == 201
    assert comment_2_resp.json()["level"] == 2

    comments_resp = client.get(f"/api/v1/community/posts/{post_id}/comments")
    assert comments_resp.status_code == 200
    assert len(comments_resp.json()["comments"]) == 2

    like_post_resp = client.post(
        f"/api/v1/community/posts/{post_id}/like",
        json={"user_id": user_b.user_id},
    )
    assert like_post_resp.status_code == 200

    favorite_resp = client.post(
        f"/api/v1/community/posts/{post_id}/favorite",
        json={"user_id": user_b.user_id},
    )
    assert favorite_resp.status_code == 200

    like_comment_resp = client.post(
        f"/api/v1/community/comments/{comment_1['comment_id']}/like",
        json={"user_id": user_a.user_id},
    )
    assert like_comment_resp.status_code == 200

    detail_resp = client.get(f"/api/v1/community/posts/{post_id}")
    detail = detail_resp.json()
    assert detail["like_count"] == 1
    assert detail["comment_count"] == 2

    tags_resp = client.get("/api/v1/community/tags")
    assert tags_resp.status_code == 200
    assert tags_resp.json()[0]["name"] == "测试标签"


def test_delete_post_by_owner_updates_lists_and_tags(client, seeded_users):
    user_a, user_b = seeded_users
    post_resp = client.post(
        "/api/v1/community/posts",
        json={
            "user_id": user_a.user_id,
            "title": "待删除帖子",
            "content": "删除后不应该再被查询到",
            "images": [],
            "tag_names": ["删除测试"],
        },
    )
    assert post_resp.status_code == 201
    post_id = post_resp.json()["post_id"]

    like_resp = client.post(
        f"/api/v1/community/posts/{post_id}/like",
        json={"user_id": user_b.user_id},
    )
    assert like_resp.status_code == 200

    delete_resp = client.delete(
        f"/api/v1/community/posts/{post_id}",
        json={"user_id": user_a.user_id},
    )
    assert delete_resp.status_code == 200

    detail_resp = client.get(f"/api/v1/community/posts/{post_id}")
    assert detail_resp.status_code == 404

    list_resp = client.get("/api/v1/community/posts")
    assert list_resp.status_code == 200
    assert list_resp.json() == []

    tags_resp = client.get("/api/v1/community/tags")
    assert tags_resp.status_code == 200
    assert tags_resp.json()[0]["post_count"] == 0


def test_delete_post_forbidden_for_non_owner(client, seeded_users):
    user_a, user_b = seeded_users
    post_resp = client.post(
        "/api/v1/community/posts",
        json={
            "user_id": user_a.user_id,
            "title": "禁止删除测试",
            "content": "只有作者自己可以删",
            "images": [],
            "tag_names": [],
        },
    )
    assert post_resp.status_code == 201
    post_id = post_resp.json()["post_id"]

    delete_resp = client.delete(
        f"/api/v1/community/posts/{post_id}",
        json={"user_id": user_b.user_id},
    )
    assert delete_resp.status_code == 403
    assert delete_resp.json()["detail"] == "只能删除自己的帖子"
