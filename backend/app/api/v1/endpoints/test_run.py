"""
MuseLens 测试接口 — 本地管线验证

提供一个简单的 GET 接口用于触发 A1 → A2 的接力管线，
验证 LensTemplate 参数注入和 ComfyUI 通信的端到端流程。
"""

from fastapi import APIRouter, Query, HTTPException
from app.services.compiler import LocalMockCompiler

router = APIRouter()


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
    执行 A1 (SAM2 抠图) → A2 (Inpaint 重绘) 的本地测试管线。

    **注意：** 此接口会同步阻塞等待 ComfyUI 执行完成，
    耗时可能较长（取决于模型加载和推理速度）。
    前提是 ComfyUI 已在本地启动且 image 参数指定的图片已存在于 input 目录。
    """
    try:
        compiler = LocalMockCompiler()
        # 对于测试接口，直接使用 ComfyUI input 目录中已有的图片
        # 不再走上传流程，而是直接将文件名传给透镜
        result_filename = compiler.run_mock_pipeline_by_name(
            base_image_name=image,
            segment_prompt=segment_prompt,
            inpaint_prompt=inpaint_prompt,
        )
        return {
            "status": "success",
            "message": "管线执行完毕",
            "result_filename": result_filename,
            "result_url": f"http://127.0.0.1:8188/view?filename={result_filename}&type=output",
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"管线执行失败: {str(e)}")
