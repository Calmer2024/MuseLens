"""
模板市场服务。

说明：
- 历史命名仍保留为 market_service，避免影响既有导入路径
- 当前业务语义已经切换为“模板市场”
- 模板卡片本体保存标题、原图、结果图、作者、标签等信息
- 模板版本保存可直接复用的 MuseDNA / DAGBlueprint 快照
"""

from __future__ import annotations

import re
from decimal import Decimal
from typing import Any, Dict, List, Optional

from sqlalchemy import func, or_
from sqlalchemy.orm import Session

from app.models.asset_tree_models import AssetNode
from app.models.market_models import (
    LensFavorite,
    LensReview,
    MarketLens,
    MarketLensTag,
    MarketLensVersion,
    MarketTag,
    UserLens,
)
from app.models.user_models import User
from app.schemas.lens import DAGBlueprint


ALLOWED_MARKET_STATUS = {"active", "deprecated", "removed"}
ALLOWED_PUBLISH_SOURCE = {"manual", "asset_node", "editor_episode", "router_result"}


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


def _normalize_tag_names(tag_names: List[str] | None) -> List[str]:
    result: List[str] = []
    seen: set[str] = set()
    for raw in tag_names or []:
        name = _normalize_text(raw).lstrip("#")
        if not name or name in seen:
            continue
        seen.add(name)
        result.append(name)
    return result


def _slugify_key(value: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "_", _normalize_text(value).lower())
    slug = slug.strip("_")
    return slug or "template"


def _generate_template_key(db: Session, *, author_id: int, title: str) -> str:
    base = f"template_{author_id}_{_slugify_key(title)}"
    candidate = base
    suffix = 2
    while db.query(MarketLens).filter(MarketLens.lens_key == candidate).first():
        candidate = f"{base}_{suffix}"
        suffix += 1
    return candidate


def _next_version_label(db: Session, lens_id: int, requested_version: str | None) -> str:
    if _normalize_text(requested_version):
        return _normalize_text(requested_version)

    latest = get_latest_market_lens_version(db, lens_id)
    if latest is None:
        return "1.0.0"

    latest_value = _normalize_text(latest.version)
    semver_match = re.fullmatch(r"(\d+)\.(\d+)\.(\d+)", latest_value)
    if semver_match:
        major, minor, patch = semver_match.groups()
        return f"{major}.{minor}.{int(patch) + 1}"

    simple_match = re.fullmatch(r"v(\d+)", latest_value, re.IGNORECASE)
    if simple_match:
        return f"v{int(simple_match.group(1)) + 1}"

    count = db.query(MarketLensVersion).filter(MarketLensVersion.lens_id == lens_id).count()
    return f"v{count + 1}"


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


def get_market_tag_by_name(db: Session, name: str) -> Optional[MarketTag]:
    return db.query(MarketTag).filter(MarketTag.name == name).first()


def get_market_lens_author(db: Session, lens_id: int) -> Optional[User]:
    lens = get_market_lens(db, lens_id)
    if not lens or lens.author_id is None:
        return None
    return db.query(User).filter(User.user_id == lens.author_id).first()


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
    把作者自己的 MuseDNA 转成可分享版本。

    为了让模板可以被其他用户复用，这里会把 initial_inputs 里的原始文件名清空，
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
            raise ValueError("来源资产节点没有可分享的 MuseDNA / blueprint 快照")
        sanitized_blueprint, required_inputs = _normalize_blueprint_for_share(dict(node.muse_dna))
        return sanitized_blueprint, required_inputs, node.node_id

    if blueprint:
        sanitized_blueprint, required_inputs = _normalize_blueprint_for_share(dict(blueprint))
        return sanitized_blueprint, required_inputs, None

    return None, [], None


def _resolve_root_node(db: Session, node: AssetNode) -> AssetNode:
    root_id = (node.path or [node.node_id])[0]
    root = get_asset_node(db, root_id) if root_id else None
    return root or node


