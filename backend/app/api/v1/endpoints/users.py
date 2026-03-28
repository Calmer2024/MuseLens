"""
用户管理 API。
"""

from typing import List

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.schemas.asset_tree import MessageResponse
from app.schemas.user import (
    FollowActionRequest,
    UserLoginRequest,
    UserLoginResponse,
    UserOut,
    UserRegisterRequest,
    UserSummary,
    UserUpdateRequest,
)
from app.services import user_service

router = APIRouter()


@router.post("/register", response_model=UserOut, summary="注册用户")
def register_user(body: UserRegisterRequest, db: Session = Depends(get_db)) -> UserOut:
    try:
        user = user_service.create_user(
            db,
            username=body.username,
            password=body.password,
            nickname=body.nickname,
            email=body.email,
            bio=body.bio,
        )
    except ValueError as exc:
        raise HTTPException(status_code=409, detail=str(exc))
    return UserOut.model_validate(user)


@router.post("/login", response_model=UserLoginResponse, summary="用户登录")
def login_user(body: UserLoginRequest, db: Session = Depends(get_db)) -> UserLoginResponse:
    user = user_service.authenticate_user(db, body.username, body.password)
    if not user:
        raise HTTPException(status_code=401, detail="用户名或密码错误")
    return UserLoginResponse(message="登录成功", user=UserOut.model_validate(user))


@router.get("/{user_id}", response_model=UserOut, summary="获取用户详情")
def get_user(user_id: int, db: Session = Depends(get_db)) -> UserOut:
    user = user_service.get_user(db, user_id)
    if not user:
        raise HTTPException(status_code=404, detail=f"用户不存在：{user_id}")
    return UserOut.model_validate(user)


@router.patch("/{user_id}", response_model=UserOut, summary="更新用户资料")
def update_user(user_id: int, body: UserUpdateRequest, db: Session = Depends(get_db)) -> UserOut:
    try:
        user = user_service.update_user(
            db,
            user_id=user_id,
            nickname=body.nickname,
            email=body.email,
            bio=body.bio,
            avatar_url=body.avatar_url,
            banner_url=body.banner_url,
            member_level=body.member_level,
            is_verified=body.is_verified,
        )
    except ValueError as exc:
        raise HTTPException(status_code=409, detail=str(exc))
    if not user:
        raise HTTPException(status_code=404, detail=f"用户不存在：{user_id}")
    return UserOut.model_validate(user)


@router.post("/{user_id}/follow", response_model=MessageResponse, summary="关注用户")
def follow_user(user_id: int, body: FollowActionRequest, db: Session = Depends(get_db)) -> MessageResponse:
    try:
        created = user_service.follow_user(db, follower_id=body.follower_id, following_id=user_id)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    message = "关注成功" if created else "已关注，无需重复操作"
    return MessageResponse(message=message)


@router.delete("/{user_id}/follow", response_model=MessageResponse, summary="取消关注")
def unfollow_user(user_id: int, body: FollowActionRequest, db: Session = Depends(get_db)) -> MessageResponse:
    removed = user_service.unfollow_user(db, follower_id=body.follower_id, following_id=user_id)
    message = "取消关注成功" if removed else "关注关系不存在"
    return MessageResponse(message=message)


@router.get("/{user_id}/followers", response_model=List[UserSummary], summary="获取粉丝列表")
def list_followers(user_id: int, db: Session = Depends(get_db)) -> List[UserSummary]:
    if not user_service.get_user(db, user_id):
        raise HTTPException(status_code=404, detail=f"用户不存在：{user_id}")
    return [UserSummary.model_validate(item) for item in user_service.list_followers(db, user_id)]


@router.get("/{user_id}/following", response_model=List[UserSummary], summary="获取关注列表")
def list_following(user_id: int, db: Session = Depends(get_db)) -> List[UserSummary]:
    if not user_service.get_user(db, user_id):
        raise HTTPException(status_code=404, detail=f"用户不存在：{user_id}")
    return [UserSummary.model_validate(item) for item in user_service.list_following(db, user_id)]
