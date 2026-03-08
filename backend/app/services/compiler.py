"""
MuseLens 本地接力编译器 (Local Mock Compiler)

模拟 LLM Router 的决策逻辑，将 A1 (SAM2 抠图) 和 A2 (Inpaint 重绘) 串联执行。
核心流程：
  1. 将用户原图上传至 ComfyUI input 目录
  2. 执行 A1 透镜 → 获取遮罩图路径
  3. 将遮罩自动注入 A2 透镜的 mask_target 参数
  4. 执行 A2 透镜 → 返回最终生成图片的文件名

复用了 comfy_service.py 中与 ComfyUI API 的通信逻辑，
但将"硬编码 JSON 拼接"升级为"基于 LensTemplate 的参数注入"。
"""

import json
import shutil
import logging
import urllib.request
import urllib.parse
import uuid
import os

import requests
import websocket

from app.schemas.lens import LensTemplate
from app.lenses.registry import get_lens

logger = logging.getLogger(__name__)

# ComfyUI 地址 (与 comfy_service.py 保持一致)
COMFY_HOST = "127.0.0.1:8188"
COMFY_HTTP = f"http://{COMFY_HOST}"
COMFY_WS = f"ws://{COMFY_HOST}/ws?clientId="

# ComfyUI 的 output 目录 (根据实际安装路径修改)
COMFYUI_OUTPUT_DIR = os.environ.get(
    "COMFYUI_OUTPUT_DIR",
    r"E:\ComfyUI\ComfyUI_windows_portable\ComfyUI\output",
)
COMFYUI_INPUT_DIR = os.environ.get(
    "COMFYUI_INPUT_DIR",
    r"E:\ComfyUI\ComfyUI_windows_portable\ComfyUI\input",
)


class ComfyBridge:
    """
    与 ComfyUI HTTP/WebSocket API 通信的底层桥梁。
    提供：上传图片、提交工作流、等待执行完成、获取输出文件名。
    """

    def __init__(self) -> None:
        self.client_id = str(uuid.uuid4())

    def _connect_ws(self) -> websocket.WebSocket:
        """建立 WebSocket 连接"""
        ws = websocket.WebSocket()
        ws.connect(COMFY_WS + self.client_id)
        return ws

    def upload_image(self, file_path: str, target_filename: str) -> dict:
        """上传图片到 ComfyUI 的 input 目录"""
        with open(file_path, "rb") as f:
            files = {"image": (target_filename, f)}
            data = {"type": "input", "overwrite": "true"}
            resp = requests.post(f"{COMFY_HTTP}/upload/image", files=files, data=data)
            resp.raise_for_status()
            return resp.json()

    def queue_prompt(self, workflow: dict) -> str:
        """提交工作流到 ComfyUI 队列，返回 prompt_id"""
        payload = json.dumps({
            "prompt": workflow,
            "client_id": self.client_id,
        }).encode("utf-8")
        req = urllib.request.Request(f"{COMFY_HTTP}/prompt", data=payload)
        result = json.loads(urllib.request.urlopen(req).read())
        return result["prompt_id"]

    def wait_for_completion(self, prompt_id: str) -> None:
        """通过 WebSocket 阻塞等待指定任务执行完成"""
        ws = self._connect_ws()
        try:
            while True:
                msg = ws.recv()
                if isinstance(msg, str):
                    data = json.loads(msg)
                    if data.get("type") == "executing":
                        exec_data = data["data"]
                        # node=None 表示整个 prompt 执行完毕
                        if exec_data.get("node") is None and exec_data.get("prompt_id") == prompt_id:
                            break
        finally:
            ws.close()

    def get_output_filename(self, prompt_id: str, output_node_id: str) -> str:
        """
        从 ComfyUI History API 获取指定输出节点生成的文件名。

        Args:
            prompt_id: 任务 ID
            output_node_id: SaveImage 节点的 ID (如 "14")

        Returns:
            生成的文件名 (如 "ComfyUI_00042_.png")
        """
        url = f"{COMFY_HTTP}/history/{prompt_id}"
        with urllib.request.urlopen(url) as resp:
            history = json.loads(resp.read())

        node_output = history[prompt_id]["outputs"][output_node_id]
        # SaveImage 节点的 outputs 结构: {"images": [{"filename": "...", "subfolder": "", "type": "output"}]}
        return node_output["images"][0]["filename"]

    def execute_lens(self, lens: LensTemplate, params: dict[str, str]) -> str:
        """
        执行单个透镜的完整生命周期：注入参数 → 提交 → 等待 → 返回输出文件名。

        Args:
            lens: 要执行的透镜模板
            params: 注入参数 (name → value)

        Returns:
            第一个 output 节点生成的文件名
        """
        # 1. 参数注入，得到可执行的 workflow JSON
        workflow = lens.inject_inputs(params)
        logger.info(f"[{lens.lens_id}] 参数注入完成，准备提交 ComfyUI")

        # 2. 提交到 ComfyUI 队列
        prompt_id = self.queue_prompt(workflow)
        logger.info(f"[{lens.lens_id}] 已提交，prompt_id={prompt_id}")

        # 3. 阻塞等待执行完成
        self.wait_for_completion(prompt_id)
        logger.info(f"[{lens.lens_id}] 执行完成")

        # 4. 从 History 获取输出文件名
        output_node_id = lens.outputs[0].mapping.node_id
        output_filename = self.get_output_filename(prompt_id, output_node_id)
        logger.info(f"[{lens.lens_id}] 输出文件: {output_filename}")

        return output_filename


