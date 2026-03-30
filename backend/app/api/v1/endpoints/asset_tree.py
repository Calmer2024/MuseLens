"""
树状资产管理 REST API 端点

路由前缀：/api/v1/asset-tree
标签：Asset Tree

端点总览
--------
【项目】
  POST   /projects                               创建项目
  GET    /projects                               列出所有项目
  GET    /projects/{project_id}                  获取项目详情
  PATCH  /projects/{project_id}                  更新项目信息
  POST   /projects/{project_id}/current-node     切换当前节点
  DELETE /projects/{project_id}                  删除项目

【树】
  GET    /projects/{project_id}/tree             获取完整树（节点+边）

【节点】
  POST   /projects/{project_id}/root-node        添加根节点
  POST   /projects/{project_id}/nodes            创建子节点
  GET    /nodes/{node_id}                        获取节点详情
  PATCH  /nodes/{node_id}/status                 更新节点状态（异步回调）
  GET    /nodes/{node_id}/ancestors              获取祖先路径
  GET    /nodes/{node_id}/descendants            获取所有后代
  DELETE /nodes/{node_id}                        删除节点（?cascade=false）

【对比】
  GET    /nodes/compare?nodeA=...&nodeB=...      对比两个节点

【标签】
  POST   /nodes/{node_id}/tags                   添加节点标签
  GET    /nodes/{node_id}/tags                   获取节点所有标签
  DELETE /tags/{tag_id}                          删除标签
"""

from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.schemas.asset_tree import (
    AddNodeTagRequest,
    AddRootNodeRequest,
    AncestorPathResponse,
    AssetEdgeOut,
    AssetEdgeSummary,
    AssetNodeOut,
    AssetNodeSummary,
    CreateChildNodeRequest,
    CreateChildNodeResponse,
    DescendantsResponse,
    MessageResponse,
    NodeCompareResponse,
    NodeTagOut,
    ProjectCreateRequest,
    ProjectOut,
    ProjectTreeResponse,
    ProjectUpdateRequest,
    SwitchCurrentNodeRequest,
    UpdateNodeStatusRequest,
)
from app.services import asset_tree_service as svc
from app.services import editor_session_service as editor_session_svc

router = APIRouter()


# ============================================================
# 内部工具：ORM → Pydantic
# ============================================================

def _project_out(p) -> ProjectOut:
    return ProjectOut.model_validate(p)


def _node_out(d: dict) -> AssetNodeOut:
    return AssetNodeOut.model_validate(d)


def _node_summary(d: dict) -> AssetNodeSummary:
    return AssetNodeSummary.model_validate(d)


def _edge_out(d: dict) -> AssetEdgeOut:
    return AssetEdgeOut.model_validate(d)


def _edge_summary(d: dict) -> AssetEdgeSummary:
    return AssetEdgeSummary.model_validate(d)


def _tag_out(t) -> NodeTagOut:
    return NodeTagOut.model_validate(t)


def _raise_service_error(exc: Exception) -> None:
    if isinstance(exc, LookupError):
        raise HTTPException(status_code=404, detail=str(exc))
    raise HTTPException(status_code=400, detail=str(exc))


# ============================================================
# 项目接口
# ============================================================

@router.post(
    "/projects",
    response_model=ProjectOut,
    summary="创建项目",
    description="创建一个空项目（不含根节点），之后需调用 /root-node 上传原图。",
)
def create_project(
    body: ProjectCreateRequest,
    db: Session = Depends(get_db),
) -> ProjectOut:
    project = svc.create_project(db, name=body.name, description=body.description or "")
    return _project_out(project)


@router.get(
    "/projects",
    response_model=List[ProjectOut],
    summary="列出所有项目",
)
def list_projects(db: Session = Depends(get_db)) -> List[ProjectOut]:
    projects = svc.list_projects(db)
    return [_project_out(p) for p in projects]


@router.get(
    "/projects/{project_id}",
    response_model=ProjectOut,
    summary="获取项目详情",
)
def get_project(
    project_id: str,
    db: Session = Depends(get_db),
) -> ProjectOut:
    project = svc.get_project(db, project_id)
    if not project:
        raise HTTPException(status_code=404, detail=f"项目不存在：{project_id}")
    return _project_out(project)