def _derive_template_media_from_result_node(db: Session, result_node: AssetNode) -> Dict[str, Any]:
    root_node = _resolve_root_node(db, result_node)
    return {
        "cover_image_url": result_node.thumbnail_url or result_node.image_url,
        "preview_asset_node_id": result_node.node_id,
        "original_image_url": root_node.image_url,
        "original_thumbnail_url": root_node.thumbnail_url,
        "result_image_url": result_node.image_url,
        "result_thumbnail_url": result_node.thumbnail_url,
        "source_project_id": result_node.project_id,
        "source_root_node_id": root_node.node_id,
        "result_asset_node_id": result_node.node_id,
    }


def _apply_lens_media_fields(
    lens: MarketLens,
    *,
    cover_image_url: str | None = None,
    preview_asset_node_id: str | None = None,
    original_image_url: str | None = None,
    original_thumbnail_url: str | None = None,
    result_image_url: str | None = None,
    result_thumbnail_url: str | None = None,
    source_project_id: str | None = None,
    source_root_node_id: str | None = None,
    result_asset_node_id: str | None = None,
) -> None:
    lens.cover_image_url = _normalize_text(cover_image_url) or None
    lens.preview_asset_node_id = preview_asset_node_id
    lens.original_image_url = _normalize_text(original_image_url) or None
    lens.original_thumbnail_url = _normalize_text(original_thumbnail_url) or None
    lens.result_image_url = _normalize_text(result_image_url) or None
    lens.result_thumbnail_url = _normalize_text(result_thumbnail_url) or None
    lens.source_project_id = source_project_id
    lens.source_root_node_id = source_root_node_id
    lens.result_asset_node_id = result_asset_node_id


def _get_or_create_market_tags(db: Session, tag_names: List[str]) -> List[MarketTag]:
    tags: List[MarketTag] = []
    for name in _normalize_tag_names(tag_names):
        tag = get_market_tag_by_name(db, name)
        if not tag:
            tag = MarketTag(name=name, description="", template_count=0)
            db.add(tag)
            db.flush()
        tags.append(tag)
    return tags


def list_market_lens_tags(db: Session, lens_id: int) -> List[MarketTag]:
    return (
        db.query(MarketTag)
        .join(MarketLensTag, MarketLensTag.tag_id == MarketTag.tag_id)
        .filter(MarketLensTag.lens_id == lens_id)
        .order_by(MarketTag.template_count.desc(), MarketTag.name.asc())
        .all()
    )


def list_market_tags(db: Session) -> List[MarketTag]:
    return db.query(MarketTag).order_by(MarketTag.template_count.desc(), MarketTag.name.asc()).all()


