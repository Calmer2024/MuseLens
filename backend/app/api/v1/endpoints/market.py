"""
透镜市场 API。
"""

from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.schemas.asset_tree import MessageResponse
from app.schemas.market import (
    LensFavoriteRequest,
    LensReviewCreateRequest,
    LensReviewOut,
    LensInstallRequest,
    MarketLensCreateRequest,
    MarketLensDetail,
    MarketLensOut,
    MarketLensUpdateRequest,
    MarketLensVersionCreateRequest,
    MarketLensVersionOut,
)
from app.services import market_service as svc

router = APIRouter()


def _market_lens_detail(db: Session, lens) -> MarketLensDetail:
    return MarketLensDetail(
        **MarketLensOut.model_validate(lens).model_dump(),
        versions=[MarketLensVersionOut.model_validate(item) for item in svc.list_market_lens_versions(db, lens.lens_id)],
        reviews=[LensReviewOut.model_validate(item) for item in svc.list_lens_reviews(db, lens.lens_id)],
    )


@router.post("/lenses", response_model=MarketLensOut, status_code=201, summary="创建市场透镜")
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
            status=body.status,
        )
    except ValueError as exc:
        raise HTTPException(status_code=409, detail=str(exc))
    return MarketLensOut.model_validate(lens)


@router.patch("/lenses/{lens_id}", response_model=MarketLensOut, summary="更新市场透镜")
def update_market_lens(lens_id: int, body: MarketLensUpdateRequest, db: Session = Depends(get_db)) -> MarketLensOut:
    lens = svc.update_market_lens(
        db,
        lens_id=lens_id,
        name=body.name,
        description=body.description,
        category=body.category,
        price=body.price,
        is_official=body.is_official,
        status=body.status,
    )
    if not lens:
        raise HTTPException(status_code=404, detail=f"透镜不存在：{lens_id}")
    return MarketLensOut.model_validate(lens)


@router.get("/lenses", response_model=List[MarketLensOut], summary="列出市场透镜")
def list_market_lenses(
    category: str | None = Query(default=None),
    status: str | None = Query(default=None),
    is_official: bool | None = Query(default=None),
    db: Session = Depends(get_db),
) -> List[MarketLensOut]:
    lenses = svc.list_market_lenses(db, category=category, status=status, is_official=is_official)
    return [MarketLensOut.model_validate(item) for item in lenses]


@router.get("/lenses/{lens_id}", response_model=MarketLensDetail, summary="获取透镜详情")
def get_market_lens_detail(lens_id: int, db: Session = Depends(get_db)) -> MarketLensDetail:
    lens = svc.get_market_lens(db, lens_id)
    if not lens:
        raise HTTPException(status_code=404, detail=f"透镜不存在：{lens_id}")
    return _market_lens_detail(db, lens)


@router.post("/lenses/{lens_id}/versions", response_model=MarketLensVersionOut, status_code=201, summary="创建透镜版本")
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
            changelog=body.changelog,
            is_latest=body.is_latest,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    return MarketLensVersionOut.model_validate(version)


@router.post("/lenses/{lens_id}/install", response_model=MessageResponse, summary="安装透镜")
def install_lens(lens_id: int, body: LensInstallRequest, db: Session = Depends(get_db)) -> MessageResponse:
    try:
        created = svc.install_lens(db, user_id=body.user_id, lens_id=lens_id, version_id=body.version_id)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    return MessageResponse(message="安装成功" if created else "已安装，已切换到指定版本")


@router.delete("/lenses/{lens_id}/install", response_model=MessageResponse, summary="卸载透镜")
def uninstall_lens(lens_id: int, body: LensInstallRequest, db: Session = Depends(get_db)) -> MessageResponse:
    removed = svc.uninstall_lens(db, user_id=body.user_id, lens_id=lens_id)
    return MessageResponse(message="卸载成功" if removed else "用户未安装该透镜")


@router.post("/lenses/{lens_id}/favorite", response_model=MessageResponse, summary="收藏透镜")
def favorite_lens(lens_id: int, body: LensFavoriteRequest, db: Session = Depends(get_db)) -> MessageResponse:
    try:
        created = svc.favorite_lens(db, user_id=body.user_id, lens_id=lens_id)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    return MessageResponse(message="收藏成功" if created else "已收藏，无需重复操作")


@router.delete("/lenses/{lens_id}/favorite", response_model=MessageResponse, summary="取消收藏透镜")
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
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    return LensReviewOut.model_validate(review)


@router.get("/users/{user_id}/installed", response_model=List[MarketLensOut], summary="获取用户已安装透镜")
def list_user_installed_lenses(user_id: int, db: Session = Depends(get_db)) -> List[MarketLensOut]:
    return [MarketLensOut.model_validate(item) for item in svc.list_user_installed_lenses(db, user_id)]


@router.get("/users/{user_id}/favorites", response_model=List[MarketLensOut], summary="获取用户收藏透镜")
def list_user_favorite_lenses(user_id: int, db: Session = Depends(get_db)) -> List[MarketLensOut]:
    return [MarketLensOut.model_validate(item) for item in svc.list_user_favorite_lenses(db, user_id)]
