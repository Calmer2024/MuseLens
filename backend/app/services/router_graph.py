"""
Router v2：使用 LangGraph 编排 retrieve → plan → validate，并在需要时 enrich 后重跑 plan（最多一次）。
"""
from __future__ import annotations

from contextvars import ContextVar, Token
from dataclasses import dataclass
from typing import TYPE_CHECKING, Any, Dict, List, Literal, Optional, TypedDict

from langgraph.graph import END, StateGraph

from app.models.router_session_model import RouterSessionRecord
from app.schemas.planner import PlannerInput, PlannerOutput
from app.schemas.router import (
    ClarifyQuestion,
    QuestionBind,
    QuestionBindTarget,
    QuestionType,
    RouterResponse,
    RouterRouteRequest,
    RouterStatus,
)
from app.services.blueprint_validator import blueprint_validator

if TYPE_CHECKING:
    from app.services.router_service import RouterService


class RouterGraphState(TypedDict, total=False):
    """LangGraph 状态（可序列化字段）。"""

    lenses: List[Dict[str, Any]]
    candidates_payload: List[Dict[str, Any]]
    planner_out: Dict[str, Any]
    verrors: List[Dict[str, Any]]
    enrich_attempted: bool


@dataclass
class RouterV2Context:
    router: RouterService
    db: Any  # Session
    sess: RouterSessionRecord
    req: RouterRouteRequest
    task_desc: str
    collected_params: Dict[str, Any]
    response: Optional[RouterResponse] = None


_ctx_var: ContextVar[Optional[RouterV2Context]] = ContextVar("router_v2_ctx", default=None)


def _get_ctx() -> RouterV2Context:
    c = _ctx_var.get()
    if c is None:
        raise RuntimeError("RouterV2Context 未设置")
    return c


def _planner_to_clarify_questions(router: "RouterService", po: PlannerOutput) -> List[ClarifyQuestion]:
    """
    将 Planner 的结构化追问与 missing_params 转为对外的 ClarifyQuestion。
    若 clarification_questions 为空但存在 missing_params，则用 reason 生成一条可回填的追问。
    """
    items: List[ClarifyQuestion] = list(
        router._to_clarify_questions(po.clarification_questions)
    )
    if items:
        return items
    for m in po.missing_params or []:
        items.append(
            ClarifyQuestion(
                id=f"{m.lens_id}.{m.param_name}",
                prompt=(m.reason or "").strip()
                or f"请补充透镜 {m.lens_id} 的参数 {m.param_name}",
                type=QuestionType.TEXT,
                options=[],
                required=True,
                binds=[
                    QuestionBind(
                        step_id=None,
                        lens_id=m.lens_id,
                        target=QuestionBindTarget.PARAM,
                        name=m.param_name,
                    )
                ],
            )
        )
    return items


def _extract_lens_ids_for_enrich(po: PlannerOutput) -> List[str]:
    ids: List[str] = []
    for m in po.missing_params or []:
        ids.append(m.lens_id)
    for q in po.clarification_questions or []:
        ids.append(q.param_ref.lens_id)
    if po.blueprint:
        for s in po.blueprint.steps:
            ids.append(s.lens_id)
    seen = set()
    out: List[str] = []
    for lid in ids:
        if lid and lid not in seen:
            seen.add(lid)
            out.append(lid)
    return out


def _should_enrich(po: PlannerOutput, verrors: List[Dict[str, Any]]) -> bool:
    if po.missing_params or po.clarification_questions:
        return True
    if verrors:
        return True
    if po.blueprint is None and (po.missing_params or po.clarification_questions):
        return True
    return False


def _node_retrieve(_state: RouterGraphState) -> Dict[str, Any]:
    ctx = _get_ctx()
    lenses = ctx.router._retrieval.retrieve(ctx.db, task_desc=ctx.task_desc, top_k=5)
    payload = [l.model_dump() for l in lenses]
    return {
        "lenses": payload,
        "candidates_payload": list(payload),
    }


