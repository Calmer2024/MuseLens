from __future__ import annotations

from fastapi import APIRouter, HTTPException, Query
from fastapi.responses import RedirectResponse, Response

from app.services.object_storage_service import storage_service


router = APIRouter()


@router.get("/object")
def get_object(ref: str = Query(..., description="Object ref, such as minio://bucket/key")):
    try:
        if ref.startswith(("http://", "https://")):
            return RedirectResponse(ref, status_code=307)

        url = storage_service.get_download_url(ref)
        if url != storage_service.build_proxy_url(ref):
            return RedirectResponse(url, status_code=307)

        content = storage_service.get_bytes(ref)
        stat = storage_service.stat(ref)
        return Response(content=content, media_type=stat["content_type"])
    except Exception as exc:
        raise HTTPException(status_code=404, detail=f"Object not found: {exc}")
