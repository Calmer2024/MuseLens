"""
Lens management API.

All writes go to the database and refresh the in-memory registry.
"""

import os
import re
import struct
import asyncio
import base64
import uuid
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.lenses import registry
from app.schemas.lens import DAGBlueprint, DAGStep
from app.models.lens_model import LensRecord
from app.schemas.router import RouterStepResult
from app.services.compiler import COMFYUI_INPUT_DIR, COMFYUI_OUTPUT_DIR, MuseDNACompiler
from app.services.execution_service import (
    build_input_asset_url,
    build_result_url,
    build_step_results,
    execute_blueprint_with_optional_stream,
    infer_result_filename,
    run_blueprint_with_stream_events,
)
from app.services.lens_control_translation_service import translate_lens_controls
from app.services.lens_ui_control_service import get_lens_tweak_controls
from app.services.lens_embedding_sync import sync_lens_embeddings
from app.services.router_stream_service import router_stream_service

router = APIRouter()
compiler = MuseDNACompiler(input_dir=COMFYUI_INPUT_DIR, output_dir=COMFYUI_OUTPUT_DIR)


class NodeMappingIn(BaseModel):
    node_id: str = Field(..., description="ComfyUI JSON node id")
    field_name: str = Field(..., description="Target input field name")


class LensAssetIn(BaseModel):
    name: str = Field(..., description="Semantic asset name, e.g. 'base_image'")
    type: str = Field(..., description="Asset type, e.g. 'IMAGE' / 'MASK'")
    mapping: NodeMappingIn


class LensParamIn(BaseModel):
    name: str = Field(..., description="Semantic param name, e.g. 'positive_prompt'")
    type: str = Field(..., description="Param type, e.g. 'TEXT' / 'FLOAT'")
    description: str = Field(default="", description="Param description for Planner/RAG")
    mapping: NodeMappingIn


class LensExampleIn(BaseModel):
    nl_desc: str = Field(default="", description="Few-shot natural language example")
    params_example: Dict[str, Any] = Field(
        default_factory=dict,
        description="Few-shot grounded params example",
    )


class LensRegisterRequest(BaseModel):
    lens_id: str = Field(..., description="Unique lens id, e.g. 'lens_inpaint_bg'")
    layer: str = Field(..., description="Layer, A1 ~ A5")
    description: str = Field(default="", description="Lens description")
    workflow_file_path: str = Field(
        ...,
        description="Workflow JSON path, absolute path or a file under backend/lens/",
    )
    inputs: List[LensAssetIn] = Field(default_factory=list)
    outputs: List[LensAssetIn] = Field(default_factory=list)
    params: List[LensParamIn] = Field(default_factory=list)
    examples: List[LensExampleIn] = Field(default_factory=list)


class LensSummary(BaseModel):
    lens_id: str
    layer: str
    description: str
    workflow_file_path: str
    created_at: Optional[Any] = None
    updated_at: Optional[Any] = None


class LensDetail(LensSummary):
    inputs: List[Dict[str, Any]] = []
    outputs: List[Dict[str, Any]] = []
    params: List[Dict[str, Any]] = []
    tweak_controls: List[Dict[str, Any]] = []


class LensRunRequest(BaseModel):
    lens_id: str = Field(..., description="要直接执行的透镜 ID")
    assets: Dict[str, str] = Field(
        default_factory=dict,
        description="输入资产映射：键为透镜 input 名称，值为已存在的文件名",
    )
    params: Dict[str, Any] = Field(
        default_factory=dict,
        description="前端直接填写的透镜参数，不经过 LLM",
    )
    async_execution: bool = Field(
        default=False,
        description="是否以异步流式方式执行。为 true 时，HTTP 只返回启动信息，实时进度通过 WebSocket 推送。",
    )
    stream_id: Optional[str] = Field(
        default=None,
        description="流式执行通道 ID。若 async_execution=true，则建议先连接 `/api/v1/router/ws/run/{stream_id}`。",
    )


