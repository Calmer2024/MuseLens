from fastapi import APIRouter, UploadFile, File, Form, HTTPException
from fastapi.responses import Response
from app.services.comfy_service import ComfyService
import shutil
import os

router = APIRouter()
comfy_service = ComfyService()

@router.post("/inpaint")
async def inpaint_image(
    image: UploadFile = File(...),
    prompt: str = Form(...)
):
    # 1. 保存上传的临时文件
    temp_dir = "temp_uploads"
    os.makedirs(temp_dir, exist_ok=True)
    
    input_path = f"{temp_dir}/{image.filename}"
    
    with open(input_path, "wb") as buffer:
        shutil.copyfileobj(image.file, buffer)

    # 2. 调用 ComfyUI 服务
    generated_image_bytes = comfy_service.generate_image(input_path, prompt)

    os.remove(input_path)

    if generated_image_bytes:
        # 直接返回图片二进制流
        return Response(content=generated_image_bytes, media_type="image/png")
    else:
        raise HTTPException(status_code=500, detail="Image generation failed")