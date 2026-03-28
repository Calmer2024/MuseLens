"""
Lens 管理 API

提供对透镜注册表的 CRUD 操作，所有变更同时写入数据库并刷新内存注册表。

端点一览：
  POST   /api/v1/lenses/register           注册（或覆盖）一个透镜
  GET    /api/v1/lenses/                   列出所有已注册透镜的概要信息
  GET    /api/v1/lenses/{lens_id}          查看单个透镜的完整信息
  DELETE /api/v1/lenses/{lens_id}          注销透镜
  POST   /api/v1/lenses/reload             从数据库全量重载内存注册表
"""

import os
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.lenses import registry
from app.models.lens_model import LensRecord

router = APIRouter()


# ============================================================
# 请求 / 响应 Pydantic 模型
# ============================================================

class NodeMappingIn(BaseModel):
    node_id: str = Field(..., description="ComfyUI JSON 中的节点 ID")
    field_name: str = Field(..., description="该节点 inputs 下的字段名")


class LensAssetIn(BaseModel):
    name: str = Field(..., description="资产语义名称，如 'base_image'")
    type: str = Field(..., description="资产类型，如 'IMAGE' / 'MASK'")
    mapping: NodeMappingIn


class LensParamIn(BaseModel):
    name: str = Field(..., description="参数语义名称，如 'positive_prompt'")
    type: str = Field(..., description="参数类型，如 'TEXT' / 'FLOAT'")
    description: str = Field(default="", description="参数说明，供 LLM 理解")
    mapping: NodeMappingIn


class LensExampleIn(BaseModel):
    """LLM few-shot 示例：nl_desc + 参数落地示例。"""

    nl_desc: str = Field(default="", description="自然语言示例描述")
    params_example: Dict[str, Any] = Field(
        default_factory=dict, description="对应的参数示例（JSON）"
    )


class LensRegisterRequest(BaseModel):
    """注册透镜时的请求体。"""
    lens_id: str = Field(..., description="透镜唯一 ID，如 'lens_inpaint_bg'")
    layer: str = Field(..., description="功能层级，A1 ~ A5")
    description: str = Field(default="", description="透镜功能描述")
    workflow_file_path: str = Field(
        ...,
        description="ComfyUI 工作流 JSON 的本地路径（绝对路径，或 backend/lens/ 目录下的文件名）",
    )
    inputs: List[LensAssetIn] = Field(default_factory=list)
    outputs: List[LensAssetIn] = Field(default_factory=list)
    params: List[LensParamIn] = Field(default_factory=list)
    examples: List[LensExampleIn] = Field(
        default_factory=list, description="LLM few-shot 示例，用于 `lens_examples`"
    )


class LensSummary(BaseModel):
    """透镜列表中的概要信息。"""
    lens_id: str
    layer: str
    description: str
    workflow_file_path: str
    created_at: Optional[Any] = None
    updated_at: Optional[Any] = None


class LensDetail(LensSummary):
    """透镜的完整信息（含 inputs / outputs / params 定义）。"""
    inputs: List[Dict[str, Any]] = []
    outputs: List[Dict[str, Any]] = []
    params: List[Dict[str, Any]] = []


# ============================================================
# 端点实现
# ============================================================

@router.post("/register", response_model=LensSummary, summary="注册透镜")
def register_lens(req: LensRegisterRequest, db: Session = Depends(get_db)):
    """
    注册一个新透镜，或覆盖已有同名透镜。

    - 工作流 JSON 文件须已存在于本地，本接口不负责上传工作流。
    - 注册成功后，该透镜立即可被 Router / Compiler 调用，无需重启服务。
    """
    data: Dict[str, Any] = req.model_dump()
    try:
        template = registry.register_lens(db, data)
    except FileNotFoundError as exc:
        raise HTTPException(status_code=422, detail=str(exc))
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"注册失败：{exc}")

    record = db.query(LensRecord).filter(LensRecord.lens_id == template.lens_id).first()

    # 写入/覆盖 LLM few-shot examples
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

    # 如果启用了 pgvector RAG，就在注册成功后同步向量库，让检索立即可用。
    if os.getenv("MUSELENS_RAG_BACKEND", "").lower() == "pgvector":
        try:
            from app.services.lens_embedding_sync import sync_lens_embeddings

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
            # 注册本身应尽量成功；向量同步失败不应让 API 直接失败。
            print(f"[Lenses] 警告：向量同步失败：{exc}")
    return LensSummary(
        lens_id=record.lens_id,
        layer=record.layer,
        description=record.description,
        workflow_file_path=record.workflow_file_path,
        created_at=record.created_at,
        updated_at=record.updated_at,
    )


@router.get("/", response_model=List[LensSummary], summary="列出所有已注册透镜")
def list_lenses(db: Session = Depends(get_db)):
    """返回所有已注册透镜的概要信息列表（不含具体插槽定义）。"""
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


@router.get("/{lens_id}", response_model=LensDetail, summary="查看单个透镜详情")
def get_lens_detail(lens_id: str, db: Session = Depends(get_db)):
    """返回单个透镜的完整信息，包括 inputs / outputs / params 插槽定义。"""
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
        inputs=record.inputs or [],  # PostgreSQL JSONB 自动反序列化
        outputs=record.outputs or [],
        params=record.params or [],
    )


@router.delete("/{lens_id}", summary="注销透镜")
def delete_lens(lens_id: str, db: Session = Depends(get_db)):
    """
    从数据库和内存注册表中移除指定透镜。
    注销后该透镜立即不可被调用，无需重启服务。
    """
    success = registry.unregister_lens(db, lens_id)
    if not success:
        raise HTTPException(status_code=404, detail=f"透镜 '{lens_id}' 不存在，无法注销。")
    return {"detail": f"透镜 '{lens_id}' 已成功注销。"}


@router.post("/reload", summary="从数据库重载内存注册表")
def reload_registry(db: Session = Depends(get_db)):
    """
    将数据库中的所有 Lens 重新加载到内存注册表。
    当工作流文件被手动修改后可调用此接口，使变更生效。
    """
    result = registry.reload_registry(db)
    return {
        "detail": f"注册表已重载，共 {len(result)} 个透镜。",
        "lens_ids": list(result.keys()),
    }
