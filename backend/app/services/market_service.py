"""
透镜市场服务。

当前市场模块的业务语义：
- 用户把自己的修图 blueprint 分享成一个可复用 preset
- 其他用户可以安装、收藏、评价，也可以直接取出 blueprint 应用
"""

from __future__ import annotations

from decimal import Decimal
from typing import Any, Dict, List, Optional

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.asset_tree_models import AssetNode
from app.models.market_models import LensFavorite, LensReview, MarketLens, MarketLensVersion, UserLens
from app.models.user_models import User
from app.schemas.lens import DAGBlueprint


ALLOWED_MARKET_STATUS = {"active", "deprecated", "removed"}
ALLOWED_PUBLISH_SOURCE = {"manual", "asset_node", "editor_episode"}


def _normalize_text(value: str | None) -> str:
    return (value or "").strip()


def _normalize_status(value: str | None) -> str:
    normalized = _normalize_text(value) or "active"
    if normalized not in ALLOWED_MARKET_STATUS:
        raise ValueError(f"status 不合法，可选值为：{', '.join(sorted(ALLOWED_MARKET_STATUS))}")
    return normalized


def _normalize_publish_source(value: str | None, *, default: str = "manual") -> str:
    normalized = _normalize_text(value) or default
    if normalized not in ALLOWED_PUBLISH_SOURCE:
        raise ValueError(f"published_from 不合法，可选值为：{', '.join(sorted(ALLOWED_PUBLISH_SOURCE))}")
    return normalized


def get_market_lens(db: Session, lens_id: int) -> Optional[MarketLens]:
    return db.query(MarketLens).filter(MarketLens.lens_id == lens_id).first()


def get_market_lens_version(db: Session, version_id: int) -> Optional[MarketLensVersion]:
    return db.query(MarketLensVersion).filter(MarketLensVersion.version_id == version_id).first()


def get_latest_market_lens_version(db: Session, lens_id: int) -> Optional[MarketLensVersion]:
    version = (
        db.query(MarketLensVersion)
        .filter(MarketLensVersion.lens_id == lens_id, MarketLensVersion.is_latest.is_(True))
        .order_by(MarketLensVersion.version_id.desc())
        .first()
    )
    if version is not None:
        return version

    return (
        db.query(MarketLensVersion)
        .filter(MarketLensVersion.lens_id == lens_id)
        .order_by(MarketLensVersion.created_at.desc(), MarketLensVersion.version_id.desc())
        .first()
    )


def get_asset_node(db: Session, node_id: str) -> Optional[AssetNode]:
    return db.query(AssetNode).filter(AssetNode.node_id == node_id).first()


def _require_existing_user(db: Session, user_id: int) -> User:
    user = db.query(User).filter(User.user_id == user_id).first()
    if not user:
        raise ValueError(f"用户不存在：{user_id}")
    return user


def _require_existing_asset_node(db: Session, node_id: str) -> AssetNode:
    node = get_asset_node(db, node_id)
    if not node:
        raise ValueError(f"资产节点不存在：{node_id}")
    return node


def _normalize_blueprint_for_share(blueprint_payload: Dict[str, Any]) -> tuple[Dict[str, Any], List[str]]:
    """
    把作者自己的 blueprint 转成可分享版本。

    为了让 preset 可以被其他用户复用，这里会把 initial_inputs 里的原始文件名清空，
    仅保留输入槽位名称。真正应用时由调用方重新提供这些输入。
    """

    blueprint = DAGBlueprint.model_validate(blueprint_payload)
    required_inputs = list(blueprint.initial_inputs.keys())
    blueprint.initial_inputs = {key: "" for key in required_inputs}
    return blueprint.model_dump(), required_inputs


def _resolve_shared_blueprint(
    db: Session,
    *,
    blueprint: Dict[str, Any] | None,
    source_asset_node_id: str | None,
) -> tuple[Dict[str, Any] | None, List[str], str | None]:
    if source_asset_node_id:
        node = _require_existing_asset_node(db, source_asset_node_id)
        if not node.muse_dna:
            raise ValueError("来源资产节点没有可分享的 muse_dna / blueprint 快照")
        sanitized_blueprint, required_inputs = _normalize_blueprint_for_share(dict(node.muse_dna))
        return sanitized_blueprint, required_inputs, node.node_id

    if blueprint:
        sanitized_blueprint, required_inputs = _normalize_blueprint_for_share(dict(blueprint))
        return sanitized_blueprint, required_inputs, None

    return None, [], None


