"""
透镜市场服务。
"""

from __future__ import annotations

from decimal import Decimal
from typing import List, Optional

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.market_models import (
    LensFavorite,
    LensReview,
    MarketLens,
    MarketLensVersion,
    UserLens,
)
from app.models.user_models import User


def get_market_lens(db: Session, lens_id: int) -> Optional[MarketLens]:
    return db.query(MarketLens).filter(MarketLens.lens_id == lens_id).first()


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
    status: str,
) -> MarketLens:
    if db.query(MarketLens).filter(MarketLens.lens_key == lens_key).first():
        raise ValueError(f"透镜键已存在：{lens_key}")
    if author_id is not None and not db.query(User).filter(User.user_id == author_id).first():
        raise ValueError(f"作者用户不存在：{author_id}")

    lens = MarketLens(
        lens_key=lens_key,
        name=name,
        description=description,
        author_id=author_id,
        category=category,
        price=price,
        is_official=is_official,
        status=status,
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
    status: str | None = None,
) -> Optional[MarketLens]:
    lens = get_market_lens(db, lens_id)
    if not lens:
        return None
    if name is not None:
        lens.name = name
    if description is not None:
        lens.description = description
    if category is not None:
        lens.category = category
    if price is not None:
        lens.price = price
    if is_official is not None:
        lens.is_official = is_official
    if status is not None:
        lens.status = status
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
    return query.order_by(MarketLens.rating.desc(), MarketLens.install_count.desc(), MarketLens.lens_id.asc()).all()


def create_market_lens_version(
    db: Session,
    *,
    lens_id: int,
    version: str,
    base_workflow: dict,
    parameters: dict,
    ui_schema: dict,
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

    if is_latest:
        (
            db.query(MarketLensVersion)
            .filter(MarketLensVersion.lens_id == lens_id, MarketLensVersion.is_latest.is_(True))
            .update({"is_latest": False})
        )

    version_record = MarketLensVersion(
        lens_id=lens_id,
        version=version,
        base_workflow=base_workflow,
        parameters=parameters,
        ui_schema=ui_schema,
        changelog=changelog,
        is_latest=is_latest,
    )
    db.add(version_record)
    db.commit()
    db.refresh(version_record)
    return version_record


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


def install_lens(
    db: Session,
    *,
    user_id: int,
    lens_id: int,
    version_id: int | None = None,
) -> bool:
    if not db.query(User).filter(User.user_id == user_id).first():
        raise ValueError(f"用户不存在：{user_id}")
    lens = get_market_lens(db, lens_id)
    if not lens:
        raise ValueError(f"透镜不存在：{lens_id}")

    if version_id is None:
        latest = (
            db.query(MarketLensVersion)
            .filter(MarketLensVersion.lens_id == lens_id, MarketLensVersion.is_latest.is_(True))
            .first()
        )
        if not latest:
            latest = (
                db.query(MarketLensVersion)
                .filter(MarketLensVersion.lens_id == lens_id)
                .order_by(MarketLensVersion.created_at.desc())
                .first()
            )
        if not latest:
            raise ValueError("该透镜还没有可安装版本")
        version_id = latest.version_id
    else:
        version = db.query(MarketLensVersion).filter(MarketLensVersion.version_id == version_id).first()
        if not version or version.lens_id != lens_id:
            raise ValueError("指定版本不存在或不属于该透镜")

    existing = db.query(UserLens).filter(UserLens.user_id == user_id, UserLens.lens_id == lens_id).first()
    if existing:
        existing.version_id = version_id
        db.commit()
        return False

    db.add(UserLens(user_id=user_id, lens_id=lens_id, version_id=version_id))
    lens.install_count += 1
    db.commit()
    return True


def uninstall_lens(db: Session, *, user_id: int, lens_id: int) -> bool:
    relation = db.query(UserLens).filter(UserLens.user_id == user_id, UserLens.lens_id == lens_id).first()
    if not relation:
        return False
    lens = get_market_lens(db, lens_id)
    db.delete(relation)
    if lens:
        lens.install_count = max(0, lens.install_count - 1)
    db.commit()
    return True


def favorite_lens(db: Session, *, user_id: int, lens_id: int) -> bool:
    if not db.query(User).filter(User.user_id == user_id).first():
        raise ValueError(f"用户不存在：{user_id}")
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
    if not db.query(User).filter(User.user_id == user_id).first():
        raise ValueError(f"用户不存在：{user_id}")
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
        review.content = content
    else:
        review = LensReview(user_id=user_id, lens_id=lens_id, rating=rating, content=content)
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
