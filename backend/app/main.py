from fastapi import FastAPI
from app.api.v1 import websocket
# from app.api.v1.endpoints import editor  # 后续导入

app = FastAPI(title="Nano Banana API")

# 1. 挂载 WebSocket 路由
# 前端连接地址: ws://localhost:8000/ws/editor
app.include_router(websocket.router, prefix="/ws", tags=["websocket"])

@app.get("/")
def read_root():
    return {"message": "Nano Banana Backend is Running!"}