def _node_plan(state: RouterGraphState) -> Dict[str, Any]:
    ctx = _get_ctx()
    sess = ctx.sess
    req = ctx.req
    planner_input = PlannerInput(
        task_desc=ctx.task_desc,
        base_image_meta=req.base_image_meta or (sess.base_image_meta or {}),
        candidates=state["candidates_payload"],
        session_context={
            "collected_params": ctx.collected_params,
            "pending_questions": sess.pending_questions or [],
            "lens_history": sess.lens_history or [],
            "previous_blueprint": sess.pending_blueprint,
        },
    )
    planner_out = ctx.router._planner.plan(planner_input)
    return {"planner_out": planner_out.model_dump()}


def _node_validate(state: RouterGraphState) -> Dict[str, Any]:
    ctx = _get_ctx()
    po = PlannerOutput.model_validate(state["planner_out"])
    if not po.blueprint:
        return {"verrors": []}
    verrors = blueprint_validator.validate(
        ctx.db, po.blueprint, collected_params=ctx.collected_params
    )
    return {"verrors": [e.__dict__ for e in verrors]}


def _route_after_validate(state: RouterGraphState) -> Literal["enrich", "finalize"]:
    if state.get("enrich_attempted"):
        return "finalize"
    po = PlannerOutput.model_validate(state["planner_out"])
    verrors = state.get("verrors") or []
    if not _should_enrich(po, verrors):
        return "finalize"
    ids = _extract_lens_ids_for_enrich(po)
    if not ids:
        return "finalize"
    return "enrich"


def _node_enrich(state: RouterGraphState) -> Dict[str, Any]:
    ctx = _get_ctx()
    po = PlannerOutput.model_validate(state["planner_out"])
    lens_ids = _extract_lens_ids_for_enrich(po)
    score_by_id: Dict[str, float] = {}
    for row in state.get("lenses") or []:
        lid = row.get("lens_id")
        if isinstance(lid, str):
            score_by_id[lid] = float(row.get("score") or 0.0)
    enriched = ctx.router._retrieval.retrieve_by_lens_ids(
        ctx.db, lens_ids, score_by_id=score_by_id or None
    )
    payload = [l.model_dump() for l in enriched]
    return {
        "candidates_payload": payload,
        "enrich_attempted": True,
    }


