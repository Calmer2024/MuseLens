from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

# 导入路由
from app.api.v1.endpoints import editor
from app.api.v1.endpoints import router as router_endpoint
from app.api.v1.endpoints import test_run

app = FastAPI(title="MuseLens API", version="1.0.0")

# --- 1. 关键配置：CORS (解决跨域问题) ---
# 允许 Flutter 模拟器、真机、浏览器访问后端
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
# 将 editor.py 中的接口挂载到 /api/v1/editor 下
app.include_router(editor.router, prefix="/api/v1/editor", tags=["editor"])
# Router：意图路由与追问机制
app.include_router(router_endpoint.router, prefix="/api/v1/router", tags=["router"])
# 将 test_run.py 中的测试接口挂载到 /api/v1/test 下
app.include_router(test_run.router, prefix="/api/v1/test", tags=["test"])

# --- 3. 根路由 (健康检查) ---
@app.get("/")
def read_root():
    return {
        "status": "online",
        "message": "MuseLens Backend is running!",
        "docs_url": "http://127.0.0.1:8000/docs"
    }

# --- 4. 静态文件 (可选) ---
# 如果你需要直接访问生成的临时图片，可以挂载静态目录
# app.mount("/static", StaticFiles(directory="temp_uploads"), name="static")