from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# 导入路由
from app.api.v1.endpoints import editor
from app.api.v1.endpoints import router as router_endpoint
from app.api.v1.endpoints import test_run
from app.api.v1.endpoints import lenses as lenses_endpoint

# 数据库与注册表
from app.core.database import init_db, SessionLocal
from app.lenses import registry


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
        registry.reload_registry(db)
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
app.include_router(lenses_endpoint.router,  prefix="/api/v1/lenses",  tags=["lenses"])

# --- 3. 根路由（健康检查）---
@app.get("/")
def read_root():
    return {
        "status": "online",
        "message": "MuseLens Backend is running!",
        "docs_url": "http://127.0.0.1:8000/docs",
        "registered_lenses": list(registry.LENS_REGISTRY.keys()),
    }