class LocalMockCompiler:
    """
    本地接力编译器 — 模拟 LLM Router 的决策逻辑。

    硬编码执行 A1 (SAM2 抠图) → A2 (Inpaint 重绘) 的串联管线，
    自动将 A1 的遮罩输出搬运到 ComfyUI input 目录，
    并注入为 A2 的 mask_target 参数。
    """

    def __init__(self) -> None:
        self.bridge = ComfyBridge()

    def _relay_output_to_input(self, output_filename: str) -> str:
        """
        IO 搬运：将 ComfyUI output 目录中的产物复制到 input 目录，
        使下游透镜的 LoadImage 节点能够读取。

        Args:
            output_filename: output 目录下的文件名

        Returns:
            复制到 input 目录后的文件名 (保持不变)
        """
        src = os.path.join(COMFYUI_OUTPUT_DIR, output_filename)
        dst = os.path.join(COMFYUI_INPUT_DIR, output_filename)
        shutil.copy2(src, dst)
        logger.info(f"[搬运] {src} → {dst}")
        return output_filename

    def run_mock_pipeline(
        self,
        base_image_path: str,
        segment_prompt: str = "subject",
        inpaint_prompt: str = "a beautiful garden with flowers",
    ) -> str:
        """
        执行 A1 → A2 的模拟接力管线。

        流程：
          Step A: 上传原图 → 执行 lens_sam2_matting → 获取遮罩文件名
          Step B: 搬运遮罩至 input → 执行 lens_inpaint_bg → 返回最终图片文件名

        Args:
            base_image_path: 用户原图的本地绝对路径
            segment_prompt: SAM2 的分割提示词 (描述要提取的目标)
            inpaint_prompt: Inpaint 的正向提示词 (描述目标效果)

        Returns:
            最终生成图片的文件名 (位于 ComfyUI output 目录下)
        """
        # --- 准备：上传原图到 ComfyUI input ---
        base_filename = os.path.basename(base_image_path)
        self.bridge.upload_image(base_image_path, base_filename)
        logger.info(f"[管线] 原图已上传: {base_filename}")

        # =============================================
        # Step A: 执行 A1 — SAM2 语义抠图
        # =============================================
        lens_a1 = get_lens("lens_sam2_matting")
        mask_filename = self.bridge.execute_lens(lens_a1, {
            "base_image": base_filename,
            "prompt": segment_prompt,
        })

        # =============================================
        # 接力搬运：output → input
        # =============================================
        relay_mask = self._relay_output_to_input(mask_filename)

        # =============================================
        # Step B: 执行 A2 — Inpaint 局部重绘
        # =============================================
        lens_a2 = get_lens("lens_inpaint_bg")
        result_filename = self.bridge.execute_lens(lens_a2, {
            "base_image": base_filename,
            "mask_target": relay_mask,         # ← A1 的输出自动注入为 A2 的输入
            "positive_prompt": inpaint_prompt,
        })

        logger.info(f"[管线] 管线执行完毕，最终输出: {result_filename}")
        return result_filename

    def run_mock_pipeline_by_name(
        self,
        base_image_name: str,
        segment_prompt: str = "subject",
        inpaint_prompt: str = "a beautiful garden with flowers",
    ) -> str:
        """
        与 run_mock_pipeline 逻辑相同，但接受 ComfyUI input 目录中已有的文件名，
        跳过上传步骤。适合测试接口直接调用。

        Args:
            base_image_name: ComfyUI input 目录中已存在的图片文件名
            segment_prompt: SAM2 的分割提示词
            inpaint_prompt: Inpaint 的正向提示词

        Returns:
            最终生成图片的文件名
        """
        logger.info(f"[管线] 使用已有图片: {base_image_name}")

        # Step A: 执行 A1 — SAM2 语义抠图
        lens_a1 = get_lens("lens_sam2_matting")
        mask_filename = self.bridge.execute_lens(lens_a1, {
            "base_image": base_image_name,
            "prompt": segment_prompt,
        })

        # 接力搬运：output → input
        relay_mask = self._relay_output_to_input(mask_filename)

        # Step B: 执行 A2 — Inpaint 局部重绘
        lens_a2 = get_lens("lens_inpaint_bg")
        result_filename = self.bridge.execute_lens(lens_a2, {
            "base_image": base_image_name,
            "mask_target": relay_mask,
            "positive_prompt": inpaint_prompt,
        })

        logger.info(f"[管线] 管线执行完毕，最终输出: {result_filename}")
        return result_filename
