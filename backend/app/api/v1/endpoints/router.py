import os
import uuid

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.lenses.registry import get_lens
from app.schemas.router import (
    RouterBaseImageUploadResponse,
    RouterAnswerRequest,
    RouterCompileRequest,
    RouterRouteAndRunRequest,
    RouterRouteAndRunResponse,
    RouterRouteRequest,
    RouterResponse,
    RouterStatus,
)
from app.services.compiler import COMFYUI_INPUT_DIR, COMFYUI_OUTPUT_DIR, MuseDNACompiler
from app.services.router_service import router_service


router = APIRouter()
compiler = MuseDNACompiler(input_dir=COMFYUI_INPUT_DIR, output_dir=COMFYUI_OUTPUT_DIR)


@router.post("/upload-base-image", response_model=RouterBaseImageUploadResponse)
async def upload_base_image(
    image: UploadFile = File(...),
) -> RouterBaseImageUploadResponse:
    """
    上传 Router 所需的源图到 ComfyUI input 目录。
    """
    original_filename = (image.filename or "upload.png").strip() or "upload.png"
    _, extension = os.path.splitext(original_filename)
    safe_extension = extension.lower()
    if not safe_extension or len(safe_extension) > 10:
        safe_extension = ".png"

    stored_filename = f"router_{uuid.uuid4().hex}{safe_extension}"
    os.makedirs(COMFYUI_INPUT_DIR, exist_ok=True)
    target_path = os.path.join(COMFYUI_INPUT_DIR, stored_filename)

    try:
        contents = await image.read()
        with open(target_path, "wb") as file:
            file.write(contents)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to store uploaded image: {exc}")
    finally:
        await image.close()

    return RouterBaseImageUploadResponse(
        filename=stored_filename,
        original_filename=original_filename,
        file_size=len(contents),
    )


@router.post("/route", response_model=RouterResponse)
def route(req: RouterRouteRequest, db: Session = Depends(get_db)) -> RouterResponse:
    """
    统一路由入口（v2）：
    - 若携带 answers：作为追问回答继续编译；
    - 否则：尝试编译蓝图或返回追问。

    该端点用于逐步替代 /compile_or_ask 与 /answer。
    """
    return router_service.route_with_db(req, db=db)


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

    try:
        final_context = await compiler.execute_blueprint(routed.blueprint)
        result_filename = _infer_result_filename(routed.blueprint, final_context)
        payload.update(
            {
                "executed": True,
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

