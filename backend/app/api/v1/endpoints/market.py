"""
透镜市场 API。
"""

from __future__ import annotations

import asyncio
from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.schemas.asset_tree import MessageResponse
from app.schemas.market import (
    LensFavoriteRequest,
    LensInstallRequest,
    LensReviewCreateRequest,
    LensReviewOut,
    MarketLensApplyRequest,
    MarketLensApplyResponse,
    MarketLensApplyStepResult,
    MarketLensCreateRequest,
    MarketLensDetail,
    MarketLensOut,
    MarketLensPublishFromNodeRequest,
    MarketLensPublishResponse,
    MarketLensUpdateRequest,
    MarketLensVersionCreateRequest,
    MarketLensVersionOut,
)
from app.services import market_service as svc
from app.services.compiler import COMFYUI_INPUT_DIR, COMFYUI_OUTPUT_DIR, MuseDNACompiler
from app.services.execution_service import (
    build_result_url,
    build_step_results,
    execute_blueprint_with_optional_stream,
    infer_result_filename,
    run_blueprint_with_stream_events,
)
from app.services.router_stream_service import router_stream_service

router = APIRouter()
compiler = MuseDNACompiler(input_dir=COMFYUI_INPUT_DIR, output_dir=COMFYUI_OUTPUT_DIR)


def _market_lens_detail(db: Session, lens) -> MarketLensDetail:
    return MarketLensDetail(
        **MarketLensOut.model_validate(lens).model_dump(),
        versions=[MarketLensVersionOut.model_validate(item) for item in svc.list_market_lens_versions(db, lens.lens_id)],
        reviews=[LensReviewOut.model_validate(item) for item in svc.list_lens_reviews(db, lens.lens_id)],
    )


def _raise_market_error(exc: Exception, *, duplicate_as_conflict: bool = False) -> None:
    if duplicate_as_conflict and "已存在" in str(exc):
        raise HTTPException(status_code=409, detail=str(exc))
    raise HTTPException(status_code=400, detail=str(exc))


@router.post("/lenses", response_model=MarketLensOut, status_code=201, summary="创建市场 preset")
def create_market_lens(body: MarketLensCreateRequest, db: Session = Depends(get_db)) -> MarketLensOut:
    try:
        lens = svc.create_market_lens(
            db,
            lens_key=body.lens_key,
            name=body.name,
            description=body.description,
            author_id=body.author_id,
            category=body.category,
            price=body.price,
            is_official=body.is_official,
            cover_image_url=body.cover_image_url,
            preview_asset_node_id=body.preview_asset_node_id,
            status=body.status,
        )
    except Exception as exc:
        _raise_market_error(exc, duplicate_as_conflict=True)
    return MarketLensOut.model_validate(lens)


@router.post(
    "/lenses/publish-from-node",
    response_model=MarketLensPublishResponse,
    status_code=201,
    summary="从资产节点发布 preset",
)
def publish_market_lens_from_node(
    body: MarketLensPublishFromNodeRequest,
    db: Session = Depends(get_db),
) -> MarketLensPublishResponse:
    try:
        lens, version = svc.publish_market_lens_from_asset_node(
            db,
            lens_key=body.lens_key,
            name=body.name,
            description=body.description,
            author_id=body.author_id,
            source_asset_node_id=body.source_asset_node_id,
            source_episode_id=body.source_episode_id,
            category=body.category,
            price=body.price,
            is_official=body.is_official,
            status=body.status,
            version=body.version,
            changelog=body.changelog,
            parameters=body.parameters,
            ui_schema=body.ui_schema,
            base_workflow=body.base_workflow,
        )
    except Exception as exc:
        _raise_market_error(exc, duplicate_as_conflict=True)

    return MarketLensPublishResponse(
        lens=MarketLensOut.model_validate(lens),
        version=MarketLensVersionOut.model_validate(version),
    )


