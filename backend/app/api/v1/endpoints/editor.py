import os
import json
import logging
import asyncio
from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from app.schemas.lens import DAGBlueprint, DAGStep
from app.services.compiler import MuseDNACompiler, COMFYUI_INPUT_DIR, COMFYUI_OUTPUT_DIR

logger = logging.getLogger(__name__)

router = APIRouter()

# 实例化全局单例编译器
compiler = MuseDNACompiler(
    input_dir=COMFYUI_INPUT_DIR,
    output_dir=COMFYUI_OUTPUT_DIR
)


@router.websocket("/ws/editor/{client_id}")
async def editor_websocket_endpoint(websocket: WebSocket, client_id: str):
    """
    WebSocket 编辑器网关。
    前端连入后，可以通过发送 action="generate" 触发后端的 DAG 生成并实时接收图像回传。
    """
    await websocket.accept()
    logger.info(f"[WS] Client {client_id} connected.")
    try:
        while True:
            # 接收前端消息
            data = await websocket.receive_text()
            payload = json.loads(data)
            logger.info(f"[WS] Client {client_id} sent: {payload}")

            if payload.get("action") == "generate":
                # 为了本地测试，硬编码生成一个模拟 LLM RAG 输出的 DAGBlueprint
                # 管线: 1. A1 语义抠图 -> 2. A2 局部重绘
                
                # 假设前端界面中已经存放了一个 base_image 叫 "photo.png"
                # （你需要确保 ComfyUI 的 input 目录下确实有一个叫对应名字的图片）
                base_img_name = payload.get("base_image", "input_image.png")
                segment_prompt = payload.get("segment_prompt", "subject")
                inpaint_prompt = payload.get("inpaint_prompt", "a beautiful garden")

                test_blueprint = DAGBlueprint(
                    # 初始化全局黑板，将外源输入映射为物理文件名
                    initial_inputs={
                        "user_base_image": base_img_name
                    },
                    steps=[
                        # Step 1: 语义抠图
                        DAGStep(
                            step_id="step_1_matting",
                            lens_id="lens_sam2_matting",
                            # "$变量名" -> 动态从黑板寻址
                            input_links={
                                "base_image": "$user_base_image"
                            },
                            # 动态参数注入
                            params={
                                "prompt": segment_prompt
                            }
                        ),
                        # Step 2: 换背景重绘
                        DAGStep(
                            step_id="step_2_inpaint",
                            lens_id="lens_inpaint_bg",
                            input_links={
                                "base_image": "$user_base_image",
                                # 核心跨距拓扑传递：将上一步产出的局部遮罩输入给当前步的 mask_target
                                "mask_target": "$step_1_matting.mask_result"
                            },
                            params={
                                "positive_prompt": inpaint_prompt
                            }
                        )
                    ]
                )

                # 回调函数：当一个 Step 处理完成时，由 Compiler 自动调用
                async def send_progress_to_ws(step_id: str, output_assets: dict):
                    await websocket.send_json({
                        "event": "step_completed",
                        "step_id": step_id,
                        "outputs": output_assets
                    })
                    logger.info(f"[WS] Pushed progress for {step_id} to {client_id}")

                # 启动后台非阻塞任务跑图
                asyncio.create_task(
                    compiler.execute_blueprint(
                        blueprint=test_blueprint,
                        progress_callback=send_progress_to_ws
                    )
                )
                
                # 立即向前端回复开始
                await websocket.send_json({
                    "event": "pipeline_started",
                    "message": "DAG Pipeline is running in the background."
                })

    except WebSocketDisconnect:
        logger.info(f"[WS] Client {client_id} disconnected.")
    except Exception as e:
        logger.error(f"[WS] Error for client {client_id}: {e}")
        try:
             await websocket.send_json({"event": "error", "message": str(e)})
        except:
             pass