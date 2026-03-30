import asyncio
import os
import uuid

from fastapi import APIRouter, Depends, WebSocket, WebSocketDisconnect
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.lenses.registry import get_lens
from app.schemas.router import (
    RouterAnswerRequest,
    RouterCompileRequest,
    RouterRouteAndRunRequest,
    RouterRouteAndRunResponse,
    RouterRouteRequest,
    RouterResponse,
    RouterStatus,
)
from app.services.compiler import COMFYUI_INPUT_DIR, COMFYUI_OUTPUT_DIR, MuseDNACompiler
from app.services.router_stream_service import router_stream_service
from app.services.router_service import router_service


router = APIRouter()
compiler = MuseDNACompiler(input_dir=COMFYUI_INPUT_DIR, output_dir=COMFYUI_OUTPUT_DIR)


@router.post("/route", response_model=RouterResponse)
def route(req: RouterRouteRequest, db: Session = Depends(get_db)) -> RouterResponse:
    """
    统一路由入口（v2）：
    - 若携带 answers：作为追问回答继续编译；
    - 否则：尝试编译蓝图或返回追问。

    该端点用于逐步替代 /compile_or_ask 与 /answer。
    """
    return router_service.route_with_db(req, db=db)


@router.get("/stream/new")
def new_stream_id() -> dict[str, str]:
    return {"stream_id": str(uuid.uuid4())}


@router.post("/route_and_run", response_model=RouterRouteAndRunResponse)
async def route_and_run(
    req: RouterRouteAndRunRequest,
    db: Session = Depends(get_db),
) -> RouterRouteAndRunResponse:
    """
    Router 测试执行闭环：
    - 先复用现有 Router 编排；
    - 若返回 need_clarification，则原样返回追问；
    - 若返回 ready 且 execute_when_ready=true，则继续执行 blueprint。
    """
    routed = router_service.route_with_db(req, db=db)
    payload = routed.model_dump()
    payload.update(
        {
            "executed": False,
            "execution_context": {},
            "result_filename": None,
            "result_url": None,
            "execution_error": None,
            "execution_started": False,
            "stream_id": req.stream_id,
            "step_results": [],
        }
    )

    if routed.status != RouterStatus.READY or not req.execute_when_ready:
        return RouterRouteAndRunResponse(**payload)

    if routed.blueprint is None:
        payload["execution_error"] = "Router returned ready but blueprint is missing."
        return RouterRouteAndRunResponse(**payload)

    if not routed.blueprint.initial_inputs.get("user_base_image"):
        payload["execution_error"] = "Blueprint is missing initial input 'user_base_image'."
        return RouterRouteAndRunResponse(**payload)

    stream_id = req.stream_id
    if req.async_execution and req.execute_when_ready and not stream_id:
        payload["execution_error"] = "async_execution=true requires stream_id. Please connect websocket first."
        return RouterRouteAndRunResponse(**payload)

    if req.async_execution and req.execute_when_ready and stream_id:
        await router_stream_service.emit(
            stream_id,
            {
                "event": "blueprint_ready",
                "session_id": routed.session_id,
                "stream_id": stream_id,
                "status": routed.status.value,
                "blueprint": routed.blueprint.model_dump(),
            },
        )
        asyncio.create_task(
            _run_blueprint_with_stream_events(
                blueprint=routed.blueprint,
                session_id=routed.session_id,
                stream_id=stream_id,
            )
        )
        payload["execution_started"] = True
        return RouterRouteAndRunResponse(**payload)

    try:
        final_context = await _execute_blueprint_with_optional_stream(
            blueprint=routed.blueprint,
            session_id=routed.session_id,
            stream_id=stream_id,
        )
        result_filename = _infer_result_filename(routed.blueprint, final_context)
        payload.update(
            {
                "executed": True,
                "execution_started": True,
                "execution_context": final_context,
                "result_filename": result_filename,
                "result_url": _build_result_url(result_filename) if result_filename else None,
                "step_results": _build_step_results(routed.blueprint, final_context),
            }
        )
        if not result_filename:
            payload["execution_error"] = "Blueprint executed, but no result image was found in execution context."
    except Exception as exc:
        payload["execution_error"] = str(exc)

    return RouterRouteAndRunResponse(**payload)


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


@router.websocket("/ws/run/{stream_id}")
async def route_and_run_websocket(websocket: WebSocket, stream_id: str) -> None:
    await router_stream_service.connect(stream_id, websocket)
    try:
        await websocket.send_json(
            {
                "event": "connected",
                "stream_id": stream_id,
            }
        )
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        await router_stream_service.disconnect(stream_id, websocket)
    except Exception:
        await router_stream_service.disconnect(stream_id, websocket)


