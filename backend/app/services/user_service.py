"""
用户管理服务。
"""

from __future__ import annotations

import base64
import hashlib
import hmac
import os
from typing import List, Optional

from sqlalchemy.orm import Session

from app.models.user_models import Follow, User


def _hash_password(password: str, salt: bytes | None = None) -> str:
    if salt is None:
        salt = os.urandom(16)
    iterations = 120000
    digest = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, iterations)
    return (
        "pbkdf2_sha256$"
        f"{iterations}$"
        f"{base64.b64encode(salt).decode('utf-8')}$"
        f"{base64.b64encode(digest).decode('utf-8')}"
    )


def verify_password(password: str, stored_hash: str) -> bool:
    try:
        algorithm, iterations_text, salt_text, digest_text = stored_hash.split("$", 3)
        if algorithm != "pbkdf2_sha256":
            return False
        iterations = int(iterations_text)
        salt = base64.b64decode(salt_text.encode("utf-8"))
        expected = base64.b64decode(digest_text.encode("utf-8"))
    except Exception:
        return False

    actual = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, iterations)
    return hmac.compare_digest(actual, expected)


def get_user(db: Session, user_id: int) -> Optional[User]:
    return db.query(User).filter(User.user_id == user_id).first()


def get_user_by_username(db: Session, username: str) -> Optional[User]:
    return db.query(User).filter(User.username == username).first()


def create_user(
    db: Session,
    *,
    username: str,
    password: str,
    nickname: str,
    email: str | None = None,
    bio: str = "",
) -> User:
    if get_user_by_username(db, username):
        raise ValueError(f"用户名已存在：{username}")
    if email and db.query(User).filter(User.email == email).first():
        raise ValueError(f"邮箱已存在：{email}")

    user = User(
        username=username,
        password_hash=_hash_password(password),
        nickname=nickname,
        email=email,
        bio=bio,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def authenticate_user(db: Session, username: str, password: str) -> Optional[User]:
    user = get_user_by_username(db, username)
    if not user:
        return None
    if not verify_password(password, user.password_hash):
        return None
    return user


def update_user(
    db: Session,
    *,
    user_id: int,
    nickname: str | None = None,
    email: str | None = None,
    bio: str | None = None,
    avatar_url: str | None = None,
    banner_url: str | None = None,
    member_level: str | None = None,
    is_verified: bool | None = None,
) -> Optional[User]:
    user = get_user(db, user_id)
    if not user:
        return None

    if email is not None:
        existing = db.query(User).filter(User.email == email, User.user_id != user_id).first()
        if existing:
            raise ValueError(f"邮箱已存在：{email}")
        user.email = email
    if nickname is not None:
        user.nickname = nickname
    if bio is not None:
        user.bio = bio
    if avatar_url is not None:
        user.avatar_url = avatar_url
    if banner_url is not None:
        user.banner_url = banner_url
    if member_level is not None:
        user.member_level = member_level
    if is_verified is not None:
        user.is_verified = is_verified

    db.commit()
    db.refresh(user)
    return user


def follow_user(db: Session, *, follower_id: int, following_id: int) -> bool:
    if follower_id == following_id:
        raise ValueError("不能关注自己")

    follower = get_user(db, follower_id)
    following = get_user(db, following_id)
    if not follower or not following:
        raise ValueError("关注双方用户必须存在")

    existing = (
        db.query(Follow)
        .filter(Follow.follower_id == follower_id, Follow.following_id == following_id)
        .first()
    )
    if existing:
        return False

    db.add(Follow(follower_id=follower_id, following_id=following_id))
    follower.following_count += 1
    following.follower_count += 1
    db.commit()
    return True


def unfollow_user(db: Session, *, follower_id: int, following_id: int) -> bool:
    relation = (
        db.query(Follow)
        .filter(Follow.follower_id == follower_id, Follow.following_id == following_id)
        .first()
    )
    if not relation:
        return False

    follower = get_user(db, follower_id)
    following = get_user(db, following_id)
    db.delete(relation)
    if follower:
        follower.following_count = max(0, follower.following_count - 1)
    if following:
        following.follower_count = max(0, following.follower_count - 1)
    db.commit()
    return True


def list_followers(db: Session, user_id: int) -> List[User]:
    return (
        db.query(User)
        .join(Follow, Follow.follower_id == User.user_id)
        .filter(Follow.following_id == user_id)
        .order_by(User.user_id.asc())
        .all()
    )


def list_following(db: Session, user_id: int) -> List[User]:
    return (
        db.query(User)
        .join(Follow, Follow.following_id == User.user_id)
        .filter(Follow.follower_id == user_id)
        .order_by(User.user_id.asc())
        .all()
    )