class LensRunResponse(BaseModel):
    lens_id: str = Field(..., description="已执行的透镜 ID")
    blueprint: DAGBlueprint = Field(..., description="根据前端输入直接构建出的单步 blueprint")
    executed: bool = Field(default=False, description="是否已执行完成")
    execution_started: bool = Field(default=False, description="是否已成功启动执行")
    stream_id: Optional[str] = Field(default=None, description="关联的流式执行通道 ID")
    execution_context: Dict[str, str] = Field(
        default_factory=dict,
        description="执行完成后的上下文结果，键通常为 step_id.output_name",
    )
    result_filename: Optional[str] = Field(default=None, description="最终结果文件名")
    result_url: Optional[str] = Field(default=None, description="最终结果图预览地址")
    execution_error: Optional[str] = Field(default=None, description="执行阶段错误信息")
    step_results: List[RouterStepResult] = Field(
        default_factory=list,
        description="逐步执行结果。单透镜直连执行时通常只有一步。",
    )


class MaskAssetSaveRequest(BaseModel):
    mask_base64: str = Field(
        ...,
        description="前端画布导出的遮罩 PNG base64 或 data URL。",
    )
    filename: Optional[str] = Field(
        default=None,
        description="可选：指定保存文件名。不传时后端自动生成。",
    )
    asset_name: str = Field(
        default="mask",
        description="建议前端后续写入 user_assets 或 assets 时使用的资产名，默认 mask。",
    )
    prompt_hint: Optional[str] = Field(
        default=None,
        description="可选：记录该遮罩对应的目标描述，如 woman / sky，仅供前端显示。",
    )


class MaskAssetSaveRequestV2(BaseModel):
    mask_base64: str = Field(..., description="前端画布导出的遮罩 PNG base64 或 data URL。")
    filename: Optional[str] = Field(default=None, description="可选：指定保存文件名，不传则自动生成。")
    asset_name: str = Field(
        default="mask",
        description="保存后建议写入 user_assets 或 assets 时使用的资产名，默认 mask。",
    )
    prompt_hint: Optional[str] = Field(
        default=None,
        description="可选：记录该遮罩对应的目标描述，例如 woman / sky，仅供前端展示。",
    )
    source: str = Field(
        default="mask_editor",
        description="遮罩来源，默认 mask_editor，便于前端区分来自手动涂抹还是其他入口。",
    )
    metadata: Dict[str, Any] = Field(
        default_factory=dict,
        description="可选附加信息，例如原图尺寸、画布缩放、笔刷配置等。",
    )


class MaskAssetSaveResponseV2(BaseModel):
    asset_name: str = Field(..., description="建议使用的资产键名，默认 mask。")
    filename: str = Field(..., description="已保存到 ComfyUI input 目录中的遮罩文件名。")
    preview_url: str = Field(..., description="前端可直接预览该遮罩的 URL。")
    prompt_hint: Optional[str] = Field(default=None, description="前端传入的目标描述。")
    source: str = Field(default="mask_editor", description="遮罩来源。")
    mime_type: str = Field(default="image/png", description="遮罩 MIME 类型。")
    byte_size: int = Field(..., description="遮罩文件大小，单位字节。")
    width: int = Field(..., description="遮罩图片宽度。")
    height: int = Field(..., description="遮罩图片高度。")
    metadata: Dict[str, Any] = Field(default_factory=dict, description="前端附加元信息。")
    user_assets_patch: Dict[str, str] = Field(
        default_factory=dict,
        description="建议直接合并进 Router 请求体 user_assets 的字段。",
    )


def _decode_mask_base64(mask_base64: str) -> bytes:
    raw = (mask_base64 or "").strip()
    if not raw:
        raise HTTPException(status_code=422, detail="mask_base64 不能为空。")

    try:
        payload = raw.split(",", 1)[1] if raw.startswith("data:") else raw
        return base64.b64decode(payload, validate=True)
    except Exception:
        raise HTTPException(status_code=422, detail="mask_base64 不是合法的 base64 PNG 数据。")


def _extract_png_size(binary: bytes) -> tuple[int, int]:
    if not binary.startswith(b"\x89PNG\r\n\x1a\n"):
        raise HTTPException(status_code=422, detail="当前仅支持保存 PNG 遮罩。")
    if len(binary) < 24:
        raise HTTPException(status_code=422, detail="PNG 遮罩数据不完整。")
    try:
        width, height = struct.unpack(">II", binary[16:24])
    except struct.error:
        raise HTTPException(status_code=422, detail="无法解析 PNG 遮罩尺寸。")
    if width <= 0 or height <= 0:
        raise HTTPException(status_code=422, detail="PNG 遮罩尺寸无效。")
    return width, height


