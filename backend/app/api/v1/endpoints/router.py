from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.schemas.router import (
    RouterAnswerRequest,
    RouterCompileRequest,
    RouterRouteRequest,
    RouterResponse,
)
from app.services.router_service import router_service


router = APIRouter()


@router.post("/route", response_model=RouterResponse)
def route(req: RouterRouteRequest, db: Session = Depends(get_db)) -> RouterResponse:
    """
    统一路由入口（v2）：
    - 若携带 answers：作为追问回答继续编译；
    - 否则：尝试编译蓝图或返回追问。

    该端点用于逐步替代 /compile_or_ask 与 /answer。
    """
    return router_service.route_with_db(req, db=db)


@router.post("/compile_or_ask", response_model=RouterResponse)
def compile_or_ask(req: RouterCompileRequest, db: Session = Depends(get_db)) -> RouterResponse:
    """
    路由入口：
    - 若信息足够，直接返回 READY 状态的 DAGBlueprint；
    - 若信息不足，返回 need_clarification 与追问列表。
    """
    # 兼容旧端点：转发到统一入口
    return router_service.route_with_db(
        RouterRouteRequest(
            user_id=req.user_id,
            session_id=req.session_id,
            user_message=req.user_prompt,
            base_image=req.base_image,
            answers={},
        ),
        db=db,
    )


@router.post("/answer", response_model=RouterResponse)
def answer(req: RouterAnswerRequest, db: Session = Depends(get_db)) -> RouterResponse:
    """
    回答追问并继续完成编译。
    """
    # 兼容旧端点：转发到统一入口
    return router_service.route_with_db(
        RouterRouteRequest(
            user_id="",
            session_id=req.session_id,
            user_message=None,
            base_image=None,
            answers=req.answers,
        ),
        db=db,
    )

