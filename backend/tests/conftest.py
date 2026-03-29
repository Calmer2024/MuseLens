"""
Pytest 全局配置与 PostgreSQL 集成测试夹具。

- 自动加载 backend/.env（不覆盖已存在的环境变量），便于本地跑集成测试。
- 若未设置 MUSELENS_TEST_POSTGRES_DSN 但已配置 MUSELENS_PG_DSN，则复用后者作为
  可建库的 admin DSN（与常见本地 docker-compose 一致）。
"""

from __future__ import annotations

import os
import uuid
from contextlib import contextmanager
from pathlib import Path
from urllib.parse import urlparse, urlunparse

import psycopg
import pytest
from fastapi.testclient import TestClient
from psycopg import sql
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, create_db_engine, get_db, normalize_database_url
from app.lenses import registry
from app.main import app


def ensure_orm_metadata_models() -> None:
    """确保 Base.metadata 包含 router_sessions 等全部表，再 create_all。"""
    from app.models import asset_tree_models  # noqa: F401
    from app.models import community_models  # noqa: F401
    from app.models import lens_example_model  # noqa: F401
    from app.models import lens_model  # noqa: F401
    from app.models import market_models  # noqa: F401
    from app.models import router_session_model  # noqa: F401
    from app.models import user_models  # noqa: F401


def pytest_configure(config) -> None:
    try:
        from dotenv import load_dotenv
    except ImportError:
        load_dotenv = None  # type: ignore[assignment]

    if load_dotenv is not None:
        env_path = Path(__file__).resolve().parent.parent / ".env"
        if env_path.is_file():
            load_dotenv(env_path, override=False)

    if not os.getenv("MUSELENS_TEST_POSTGRES_DSN", "").strip():
        pg = os.getenv("MUSELENS_PG_DSN", "").strip()
        if pg:
            os.environ["MUSELENS_TEST_POSTGRES_DSN"] = pg


def admin_dsn() -> str:
    """供需要显式连接 Postgres 的测试使用（与 _admin_dsn 行为一致）。"""
    dsn = os.getenv("MUSELENS_TEST_POSTGRES_DSN", "").strip()
    if not dsn:
        pytest.skip("set MUSELENS_TEST_POSTGRES_DSN (或 MUSELENS_PG_DSN) to run PostgreSQL integration tests")
    return dsn


def _replace_db_name(dsn: str, db_name: str) -> str:
    parsed = urlparse(dsn)
    return urlunparse(parsed._replace(path=f"/{db_name}"))


@contextmanager
def temporary_postgres_database():
    """
    创建临时数据库，yield 该库连接串，结束后 DROP。
    需要 MUSELENS_TEST_POSTGRES_DSN 指向具备 CREATEDB 权限的账号。
    """
    admin = admin_dsn()
    db_name = f"muselens_test_{uuid.uuid4().hex[:8]}"

    with psycopg.connect(admin, autocommit=True) as conn:
        with conn.cursor() as cur:
            cur.execute(sql.SQL("CREATE DATABASE {}").format(sql.Identifier(db_name)))

    try:
        yield _replace_db_name(admin, db_name)
    finally:
        with psycopg.connect(admin, autocommit=True) as conn:
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
    with temporary_postgres_database() as raw_dsn:
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


@pytest.fixture(scope="function")
def client(postgres_test_db):
    return TestClient(app)
