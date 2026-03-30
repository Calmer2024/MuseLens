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
    alice = user_service.create_user(
        test_db,
        username="chat_alice",
        password="pass123456",
        nickname="聊天用户A",
        email="chat_alice@example.com",
    )
    bob = user_service.create_user(
        test_db,
        username="chat_bob",
        password="pass123456",
        nickname="聊天用户B",
        email="chat_bob@example.com",
    )
    carol = user_service.create_user(
        test_db,
        username="chat_carol",
        password="pass123456",
        nickname="聊天用户C",
        email="chat_carol@example.com",
    )

    user_service.follow_user(test_db, follower_id=alice.user_id, following_id=bob.user_id)
    user_service.follow_user(test_db, follower_id=bob.user_id, following_id=alice.user_id)
    user_service.follow_user(test_db, follower_id=alice.user_id, following_id=carol.user_id)
    return alice, bob, carol


def _open_conversation(client: TestClient, user_id: int, friend_user_id: int):
    return client.post(
        "/api/v1/chat/conversations/direct",
        json={"user_id": user_id, "friend_user_id": friend_user_id},
    )


def test_chat_friends_and_conversation_open_flow(client, seeded_users):
    alice, bob, carol = seeded_users

    friends_resp = client.get(f"/api/v1/chat/friends/{alice.user_id}")
    assert friends_resp.status_code == 200
    friends = friends_resp.json()
    assert len(friends) == 1
    assert friends[0]["user_id"] == bob.user_id
    assert friends[0]["conversation_id"] is None

    open_resp = _open_conversation(client, alice.user_id, bob.user_id)
    assert open_resp.status_code == 200
    data = open_resp.json()
    assert data["created"] is True
    conversation_id = data["conversation"]["conversation_id"]
    assert data["conversation"]["peer_user"]["user_id"] == bob.user_id

    reopen_resp = _open_conversation(client, alice.user_id, bob.user_id)
    assert reopen_resp.status_code == 200
    assert reopen_resp.json()["created"] is False
    assert reopen_resp.json()["conversation"]["conversation_id"] == conversation_id

    invalid_resp = _open_conversation(client, alice.user_id, carol.user_id)
    assert invalid_resp.status_code == 400
    assert "互相关注" in invalid_resp.json()["detail"]


def test_chat_send_text_post_and_preset_flow(client, seeded_users):
    alice, bob, _ = seeded_users
    conversation = _open_conversation(client, alice.user_id, bob.user_id).json()["conversation"]
    conversation_id = conversation["conversation_id"]

    post_resp = client.post(
        "/api/v1/community/posts",
        json={
            "user_id": alice.user_id,
            "title": "聊天里分享的帖子",
            "content": "这是一条准备在私聊中分享的帖子",
            "images": [
                {
                    "image_url": "https://example.com/chat-post.png",
                    "thumbnail_url": "https://example.com/chat-post-thumb.png",
                    "width": 640,
                    "height": 480,
                    "order_index": 0,
                }
            ],
            "tag_names": ["聊天", "分享"],
        },
    )
    assert post_resp.status_code == 201
    post = post_resp.json()

    lens_resp = client.post(
        "/api/v1/market/lenses",
        json={
            "lens_key": "chat_preset_lens",
            "name": "聊天分享预设",
            "description": "用于聊天分享的预设",
            "author_id": bob.user_id,
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
        json={"sender_id": alice.user_id, "content": "你好，这里先发一条文本消息"},
    )
    assert text_resp.status_code == 201
    assert text_resp.json()["message_type"] == "text"

    share_post_resp = client.post(
        f"/api/v1/chat/conversations/{conversation_id}/messages",
        json={
            "sender_id": alice.user_id,
            "content": "给你看看这条帖子",
            "share": {
                "share_type": "post",
                "post_id": post["post_id"],
            },
        },
    )
    assert share_post_resp.status_code == 201
    post_message = share_post_resp.json()
    assert post_message["message_type"] == "text_share"
    assert post_message["share"]["share_type"] == "post"
    assert post_message["share"]["share_source_type"] == "community_post"
    assert post_message["share"]["resource_id"] == str(post["post_id"])

    share_preset_resp = client.post(
        f"/api/v1/chat/conversations/{conversation_id}/messages",
        json={
            "sender_id": bob.user_id,
            "content": "",
            "share": {
                "share_type": "preset",
                "market_lens_id": lens["lens_id"],
            },
        },
    )
    assert share_preset_resp.status_code == 201
    preset_message = share_preset_resp.json()
    assert preset_message["message_type"] == "share"
    assert preset_message["share"]["share_type"] == "preset"
    assert preset_message["share"]["share_source_type"] == "market_lens"
    assert preset_message["share"]["title"] == "聊天分享预设"

    list_resp = client.get(
        f"/api/v1/chat/conversations/{conversation_id}/messages",
        params={"user_id": alice.user_id, "limit": 20},
    )
    assert list_resp.status_code == 200
    messages = list_resp.json()["messages"]
    assert len(messages) == 3
    assert messages[1]["share"]["title"] == "聊天里分享的帖子"
    assert messages[2]["share"]["title"] == "聊天分享预设"

    detail_before_read = client.get(
        f"/api/v1/chat/conversations/{conversation_id}",
        params={"user_id": alice.user_id},
    )
    assert detail_before_read.status_code == 200
    assert detail_before_read.json()["unread_count"] == 1
    assert detail_before_read.json()["last_message"]["share_type"] == "preset"

    read_resp = client.post(
        f"/api/v1/chat/conversations/{conversation_id}/read",
        json={"user_id": alice.user_id},
    )
    assert read_resp.status_code == 200

    detail_after_read = client.get(
        f"/api/v1/chat/conversations/{conversation_id}",
        params={"user_id": alice.user_id},
    )
    assert detail_after_read.status_code == 200
    assert detail_after_read.json()["unread_count"] == 0

    post_detail_resp = client.get(f"/api/v1/community/posts/{post['post_id']}")
    assert post_detail_resp.status_code == 200
    assert post_detail_resp.json()["share_count"] == 1

    conversations_resp = client.get(
        "/api/v1/chat/conversations",
        params={"user_id": bob.user_id},
    )
    assert conversations_resp.status_code == 200
    assert conversations_resp.json()[0]["last_message"]["share_type"] == "preset"


def test_chat_access_control_for_non_participant(client, seeded_users):
    alice, bob, carol = seeded_users
    conversation_id = _open_conversation(client, alice.user_id, bob.user_id).json()["conversation"]["conversation_id"]

    resp = client.get(
        f"/api/v1/chat/conversations/{conversation_id}",
        params={"user_id": carol.user_id},
    )
    assert resp.status_code == 403
