import os
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# 导入路由
from app.api.v1.endpoints import editor
from app.api.v1.endpoints import router as router_endpoint
from app.api.v1.endpoints import test_run
from app.api.v1.endpoints import lenses as lenses_endpoint
from app.api.v1.endpoints import asset_tree as asset_tree_endpoint
from app.api.v1.endpoints import users as users_endpoint
from app.api.v1.endpoints import community as community_endpoint
from app.api.v1.endpoints import market as market_endpoint
from app.api.v1.endpoints import chat as chat_endpoint
from app.api.v1.endpoints import editor_sessions as editor_sessions_endpoint
from app.api.v1.endpoints import storage as storage_endpoint

# 数据库与注册表
from app.core.database import init_db, SessionLocal
from app.lenses import registry
from app.models.lens_model import LensRecord
from app.services.lens_embedding_sync import sync_lens_embeddings


# ============================================================
# 生命周期：启动时初始化数据库并加载注册表
# ============================================================

@asynccontextmanager
async def lifespan(app: FastAPI):
    # --- 启动阶段 ---
    # 1. 建表（幂等，已存在则跳过）
    init_db()

    # 2. 从数据库加载 Lens 注册表到内存
    db = SessionLocal()
    try:
        # 启动时始终补齐一遍内置透镜，避免旧库里只保留部分历史记录，
        # 导致 Router v2 的 Retrieval 只能看到残缺 candidates。
        registry.seed_builtin_lenses_into_db(db)

        registry.reload_registry(db)

        # 3. 若启用 pgvector，则在启动时自愈 embeddings 表与全量向量数据
        if os.getenv("MUSELENS_RAG_BACKEND", "").lower() == "pgvector":
            pg_dsn = os.getenv("MUSELENS_PG_DSN")
            if not pg_dsn:
                print("[Startup] 警告：MUSELENS_RAG_BACKEND=pgvector 但未设置 MUSELENS_PG_DSN，跳过 embeddings 同步。")
            else:
                table_name = os.getenv("MUSELENS_RAG_PGVECTOR_TABLE", "lens_embeddings")
                count = sync_lens_embeddings(
                    dsn=pg_dsn,
                    table_name=table_name,
                    registry=registry.LENS_REGISTRY,
                    include_examples=True,
                )
                print(f"[Startup] 已同步 {count} 条 lens embeddings 到表 {table_name}。")
    finally:
        db.close()

    yield  # 应用运行中...

    # --- 关闭阶段（如有需要可在此处释放资源）---


# ============================================================
# FastAPI 应用
# ============================================================

app = FastAPI(
    title="MuseLens API",
    version="1.0.0",
    lifespan=lifespan,
)

# --- 1. 关键配置：CORS (解决跨域问题) ---
origins = [
    "http://localhost",
    "http://localhost:8000",
    "http://127.0.0.1:8000",
    "*"  # 开发阶段允许所有 IP，生产环境需改为具体域名
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- 2. 挂载路由 ---
app.include_router(editor.router,           prefix="/api/v1/editor",  tags=["editor"])
app.include_router(router_endpoint.router,  prefix="/api/v1/router",  tags=["router"])
app.include_router(test_run.router,         prefix="/api/v1/test",    tags=["test"])
app.include_router(lenses_endpoint.router,     prefix="/api/v1/lenses",     tags=["lenses"])
app.include_router(asset_tree_endpoint.router, prefix="/api/v1/asset-tree", tags=["Asset Tree"])
app.include_router(users_endpoint.router,      prefix="/api/v1/users",      tags=["users"])
app.include_router(community_endpoint.router,  prefix="/api/v1/community",  tags=["community"])
app.include_router(market_endpoint.router,     prefix="/api/v1/market",     tags=["market"])
app.include_router(chat_endpoint.router,       prefix="/api/v1/chat",       tags=["chat"])
app.include_router(editor_sessions_endpoint.router, prefix="/api/v1/editor-sessions", tags=["editor-sessions"])
app.include_router(storage_endpoint.router, prefix="/api/v1/storage", tags=["storage"])

# --- 3. 根路由（健康检查）---
@app.get("/")
def read_root():
    return {
        "status": "online",
        "message": "MuseLens Backend is running!",
        "docs_url": "http://127.0.0.1:8000/docs",
        "registered_lenses": list(registry.LENS_REGISTRY.keys()),
    }