def _sanitize_asset_name(asset_name: str) -> str:
    normalized = re.sub(r"[^a-zA-Z0-9_-]+", "_", (asset_name or "mask").strip()).strip("_")
    return normalized or "mask"


def _normalize_mask_filename(filename: Optional[str], asset_name: str) -> str:
    raw_name = (filename or "").strip()
    if raw_name:
        if not raw_name.lower().endswith(".png"):
            raw_name += ".png"
        safe_filename = os.path.basename(raw_name)
        if safe_filename != raw_name:
            raise HTTPException(status_code=422, detail="filename 不能包含路径。")
        return safe_filename
    return f"{_sanitize_asset_name(asset_name)}_{uuid.uuid4().hex}.png"


def _save_mask_asset(
    *,
    binary: bytes,
    asset_name: str,
    filename: Optional[str],
    prompt_hint: Optional[str],
    source: str,
    metadata: Optional[Dict[str, Any]],
) -> MaskAssetSaveResponseV2:
    width, height = _extract_png_size(binary)
    safe_asset_name = _sanitize_asset_name(asset_name)
    safe_filename = _normalize_mask_filename(filename, safe_asset_name)

    os.makedirs(COMFYUI_INPUT_DIR, exist_ok=True)
    dst = os.path.join(COMFYUI_INPUT_DIR, safe_filename)
    try:
        with open(dst, "wb") as f:
            f.write(binary)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"遮罩保存失败：{exc}")

    return MaskAssetSaveResponseV2(
        asset_name=safe_asset_name,
        filename=safe_filename,
        preview_url=build_input_asset_url(safe_filename),
        prompt_hint=(prompt_hint or "").strip() or None,
        source=(source or "mask_editor").strip() or "mask_editor",
        mime_type="image/png",
        byte_size=len(binary),
        width=width,
        height=height,
        metadata=dict(metadata or {}),
        user_assets_patch={safe_asset_name: safe_filename},
    )


class MaskAssetSaveResponse(BaseModel):
    asset_name: str = Field(..., description="建议使用的资产键名，默认 mask。")
    filename: str = Field(..., description="已保存到 ComfyUI input 目录中的遮罩文件名。")
    preview_url: str = Field(..., description="前端可直接预览该遮罩的 URL。")
    prompt_hint: Optional[str] = Field(default=None, description="前端传入的目标描述。")
    user_assets_patch: Dict[str, str] = Field(
        default_factory=dict,
        description="建议直接合并进 Router 请求体 user_assets 的字段。",
    )


class LensApplyControlsRequest(BaseModel):
    assets: Dict[str, str] = Field(
        default_factory=dict,
        description="当前透镜执行所需资产映射。",
    )
    current_params: Dict[str, Any] = Field(
        default_factory=dict,
        description="当前透镜已生效参数，通常来自上一次 blueprint step.params 或上次微调结果。",
    )
    control_values: Dict[str, Any] = Field(
        default_factory=dict,
        description="前端控件收集到的值。后端将把它们翻译为 params/assets。",
    )
    execute: bool = Field(
        default=True,
        description="是否在翻译控件后立即执行。false 时只返回 translated/merged 结果。",
    )
    async_execution: bool = Field(
        default=False,
        description="是否异步流式执行。",
    )
    stream_id: Optional[str] = Field(
        default=None,
        description="异步流式执行时关联的 stream_id。",
    )


class LensApplyControlsResponse(BaseModel):
    lens_id: str = Field(..., description="透镜 ID")
    translated_params: Dict[str, Any] = Field(
        default_factory=dict,
        description="由控件值翻译出的参数增量。",
    )
    translated_assets: Dict[str, str] = Field(
        default_factory=dict,
        description="由控件值翻译出的资产增量，例如 mask。",
    )
    merged_params: Dict[str, Any] = Field(
        default_factory=dict,
        description="当前参数与翻译结果合并后的参数。",
    )
    merged_assets: Dict[str, str] = Field(
        default_factory=dict,
        description="当前资产与翻译结果合并后的资产。",
    )
    explanations: List[str] = Field(
        default_factory=list,
        description="控件翻译说明，便于前端调试或展示。",
    )
    execution: Optional["LensRunResponse"] = Field(
        default=None,
        description="若 execute=true，则附带实际执行结果。",
    )