@router.patch("/lenses/{lens_id}", response_model=MarketLensOut, summary="更新市场 preset")
def update_market_lens(lens_id: int, body: MarketLensUpdateRequest, db: Session = Depends(get_db)) -> MarketLensOut:
    try:
        lens = svc.update_market_lens(
            db,
            lens_id=lens_id,
            name=body.name,
            description=body.description,
            category=body.category,
            price=body.price,
            is_official=body.is_official,
            cover_image_url=body.cover_image_url,
            preview_asset_node_id=body.preview_asset_node_id,
            status=body.status,
        )
    except Exception as exc:
        _raise_market_error(exc)

    if not lens:
        raise HTTPException(status_code=404, detail=f"透镜不存在：{lens_id}")
    return MarketLensOut.model_validate(lens)


@router.get("/lenses", response_model=List[MarketLensOut], summary="列出市场 preset")
def list_market_lenses(
    category: str | None = Query(default=None),
    status: str | None = Query(default=None),
    is_official: bool | None = Query(default=None),
    db: Session = Depends(get_db),
) -> List[MarketLensOut]:
    lenses = svc.list_market_lenses(db, category=category, status=status, is_official=is_official)
    return [MarketLensOut.model_validate(item) for item in lenses]


@router.get("/lenses/{lens_id}", response_model=MarketLensDetail, summary="获取 preset 详情")
def get_market_lens_detail(lens_id: int, db: Session = Depends(get_db)) -> MarketLensDetail:
    lens = svc.get_market_lens(db, lens_id)
    if not lens:
        raise HTTPException(status_code=404, detail=f"透镜不存在：{lens_id}")
    return _market_lens_detail(db, lens)


@router.post("/lenses/{lens_id}/versions", response_model=MarketLensVersionOut, status_code=201, summary="创建 preset 版本")
def create_market_lens_version(
    lens_id: int,
    body: MarketLensVersionCreateRequest,
    db: Session = Depends(get_db),
) -> MarketLensVersionOut:
    try:
        version = svc.create_market_lens_version(
            db,
            lens_id=lens_id,
            version=body.version,
            base_workflow=body.base_workflow,
            parameters=body.parameters,
            ui_schema=body.ui_schema,
            blueprint=body.blueprint,
            source_asset_node_id=body.source_asset_node_id,
            source_episode_id=body.source_episode_id,
            published_from=body.published_from,
            changelog=body.changelog,
            is_latest=body.is_latest,
        )
    except Exception as exc:
        _raise_market_error(exc)
    return MarketLensVersionOut.model_validate(version)


@router.post("/lenses/{lens_id}/apply", response_model=MarketLensApplyResponse, summary="获取或直接执行共享 blueprint")
async def apply_market_lens(
    lens_id: int,
    body: MarketLensApplyRequest,
    db: Session = Depends(get_db),
) -> MarketLensApplyResponse:
    try:
        lens, version, blueprint, required_inputs = svc.prepare_market_lens_apply(
            db,
            lens_id=lens_id,
            user_id=body.user_id,
            version_id=body.version_id,
            initial_inputs=body.initial_inputs,
            param_overrides=body.param_overrides,
        )
    except Exception as exc:
        _raise_market_error(exc)

    payload = {
        "lens": MarketLensOut.model_validate(lens),
        "version": MarketLensVersionOut.model_validate(version),
        "blueprint": blueprint,
        "required_inputs": required_inputs,
        "executed": False,
        "execution_context": {},
        "result_filename": None,
        "result_url": None,
        "execution_error": None,
        "execution_started": False,
        "stream_id": body.stream_id,
        "step_results": [],
    }

    if not body.execute_now:
        return MarketLensApplyResponse(**payload)

    session_label = f"market_lens_{lens_id}_v{version.version_id}"

    if body.async_execution and not body.stream_id:
        raise HTTPException(status_code=400, detail="async_execution=true 时必须提供 stream_id")

    if body.async_execution and body.stream_id:
        await router_stream_service.emit(
            body.stream_id,
            {
                "event": "blueprint_ready",
                "session_id": session_label,
                "stream_id": body.stream_id,
                "status": "ready",
                "blueprint": blueprint.model_dump(),
            },
        )
        asyncio.create_task(
            run_blueprint_with_stream_events(
                compiler=compiler,
                blueprint=blueprint,
                session_id=session_label,
                stream_id=body.stream_id,
            )
        )
        payload["execution_started"] = True
        return MarketLensApplyResponse(**payload)

    try:
        final_context = await execute_blueprint_with_optional_stream(
            compiler=compiler,
            blueprint=blueprint,
            session_id=session_label,
            stream_id=body.stream_id,
        )
        result_filename = infer_result_filename(blueprint, final_context)
        payload.update(
            {
                "executed": True,
                "execution_started": True,
                "execution_context": final_context,
                "result_filename": result_filename,
                "result_url": build_result_url(result_filename) if result_filename else None,
                "step_results": [
                    MarketLensApplyStepResult.model_validate(item)
                    for item in build_step_results(blueprint, final_context)
                ],
            }
        )
        if not result_filename:
            payload["execution_error"] = "Blueprint 已执行，但未在执行上下文中发现结果图。"
    except Exception as exc:
        payload["execution_error"] = str(exc)

    return MarketLensApplyResponse(**payload)


