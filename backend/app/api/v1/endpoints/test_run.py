"""
MuseLens 测试接口 — 本地 DAG 管线验证 (Phase 2)

提供一个简单的 GET / POST 接口用于触发 API 的异步接力管线，
不再依赖 WebSocket 即可验证后端 DAGCompiler 的功能。
"""

import json
from fastapi import APIRouter, Query, HTTPException

from app.schemas.lens import DAGBlueprint, DAGStep
from app.services.compiler import MuseDNACompiler, COMFYUI_INPUT_DIR, COMFYUI_OUTPUT_DIR

router = APIRouter()

# 实例化全局单例编译器
compiler = MuseDNACompiler(
    input_dir=COMFYUI_INPUT_DIR,
    output_dir=COMFYUI_OUTPUT_DIR
)


@router.get("/run_pipeline")
async def run_pipeline(
    image: str = Query(
        ...,
        description="ComfyUI input 目录中已存在的图片文件名（如 'photo.png'）",
        examples=["woman-8463055_1280.jpg"],
    ),
    segment_prompt: str = Query(
        default="subject",
        description="SAM2 分割提示词，描述要提取的目标主体",
        examples=["Woman", "cat", "sofa"],
    ),
    inpaint_prompt: str = Query(
        default="a beautiful garden with flowers",
        description="Inpaint 正向提示词，描述目标效果",
        examples=["a cyberpunk room", "a beach at sunset"],
    ),
):
    """
    HTTP GET endpoint to trigger and wait for the Phase 2 DAG Pipeline:
    A1 (SAM2 抠图) → A2 (Inpaint 重绘)。

    该接口将**异步阻塞** HTTP 请求，直到管跑图结束并返回各步的临时资产结果。
    适合用来快速做后端的连通性测试。
    """
    try:
        # 构建我们要测试的 DAGBlueprint
        test_blueprint = DAGBlueprint(
            initial_inputs={
                "user_base_image": image
            },
            steps=[
                # Step 1: 语义抠图
                DAGStep(
                    step_id="step_1_matting",
                    lens_id="lens_sam2_matting",
                    input_links={
                         "base_image": "$user_base_image"
                    },
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
                         "mask_target": "$step_1_matting.mask_result"
                    },
                    params={
                         "positive_prompt": inpaint_prompt
                    }
                )
            ]
        )

        # 执行图引擎，因为我们不需要实时进度下发，可以不用传 progress_callback
        # 等到全部跑完后，它会返回完整的 context 黑板包含所有的物理拓扑文件
        final_context = await compiler.execute_blueprint(test_blueprint)
        
        # 寻找第二步产生的结果作为最终结果
        result_filename = final_context.get("step_2_inpaint.result_image")

        if not result_filename:
             raise RuntimeError("图执行成功，但在上下文中未找到我们期望的最终产出 'step_2_inpaint.result_image'")

        return {
            "status": "success",
            "message": "DAG Pipeline 执行完毕 (HTTP 模式)",
            "context_dump": final_context,
            "result_filename": result_filename,
            "result_url": f"http://127.0.0.1:8188/view?filename={result_filename}&type=output",
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"管线执行失败: {str(e)}")