@router.post("/register", response_model=LensSummary, summary="Register or update a lens")
def register_lens(req: LensRegisterRequest, db: Session = Depends(get_db)):
    data: Dict[str, Any] = req.model_dump()
    try:
        template = registry.register_lens(db, data)
    except FileNotFoundError as exc:
        raise HTTPException(status_code=422, detail=str(exc))
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"注册失败：{exc}")

    record = db.query(LensRecord).filter(LensRecord.lens_id == template.lens_id).first()

    from app.models.lens_example_model import LensExampleRecord

    db.query(LensExampleRecord).filter(LensExampleRecord.lens_id == template.lens_id).delete()
    if req.examples:
        for ex in req.examples:
            db.add(
                LensExampleRecord(
                    lens_id=template.lens_id,
                    nl_desc=ex.nl_desc,
                    params_example=ex.params_example,
                )
            )
    db.commit()

    if os.getenv("MUSELENS_RAG_BACKEND", "").lower() == "pgvector":
        try:
            pg_dsn = os.getenv("MUSELENS_PG_DSN")
            if not pg_dsn:
                print("[Lenses] 警告：MUSELENS_RAG_BACKEND=pgvector 但未设置 MUSELENS_PG_DSN，跳过同步。")
            else:
                table_name = os.getenv("MUSELENS_RAG_PGVECTOR_TABLE", "lens_embeddings")
                sync_lens_embeddings(
                    dsn=pg_dsn,
                    table_name=table_name,
                    registry={template.lens_id: template},
                    include_examples=True,
                )
        except Exception as exc:
            print(f"[Lenses] 警告：向量同步失败：{exc}")

    return LensSummary(
        lens_id=record.lens_id,
        layer=record.layer,
        description=record.description,
        workflow_file_path=record.workflow_file_path,
        created_at=record.created_at,
        updated_at=record.updated_at,
    )


@router.get("/", response_model=List[LensSummary], summary="List registered lenses")
def list_lenses(db: Session = Depends(get_db)):
    records = db.query(LensRecord).order_by(LensRecord.layer, LensRecord.lens_id).all()
    return [
        LensSummary(
            lens_id=r.lens_id,
            layer=r.layer,
            description=r.description,
            workflow_file_path=r.workflow_file_path,
            created_at=r.created_at,
            updated_at=r.updated_at,
        )
        for r in records
    ]


@router.get("/stream/new", summary="Create a new stream id for direct lens execution")
def new_lens_stream_id() -> dict[str, str]:
    return {"stream_id": str(uuid.uuid4())}


@router.post("/mask-assets", response_model=MaskAssetSaveResponseV2, summary="Save a painted mask asset for later Router or lens execution")
def save_mask_asset(body: MaskAssetSaveRequestV2) -> MaskAssetSaveResponseV2:
    binary = _decode_mask_base64(body.mask_base64)
    return _save_mask_asset(
        binary=binary,
        asset_name=body.asset_name,
        filename=body.filename,
        prompt_hint=body.prompt_hint,
        source=body.source,
        metadata=body.metadata,
    )

    raw = (body.mask_base64 or "").strip()
    if not raw:
        raise HTTPException(status_code=422, detail="mask_base64 不能为空。")

    try:
        payload = raw.split(",", 1)[1] if raw.startswith("data:") else raw
        binary = base64.b64decode(payload, validate=True)
    except Exception:
        raise HTTPException(status_code=422, detail="mask_base64 不是合法的 base64 PNG 数据。")

    if not binary.startswith(b"\x89PNG\r\n\x1a\n"):
        raise HTTPException(status_code=422, detail="当前仅支持保存 PNG 遮罩。")

    filename = (body.filename or "").strip()
    if filename:
        if not filename.lower().endswith(".png"):
            filename += ".png"
    else:
        filename = f"mask_{uuid.uuid4().hex}.png"

    safe_filename = os.path.basename(filename)
    if safe_filename != filename:
        raise HTTPException(status_code=422, detail="filename 不能包含路径。")

    os.makedirs(COMFYUI_INPUT_DIR, exist_ok=True)
    dst = os.path.join(COMFYUI_INPUT_DIR, safe_filename)
    try:
        with open(dst, "wb") as f:
            f.write(binary)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"遮罩保存失败：{exc}")

    asset_name = (body.asset_name or "mask").strip() or "mask"
    return MaskAssetSaveResponse(
        asset_name=asset_name,
        filename=safe_filename,
        preview_url=build_input_asset_url(safe_filename),
        prompt_hint=(body.prompt_hint or "").strip() or None,
        user_assets_patch={asset_name: safe_filename},
    )


