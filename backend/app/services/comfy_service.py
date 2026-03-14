"""
MuseLens 异步通信服务 (Async ComfyService)

重写底层的 ComfyUI 通信机制：
完全抛弃了阻塞的 requests, urllib 和 websocket-client。
引入 httpx.AsyncClient 和 websockets 库来实现非阻塞的协程流式获取，
包含对生成进度的异步回调支持。
"""

import json
import uuid
import os
import asyncio
import logging
import httpx
import websockets

logger = logging.getLogger(__name__)

# ComfyUI 地址
COMFY_URL = "127.0.0.1:8188"
SERVER_ADDRESS = f"http://{COMFY_URL}"
WS_ADDRESS = f"ws://{COMFY_URL}/ws?clientId="


class AsyncComfyRunner:
    """
    负责与 ComfyUI 进行异步通信的执行器类。
    """
    def __init__(self):
        self.client_id = str(uuid.uuid4())
        # 设置较大的超时门限，防止大图生成超时
        self.http_client = httpx.AsyncClient(timeout= httpx.Timeout(600.0))

    async def upload_image(self, file_path: str, file_name: str, image_type: str = "input") -> dict:
        """异步上传图片"""
        with open(file_path, 'rb') as f:
            files = {"image": (file_name, f)}
            data = {"type": image_type, "overwrite": "true"}
            response = await self.http_client.post(f"{SERVER_ADDRESS}/upload/image", data=data, files=files)
            response.raise_for_status()
            return response.json()

    async def queue_prompt(self, workflow_json: dict) -> str:
        """异步排队提交任务"""
        payload = {"prompt": workflow_json, "client_id": self.client_id}
        response = await self.http_client.post(f"{SERVER_ADDRESS}/prompt", json=payload)
        response.raise_for_status()
        return response.json()["prompt_id"]

    async def get_history(self, prompt_id: str) -> dict:
        """异步获取生成历史与输出详情"""
        response = await self.http_client.get(f"{SERVER_ADDRESS}/history/{prompt_id}")
        response.raise_for_status()
        return response.json()

    async def get_image(self, filename: str, subfolder: str, folder_type: str) -> bytes:
        """异步下载 ComfyUI 的输出图字节"""
        params = {"filename": filename, "subfolder": subfolder, "type": folder_type}
        response = await self.http_client.get(f"{SERVER_ADDRESS}/view", params=params)
        response.raise_for_status()
        return response.content

    async def wait_for_completion(self, prompt_id: str) -> None:
        """
        异步监听 WebSocket 等待指定的 prompt_id 执行完成。
        """
        async with websockets.connect(WS_ADDRESS + self.client_id) as ws:
            while True:
                out = await ws.recv()
                if isinstance(out, str):
                    message = json.loads(out)
                    # ComfyUI 进度日志
                    if message['type'] == 'progress':
                        data = message['data']
                        logger.debug(f"[ComfyUI] 正在推理节点 {data.get('node')}: {data.get('value')}/{data.get('max')}")
                    # ComfyUI 节点执行状态
                    elif message['type'] == 'executing':
                        data = message['data']
                        # 如果 node 为 null 并且 prompt_id 对应，则表示这个管线跑完了
                        if data['node'] is None and data.get('prompt_id') == prompt_id:
                            return

    async def get_output_filename(self, prompt_id: str, output_node_id: str) -> str:
        """
        从历史记录中抽取出指定的 SaveImage 节点生成的文件名。
        """
        history = await self.get_history(prompt_id)
        if prompt_id not in history:
            raise RuntimeError(f"未能在 ComfyUI History 中找到 prompt_id {prompt_id}")
            
        node_output = history[prompt_id]["outputs"].get(output_node_id)
        if not node_output or "images" not in node_output or len(node_output["images"]) == 0:
             raise RuntimeError(f"节点 {output_node_id} 未产出任何 image 输出")
             
        # {"filename": "...", "subfolder": "", "type": "output"}
        return node_output["images"][0]["filename"]

    async def close(self):
        """关闭底层 HTTP Client"""
        await self.http_client.aclose()