from __future__ import annotations

from fastapi import HTTPException

from app.services.object_storage_service import storage_service


def upload_user_image(*, session_id: str, original_filename: str, binary: bytes, bucket: str | None = None) -> str:
    safe_filename = original_filename or "upload.png"
    bucket_name = bucket or storage_service.input_bucket
    key = storage_service.build_input_object_key(session_id=session_id, filename=safe_filename)
    return storage_service.put_bytes(
        bucket=bucket_name,
        key=key,
        data=binary,
        content_type="image/png" if safe_filename.lower().endswith(".png") else "application/octet-stream",
    )


def build_asset_url(asset_ref: str | None) -> str | None:
    if not asset_ref:
        return None
    return storage_service.get_download_url(asset_ref)


def ensure_storage_error(exc: Exception) -> HTTPException:
    return HTTPException(status_code=500, detail=f"Object storage operation failed: {exc}")