def _replace_market_lens_tags(db: Session, lens_id: int, tag_names: List[str]) -> None:
    normalized_names = _normalize_tag_names(tag_names)
    current_tags = list_market_lens_tags(db, lens_id)
    current_by_id = {tag.tag_id: tag for tag in current_tags}
    desired_tags = _get_or_create_market_tags(db, normalized_names)
    desired_by_id = {tag.tag_id: tag for tag in desired_tags}

    for tag_id, tag in current_by_id.items():
        if tag_id in desired_by_id:
            continue
        relation = (
            db.query(MarketLensTag)
            .filter(MarketLensTag.lens_id == lens_id, MarketLensTag.tag_id == tag_id)
            .first()
        )
        if relation:
            db.delete(relation)
            tag.template_count = max(0, int(tag.template_count or 0) - 1)

    for tag_id, tag in desired_by_id.items():
        if tag_id in current_by_id:
            continue
        db.add(MarketLensTag(lens_id=lens_id, tag_id=tag_id))
        tag.template_count = int(tag.template_count or 0) + 1


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
    original_image_url: str | None = None,
    original_thumbnail_url: str | None = None,
    result_image_url: str | None = None,
    result_thumbnail_url: str | None = None,
    source_project_id: str | None = None,
    source_root_node_id: str | None = None,
    result_asset_node_id: str | None = None,
    status: str = "active",
) -> MarketLens:
    normalized_key = _normalize_text(lens_key)
    if db.query(MarketLens).filter(MarketLens.lens_key == normalized_key).first():
        raise ValueError(f"模板键已存在：{normalized_key}")
    if author_id is not None:
        _require_existing_user(db, author_id)
    if preview_asset_node_id is not None:
        _require_existing_asset_node(db, preview_asset_node_id)
    if source_root_node_id is not None:
        _require_existing_asset_node(db, source_root_node_id)
    if result_asset_node_id is not None:
        _require_existing_asset_node(db, result_asset_node_id)

    lens = MarketLens(
        lens_key=normalized_key,
        name=_normalize_text(name),
        description=_normalize_text(description),
        author_id=author_id,
        category=_normalize_text(category) or None,
        price=price,
        is_official=is_official,
        status=_normalize_status(status),
    )
    _apply_lens_media_fields(
        lens,
        cover_image_url=cover_image_url,
        preview_asset_node_id=preview_asset_node_id,
        original_image_url=original_image_url,
        original_thumbnail_url=original_thumbnail_url,
        result_image_url=result_image_url,
        result_thumbnail_url=result_thumbnail_url,
        source_project_id=source_project_id,
        source_root_node_id=source_root_node_id,
        result_asset_node_id=result_asset_node_id,
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
    original_image_url: str | None = None,
    original_thumbnail_url: str | None = None,
    result_image_url: str | None = None,
    result_thumbnail_url: str | None = None,
    source_project_id: str | None = None,
    source_root_node_id: str | None = None,
    result_asset_node_id: str | None = None,
    status: str | None = None,
) -> Optional[MarketLens]:
    lens = get_market_lens(db, lens_id)
    if not lens:
        return None

    if preview_asset_node_id is not None:
        _require_existing_asset_node(db, preview_asset_node_id)
    if source_root_node_id is not None:
        _require_existing_asset_node(db, source_root_node_id)
    if result_asset_node_id is not None:
        _require_existing_asset_node(db, result_asset_node_id)

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
    if original_image_url is not None:
        lens.original_image_url = _normalize_text(original_image_url) or None
    if original_thumbnail_url is not None:
        lens.original_thumbnail_url = _normalize_text(original_thumbnail_url) or None
    if result_image_url is not None:
        lens.result_image_url = _normalize_text(result_image_url) or None
    if result_thumbnail_url is not None:
        lens.result_thumbnail_url = _normalize_text(result_thumbnail_url) or None
    if source_project_id is not None:
        lens.source_project_id = source_project_id
    if source_root_node_id is not None:
        lens.source_root_node_id = source_root_node_id
    if result_asset_node_id is not None:
        lens.result_asset_node_id = result_asset_node_id
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
    q: str | None = None,
    tag_name: str | None = None,
    author_id: int | None = None,
    favorited_by: int | None = None,
) -> List[MarketLens]:
    query = db.query(MarketLens)

    if author_id is not None:
        query = query.filter(MarketLens.author_id == author_id)
    if category is not None:
        query = query.filter(MarketLens.category == _normalize_text(category))
    if status is not None:
        query = query.filter(MarketLens.status == _normalize_text(status))
    if is_official is not None:
        query = query.filter(MarketLens.is_official.is_(is_official))
    if favorited_by is not None:
        query = query.join(LensFavorite, LensFavorite.lens_id == MarketLens.lens_id).filter(
            LensFavorite.user_id == favorited_by
        )
    if tag_name:
        normalized_tag = _normalize_text(tag_name).lstrip("#")
        query = (
            query.join(MarketLensTag, MarketLensTag.lens_id == MarketLens.lens_id)
            .join(MarketTag, MarketTag.tag_id == MarketLensTag.tag_id)
            .filter(MarketTag.name == normalized_tag)
        )
    if q:
        keyword = f"%{_normalize_text(q).lower()}%"
        query = (
            query.outerjoin(User, User.user_id == MarketLens.author_id)
            .outerjoin(MarketLensTag, MarketLensTag.lens_id == MarketLens.lens_id)
            .outerjoin(MarketTag, MarketTag.tag_id == MarketLensTag.tag_id)
            .filter(
                or_(
                    func.lower(MarketLens.name).like(keyword),
                    func.lower(MarketLens.description).like(keyword),
                    func.lower(func.coalesce(User.nickname, "")).like(keyword),
                    func.lower(func.coalesce(MarketTag.name, "")).like(keyword),
                )
            )
        )

    return (
        query.distinct()
        .order_by(
            MarketLens.favorite_count.desc(),
            MarketLens.apply_count.desc(),
            MarketLens.install_count.desc(),
            MarketLens.rating.desc(),
            MarketLens.lens_id.asc(),
        )
        .all()
    )


