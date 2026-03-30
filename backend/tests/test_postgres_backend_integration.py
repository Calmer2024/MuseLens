import json
import os
import tempfile
import uuid
from contextlib import contextmanager
from urllib.parse import urlparse, urlunparse

import psycopg
import pytest
from fastapi.testclient import TestClient
from psycopg import sql
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, create_db_engine, get_db, normalize_database_url
from app.lenses import registry
from app.main import app
from app.models.lens_model import LensRecord


def _admin_dsn() -> str:
    dsn = os.getenv("MUSELENS_TEST_POSTGRES_DSN", "").strip()
    if not dsn:
        pytest.skip("set MUSELENS_TEST_POSTGRES_DSN to run PostgreSQL integration tests")
    return dsn


def _replace_db_name(dsn: str, db_name: str) -> str:
    parsed = urlparse(dsn)
    return urlunparse(parsed._replace(path=f"/{db_name}"))


@contextmanager
def _temporary_postgres_database():
    admin_dsn = _admin_dsn()
    db_name = f"muselens_test_{uuid.uuid4().hex[:8]}"

    with psycopg.connect(admin_dsn, autocommit=True) as conn:
        with conn.cursor() as cur:
            cur.execute(sql.SQL("CREATE DATABASE {}").format(sql.Identifier(db_name)))

    try:
        yield _replace_db_name(admin_dsn, db_name)
    finally:
        with psycopg.connect(admin_dsn, autocommit=True) as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT pg_terminate_backend(pid)
                    FROM pg_stat_activity
                    WHERE datname = %s AND pid <> pg_backend_pid()
                    """,
                    (db_name,),
                )
                cur.execute(sql.SQL("DROP DATABASE IF EXISTS {}").format(sql.Identifier(db_name)))


@pytest.fixture(scope="function")
def postgres_test_db():
    with _temporary_postgres_database() as raw_dsn:
        sqlalchemy_url = normalize_database_url(raw_dsn)
        engine = create_db_engine(sqlalchemy_url)
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
        try:
            yield {
                "raw_dsn": raw_dsn,
                "sqlalchemy_url": sqlalchemy_url,
                "engine": engine,
                "session_local": session_local,
                "db": db,
            }
        finally:
            db.close()
            app.dependency_overrides.clear()
            registry.LENS_REGISTRY.clear()
            registry.load_builtin_lenses_into_memory()
            engine.dispose()


@pytest.fixture(scope="function")
def client(postgres_test_db):
    return TestClient(app)


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

    delete_forbidden_resp = client.delete(
        f"/api/v1/community/posts/{post['post_id']}",
        json={"user_id": author["user_id"]},
    )
    assert delete_forbidden_resp.status_code == 403

    delete_resp = client.delete(
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
