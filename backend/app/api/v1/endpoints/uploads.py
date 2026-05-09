"""
通用图片上传 endpoint。

将前端选择的图片上传到 MinIO 对象存储，返回可持久化的 download_url。
"""

from __future__ import annotations

import uuid

from fastapi import APIRouter, File, Form, HTTPException, UploadFile
from pydantic import BaseModel

from app.services.object_storage_service import storage_service


router = APIRouter()


_PURPOSE_PREFIXES = {
    "community_post": "uploads/community/posts",
    "avatar": "uploads/avatars",
    "banner": "uploads/banners",
    "editor_result": "uploads/editor",
    "project_cover": "uploads/projects",
    "ai_tool_asset": "uploads/ai_assets",
    "general": "uploads/general",
}


class ImageUploadResponse(BaseModel):
    object_ref: str
    download_url: str


@router.post("/image", response_model=ImageUploadResponse, summary="上传图片到对象存储")
async def upload_image(
    file: UploadFile = File(..., description="图片文件"),
    purpose: str = Form(default="general", description="用途: community_post, avatar, banner, editor_result, project_cover, ai_tool_asset, general"),
) -> ImageUploadResponse:
    if not storage_service.is_minio_enabled:
        raise HTTPException(status_code=503, detail="对象存储服务未配置")

    binary = await file.read()
    if not binary:
        raise HTTPException(status_code=400, detail="上传文件为空")

    original_filename = (file.filename or "upload.png").strip() or "upload.png"
    prefix = _PURPOSE_PREFIXES.get(purpose, _PURPOSE_PREFIXES["general"])
    unique_name = f"{uuid.uuid4().hex}_{original_filename}"
    key = storage_service.normalize_key(prefix, unique_name)

    content_type = file.content_type or "application/octet-stream"

    try:
        object_ref = storage_service.put_bytes(
            bucket=storage_service.input_bucket,
            key=key,
            data=binary,
            content_type=content_type,
        )
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"上传失败: {exc}")

    download_url = storage_service.get_download_url(object_ref)

    return ImageUploadResponse(
        object_ref=object_ref,
        download_url=download_url,
    )