@router.post("/mask-assets/upload", response_model=MaskAssetSaveResponseV2, summary="Upload a PNG mask asset file for later Router or lens execution")
async def upload_mask_asset(
    file: UploadFile = File(..., description="前端直接上传的 PNG 遮罩文件"),
    asset_name: str = Form(default="mask"),
    prompt_hint: Optional[str] = Form(default=None),
    filename: Optional[str] = Form(default=None),
    source: str = Form(default="mask_editor"),
    metadata_json: Optional[str] = Form(default=None),
) -> MaskAssetSaveResponseV2:
    content_type = (file.content_type or "").lower()
    upload_filename = file.filename or ""
    if content_type and content_type != "image/png" and not upload_filename.lower().endswith(".png"):
        raise HTTPException(status_code=422, detail="当前仅支持上传 PNG 遮罩。")

    try:
        binary = await file.read()
    finally:
        await file.close()

    metadata: Dict[str, Any] = {}
    if metadata_json:
        import json

        try:
            parsed = json.loads(metadata_json)
        except Exception:
            raise HTTPException(status_code=422, detail="metadata_json 不是合法的 JSON。")
        if not isinstance(parsed, dict):
            raise HTTPException(status_code=422, detail="metadata_json 必须是 JSON 对象。")
        metadata = parsed

    return _save_mask_asset(
        binary=binary,
        asset_name=asset_name,
        filename=filename or upload_filename,
        prompt_hint=prompt_hint,
        source=source,
        metadata=metadata,
    )


@router.post("/run", response_model=LensRunResponse, summary="Directly execute one lens without LLM")
async def run_lens(req: LensRunRequest, db: Session = Depends(get_db)) -> LensRunResponse:
    return await _execute_single_lens(
        lens_id=req.lens_id,
        assets=req.assets,
        params=req.params,
        async_execution=req.async_execution,
        stream_id=req.stream_id,
    )


@router.post("/{lens_id}/apply-controls", response_model=LensApplyControlsResponse, summary="Translate tweak controls to params/assets and optionally execute")
async def apply_lens_controls(lens_id: str, req: LensApplyControlsRequest) -> LensApplyControlsResponse:
    try:
        registry.get_lens(lens_id)
    except KeyError:
        raise HTTPException(status_code=404, detail=f"透镜 '{lens_id}' 不存在。")

    translated = translate_lens_controls(
        lens_id=lens_id,
        control_values=req.control_values,
        current_params=req.current_params,
        current_assets=req.assets,
    )
    execution = None
    if req.execute:
        execution = await _execute_single_lens(
            lens_id=lens_id,
            assets=translated["merged_assets"],
            params=translated["merged_params"],
            async_execution=req.async_execution,
            stream_id=req.stream_id,
        )

    return LensApplyControlsResponse(
        lens_id=lens_id,
        translated_params=translated["translated_params"],
        translated_assets=translated["translated_assets"],
        merged_params=translated["merged_params"],
        merged_assets=translated["merged_assets"],
        explanations=translated["explanations"],
        execution=execution,
    )


async def _execute_single_lens(
    *,
    lens_id: str,
    assets: Dict[str, str],
    params: Dict[str, Any],
    async_execution: bool,
    stream_id: Optional[str],
) -> LensRunResponse:
    template = registry.get_lens(lens_id)

    blueprint = DAGBlueprint(
        initial_inputs=dict(assets or {}),
        steps=[
            DAGStep(
                step_id="step_1_direct_lens",
                lens_id=lens_id,
                input_links={asset.name: f"${asset.name}" for asset in template.inputs},
                params=dict(params or {}),
            )
        ],
    )

    payload = {
        "lens_id": lens_id,
        "blueprint": blueprint,
        "executed": False,
        "execution_started": False,
        "stream_id": stream_id,
        "execution_context": {},
        "result_filename": None,
        "result_url": None,
        "execution_error": None,
        "step_results": [],
    }

    missing_assets = [asset.name for asset in template.inputs if asset.name not in (assets or {})]
    if missing_assets:
        payload["execution_error"] = f"缺少必须的输入资产: {', '.join(missing_assets)}"
        return LensRunResponse(**payload)

    if async_execution and not stream_id:
        payload["execution_error"] = "async_execution=true requires stream_id. Please connect websocket first."
        return LensRunResponse(**payload)

    if async_execution and stream_id:
        await router_stream_service.emit(
            stream_id,
            {
                "event": "blueprint_ready",
                "session_id": lens_id,
                "stream_id": stream_id,
                "status": "ready",
                "blueprint": blueprint.model_dump(),
            },
        )
        asyncio.create_task(
            run_blueprint_with_stream_events(
                compiler=compiler,
                blueprint=blueprint,
                session_id=lens_id,
                stream_id=stream_id,
            )
        )
        payload["execution_started"] = True
        return LensRunResponse(**payload)

    try:
        final_context = await execute_blueprint_with_optional_stream(
            compiler=compiler,
            blueprint=blueprint,
            session_id=lens_id,
            stream_id=stream_id,
        )
        result_filename = infer_result_filename(blueprint, final_context)
        payload.update(
            {
                "executed": True,
                "execution_started": True,
                "execution_context": final_context,
                "result_filename": result_filename,
                "result_url": build_result_url(result_filename) if result_filename else None,
                "step_results": build_step_results(blueprint, final_context),
            }
        )
        if not result_filename:
            payload["execution_error"] = "Lens executed, but no result image was found in execution context."
    except Exception as exc:
        payload["execution_error"] = str(exc)

    return LensRunResponse(**payload)


