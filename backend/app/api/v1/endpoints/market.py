"""
模板市场 API。

兼容性说明：
- 历史路由仍保留 `/market/lenses/...`
- 新增更符合业务语义的 `/market/templates/...`
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
    MarketAuthorOut,
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
    MarketTagOut,
    TemplateApplyRequest,
    TemplateApplyResponse,
    TemplateCardOut,
    TemplateDetailOut,
    TemplatePublishFromNodeRequest,
    TemplatePublishRequest,
    TemplatePublishResponse,
    TemplateUpdateRequest,
    TemplateVersionOut,
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


def _author_out(user) -> MarketAuthorOut | None:
    if user is None:
        return None
    return MarketAuthorOut(
        user_id=user.user_id,
        username=user.username,
        nickname=user.nickname,
        avatar_url=user.avatar_url,
        is_verified=user.is_verified,
    )


def _version_out(version) -> MarketLensVersionOut:
    return MarketLensVersionOut.model_validate(version)


def _template_version_out(version) -> TemplateVersionOut:
    return TemplateVersionOut(
        version_id=version.version_id,
        template_id=version.lens_id,
        version=version.version,
        musedna=version.blueprint,
        required_inputs=list(version.required_inputs or []),
        parameters=dict(version.parameters or {}),
        ui_schema=dict(version.ui_schema or {}),
        base_workflow=dict(version.base_workflow or {}),
        source_asset_node_id=version.source_asset_node_id,
        source_episode_id=version.source_episode_id,
        published_from=version.published_from,
        changelog=version.changelog,
        is_latest=version.is_latest,
        created_at=version.created_at,
    )


def _market_lens_detail(db: Session, lens) -> MarketLensDetail:
    return MarketLensDetail(
        **MarketLensOut.model_validate(lens).model_dump(),
        versions=[_version_out(item) for item in svc.list_market_lens_versions(db, lens.lens_id)],
        reviews=[LensReviewOut.model_validate(item) for item in svc.list_lens_reviews(db, lens.lens_id)],
        tags=[MarketTagOut.model_validate(item) for item in svc.list_market_lens_tags(db, lens.lens_id)],
        author=_author_out(svc.get_market_lens_author(db, lens.lens_id)),
    )


def _template_card_out(db: Session, lens) -> TemplateCardOut:
    tags = [MarketTagOut.model_validate(item) for item in svc.list_market_lens_tags(db, lens.lens_id)]
    return TemplateCardOut(
        template_id=lens.lens_id,
        template_key=lens.lens_key,
        title=lens.name,
        description=lens.description,
        author_id=lens.author_id,
        author=_author_out(svc.get_market_lens_author(db, lens.lens_id)),
        category=lens.category,
        is_official=lens.is_official,
        status=lens.status,
        cover_image_url=lens.cover_image_url,
        original_image_url=lens.original_image_url,
        original_thumbnail_url=lens.original_thumbnail_url,
        result_image_url=lens.result_image_url,
        result_thumbnail_url=lens.result_thumbnail_url,
        source_project_id=lens.source_project_id,
        source_root_node_id=lens.source_root_node_id,
        result_asset_node_id=lens.result_asset_node_id,
        preview_asset_node_id=lens.preview_asset_node_id,
        apply_count=int(lens.apply_count or 0),
        favorite_count=int(lens.favorite_count or 0),
        install_count=int(lens.install_count or 0),
        rating=lens.rating,
        rating_count=int(lens.rating_count or 0),
        tags=tags,
        tag_names=[item.name for item in tags],
        created_at=lens.created_at,
        updated_at=lens.updated_at,
    )


def _template_detail_out(db: Session, lens) -> TemplateDetailOut:
    versions = [_template_version_out(item) for item in svc.list_market_lens_versions(db, lens.lens_id)]
    current_version = next((item for item in versions if item.is_latest), versions[0] if versions else None)
    return TemplateDetailOut(
        **_template_card_out(db, lens).model_dump(),
        current_version=current_version,
        versions=versions,
        reviews=[LensReviewOut.model_validate(item) for item in svc.list_lens_reviews(db, lens.lens_id)],
    )


def _raise_market_error(exc: Exception, *, duplicate_as_conflict: bool = False) -> None:
    if duplicate_as_conflict and "已存在" in str(exc):
        raise HTTPException(status_code=409, detail=str(exc))
    raise HTTPException(status_code=400, detail=str(exc))


async def _build_apply_payload(
    *,
    db: Session,
    lens_id: int,
    user_id: int | None,
    version_id: int | None,
    initial_inputs: dict[str, str],
    param_overrides: dict[str, dict],
    execute_now: bool,
    async_execution: bool,
    stream_id: str | None,
) -> tuple[dict, object, object, object]:
    lens, version, blueprint, required_inputs = svc.prepare_market_lens_apply(
        db,
        lens_id=lens_id,
        user_id=user_id,
        version_id=version_id,
        initial_inputs=initial_inputs,
        param_overrides=param_overrides,
    )

    payload = {
        "template": _template_card_out(db, lens),
        "lens": MarketLensOut.model_validate(lens),
        "version": _template_version_out(version),
        "legacy_version": _version_out(version),
        "musedna": blueprint,
        "blueprint": blueprint,
        "required_inputs": required_inputs,
        "executed": False,
        "execution_context": {},
        "result_filename": None,
        "result_url": None,
        "execution_error": None,
        "execution_started": False,
        "stream_id": stream_id,
        "step_results": [],
    }

    if not execute_now:
        return payload, lens, version, blueprint

    session_label = f"template_{lens_id}_v{version.version_id}"

    if async_execution and not stream_id:
        raise HTTPException(status_code=400, detail="async_execution=true 时必须提供 stream_id")

    if async_execution and stream_id:
        await router_stream_service.emit(
            stream_id,
            {
                "event": "blueprint_ready",
                "session_id": session_label,
                "stream_id": stream_id,
                "status": "ready",
                "blueprint": blueprint.model_dump(),
            },
        )
        asyncio.create_task(
            run_blueprint_with_stream_events(
                compiler=compiler,
                blueprint=blueprint,
                session_id=session_label,
                stream_id=stream_id,
            )
        )
        payload["execution_started"] = True
        return payload, lens, version, blueprint

    try:
        final_context = await execute_blueprint_with_optional_stream(
            compiler=compiler,
            blueprint=blueprint,
            session_id=session_label,
            stream_id=stream_id,
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
            payload["execution_error"] = "模板 MuseDNA 已执行，但未在执行上下文中发现结果图。"
    except Exception as exc:
        payload["execution_error"] = str(exc)

    return payload, lens, version, blueprint


@router.get("/templates/tags", response_model=List[MarketTagOut], summary="获取模板标签列表")
def list_template_tags(db: Session = Depends(get_db)) -> List[MarketTagOut]:
    return [MarketTagOut.model_validate(item) for item in svc.list_market_tags(db)]


@router.post("/templates/publish", response_model=TemplatePublishResponse, status_code=201, summary="发布或更新模板卡片")
def publish_template(body: TemplatePublishRequest, db: Session = Depends(get_db)) -> TemplatePublishResponse:
    try:
        lens, version = svc.publish_template(
            db,
            template_id=body.template_id,
            template_key=body.template_key,
            author_id=body.author_id,
            title=body.title,
            description=body.description,
            musedna=body.musedna,
            tag_names=body.tag_names,
            category=body.category,
            is_official=body.is_official,
            status=body.status,
            original_image_url=body.original_image_url,
            original_thumbnail_url=body.original_thumbnail_url,
            result_image_url=body.result_image_url,
            result_thumbnail_url=body.result_thumbnail_url,
            source_project_id=body.source_project_id,
            source_root_node_id=body.source_root_node_id,
            result_asset_node_id=body.result_asset_node_id,
            version=body.version,
            changelog=body.changelog,
            parameters=body.parameters,
            ui_schema=body.ui_schema,
            base_workflow=body.base_workflow,
        )
    except Exception as exc:
        _raise_market_error(exc, duplicate_as_conflict=True)
    return TemplatePublishResponse(template=_template_card_out(db, lens), version=_template_version_out(version))


@router.post("/templates/publish-from-node", response_model=TemplatePublishResponse, status_code=201, summary="从资产节点发布模板")
def publish_template_from_node(
    body: TemplatePublishFromNodeRequest,
    db: Session = Depends(get_db),
) -> TemplatePublishResponse:
    try:
        lens, version = svc.publish_template_from_asset_node(
            db,
            template_id=body.template_id,
            template_key=body.template_key,
            author_id=body.author_id,
            title=body.title,
            description=body.description,
            result_asset_node_id=body.result_asset_node_id,
            tag_names=body.tag_names,
            category=body.category,
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
    return TemplatePublishResponse(template=_template_card_out(db, lens), version=_template_version_out(version))


@router.patch("/templates/{template_id}", response_model=TemplateCardOut, summary="更新模板卡片信息")
def update_template(template_id: int, body: TemplateUpdateRequest, db: Session = Depends(get_db)) -> TemplateCardOut:
    try:
        lens = svc.update_market_lens(
            db,
            lens_id=template_id,
            name=body.title,
            description=body.description,
            category=body.category,
            is_official=body.is_official,
            cover_image_url=body.cover_image_url,
            original_image_url=body.original_image_url,
            original_thumbnail_url=body.original_thumbnail_url,
            result_image_url=body.result_image_url,
            result_thumbnail_url=body.result_thumbnail_url,
            status=body.status,
        )
        if lens and body.tag_names is not None:
            svc._replace_market_lens_tags(db, template_id, body.tag_names)  # noqa: SLF001
            db.commit()
            db.refresh(lens)
    except Exception as exc:
        _raise_market_error(exc)
    if not lens:
        raise HTTPException(status_code=404, detail=f"模板不存在：{template_id}")
    return _template_card_out(db, lens)


@router.get("/templates", response_model=List[TemplateCardOut], summary="列出模板卡片")
def list_templates(
    q: str | None = Query(default=None, description="关键词搜索，支持标题/描述/作者昵称/标签"),
    tag_name: str | None = Query(default=None, description="标签筛选"),
    category: str | None = Query(default=None),
    status: str | None = Query(default=None),
    is_official: bool | None = Query(default=None),
    author_id: int | None = Query(default=None, description="只看某个作者发布的模板"),
    favorited_by: int | None = Query(default=None, description="只看某个用户收藏的模板"),
    db: Session = Depends(get_db),
) -> List[TemplateCardOut]:
    lenses = svc.list_market_lenses(
        db,
        q=q,
        tag_name=tag_name,
        category=category,
        status=status,
        is_official=is_official,
        author_id=author_id,
        favorited_by=favorited_by,
    )
    return [_template_card_out(db, item) for item in lenses]


@router.get("/templates/{template_id}", response_model=TemplateDetailOut, summary="获取模板详情")
def get_template_detail(template_id: int, db: Session = Depends(get_db)) -> TemplateDetailOut:
    lens = svc.get_market_lens(db, template_id)
    if not lens:
        raise HTTPException(status_code=404, detail=f"模板不存在：{template_id}")
    return _template_detail_out(db, lens)


@router.post("/templates/{template_id}/apply", response_model=TemplateApplyResponse, summary="应用模板 MuseDNA")
async def apply_template(
    template_id: int,
    body: TemplateApplyRequest,
    db: Session = Depends(get_db),
) -> TemplateApplyResponse:
    try:
        payload, _, version, _ = await _build_apply_payload(
            db=db,
            lens_id=template_id,
            user_id=body.user_id,
            version_id=body.version_id,
            initial_inputs=body.initial_inputs,
            param_overrides=body.param_overrides,
            execute_now=body.execute_now,
            async_execution=body.async_execution,
            stream_id=body.stream_id,
        )
    except Exception as exc:
        _raise_market_error(exc)
    return TemplateApplyResponse(
        template=payload["template"],
        version=payload["version"],
        musedna=payload["musedna"],
        required_inputs=payload["required_inputs"],
        executed=payload["executed"],
        execution_context=payload["execution_context"],
        result_filename=payload["result_filename"],
        result_url=payload["result_url"],
        execution_error=payload["execution_error"],
        execution_started=payload["execution_started"],
        stream_id=payload["stream_id"],
        step_results=payload["step_results"],
    )


@router.post("/templates/{template_id}/favorite", response_model=MessageResponse, summary="收藏模板")
def favorite_template(template_id: int, body: LensFavoriteRequest, db: Session = Depends(get_db)) -> MessageResponse:
    try:
        created = svc.favorite_lens(db, user_id=body.user_id, lens_id=template_id)
    except Exception as exc:
        _raise_market_error(exc)
    return MessageResponse(message="收藏成功" if created else "已收藏，无需重复操作")


@router.delete("/templates/{template_id}/favorite", response_model=MessageResponse, summary="取消收藏模板")
def unfavorite_template(template_id: int, body: LensFavoriteRequest, db: Session = Depends(get_db)) -> MessageResponse:
    removed = svc.unfavorite_lens(db, user_id=body.user_id, lens_id=template_id)
    return MessageResponse(message="取消收藏成功" if removed else "收藏记录不存在")


@router.get("/users/{user_id}/templates/published", response_model=List[TemplateCardOut], summary="获取用户发布的模板")
def list_user_published_templates(user_id: int, db: Session = Depends(get_db)) -> List[TemplateCardOut]:
    return [_template_card_out(db, item) for item in svc.list_user_published_lenses(db, user_id)]


@router.get("/users/{user_id}/templates/favorites", response_model=List[TemplateCardOut], summary="获取用户收藏的模板")
def list_user_favorite_templates(user_id: int, db: Session = Depends(get_db)) -> List[TemplateCardOut]:
    return [_template_card_out(db, item) for item in svc.list_user_favorite_lenses(db, user_id)]


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
            original_image_url=body.original_image_url,
            original_thumbnail_url=body.original_thumbnail_url,
            result_image_url=body.result_image_url,
            result_thumbnail_url=body.result_thumbnail_url,
            source_project_id=body.source_project_id,
            source_root_node_id=body.source_root_node_id,
            result_asset_node_id=body.result_asset_node_id,
            status=body.status,
        )
    except Exception as exc:
        _raise_market_error(exc, duplicate_as_conflict=True)
    return MarketLensOut.model_validate(lens)


@router.post("/lenses/publish-from-node", response_model=MarketLensPublishResponse, status_code=201, summary="从资产节点发布 preset")
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
    return MarketLensPublishResponse(lens=MarketLensOut.model_validate(lens), version=_version_out(version))


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
            original_image_url=body.original_image_url,
            original_thumbnail_url=body.original_thumbnail_url,
            result_image_url=body.result_image_url,
            result_thumbnail_url=body.result_thumbnail_url,
            source_project_id=body.source_project_id,
            source_root_node_id=body.source_root_node_id,
            result_asset_node_id=body.result_asset_node_id,
            status=body.status,
        )
    except Exception as exc:
        _raise_market_error(exc)
    if not lens:
        raise HTTPException(status_code=404, detail=f"模板不存在：{lens_id}")
    return MarketLensOut.model_validate(lens)


@router.get("/lenses", response_model=List[MarketLensOut], summary="列出市场 preset")
def list_market_lenses(
    category: str | None = Query(default=None),
    status: str | None = Query(default=None),
    is_official: bool | None = Query(default=None),
    q: str | None = Query(default=None),
    tag_name: str | None = Query(default=None),
    author_id: int | None = Query(default=None),
    favorited_by: int | None = Query(default=None),
    db: Session = Depends(get_db),
) -> List[MarketLensOut]:
    lenses = svc.list_market_lenses(
        db,
        category=category,
        status=status,
        is_official=is_official,
        q=q,
        tag_name=tag_name,
        author_id=author_id,
        favorited_by=favorited_by,
    )
    return [MarketLensOut.model_validate(item) for item in lenses]


@router.get("/lenses/{lens_id}", response_model=MarketLensDetail, summary="获取 preset 详情")
def get_market_lens_detail(lens_id: int, db: Session = Depends(get_db)) -> MarketLensDetail:
    lens = svc.get_market_lens(db, lens_id)
    if not lens:
        raise HTTPException(status_code=404, detail=f"模板不存在：{lens_id}")
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
    return _version_out(version)


@router.post("/lenses/{lens_id}/apply", response_model=MarketLensApplyResponse, summary="获取或直接执行共享 blueprint")
async def apply_market_lens(
    lens_id: int,
    body: MarketLensApplyRequest,
    db: Session = Depends(get_db),
) -> MarketLensApplyResponse:
    try:
        payload, _, _, _ = await _build_apply_payload(
            db=db,
            lens_id=lens_id,
            user_id=body.user_id,
            version_id=body.version_id,
            initial_inputs=body.initial_inputs,
            param_overrides=body.param_overrides,
            execute_now=body.execute_now,
            async_execution=body.async_execution,
            stream_id=body.stream_id,
        )
    except Exception as exc:
        _raise_market_error(exc)
    return MarketLensApplyResponse(
        lens=payload["lens"],
        version=payload["legacy_version"],
        blueprint=payload["blueprint"],
        required_inputs=payload["required_inputs"],
        executed=payload["executed"],
        execution_context=payload["execution_context"],
        result_filename=payload["result_filename"],
        result_url=payload["result_url"],
        execution_error=payload["execution_error"],
        execution_started=payload["execution_started"],
        stream_id=payload["stream_id"],
        step_results=payload["step_results"],
    )


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
    return MessageResponse(message="卸载成功" if removed else "用户未安装该模板")


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