def _node_finalize(state: RouterGraphState) -> Dict[str, Any]:
    ctx = _get_ctx()
    db = ctx.db
    sess = ctx.sess
    collected = ctx.collected_params

    po = PlannerOutput.model_validate(state["planner_out"])
    _hydrate_blueprint_initial_inputs(ctx, po)
    lenses_raw = state.get("lenses") or []
    retrieved_ids = [str(x.get("lens_id")) for x in lenses_raw if x.get("lens_id")]
    verrors = state.get("verrors") or []

    questions = _planner_to_clarify_questions(ctx.router, po)

    # 有 blueprint：先处理校验错误，再区分 READY / 追问
    if po.blueprint:
        if verrors:
            from app.services.router_session_store import router_session_store

            router_session_store.upsert_json_fields(
                db,
                sess.session_id,
                collected_params=collected,
            )
            ctx.response = RouterResponse(
                session_id=sess.session_id,
                status=RouterStatus.FAILED,
                thought_process="Blueprint 静态校验失败。",
                questions=[],
                blueprint=None,
                extra={"validation_errors": verrors},
            )
            return {}

        if questions:
            from app.services.router_session_store import router_session_store

            router_session_store.upsert_json_fields(
                db,
                sess.session_id,
                collected_params=collected,
                pending_blueprint=po.blueprint.model_dump(),
                pending_questions=[q.model_dump() for q in questions],
            )
            ctx.response = RouterResponse(
                session_id=sess.session_id,
                status=RouterStatus.NEED_CLARIFICATION,
                thought_process=po.thought or "参数信息不足，需要向用户追问补齐。",
                questions=questions,
                blueprint=None,
                extra={"retrieved_lenses": retrieved_ids},
            )
            return {}

        lens_history = list(sess.lens_history or [])
        lens_history.append({"blueprint": po.blueprint.model_dump()})
        from app.services.router_session_store import router_session_store

        router_session_store.upsert_json_fields(
            db,
            sess.session_id,
            collected_params=collected,
            pending_blueprint=None,
            pending_questions=[],
            lens_history=lens_history,
        )
        ctx.response = RouterResponse(
            session_id=sess.session_id,
            status=RouterStatus.READY,
            thought_process=po.thought or "已生成可执行 Blueprint。",
            questions=[],
            blueprint=po.blueprint,
            extra={"retrieved_lenses": retrieved_ids},
        )
        return {}

    # 无 blueprint：若有结构化追问或 missing_params，走 NEED_CLARIFICATION（而非 FAILED）
    if questions:
        from app.services.router_session_store import router_session_store

        router_session_store.upsert_json_fields(
            db,
            sess.session_id,
            collected_params=collected,
            pending_blueprint=None,
            pending_questions=[q.model_dump() for q in questions],
        )
        ctx.response = RouterResponse(
            session_id=sess.session_id,
            status=RouterStatus.NEED_CLARIFICATION,
            thought_process=po.thought or "参数信息不足，需要向用户追问补齐。",
            questions=questions,
            blueprint=None,
            extra={"retrieved_lenses": retrieved_ids, "planner": po.model_dump()},
        )
        return {}

    from app.services.router_session_store import router_session_store

    router_session_store.upsert_json_fields(
        db,
        sess.session_id,
        collected_params=collected,
    )
    ctx.response = RouterResponse(
        session_id=sess.session_id,
        status=RouterStatus.FAILED,
        thought_process=po.thought or "Planner 未返回 blueprint，且未给出可执行的追问项。",
        questions=[],
        blueprint=None,
        extra={"planner": po.model_dump()},
    )
    return {}


def _hydrate_blueprint_initial_inputs(ctx: RouterV2Context, po: PlannerOutput) -> None:
    if po.blueprint is None:
        return

    base_image = ctx.req.base_image or ctx.sess.base_image or ""
    if not base_image:
        return

    po.blueprint.initial_inputs["user_base_image"] = base_image


def build_router_v2_graph() -> Any:
    g = StateGraph(RouterGraphState)
    g.add_node("retrieve", _node_retrieve)
    g.add_node("plan", _node_plan)
    g.add_node("validate", _node_validate)
    g.add_node("enrich", _node_enrich)
    g.add_node("finalize", _node_finalize)

    g.set_entry_point("retrieve")
    g.add_edge("retrieve", "plan")
    g.add_edge("plan", "validate")
    g.add_conditional_edges(
        "validate",
        _route_after_validate,
        {"enrich": "enrich", "finalize": "finalize"},
    )
    g.add_edge("enrich", "plan")
    g.add_edge("finalize", END)
    return g.compile()


_compiled_router_v2_graph: Any = None


def get_router_v2_graph() -> Any:
    global _compiled_router_v2_graph
    if _compiled_router_v2_graph is None:
        _compiled_router_v2_graph = build_router_v2_graph()
    return _compiled_router_v2_graph


def invoke_router_v2_graph(
    router: RouterService,
    *,
    db: Any,
    sess: RouterSessionRecord,
    req: RouterRouteRequest,
    task_desc: str,
    collected_params: Dict[str, Any],
) -> RouterResponse:
    ctx = RouterV2Context(
        router=router,
        db=db,
        sess=sess,
        req=req,
        task_desc=task_desc,
        collected_params=collected_params,
        response=None,
    )
    token: Token = _ctx_var.set(ctx)
    try:
        graph = get_router_v2_graph()
        graph.invoke({"enrich_attempted": False})
        if ctx.response is None:
            raise RuntimeError("Router v2 graph 未产出 response")
        return ctx.response
    finally:
        _ctx_var.reset(token)