def create_market_lens(
    db: Session,
    *,
    lens_key: str,
    name: str,
    description: str,
    author_id: int | None,
    category: str | None,
    price: Decimal,
    is_official: bool,
    cover_image_url: str | None,
    preview_asset_node_id: str | None,
    status: str,
) -> MarketLens:
    if db.query(MarketLens).filter(MarketLens.lens_key == lens_key).first():
        raise ValueError(f"透镜键已存在：{lens_key}")
    if author_id is not None:
        _require_existing_user(db, author_id)
    if preview_asset_node_id is not None:
        _require_existing_asset_node(db, preview_asset_node_id)

    lens = MarketLens(
        lens_key= _normalize_text(lens_key),
        name=_normalize_text(name),
        description=_normalize_text(description),
        author_id=author_id,
        category=_normalize_text(category) or None,
        price=price,
        is_official=is_official,
        cover_image_url=_normalize_text(cover_image_url) or None,
        preview_asset_node_id=preview_asset_node_id,
        status=_normalize_status(status),
    )
    db.add(lens)
    db.commit()
    db.refresh(lens)
    return lens


def update_market_lens(
    db: Session,
    *,
    lens_id: int,
    name: str | None = None,
    description: str | None = None,
    category: str | None = None,
    price: Decimal | None = None,
    is_official: bool | None = None,
    cover_image_url: str | None = None,
    preview_asset_node_id: str | None = None,
    status: str | None = None,
) -> Optional[MarketLens]:
    lens = get_market_lens(db, lens_id)
    if not lens:
        return None

    if preview_asset_node_id is not None:
        _require_existing_asset_node(db, preview_asset_node_id)

    if name is not None:
        lens.name = _normalize_text(name)
    if description is not None:
        lens.description = _normalize_text(description)
    if category is not None:
        lens.category = _normalize_text(category) or None
    if price is not None:
        lens.price = price
    if is_official is not None:
        lens.is_official = is_official
    if cover_image_url is not None:
        lens.cover_image_url = _normalize_text(cover_image_url) or None
    if preview_asset_node_id is not None:
        lens.preview_asset_node_id = preview_asset_node_id
    if status is not None:
        lens.status = _normalize_status(status)

    db.commit()
    db.refresh(lens)
    return lens


def list_market_lenses(
    db: Session,
    *,
    category: str | None = None,
    status: str | None = None,
    is_official: bool | None = None,
) -> List[MarketLens]:
    query = db.query(MarketLens)
    if category is not None:
        query = query.filter(MarketLens.category == category)
    if status is not None:
        query = query.filter(MarketLens.status == status)
    if is_official is not None:
        query = query.filter(MarketLens.is_official.is_(is_official))
    return (
        query.order_by(
            MarketLens.rating.desc(),
            MarketLens.apply_count.desc(),
            MarketLens.install_count.desc(),
            MarketLens.lens_id.asc(),
        )
        .all()
    )


def create_market_lens_version(
    db: Session,
    *,
    lens_id: int,
    version: str,
    base_workflow: Dict[str, Any],
    parameters: Dict[str, Any],
    ui_schema: Dict[str, Any],
    blueprint: Dict[str, Any] | None,
    source_asset_node_id: str | None,
    source_episode_id: int | None,
    published_from: str | None,
    changelog: str,
    is_latest: bool,
) -> MarketLensVersion:
    lens = get_market_lens(db, lens_id)
    if not lens:
        raise ValueError(f"透镜不存在：{lens_id}")
    if (
        db.query(MarketLensVersion)
        .filter(MarketLensVersion.lens_id == lens_id, MarketLensVersion.version == version)
        .first()
    ):
        raise ValueError(f"透镜版本已存在：{version}")

    shared_blueprint, required_inputs, resolved_source_node_id = _resolve_shared_blueprint(
        db,
        blueprint=blueprint,
        source_asset_node_id=source_asset_node_id,
    )
    publish_source = _normalize_publish_source(
        published_from,
        default="asset_node" if resolved_source_node_id else "manual",
    )

    if is_latest:
        (
            db.query(MarketLensVersion)
            .filter(MarketLensVersion.lens_id == lens_id, MarketLensVersion.is_latest.is_(True))
            .update({"is_latest": False})
        )

    version_record = MarketLensVersion(
        lens_id=lens_id,
        version=_normalize_text(version),
        base_workflow=dict(base_workflow or {}),
        parameters=dict(parameters or {}),
        ui_schema=dict(ui_schema or {}),
        blueprint=shared_blueprint,
        required_inputs=list(required_inputs or []),
        source_asset_node_id=resolved_source_node_id,
        source_episode_id=source_episode_id,
        published_from=publish_source,
        changelog=_normalize_text(changelog),
        is_latest=is_latest,
    )
    db.add(version_record)

    if resolved_source_node_id:
        source_node = _require_existing_asset_node(db, resolved_source_node_id)
        if not lens.cover_image_url:
            lens.cover_image_url = source_node.thumbnail_url or source_node.image_url
        if not lens.preview_asset_node_id:
            lens.preview_asset_node_id = source_node.node_id

    db.commit()
    db.refresh(version_record)
    db.refresh(lens)
    return version_record