@router.patch(
    "/projects/{project_id}",
    response_model=ProjectOut,
    summary="更新项目信息",
)
def update_project(
    project_id: str,
    body: ProjectUpdateRequest,
    db: Session = Depends(get_db),
) -> ProjectOut:
    project = svc.update_project(
        db,
        project_id=project_id,
        name=body.name,
        description=body.description,
        cover_url=body.cover_url,
    )
    if not project:
        raise HTTPException(status_code=404, detail=f"项目不存在：{project_id}")
    return _project_out(project)


@router.post(
    "/projects/{project_id}/current-node",
    response_model=ProjectOut,
    summary="切换当前节点",
    description="将项目的当前活跃节点切换到指定节点，用于持久化编辑器状态。",
)
def switch_current_node(
    project_id: str,
    body: SwitchCurrentNodeRequest,
    db: Session = Depends(get_db),
) -> ProjectOut:
    project = svc.switch_current_node(db, project_id=project_id, node_id=body.node_id)
    if not project:
        raise HTTPException(
            status_code=404,
            detail=f"项目或节点不存在，或节点不属于该项目",
        )
    return _project_out(project)


@router.delete(
    "/projects/{project_id}",
    response_model=MessageResponse,
    summary="删除项目",
    description="删除项目及其所有节点、边、标签（级联删除）。",
)
def delete_project(
    project_id: str,
    db: Session = Depends(get_db),
) -> MessageResponse:
    ok = svc.delete_project(db, project_id)
    if not ok:
        raise HTTPException(status_code=404, detail=f"项目不存在：{project_id}")
    return MessageResponse(message=f"项目 {project_id} 已删除")


# ============================================================
# 树结构查询
# ============================================================

@router.get(
    "/projects/{project_id}/tree",
    response_model=ProjectTreeResponse,
    summary="获取完整树结构",
    description=(
        "返回项目中所有节点（AssetNode）和操作边（AssetEdge），"
        "用于前端 D3.js / Cytoscape.js 渲染树状图。\n\n"
        "- nodes 按 depth 升序、创建时间升序排列\n"
        "- edges 按创建时间升序排列"
    ),
)
def get_project_tree(
    project_id: str,
    db: Session = Depends(get_db),
) -> ProjectTreeResponse:
    tree = svc.get_project_tree(db, project_id)
    if not tree:
        raise HTTPException(status_code=404, detail=f"项目不存在：{project_id}")
    return ProjectTreeResponse(
        project=_project_out(tree["project"]),
        nodes=[_node_summary(n) for n in tree["nodes"]],
        edges=[_edge_summary(e) for e in tree["edges"]],
    )


# ============================================================
# 节点接口
# ============================================================

@router.post(
    "/projects/{project_id}/root-node",
    response_model=AssetNodeOut,
    status_code=201,
    summary="添加根节点（原始图片）",
    description=(
        "向项目添加第一张图片作为根节点。\n\n"
        "**注意**：每个项目只能有一个根节点，重复调用将返回 409。\n\n"
        "调用方应先将图片上传到存储后端（MinIO/本地），再将 URL 传入此接口。"
    ),
)
def add_root_node(
    project_id: str,
    body: AddRootNodeRequest,
    db: Session = Depends(get_db),
) -> AssetNodeOut:
    try:
        node = svc.add_root_node(
            db,
            project_id=project_id,
            image_url=body.image_url,
            thumbnail_url=body.thumbnail_url,
            width=body.width,
            height=body.height,
            file_size=body.file_size,
            fmt=body.format,
            metadata=body.metadata,
        )
    except ValueError as exc:
        status = 409 if "已存在根节点" in str(exc) else 404
        raise HTTPException(status_code=status, detail=str(exc))
    tags = svc.get_node_tags(db, node.node_id)
    return _node_out(svc.node_to_dict(node, tags))