@router.post("/lenses/{lens_id}/install", response_model=MessageResponse, summary="安装 preset")
def install_lens(lens_id: int, body: LensInstallRequest, db: Session = Depends(get_db)) -> MessageResponse:
    try:
        created = svc.install_lens(db, user_id=body.user_id, lens_id=lens_id, version_id=body.version_id)
    except Exception as exc:
        _raise_market_error(exc)
    return MessageResponse(message="安装成功" if created else "已安装，已切换到指定版本")


@router.delete("/lenses/{lens_id}/install", response_model=MessageResponse, summary="卸载 preset")
def uninstall_lens(lens_id: int, body: LensInstallRequest, db: Session = Depends(get_db)) -> MessageResponse:
    removed = svc.uninstall_lens(db, user_id=body.user_id, lens_id=lens_id)
    return MessageResponse(message="卸载成功" if removed else "用户未安装该透镜")


@router.post("/lenses/{lens_id}/favorite", response_model=MessageResponse, summary="收藏 preset")
def favorite_lens(lens_id: int, body: LensFavoriteRequest, db: Session = Depends(get_db)) -> MessageResponse:
    try:
        created = svc.favorite_lens(db, user_id=body.user_id, lens_id=lens_id)
    except Exception as exc:
        _raise_market_error(exc)
    return MessageResponse(message="收藏成功" if created else "已收藏，无需重复操作")


@router.delete("/lenses/{lens_id}/favorite", response_model=MessageResponse, summary="取消收藏 preset")
def unfavorite_lens(lens_id: int, body: LensFavoriteRequest, db: Session = Depends(get_db)) -> MessageResponse:
    removed = svc.unfavorite_lens(db, user_id=body.user_id, lens_id=lens_id)
    return MessageResponse(message="取消收藏成功" if removed else "收藏记录不存在")


@router.post("/lenses/{lens_id}/reviews", response_model=LensReviewOut, summary="创建或更新评价")
def create_or_update_review(
    lens_id: int,
    body: LensReviewCreateRequest,
    db: Session = Depends(get_db),
) -> LensReviewOut:
    try:
        review = svc.create_or_update_review(
            db,
            user_id=body.user_id,
            lens_id=lens_id,
            rating=body.rating,
            content=body.content,
        )
    except Exception as exc:
        _raise_market_error(exc)
    return LensReviewOut.model_validate(review)


@router.get("/users/{user_id}/installed", response_model=List[MarketLensOut], summary="获取用户已安装 preset")
def list_user_installed_lenses(user_id: int, db: Session = Depends(get_db)) -> List[MarketLensOut]:
    return [MarketLensOut.model_validate(item) for item in svc.list_user_installed_lenses(db, user_id)]


@router.get("/users/{user_id}/favorites", response_model=List[MarketLensOut], summary="获取用户收藏 preset")
def list_user_favorite_lenses(user_id: int, db: Session = Depends(get_db)) -> List[MarketLensOut]:
    return [MarketLensOut.model_validate(item) for item in svc.list_user_favorite_lenses(db, user_id)]
