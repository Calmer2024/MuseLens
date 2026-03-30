"""
Lens management API.

All writes go to the database and refresh the in-memory registry.
"""

import os
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.lenses import registry
from app.models.lens_model import LensRecord
from app.services.lens_embedding_sync import sync_lens_embeddings

router = APIRouter()


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
