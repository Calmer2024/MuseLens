"""
在同一临时 PostgreSQL 库内联调：pgvector 表 + lenses 目录表 + Retrieval。

若实例未安装 pgvector 扩展，本模块测试将 skip（不视为失败）。
"""

from __future__ import annotations

import json
import os
import tempfile

import pytest
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, create_db_engine, get_db, normalize_database_url
from app.lenses import registry
from app.main import app
from app.services.lens_embedding_sync import ensure_lens_embeddings_schema, sync_lens_embeddings
from app.services.rag_client import PgVectorLensRAGClient
from app.services.retrieval_service import RetrievalService

from tests.conftest import ensure_orm_metadata_models, temporary_postgres_database


@pytest.fixture(scope="function")
def workflow_file():
    with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False, encoding="utf-8") as f:
        json.dump({"1": {"inputs": {"image": "in.png"}, "class_type": "LoadImage"}}, f)
        path = f.name
    yield path
    if os.path.exists(path):
        os.remove(path)


@pytest.fixture(scope="function")
def postgres_ephemeral_with_pgvector():
    """
    创建临时库并尝试启用 pgvector + lens_embeddings 表。
    """
    with temporary_postgres_database() as raw_dsn:
        try:
            ensure_lens_embeddings_schema(raw_dsn, table_name="lens_embeddings")
        except Exception as exc:  # noqa: BLE001
            pytest.skip(f"pgvector 不可用或无权创建扩展：{exc}")

        sqlalchemy_url = normalize_database_url(raw_dsn)
        engine = create_db_engine(sqlalchemy_url)
        ensure_orm_metadata_models()
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


@pytest.mark.integration
def test_pgvector_search_merges_catalog_rows(postgres_ephemeral_with_pgvector, workflow_file):
    """PgVector 召回 lens_id 后，RetrievalService 从 lenses 表补全描述/参数。"""
    db = postgres_ephemeral_with_pgvector["db"]
    raw_dsn = postgres_ephemeral_with_pgvector["raw_dsn"]
    lens_id = "lens_pgvec_e2e"

    registry.register_lens(
        db,
        {
            "lens_id": lens_id,
            "layer": "A1",
            "description": "语义检索专用透镜 抠图分割",
            "workflow_file_path": workflow_file,
            "inputs": [],
            "outputs": [],
            "params": [],
        },
    )

    sync_lens_embeddings(
        dsn=raw_dsn,
        table_name="lens_embeddings",
        registry={lens_id: registry.get_lens(lens_id)},
        include_examples=False,
    )

    rag = PgVectorLensRAGClient(dsn=raw_dsn, table_name="lens_embeddings")
    hits = rag.search_lenses("抠图 分割", k=3)
    assert any(h.lens_id == lens_id for h in hits), "向量表应能召回已同步的 lens_id"

    retrieval = RetrievalService(rag)
    merged = retrieval.retrieve(db, task_desc="抠图 分割", top_k=5)
    row = next((x for x in merged if x.lens_id == lens_id), None)
    assert row is not None
    assert "抠图" in (row.description or "") or "分割" in (row.description or "")
