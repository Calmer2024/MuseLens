from fastapi import APIRouter

from app.schemas.router import (
    RouterAnswerRequest,
    RouterCompileRequest,
    RouterResponse,
)
from app.services.router_service import router_service


router = APIRouter()


@router.post("/compile_or_ask", response_model=RouterResponse)
def compile_or_ask(req: RouterCompileRequest) -> RouterResponse:
    """
    路由入口：
    - 若信息足够，直接返回 READY 状态的 DAGBlueprint；
    - 若信息不足，返回 need_clarification 与追问列表。
    """
    return router_service.compile_or_ask(req)


@router.post("/answer", response_model=RouterResponse)
def answer(req: RouterAnswerRequest) -> RouterResponse:
    """
    回答追问并继续完成编译。
    """
    return router_service.answer(req)