@router.get("/{lens_id}/tweak-controls", summary="Get tweak controls for a lens")
def get_lens_tweak_controls_endpoint(lens_id: str):
    try:
        registry.get_lens(lens_id)
    except KeyError:
        raise HTTPException(status_code=404, detail=f"透镜 '{lens_id}' 不存在。")
    return {
        "lens_id": lens_id,
        "tweak_controls": get_lens_tweak_controls(lens_id),
    }


@router.get("/{lens_id}", response_model=LensDetail, summary="Get lens detail")
def get_lens_detail(lens_id: str, db: Session = Depends(get_db)):
    record = db.query(LensRecord).filter(LensRecord.lens_id == lens_id).first()
    if not record:
        raise HTTPException(status_code=404, detail=f"透镜 '{lens_id}' 不存在。")

    return LensDetail(
        lens_id=record.lens_id,
        layer=record.layer,
        description=record.description,
        workflow_file_path=record.workflow_file_path,
        created_at=record.created_at,
        updated_at=record.updated_at,
        inputs=record.inputs or [],
        outputs=record.outputs or [],
        params=record.params or [],
        tweak_controls=get_lens_tweak_controls(record.lens_id),
    )


@router.delete("/{lens_id}", summary="Delete a lens")
def delete_lens(lens_id: str, db: Session = Depends(get_db)):
    success = registry.unregister_lens(db, lens_id)
    if not success:
        raise HTTPException(status_code=404, detail=f"透镜 '{lens_id}' 不存在，无法注销。")
    return {"detail": f"透镜 '{lens_id}' 已成功注销。"}


@router.post("/reload", summary="Reload in-memory registry from database")
def reload_registry(db: Session = Depends(get_db)):
    result = registry.reload_registry(db)
    return {
        "detail": f"注册表已重载，共 {len(result)} 个透镜。",
        "lens_ids": list(result.keys()),
    }


@router.post("/resync-embeddings", summary="Rebuild and sync pgvector lens embeddings")
def resync_embeddings(db: Session = Depends(get_db)):
    result = registry.reload_registry(db)

    if os.getenv("MUSELENS_RAG_BACKEND", "").lower() != "pgvector":
        return {
            "detail": "当前未启用 pgvector，已跳过 embeddings 同步。",
            "lens_ids": list(result.keys()),
        }

    pg_dsn = os.getenv("MUSELENS_PG_DSN")
    if not pg_dsn:
        raise HTTPException(
            status_code=500,
            detail="MUSELENS_RAG_BACKEND=pgvector 但未设置 MUSELENS_PG_DSN。",
        )

    try:
        table_name = os.getenv("MUSELENS_RAG_PGVECTOR_TABLE", "lens_embeddings")
        count = sync_lens_embeddings(
            dsn=pg_dsn,
            table_name=table_name,
            registry=registry.LENS_REGISTRY,
            include_examples=True,
        )
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"embeddings 同步失败：{exc}")

    return {
        "detail": f"已同步 {count} 条 lens embeddings 到表 {table_name}。",
        "lens_ids": list(result.keys()),
    }


LensApplyControlsResponse.model_rebuild()