def _create_version_record(
    db: Session,
    *,
    lens_id: int,
    version: str | None,
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
        raise ValueError(f"模板不存在：{lens_id}")

    resolved_version = _next_version_label(db, lens_id, version)
    if (
        db.query(MarketLensVersion)
        .filter(MarketLensVersion.lens_id == lens_id, MarketLensVersion.version == resolved_version)
        .first()
    ):
        raise ValueError(f"模板版本已存在：{resolved_version}")

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
        version=resolved_version,
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
        media = _derive_template_media_from_result_node(db, source_node)
        if not lens.cover_image_url:
            lens.cover_image_url = media["cover_image_url"]
        if not lens.preview_asset_node_id:
            lens.preview_asset_node_id = media["preview_asset_node_id"]
        if not lens.original_image_url:
            lens.original_image_url = media["original_image_url"]
        if not lens.original_thumbnail_url:
            lens.original_thumbnail_url = media["original_thumbnail_url"]
        if not lens.result_image_url:
            lens.result_image_url = media["result_image_url"]
        if not lens.result_thumbnail_url:
            lens.result_thumbnail_url = media["result_thumbnail_url"]
        if not lens.source_project_id:
            lens.source_project_id = media["source_project_id"]
        if not lens.source_root_node_id:
            lens.source_root_node_id = media["source_root_node_id"]
        if not lens.result_asset_node_id:
            lens.result_asset_node_id = media["result_asset_node_id"]

    return version_record


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
    version_record = _create_version_record(
        db,
        lens_id=lens_id,
        version=version,
        base_workflow=base_workflow,
        parameters=parameters,
        ui_schema=ui_schema,
        blueprint=blueprint,
        source_asset_node_id=source_asset_node_id,
        source_episode_id=source_episode_id,
        published_from=published_from,
        changelog=changelog,
        is_latest=is_latest,
    )
    db.commit()
    db.refresh(version_record)
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
    _require_existing_user(db, author_id)
    source_node = _require_existing_asset_node(db, source_asset_node_id)
    media = _derive_template_media_from_result_node(db, source_node)

    normalized_key = _normalize_text(lens_key)
    if db.query(MarketLens).filter(MarketLens.lens_key == normalized_key).first():
        raise ValueError(f"模板键已存在：{normalized_key}")

    lens = MarketLens(
        lens_key=normalized_key,
        name=_normalize_text(name),
        description=_normalize_text(description),
        author_id=author_id,
        category=_normalize_text(category) or None,
        price=price,
        is_official=is_official,
        status=_normalize_status(status),
    )
    _apply_lens_media_fields(lens, **media)
    db.add(lens)
    db.flush()

    version_record = _create_version_record(
        db,
        lens_id=lens.lens_id,
        version=version,
        base_workflow=base_workflow,
        parameters=parameters,
        ui_schema=ui_schema,
        blueprint=None,
        source_asset_node_id=source_asset_node_id,
        source_episode_id=source_episode_id,
        published_from="asset_node",
        changelog=changelog,
        is_latest=True,
    )
    db.commit()
    db.refresh(lens)
    db.refresh(version_record)
    return lens, version_record


def publish_template(
    db: Session,
    *,
    template_id: int | None,
    template_key: str | None,
    author_id: int,
    title: str,
    description: str,
    musedna: Dict[str, Any],
    tag_names: List[str],
    category: str | None,
    is_official: bool,
    status: str,
    original_image_url: str,
    original_thumbnail_url: str | None,
    result_image_url: str,
    result_thumbnail_url: str | None,
    source_project_id: str | None,
    source_root_node_id: str | None,
    result_asset_node_id: str | None,
    published_from: str = "router_result",
    version: str | None,
    changelog: str,
    parameters: Dict[str, Any],
    ui_schema: Dict[str, Any],
    base_workflow: Dict[str, Any],
) -> tuple[MarketLens, MarketLensVersion]:
    _require_existing_user(db, author_id)
    if source_root_node_id is not None:
        _require_existing_asset_node(db, source_root_node_id)
    if result_asset_node_id is not None:
        _require_existing_asset_node(db, result_asset_node_id)

    if template_id is None:
        resolved_key = _normalize_text(template_key) or _generate_template_key(db, author_id=author_id, title=title)
        if db.query(MarketLens).filter(MarketLens.lens_key == resolved_key).first():
            raise ValueError(f"模板键已存在：{resolved_key}")
        lens = MarketLens(
            lens_key=resolved_key,
            name=_normalize_text(title),
            description=_normalize_text(description),
            author_id=author_id,
            category=_normalize_text(category) or None,
            price=Decimal("0.00"),
            is_official=is_official,
            status=_normalize_status(status),
        )
        db.add(lens)
        db.flush()
    else:
        lens = get_market_lens(db, template_id)
        if not lens:
            raise ValueError(f"模板不存在：{template_id}")
        if lens.author_id not in (None, author_id):
            raise ValueError("只有模板作者才能更新该模板")
        lens.name = _normalize_text(title)
        lens.description = _normalize_text(description)
        lens.author_id = author_id
        lens.category = _normalize_text(category) or None
        lens.is_official = is_official
        lens.status = _normalize_status(status)

    _apply_lens_media_fields(
        lens,
        cover_image_url=result_thumbnail_url or result_image_url,
        preview_asset_node_id=result_asset_node_id,
        original_image_url=original_image_url,
        original_thumbnail_url=original_thumbnail_url,
        result_image_url=result_image_url,
        result_thumbnail_url=result_thumbnail_url,
        source_project_id=source_project_id,
        source_root_node_id=source_root_node_id,
        result_asset_node_id=result_asset_node_id,
    )

    version_record = _create_version_record(
        db,
        lens_id=lens.lens_id,
        version=version,
        base_workflow=base_workflow,
        parameters=parameters,
        ui_schema=ui_schema,
        blueprint=musedna,
        source_asset_node_id=result_asset_node_id,
        source_episode_id=None,
        published_from=published_from,
        changelog=changelog,
        is_latest=True,
    )

    _replace_market_lens_tags(db, lens.lens_id, tag_names)
    db.commit()
    db.refresh(lens)
    db.refresh(version_record)
    return lens, version_record


def publish_template_from_asset_node(
    db: Session,
    *,
    template_id: int | None,
    template_key: str | None,
    author_id: int,
    title: str,
    description: str,
    result_asset_node_id: str,
    tag_names: List[str],
    category: str | None,
    is_official: bool,
    status: str,
    version: str | None,
    changelog: str,
    parameters: Dict[str, Any],
    ui_schema: Dict[str, Any],
    base_workflow: Dict[str, Any],
) -> tuple[MarketLens, MarketLensVersion]:
    _require_existing_user(db, author_id)
    result_node = _require_existing_asset_node(db, result_asset_node_id)

    # 优先使用节点自带的 muse_dna，否则从资产树路径自动合成
    musedna = None
    if result_node.muse_dna:
        musedna = dict(result_node.muse_dna)
    else:
        from app.services.asset_tree_service import build_blueprint_from_path
        synthesized = build_blueprint_from_path(db, result_asset_node_id)
        if synthesized is not None:
            musedna = synthesized
        else:
            raise ValueError(
                "该修图记录中没有可复用的 AI 修图步骤，"
                "无法发布为模板。至少需要使用一个 AI 工具（如风格转换、智能抠图等）后才能上传到模板市场。"
            )

    media = _derive_template_media_from_result_node(db, result_node)
    return publish_template(
        db,
        template_id=template_id,
        template_key=template_key,
        author_id=author_id,
        title=title,
        description=description,
        musedna=musedna,
        tag_names=tag_names,
        category=category,
        is_official=is_official,
        status=status,
        original_image_url=media["original_image_url"],
        original_thumbnail_url=media["original_thumbnail_url"],
        result_image_url=media["result_image_url"],
        result_thumbnail_url=media["result_thumbnail_url"],
        source_project_id=media["source_project_id"],
        source_root_node_id=media["source_root_node_id"],
        result_asset_node_id=media["result_asset_node_id"],
        published_from="asset_node",
        version=version,
        changelog=changelog,
        parameters=parameters,
        ui_schema=ui_schema,
        base_workflow=base_workflow,
    )


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
        raise ValueError(f"模板不存在：{lens_id}")

    if version_id is not None:
        version = get_market_lens_version(db, version_id)
        if not version or version.lens_id != lens_id:
            raise ValueError("指定版本不存在，或不属于该模板")
    else:
        version = get_latest_market_lens_version(db, lens_id)

    if version is None:
        raise ValueError("该模板还没有可用版本")
    if not version.blueprint:
        raise ValueError("该模板版本还没有可直接应用的 MuseDNA")

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
        raise ValueError(f"模板不存在：{lens_id}")

    if version_id is None:
        version = get_latest_market_lens_version(db, lens_id)
        if version is None:
            raise ValueError("该模板还没有可安装版本")
        version_id = version.version_id
    else:
        version = get_market_lens_version(db, version_id)
        if not version or version.lens_id != lens_id:
            raise ValueError("指定版本不存在，或不属于该模板")

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
    lens = get_market_lens(db, lens_id)
    if not lens:
        raise ValueError(f"模板不存在：{lens_id}")
    existing = db.query(LensFavorite).filter(LensFavorite.user_id == user_id, LensFavorite.lens_id == lens_id).first()
    if existing:
        return False
    db.add(LensFavorite(user_id=user_id, lens_id=lens_id))
    lens.favorite_count = int(lens.favorite_count or 0) + 1
    db.commit()
    return True


def unfavorite_lens(db: Session, *, user_id: int, lens_id: int) -> bool:
    relation = db.query(LensFavorite).filter(LensFavorite.user_id == user_id, LensFavorite.lens_id == lens_id).first()
    if not relation:
        return False
    lens = get_market_lens(db, lens_id)
    db.delete(relation)
    if lens:
        lens.favorite_count = max(0, int(lens.favorite_count or 0) - 1)
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
        raise ValueError(f"模板不存在：{lens_id}")

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
        .order_by(MarketLens.updated_at.desc(), MarketLens.lens_id.asc())
        .all()
    )


def list_user_published_lenses(db: Session, user_id: int) -> List[MarketLens]:
    return (
        db.query(MarketLens)
        .filter(MarketLens.author_id == user_id)
        .order_by(MarketLens.updated_at.desc(), MarketLens.lens_id.asc())
        .all()
    )
