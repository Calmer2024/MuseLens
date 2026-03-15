"""
Lens 向量同步服务 (lens_embedding_sync) 的自动化测试。

在不依赖真实 PostgreSQL 的前提下，通过 mock sys.modules["psycopg"] 验证：
- 语料构建与向量字面量格式
- sync_lens_embeddings 的调用逻辑与 upsert 参数
- ensure_lens_embeddings_schema 的 SQL 执行
"""

import sys
from typing import Optional
from unittest.mock import MagicMock, patch

import pytest

from app.schemas.lens import LensLayer, LensTemplate, LensParam, ParamType, NodeMapping
from app.services.lens_embedding_sync import (
    sync_lens_embeddings,
    ensure_lens_embeddings_schema,
)
from app.services.rag_client import EMBEDDING_DIM, default_encode_text_to_vector


def _make_mini_template(lens_id: str, description: str = "", param_name: Optional[str] = None) -> LensTemplate:
    """构造最小可用的 LensTemplate 用于测试。"""
    params = []
    if param_name:
        params.append(
            LensParam(
                name=param_name,
                type=ParamType.TEXT,
                description="测试参数",
                mapping=NodeMapping(node_id="1", field_name="text"),
            )
        )
    return LensTemplate(
        lens_id=lens_id,
        layer=LensLayer.A1,
        description=description,
        raw_workflow={"nodes": []},
        inputs=[],
        outputs=[],
        params=params,
    )


def test_sync_lens_embeddings_empty_registry_returns_zero():
    """显式传入空 registry 时 sync_lens_embeddings 应返回 0，且不调用 connect。"""
    mock_psycopg = MagicMock()
    with patch.dict(sys.modules, {"psycopg": mock_psycopg}):
        count = sync_lens_embeddings(
            dsn="postgresql://localhost/test",
            registry={},
        )
    assert count == 0
    mock_psycopg.connect.assert_not_called()


def test_sync_lens_embeddings_upserts_each_lens():
    """sync_lens_embeddings 应对注册表中每个 lens 执行一次 upsert，并传入正确参数。"""
    registry = {
        "lens_a": _make_mini_template("lens_a", "描述A", "prompt_a"),
        "lens_b": _make_mini_template("lens_b", "描述B"),
    }
    fixed_vec = [0.1] * EMBEDDING_DIM

    def fake_encode(_text: str):
        return fixed_vec

    mock_conn = MagicMock()
    mock_cursor = MagicMock()
    mock_conn.__enter__ = MagicMock(return_value=mock_conn)
    mock_conn.__exit__ = MagicMock(return_value=False)
    mock_conn.cursor.return_value.__enter__ = MagicMock(return_value=mock_cursor)
    mock_conn.cursor.return_value.__exit__ = MagicMock(return_value=False)

    mock_psycopg = MagicMock()
    mock_psycopg.connect.return_value = mock_conn
    with patch.dict(sys.modules, {"psycopg": mock_psycopg}):
        count = sync_lens_embeddings(
            dsn="postgresql://localhost/test",
            registry=registry,
            encode_text_to_vector=fake_encode,
        )

    assert count == 2
    # 1 次 ensure_lens_embeddings_schema 的 CREATE + 2 次 upsert
    assert mock_cursor.execute.call_count == 3
    calls = [c[0][0] for c in mock_cursor.execute.call_args_list]
    upsert_calls = [c for c in calls if "INSERT INTO" in c and "ON CONFLICT" in c]
    assert len(upsert_calls) == 2
    # 参数应包含 lens_id, embedding, description, layer（第 0 次是 schema，第 1、2 次是 upsert）
    first_upsert_kw = mock_cursor.execute.call_args_list[1][0][1]
    assert first_upsert_kw["lens_id"] in ("lens_a", "lens_b")
    assert "embedding" in first_upsert_kw
    assert first_upsert_kw["embedding"].startswith("[") and first_upsert_kw["embedding"].endswith("]")


def test_sync_lens_embeddings_uses_default_encoder_when_not_provided():
    """未传入 encode_text_to_vector 时使用 default_encode_text_to_vector，向量维度为 EMBEDDING_DIM。"""
    registry = {"lens_one": _make_mini_template("lens_one", "hello")}
    mock_conn = MagicMock()
    mock_cursor = MagicMock()
    mock_conn.__enter__ = MagicMock(return_value=mock_conn)
    mock_conn.__exit__ = MagicMock(return_value=False)
    mock_conn.cursor.return_value.__enter__ = MagicMock(return_value=mock_cursor)
    mock_conn.cursor.return_value.__exit__ = MagicMock(return_value=False)

    mock_psycopg = MagicMock()
    mock_psycopg.connect.return_value = mock_conn
    with patch.dict(sys.modules, {"psycopg": mock_psycopg}):
        sync_lens_embeddings(dsn="postgresql://localhost/test", registry=registry)

    params = mock_cursor.execute.call_args[0][1]
    embedding_str = params["embedding"]
    values = embedding_str.strip("[]").split(",")
    assert len(values) == EMBEDDING_DIM


def test_ensure_lens_embeddings_schema_executes_create_extension_and_table():
    """ensure_lens_embeddings_schema 应执行包含 vector 扩展与建表的 SQL。"""
    mock_conn = MagicMock()
    mock_cursor = MagicMock()
    mock_conn.__enter__ = MagicMock(return_value=mock_conn)
    mock_conn.__exit__ = MagicMock(return_value=False)
    mock_conn.cursor.return_value.__enter__ = MagicMock(return_value=mock_cursor)
    mock_conn.cursor.return_value.__exit__ = MagicMock(return_value=False)

    mock_psycopg = MagicMock()
    mock_psycopg.connect.return_value = mock_conn
    with patch.dict(sys.modules, {"psycopg": mock_psycopg}):
        ensure_lens_embeddings_schema("postgresql://localhost/db", table_name="lens_embeddings")

    mock_cursor.execute.assert_called_once()
    sql = mock_cursor.execute.call_args[0][0]
    assert "CREATE EXTENSION IF NOT EXISTS vector" in sql
    assert "lens_embeddings" in sql
    assert "lens_id" in sql
    assert "embedding" in sql
    mock_conn.commit.assert_called_once()