@router.post(
    "/projects/{project_id}/nodes",
    response_model=CreateChildNodeResponse,
    status_code=201,
    summary="创建子节点（核心操作）",
    description=(
        "从指定父节点生成子节点，同时创建描述本次操作的边。\n\n"
        "**调用时机**：ComfyUI 完成图像生成并将结果上传到存储后端后，"
        "由后端编排层调用此接口将结果写入资产树。\n\n"
        "返回新创建的节点和边。"
    ),
)
def create_child_node(
    project_id: str,
    body: CreateChildNodeRequest,
    db: Session = Depends(get_db),
) -> CreateChildNodeResponse:
    try:
        if body.episode_id is not None:
            editor_session_svc.validate_episode_for_child_node(
                db,
                episode_id=body.episode_id,
                project_id=project_id,
                parent_node_id=body.parent_node_id,
            )
            node, edge = svc.create_child_node(
                db,
                project_id=project_id,
                parent_node_id=body.parent_node_id,
                image_url=body.image_url,
                thumbnail_url=body.thumbnail_url,
                width=body.width,
                height=body.height,
                file_size=body.file_size,
                fmt=body.format,
                node_type="generated",
                lens_id=body.lens_id,
                lens_name=body.lens_name,
                user_prompt=body.user_prompt,
                parameters=body.parameters,
                muse_dna=body.muse_dna,
                generation_params=body.generation_params,
                execution_time_ms=body.execution_time_ms,
                task_id=body.task_id,
                status=body.status,
                metadata=body.metadata,
                auto_commit=False,
            )
            editor_session_svc.bind_episode_target_node(
                db,
                episode_id=body.episode_id,
                target_node_id=node.node_id,
                source_node_id=body.parent_node_id,
                auto_commit=False,
            )
            db.commit()
            db.refresh(node)
            db.refresh(edge)
        else:
            node, edge = svc.create_child_node(
                db,
                project_id=project_id,
                parent_node_id=body.parent_node_id,
                image_url=body.image_url,
                thumbnail_url=body.thumbnail_url,
                width=body.width,
                height=body.height,
                file_size=body.file_size,
                fmt=body.format,
                node_type="generated",
                lens_id=body.lens_id,
                lens_name=body.lens_name,
                user_prompt=body.user_prompt,
                parameters=body.parameters,
                muse_dna=body.muse_dna,
                generation_params=body.generation_params,
                execution_time_ms=body.execution_time_ms,
                task_id=body.task_id,
                status=body.status,
                metadata=body.metadata,
            )
    except ValueError as exc:
        db.rollback()
        raise HTTPException(status_code=400, detail=str(exc))
    except Exception as exc:
        db.rollback()
        _raise_service_error(exc)

    tags = svc.get_node_tags(db, node.node_id)
    return CreateChildNodeResponse(
        node=_node_out(svc.node_to_dict(node, tags)),
        edge=_edge_out(svc.edge_to_dict(edge)),
    )


@router.get(
    "/nodes/{node_id}",
    response_model=AssetNodeOut,
    summary="获取节点详情",
)
def get_node(
    node_id: str,
    db: Session = Depends(get_db),
) -> AssetNodeOut:
    node = svc.get_node(db, node_id)
    if not node:
        raise HTTPException(status_code=404, detail=f"节点不存在：{node_id}")
    tags = svc.get_node_tags(db, node_id)
    return _node_out(svc.node_to_dict(node, tags))


@router.patch(
    "/nodes/{node_id}/status",
    response_model=AssetNodeOut,
    summary="更新节点状态",
    description=(
        "用于异步生成场景：ComfyUI 完成后回调，将状态从 generating → completed/failed，"
        "并可一并更新图片 URL 和执行耗时。"
    ),
)
def update_node_status(
    node_id: str,
    body: UpdateNodeStatusRequest,
    db: Session = Depends(get_db),
) -> AssetNodeOut:
    node = svc.update_node_status(
        db,
        node_id=node_id,
        status=body.status,
        image_url=body.image_url,
        thumbnail_url=body.thumbnail_url,
        execution_time_ms=body.execution_time_ms,
    )
    if not node:
        raise HTTPException(status_code=404, detail=f"节点不存在：{node_id}")
    tags = svc.get_node_tags(db, node_id)
    return _node_out(svc.node_to_dict(node, tags))


@router.get(
    "/nodes/{node_id}/ancestors",
    response_model=AncestorPathResponse,
    summary="获取祖先路径",
    description=(
        "返回从根节点到目标节点的完整路径（含目标节点本身），以及路径上的操作边。\n\n"
        "利用节点的 path 字段（PostgreSQL UUID[] 数组）实现 O(1) 查询，无需递归遍历。\n\n"
        "**用途**：面包屑导航、重新生成时还原操作序列。"
    ),
)
def get_ancestors(
    node_id: str,
    db: Session = Depends(get_db),
) -> AncestorPathResponse:
    result = svc.get_node_ancestors(db, node_id)
    if not result:
        raise HTTPException(status_code=404, detail=f"节点不存在：{node_id}")
    return AncestorPathResponse(
        node_id=result["node_id"],
        ancestors=[_node_summary(n) for n in result["ancestors"]],
        path_edges=[_edge_summary(e) for e in result["path_edges"]],
    )