def _infer_result_filename(blueprint, execution_context: dict[str, str]) -> str | None:
    for step in reversed(blueprint.steps):
        candidate = execution_context.get(f"{step.step_id}.result_image")
        if candidate:
            return candidate
    return None


def _build_result_url(filename: str) -> str:
    base_url = (os.getenv("COMFYUI_VIEW_BASE_URL") or "http://127.0.0.1:8188").rstrip("/")
    return f"{base_url}/view?filename={filename}&type=output"


def _build_step_results(blueprint, execution_context: dict[str, str]) -> list[dict]:
    step_results: list[dict] = []

    for step in blueprint.steps:
        outputs: list[dict] = []
        try:
            lens_template = get_lens(step.lens_id)
            output_names = [asset.name for asset in lens_template.outputs]
        except Exception:
            output_names = []

        seen_output_names: set[str] = set()
        for output_name in output_names:
            key = f"{step.step_id}.{output_name}"
            filename = execution_context.get(key)
            if not filename:
                continue
            seen_output_names.add(output_name)
            outputs.append(
                {
                    "output_name": output_name,
                    "filename": filename,
                    "url": _build_result_url(filename),
                }
            )

        step_prefix = f"{step.step_id}."
        for key, filename in execution_context.items():
            if not key.startswith(step_prefix):
                continue
            output_name = key[len(step_prefix):]
            if output_name in seen_output_names or not filename:
                continue
            outputs.append(
                {
                    "output_name": output_name,
                    "filename": filename,
                    "url": _build_result_url(filename),
                }
            )

        step_results.append(
            {
                "step_id": step.step_id,
                "lens_id": step.lens_id,
                "outputs": outputs,
            }
        )

    return step_results


async def _execute_blueprint_with_optional_stream(
    *,
    blueprint,
    session_id: str,
    stream_id: str | None,
) -> dict[str, str]:
    if not stream_id:
        return await compiler.execute_blueprint(blueprint)

    step_lens_map = {step.step_id: step.lens_id for step in blueprint.steps}

    async def on_step_started(step_id: str, lens_id: str, step_index: int, total_steps: int) -> None:
        await router_stream_service.emit(
            stream_id,
            {
                "event": "step_started",
                "session_id": session_id,
                "stream_id": stream_id,
                "step_id": step_id,
                "lens_id": lens_id,
                "step_index": step_index,
                "total_steps": total_steps,
            },
        )

    async def on_step_completed(step_id: str, output_assets: dict[str, str]) -> None:
        await router_stream_service.emit(
            stream_id,
            {
                "event": "step_completed",
                "session_id": session_id,
                "stream_id": stream_id,
                "step_id": step_id,
                "lens_id": step_lens_map.get(step_id),
                "outputs": _build_step_outputs_from_step_payload(output_assets),
            },
        )

    await router_stream_service.emit(
        stream_id,
        {
            "event": "execution_started",
            "session_id": session_id,
            "stream_id": stream_id,
            "blueprint": blueprint.model_dump(),
        },
    )

    return await compiler.execute_blueprint(
        blueprint,
        progress_callback=on_step_completed,
        step_started_callback=on_step_started,
    )


async def _run_blueprint_with_stream_events(
    *,
    blueprint,
    session_id: str,
    stream_id: str,
) -> None:
    try:
        final_context = await _execute_blueprint_with_optional_stream(
            blueprint=blueprint,
            session_id=session_id,
            stream_id=stream_id,
        )
        result_filename = _infer_result_filename(blueprint, final_context)
        await router_stream_service.emit(
            stream_id,
            {
                "event": "execution_completed",
                "session_id": session_id,
                "stream_id": stream_id,
                "execution_context": final_context,
                "result_filename": result_filename,
                "result_url": _build_result_url(result_filename) if result_filename else None,
                "step_results": _build_step_results(blueprint, final_context),
            },
        )
    except Exception as exc:
        await router_stream_service.emit(
            stream_id,
            {
                "event": "execution_failed",
                "session_id": session_id,
                "stream_id": stream_id,
                "error": str(exc),
            },
        )


def _build_step_outputs_from_step_payload(output_assets: dict[str, str]) -> list[dict]:
    outputs: list[dict] = []
    for output_name, filename in output_assets.items():
        outputs.append(
            {
                "output_name": output_name,
                "filename": filename,
                "url": _build_result_url(filename),
            }
        )
    return outputs