def publish_market_lens_from_asset_node(
    db: Session,
    *,
    lens_key: str,
    name: str,
    description: str,
    author_id: int,
    source_asset_node_id: str,
    source_episode_id: int | None,
    category: str | None,
    price: Decimal,
    is_official: bool,
    status: str,
    version: str,
    changelog: str,
    parameters: Dict[str, Any],
    ui_schema: Dict[str, Any],
    base_workflow: Dict[str, Any],
) -> tuple[MarketLens, MarketLensVersion]:
    if db.query(MarketLens).filter(MarketLens.lens_key == lens_key).first():
        raise ValueError(f"透镜键已存在：{lens_key}")

    _require_existing_user(db, author_id)
    source_node = _require_existing_asset_node(db, source_asset_node_id)
    if not source_node.muse_dna:
        raise ValueError("来源资产节点没有可分享的 muse_dna / blueprint 快照")

    shared_blueprint, required_inputs = _normalize_blueprint_for_share(dict(source_node.muse_dna))

    lens = MarketLens(
        lens_key=_normalize_text(lens_key),
        name=_normalize_text(name),
        description=_normalize_text(description),
        author_id=author_id,
        category=_normalize_text(category) or None,
        price=price,
        is_official=is_official,
        cover_image_url=source_node.thumbnail_url or source_node.image_url,
        preview_asset_node_id=source_node.node_id,
        status=_normalize_status(status),
    )
    db.add(lens)
    db.flush()

    version_record = MarketLensVersion(
        lens_id=lens.lens_id,
        version=_normalize_text(version),
        base_workflow=dict(base_workflow or {}),
        parameters=dict(parameters or {}),
        ui_schema=dict(ui_schema or {}),
        blueprint=shared_blueprint,
        required_inputs=list(required_inputs or []),
        source_asset_node_id=source_node.node_id,
        source_episode_id=source_episode_id,
        published_from="asset_node",
        changelog=_normalize_text(changelog),
        is_latest=True,
    )
    db.add(version_record)
    db.commit()
    db.refresh(lens)
    db.refresh(version_record)
    return lens, version_record


def list_market_lens_versions(db: Session, lens_id: int) -> List[MarketLensVersion]:
    return (
        db.query(MarketLensVersion)
        .filter(MarketLensVersion.lens_id == lens_id)
        .order_by(MarketLensVersion.created_at.desc(), MarketLensVersion.version_id.desc())
        .all()
    )


def list_lens_reviews(db: Session, lens_id: int) -> List[LensReview]:
    return (
        db.query(LensReview)
        .filter(LensReview.lens_id == lens_id)
        .order_by(LensReview.created_at.desc(), LensReview.review_id.desc())
        .all()
    )


def prepare_market_lens_apply(
    db: Session,
    *,
    lens_id: int,
    user_id: int | None,
    version_id: int | None,
    initial_inputs: Dict[str, str],
    param_overrides: Dict[str, Dict[str, Any]],
) -> tuple[MarketLens, MarketLensVersion, DAGBlueprint, List[str]]:
    if user_id is not None:
        _require_existing_user(db, user_id)

    lens = get_market_lens(db, lens_id)
    if not lens:
        raise ValueError(f"透镜不存在：{lens_id}")

    if version_id is not None:
        version = get_market_lens_version(db, version_id)
        if not version or version.lens_id != lens_id:
            raise ValueError("指定版本不存在，或不属于该透镜")
    else:
        version = get_latest_market_lens_version(db, lens_id)

    if version is None:
        raise ValueError("该 preset 还没有可用版本")
    if not version.blueprint:
        raise ValueError("该 preset 版本还没有可直接应用的 blueprint")

    blueprint = DAGBlueprint.model_validate(version.blueprint)
    required_inputs = list(version.required_inputs or list(blueprint.initial_inputs.keys()))
    missing_inputs = [key for key in required_inputs if not _normalize_text(initial_inputs.get(key))]
    if missing_inputs:
        raise ValueError(f"缺少必须的输入资源：{', '.join(missing_inputs)}")

    blueprint.initial_inputs = {
        key: _normalize_text(value)
        for key, value in dict(initial_inputs or {}).items()
        if _normalize_text(value)
    }

    known_step_ids = {step.step_id for step in blueprint.steps}
    unknown_step_ids = sorted(set(param_overrides.keys()) - known_step_ids)
    if unknown_step_ids:
        raise ValueError(f"参数覆盖里包含不存在的 step_id：{', '.join(unknown_step_ids)}")

    for step in blueprint.steps:
        if step.step_id in param_overrides:
            step.params.update(dict(param_overrides[step.step_id] or {}))

    lens.apply_count = int(lens.apply_count or 0) + 1
    db.commit()
    db.refresh(lens)
    return lens, version, blueprint, required_inputs