@router.get(
    "/nodes/{node_id}/descendants",
    response_model=DescendantsResponse,
    summary="获取所有后代",
    description="返回目标节点的全部后代节点（不含自身），按深度升序排列。使用递归 CTE 实现。",
)
def get_descendants(
    node_id: str,
    db: Session = Depends(get_db),
) -> DescendantsResponse:
    result = svc.get_node_descendants(db, node_id)
    if result is None:
        raise HTTPException(status_code=404, detail=f"节点不存在：{node_id}")
    return DescendantsResponse(
        node_id=result["node_id"],
        descendants=[_node_summary(n) for n in result["descendants"]],
    )


@router.delete(
    "/nodes/{node_id}",
    response_model=MessageResponse,
    summary="删除节点",
    description=(
        "删除指定节点。\n\n"
        "- `cascade=false`（默认）：只允许删除叶节点（无子节点），否则返回 400\n"
        "- `cascade=true`：级联删除该节点及其所有后代（连同关联边和标签）"
    ),
)
def delete_node(
    node_id: str,
    cascade: bool = Query(default=False, description="是否级联删除子树"),
    db: Session = Depends(get_db),
) -> MessageResponse:
    try:
        ok = svc.delete_node(db, node_id=node_id, cascade=cascade)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    if not ok:
        raise HTTPException(status_code=404, detail=f"节点不存在：{node_id}")
    cascade_note = "（含所有后代）" if cascade else ""
    return MessageResponse(message=f"节点 {node_id}{cascade_note} 已删除")


# ============================================================
# 节点对比
# ============================================================

@router.get(
    "/nodes/compare",
    response_model=NodeCompareResponse,
    summary="对比两个节点",
    description=(
        "对比 nodeA 和 nodeB 两个节点的图片与生成信息。\n\n"
        "若 nodeA → nodeB 之间存在直接操作边，一并返回边的详情。\n\n"
        "**注意**：此路由必须在 `/nodes/{node_id}` 之前注册，"
        "否则 'compare' 会被当作 node_id 参数匹配。"
    ),
)
def compare_nodes(
    nodeA: str = Query(..., description="第一个节点 ID"),
    nodeB: str = Query(..., description="第二个节点 ID"),
    db: Session = Depends(get_db),
) -> NodeCompareResponse:
    result = svc.compare_nodes(db, node_a_id=nodeA, node_b_id=nodeB)
    if result is None:
        raise HTTPException(status_code=404, detail="一个或两个节点不存在")
    return NodeCompareResponse(
        node_a=_node_out(result["node_a"]),
        node_b=_node_out(result["node_b"]),
        edge=_edge_summary(result["edge"]) if result["edge"] else None,
    )


# ============================================================
# 节点标签接口
# ============================================================

@router.post(
    "/nodes/{node_id}/tags",
    response_model=NodeTagOut,
    status_code=201,
    summary="添加节点标签",
    description="为节点打上颜色+文字标签，例如'最终版'、'客户审核'。一个节点可有多个标签。",
)
def add_node_tag(
    node_id: str,
    body: AddNodeTagRequest,
    db: Session = Depends(get_db),
) -> NodeTagOut:
    tag = svc.add_node_tag(db, node_id=node_id, label=body.label, color=body.color)
    if not tag:
        raise HTTPException(status_code=404, detail=f"节点不存在：{node_id}")
    return NodeTagOut.model_validate(tag)


@router.get(
    "/nodes/{node_id}/tags",
    response_model=List[NodeTagOut],
    summary="获取节点所有标签",
)
def get_node_tags(
    node_id: str,
    db: Session = Depends(get_db),
) -> List[NodeTagOut]:
    node = svc.get_node(db, node_id)
    if not node:
        raise HTTPException(status_code=404, detail=f"节点不存在：{node_id}")
    tags = svc.get_node_tags(db, node_id)
    return [NodeTagOut.model_validate(t) for t in tags]


@router.delete(
    "/tags/{tag_id}",
    response_model=MessageResponse,
    summary="删除节点标签",
)
def delete_tag(
    tag_id: str,
    db: Session = Depends(get_db),
) -> MessageResponse:
    ok = svc.remove_node_tag(db, tag_id)
    if not ok:
        raise HTTPException(status_code=404, detail=f"标签不存在：{tag_id}")
    return MessageResponse(message=f"标签 {tag_id} 已删除")