def install_lens(
    db: Session,
    *,
    user_id: int,
    lens_id: int,
    version_id: int | None = None,
) -> bool:
    _require_existing_user(db, user_id)
    lens = get_market_lens(db, lens_id)
    if not lens:
        raise ValueError(f"透镜不存在：{lens_id}")

    if version_id is None:
        version = get_latest_market_lens_version(db, lens_id)
        if version is None:
            raise ValueError("该透镜还没有可安装版本")
        version_id = version.version_id
    else:
        version = get_market_lens_version(db, version_id)
        if not version or version.lens_id != lens_id:
            raise ValueError("指定版本不存在，或不属于该透镜")

    existing = db.query(UserLens).filter(UserLens.user_id == user_id, UserLens.lens_id == lens_id).first()
    if existing:
        existing.version_id = version_id
        db.commit()
        return False

    db.add(UserLens(user_id=user_id, lens_id=lens_id, version_id=version_id))
    lens.install_count = int(lens.install_count or 0) + 1
    db.commit()
    return True


def uninstall_lens(db: Session, *, user_id: int, lens_id: int) -> bool:
    relation = db.query(UserLens).filter(UserLens.user_id == user_id, UserLens.lens_id == lens_id).first()
    if not relation:
        return False
    lens = get_market_lens(db, lens_id)
    db.delete(relation)
    if lens:
        lens.install_count = max(0, int(lens.install_count or 0) - 1)
    db.commit()
    return True


def favorite_lens(db: Session, *, user_id: int, lens_id: int) -> bool:
    _require_existing_user(db, user_id)
    if not get_market_lens(db, lens_id):
        raise ValueError(f"透镜不存在：{lens_id}")
    existing = db.query(LensFavorite).filter(LensFavorite.user_id == user_id, LensFavorite.lens_id == lens_id).first()
    if existing:
        return False
    db.add(LensFavorite(user_id=user_id, lens_id=lens_id))
    db.commit()
    return True


def unfavorite_lens(db: Session, *, user_id: int, lens_id: int) -> bool:
    relation = db.query(LensFavorite).filter(LensFavorite.user_id == user_id, LensFavorite.lens_id == lens_id).first()
    if not relation:
        return False
    db.delete(relation)
    db.commit()
    return True


def create_or_update_review(
    db: Session,
    *,
    user_id: int,
    lens_id: int,
    rating: int,
    content: str,
) -> LensReview:
    _require_existing_user(db, user_id)
    lens = get_market_lens(db, lens_id)
    if not lens:
        raise ValueError(f"透镜不存在：{lens_id}")

    review = (
        db.query(LensReview)
        .filter(LensReview.user_id == user_id, LensReview.lens_id == lens_id)
        .first()
    )
    if review:
        review.rating = rating
        review.content = _normalize_text(content)
    else:
        review = LensReview(user_id=user_id, lens_id=lens_id, rating=rating, content=_normalize_text(content))
        db.add(review)

    db.flush()
    _refresh_lens_rating(db, lens_id)
    db.commit()
    db.refresh(review)
    return review


def _refresh_lens_rating(db: Session, lens_id: int) -> None:
    lens = get_market_lens(db, lens_id)
    if not lens:
        return
    avg_rating, rating_count = (
        db.query(func.avg(LensReview.rating), func.count(LensReview.review_id))
        .filter(LensReview.lens_id == lens_id)
        .one()
    )
    lens.rating = Decimal(str(round(float(avg_rating or 0), 2))) if rating_count else Decimal("0.00")
    lens.rating_count = int(rating_count or 0)


def list_user_installed_lenses(db: Session, user_id: int) -> List[MarketLens]:
    return (
        db.query(MarketLens)
        .join(UserLens, UserLens.lens_id == MarketLens.lens_id)
        .filter(UserLens.user_id == user_id)
        .order_by(MarketLens.lens_id.asc())
        .all()
    )


def list_user_favorite_lenses(db: Session, user_id: int) -> List[MarketLens]:
    return (
        db.query(MarketLens)
        .join(LensFavorite, LensFavorite.lens_id == MarketLens.lens_id)
        .filter(LensFavorite.user_id == user_id)
        .order_by(MarketLens.lens_id.asc())
        .all()
    )
