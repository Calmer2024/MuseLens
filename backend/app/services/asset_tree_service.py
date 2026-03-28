"""
树状资产管理服务层 — PostgreSQL 优化版

职责：
  - 封装所有与资产树相关的数据库写入/查询操作
  - 保证树结构一致性（path、depth、node_count 等同步更新）
  - 所有操作均接受 SQLAlchemy Session，由调用方控制事务边界

PostgreSQL 优化：
  - path 字段使用原生 UUID[] 数组，祖先查询 O(1)，无需手动序列化
  - muse_dna / parameters / metadata 使用 JSONB，SQLAlchemy 自动处理序列化
  - 递归 CTE 与 PostgreSQL 完美兼容，性能更优
"""

from __future__ import annotations

import uuid
from typing import Any, Dict, List, Optional, Tuple

from sqlalchemy import text
from sqlalchemy.orm import Session

from app.models.asset_tree_models import AssetEdge, AssetNode, NodeTag, Project


# ============================================================
# 内部工具函数
# ============================================================

def _new_uuid() -> str:
    return str(uuid.uuid4())


# ============================================================
# 节点数据转换（ORM → 字典，便于构建 Pydantic 响应）
# ============================================================

def node_to_dict(node: AssetNode, tags: Optional[List[NodeTag]] = None) -> Dict[str, Any]:
    """将 AssetNode ORM 对象转为字典（与 AssetNodeOut schema 对应）。"""
    return {
        "node_id": node.node_id,
        "project_id": node.project_id,
        "image_url": node.image_url,
        "thumbnail_url": node.thumbnail_url,
        "node_type": node.node_type,
        "width": node.width,
        "height": node.height,
        "file_size": node.file_size,
        "format": node.format,
        "muse_dna": node.muse_dna,  # JSONB 自动反序列化
        "generation_params": node.generation_params,
        "depth": node.depth,
        "path": node.path or [],  # UUID[] 数组，直接使用
        "status": node.status,
        "label": node.label,
        "metadata": node.extra_metadata,
        "tags": tags or [],
        "created_at": node.created_at,
    }


def edge_to_dict(edge: AssetEdge) -> Dict[str, Any]:
    """将 AssetEdge ORM 对象转为字典（与 AssetEdgeOut schema 对应）。"""
    return {
        "edge_id": edge.edge_id,
        "project_id": edge.project_id,
        "source_node_id": edge.source_node_id,
        "target_node_id": edge.target_node_id,
        "lens_id": edge.lens_id,
        "lens_name": edge.lens_name,
        "user_prompt": edge.user_prompt,
        "parameters": edge.parameters,  # JSONB 自动反序列化
        "muse_dna": edge.muse_dna,
        "execution_time_ms": edge.execution_time_ms,
        "task_id": edge.task_id,
        "created_at": edge.created_at,
    }


# ============================================================
# Project 操作
# ============================================================

def create_project(
    db: Session,
    name: str,
    description: str = "",
) -> Project:
    """创建一个空项目（无根节点），返回已提交的 Project 对象。"""
    project = Project(
        name=name,
        description=description,
    )
    db.add(project)
    db.commit()
    db.refresh(project)
    return project


def get_project(db: Session, project_id: str) -> Optional[Project]:
    """按 ID 查询项目。不存在返回 None。"""
    return db.query(Project).filter(Project.project_id == project_id).first()


def list_projects(db: Session) -> List[Project]:
    """列出所有项目，按更新时间降序。"""
    return db.query(Project).order_by(Project.updated_at.desc()).all()


def update_project(
    db: Session,
    project_id: str,
    name: Optional[str] = None,
    description: Optional[str] = None,
    cover_url: Optional[str] = None,
) -> Optional[Project]:
    """更新项目基本信息，返回更新后的项目。"""
    project = get_project(db, project_id)
    if not project:
        return None
    if name is not None:
        project.name = name
    if description is not None:
        project.description = description
    if cover_url is not None:
        project.cover_url = cover_url
    db.commit()
    db.refresh(project)
    return project


def switch_current_node(
    db: Session,
    project_id: str,
    node_id: str,
) -> Optional[Project]:
    """
    切换项目的当前活跃节点。

    前端在用户点击树中某个节点时调用，用于持久化用户的聚焦位置。
    返回更新后的 Project，若项目或节点不存在返回 None。
    """
    project = get_project(db, project_id)
    if not project:
        return None
    node = get_node(db, node_id)
    if not node or node.project_id != project_id:
        return None
    project.current_node_id = node_id
    db.commit()
    db.refresh(project)
    return project


def delete_project(db: Session, project_id: str) -> bool:
    """
    删除项目及其所有节点/边（级联删除）。
    返回 True 表示成功，False 表示项目不存在。
    """
    project = get_project(db, project_id)
    if not project:
        return False
    db.delete(project)
    db.commit()
    return True


# ============================================================
# AssetNode 操作
# ============================================================

def get_node(db: Session, node_id: str) -> Optional[AssetNode]:
    """按 ID 查询节点。"""
    return db.query(AssetNode).filter(AssetNode.node_id == node_id).first()


def get_node_tags(db: Session, node_id: str) -> List[NodeTag]:
    return db.query(NodeTag).filter(NodeTag.node_id == node_id).all()


def add_root_node(
    db: Session,
    project_id: str,
    image_url: str,
    thumbnail_url: Optional[str] = None,
    width: Optional[int] = None,
    height: Optional[int] = None,
    file_size: Optional[int] = None,
    fmt: Optional[str] = None,
    metadata: Optional[Dict[str, Any]] = None,
) -> AssetNode:
    """
    为项目添加根节点（原始上传图）。

    规则：
      - 一个项目只能有一个根节点；若 root_node_id 已存在则抛出 ValueError
      - 成功后更新 Project.root_node_id, current_node_id, cover_url, node_count
    """
    project = get_project(db, project_id)
    if not project:
        raise ValueError(f"项目不存在：{project_id}")
    if project.root_node_id:
        raise ValueError(f"项目 {project_id} 已存在根节点 {project.root_node_id}，不可重复添加")

    node = AssetNode(
        project_id=project_id,
        image_url=image_url,
        thumbnail_url=thumbnail_url,
        node_type="original",
        width=width,
        height=height,
        file_size=file_size,
        format=fmt,
        depth=0,
        status="completed",
        extra_metadata=metadata,
    )
    db.add(node)
    db.flush()  # 生成 node_id
    
    # 更新 path = [self]
    node.path = [node.node_id]

    # 同步更新项目引用
    project.root_node_id = node.node_id
    project.current_node_id = node.node_id
    project.cover_url = image_url
    project.node_count = 1
    project.branch_count = 0

    db.commit()
    db.refresh(node)
    return node


def create_child_node(
    db: Session,
    project_id: str,
    parent_node_id: str,
    image_url: str,
    thumbnail_url: Optional[str] = None,
    width: Optional[int] = None,
    height: Optional[int] = None,
    file_size: Optional[int] = None,
    fmt: Optional[str] = None,
    node_type: str = "generated",
    lens_id: Optional[str] = None,
    lens_name: Optional[str] = None,
    user_prompt: Optional[str] = None,
    parameters: Optional[Dict[str, Any]] = None,
    muse_dna: Optional[Dict[str, Any]] = None,
    generation_params: Optional[Dict[str, Any]] = None,
    execution_time_ms: Optional[int] = None,
    task_id: Optional[str] = None,
    status: str = "completed",
    metadata: Optional[Dict[str, Any]] = None,
) -> Tuple[AssetNode, AssetEdge]:
    """
    从父节点生成子节点（核心操作）。

    返回 (新节点, 新边) 元组。

    步骤：
      1. 校验父节点与项目存在性
      2. 创建 AssetNode（depth = parent.depth + 1，path = parent.path + [self]）
      3. 创建 AssetEdge（source=parent, target=child）
      4. 更新 Project.current_node_id / node_count / branch_count
    """
    project = get_project(db, project_id)
    if not project:
        raise ValueError(f"项目不存在：{project_id}")

    parent = get_node(db, parent_node_id)
    if not parent:
        raise ValueError(f"父节点不存在：{parent_node_id}")
    if parent.project_id != project_id:
        raise ValueError(f"父节点 {parent_node_id} 不属于项目 {project_id}")

    # 判断父节点是否已有子节点（用于 branch_count 更新）
    existing_children_count = (
        db.query(AssetEdge)
        .filter(AssetEdge.source_node_id == parent_node_id)
        .count()
    )

    # 创建新节点
    parent_path = parent.path or []
    
    child_node = AssetNode(
        project_id=project_id,
        image_url=image_url,
        thumbnail_url=thumbnail_url,
        node_type=node_type,
        width=width,
        height=height,
        file_size=file_size,
        format=fmt,
        muse_dna=muse_dna,  # JSONB 自动序列化
        generation_params=generation_params,
        depth=parent.depth + 1,
        status=status,
        extra_metadata=metadata,
    )
    db.add(child_node)
    db.flush()  # 生成 node_id
    
    # 更新 path = parent.path + [self]
    child_node.path = parent_path + [child_node.node_id]

    # 创建操作边
    edge = AssetEdge(
        project_id=project_id,
        source_node_id=parent_node_id,
        target_node_id=child_node.node_id,
        lens_id=lens_id,
        lens_name=lens_name,
        user_prompt=user_prompt,
        parameters=parameters or {},  # JSONB 自动序列化
        muse_dna=muse_dna,
        execution_time_ms=execution_time_ms,
        task_id=task_id,
    )
    db.add(edge)

    # 更新项目统计
    project.current_node_id = child_node.node_id
    project.node_count = (project.node_count or 0) + 1
    # 父节点首次产生分支（从 1 个子节点变为 2+），才计入 branch_count
    if existing_children_count == 1:
        project.branch_count = (project.branch_count or 0) + 1

    db.commit()
    db.refresh(child_node)
    db.refresh(edge)
    return child_node, edge


def update_node_status(
    db: Session,
    node_id: str,
    status: str,
    image_url: Optional[str] = None,
    thumbnail_url: Optional[str] = None,
    execution_time_ms: Optional[int] = None,
) -> Optional[AssetNode]:
    """
    更新节点状态（适用于异步生成场景：ComfyUI 回调时更新 completed/failed）。
    若提供 image_url，一并更新图片 URL。
    """
    node = get_node(db, node_id)
    if not node:
        return None
    node.status = status
    if image_url:
        node.image_url = image_url
    if thumbnail_url:
        node.thumbnail_url = thumbnail_url
    if execution_time_ms is not None:
        # 若存在关联边，同步更新边的执行时间
        edge = (
            db.query(AssetEdge)
            .filter(AssetEdge.target_node_id == node_id)
            .first()
        )
        if edge:
            edge.execution_time_ms = execution_time_ms
    db.commit()
    db.refresh(node)
    return node


def delete_node(db: Session, node_id: str, cascade: bool = False) -> bool:
    """
    删除节点。

    cascade=False（默认）：
      - 只允许删除叶节点（无子节点的节点）
      - 否则抛出 ValueError，要求先删除子节点或使用 cascade=True
    cascade=True：
      - 递归删除该节点及其所有后代节点（连同关联边）
      - 同步更新 Project.node_count、branch_count

    返回 True 表示成功，False 表示节点不存在。
    """
    node = get_node(db, node_id)
    if not node:
        return False

    if cascade:
        _delete_subtree(db, node)
    else:
        # 检查是否为叶节点
        child_count = (
            db.query(AssetEdge)
            .filter(AssetEdge.source_node_id == node_id)
            .count()
        )
        if child_count > 0:
            raise ValueError(
                f"节点 {node_id} 存在 {child_count} 个子节点，"
                f"请使用 cascade=True 级联删除，或先删除子节点"
            )
        _delete_single_node(db, node)

    db.commit()
    return True


def _delete_single_node(db: Session, node: AssetNode) -> None:
    """删除单个叶节点及其入边，更新 project.node_count。"""
    project = get_project(db, node.project_id)

    # 删除入边（ON DELETE CASCADE 会处理，但显式删除更清晰）
    db.query(AssetEdge).filter(AssetEdge.target_node_id == node.node_id).delete()

    # 若该节点是 current_node_id，回退到根节点
    if project and project.current_node_id == node.node_id:
        project.current_node_id = project.root_node_id

    db.delete(node)

    if project:
        project.node_count = max(0, (project.node_count or 1) - 1)


def _delete_subtree(db: Session, root_node: AssetNode) -> None:
    """
    递归删除以 root_node 为根的子树。

    使用递归 CTE 查找所有后代 node_id，然后批量删除。
    SQLite 从 3.35 开始支持递归 CTE。
    """
    root_node_id = root_node.node_id
    project_id = root_node.project_id

    # 递归 CTE 查询所有后代（含自身）
    result = db.execute(
        text("""
            WITH RECURSIVE subtree(node_id) AS (
                SELECT :root_id
                UNION ALL
                SELECT ae.target_node_id
                FROM asset_edges ae
                JOIN subtree st ON ae.source_node_id = st.node_id
            )
            SELECT node_id FROM subtree
        """),
        {"root_id": root_node_id},
    )
    all_ids = [row[0] for row in result]

    deleted_count = len(all_ids)

    # 批量删除边（source 或 target 在列表中）
    for nid in all_ids:
        db.query(AssetEdge).filter(
            (AssetEdge.source_node_id == nid) | (AssetEdge.target_node_id == nid)
        ).delete(synchronize_session=False)

    # 批量删除节点
    db.query(AssetNode).filter(AssetNode.node_id.in_(all_ids)).delete(
        synchronize_session=False
    )

    # 更新项目统计
    project = get_project(db, project_id)
    if project:
        project.node_count = max(0, (project.node_count or deleted_count) - deleted_count)
        if project.current_node_id in all_ids:
            project.current_node_id = project.root_node_id
        # 简化：删除子树后重新计算 branch_count
        project.branch_count = _calc_branch_count(db, project_id)


def _calc_branch_count(db: Session, project_id: str) -> int:
    """统计项目中出度 >= 2 的节点数（即分叉节点数）。"""
    result = db.execute(
        text("""
            SELECT COUNT(*) FROM (
                SELECT source_node_id
                FROM asset_edges
                WHERE project_id = :pid
                GROUP BY source_node_id
                HAVING COUNT(*) >= 2
            )
        """),
        {"pid": project_id},
    )
    row = result.fetchone()
    return row[0] if row else 0


# ============================================================
# 树查询操作
# ============================================================

def get_project_tree(
    db: Session,
    project_id: str,
) -> Optional[Dict[str, Any]]:
    """
    获取项目完整树结构（用于前端渲染）。

    返回：
      {
        "project": { ... },
        "nodes": [ NodeSummary, ... ],   # 按 depth, created_at 升序
        "edges": [ EdgeSummary, ... ],   # 按 created_at 升序
      }
    若项目不存在返回 None。
    """
    project = get_project(db, project_id)
    if not project:
        return None

    nodes = (
        db.query(AssetNode)
        .filter(AssetNode.project_id == project_id)
        .order_by(AssetNode.depth.asc(), AssetNode.created_at.asc())
        .all()
    )

    edges = (
        db.query(AssetEdge)
        .filter(AssetEdge.project_id == project_id)
        .order_by(AssetEdge.created_at.asc())
        .all()
    )

    # 批量加载所有节点的标签
    node_ids = [n.node_id for n in nodes]
    tags_raw = (
        db.query(NodeTag)
        .filter(NodeTag.node_id.in_(node_ids))
        .all()
        if node_ids
        else []
    )
    tags_map: Dict[str, List[NodeTag]] = {}
    for tag in tags_raw:
        tags_map.setdefault(tag.node_id, []).append(tag)

    return {
        "project": project,
        "nodes": [
            {**node_to_dict(n, tags_map.get(n.node_id, []))}
            for n in nodes
        ],
        "edges": [edge_to_dict(e) for e in edges],
    }


def get_node_ancestors(
    db: Session,
    node_id: str,
) -> Optional[Dict[str, Any]]:
    """
    获取从根节点到目标节点的完整路径（含目标节点本身）。

    利用 path 字段 O(1) 取到路径 ID 列表，然后批量查询节点和边。

    返回：
      {
        "node_id": str,
        "ancestors": [ NodeSummary, ... ],   # 按 depth 升序
        "path_edges": [ EdgeSummary, ... ],  # 路径上的操作边，按 created_at 升序
      }
    若节点不存在返回 None。
    """
    node = get_node(db, node_id)
    if not node:
        return None

    path_ids = node.path or [node_id]  # PostgreSQL UUID[] 数组

    # 按 path 顺序查询所有祖先节点（含自身）
    nodes_map: Dict[str, AssetNode] = {}
    nodes_raw = db.query(AssetNode).filter(AssetNode.node_id.in_(path_ids)).all()
    for n in nodes_raw:
        nodes_map[n.node_id] = n

    # 按路径顺序排列
    ancestor_nodes = [nodes_map[nid] for nid in path_ids if nid in nodes_map]

    # 查询路径上的操作边（source 和 target 都在路径中且 target 不是根节点）
    path_edges: List[AssetEdge] = []
    if len(path_ids) > 1:
        pairs = list(zip(path_ids[:-1], path_ids[1:]))
        for src, tgt in pairs:
            edge = (
                db.query(AssetEdge)
                .filter(
                    AssetEdge.source_node_id == src,
                    AssetEdge.target_node_id == tgt,
                )
                .first()
            )
            if edge:
                path_edges.append(edge)

    tags_map: Dict[str, List[NodeTag]] = {}
    tags_raw = (
        db.query(NodeTag).filter(NodeTag.node_id.in_(path_ids)).all()
    )
    for tag in tags_raw:
        tags_map.setdefault(tag.node_id, []).append(tag)

    return {
        "node_id": node_id,
        "ancestors": [
            node_to_dict(n, tags_map.get(n.node_id, []))
            for n in ancestor_nodes
        ],
        "path_edges": [edge_to_dict(e) for e in path_edges],
    }


def get_node_descendants(
    db: Session,
    node_id: str,
) -> Optional[Dict[str, Any]]:
    """
    获取某节点的所有后代（不含自身）。

    使用递归 CTE 遍历 asset_edges。

    返回：
      {
        "node_id": str,
        "descendants": [ NodeSummary, ... ],
      }
    若节点不存在返回 None。
    """
    node = get_node(db, node_id)
    if not node:
        return None

    result = db.execute(
        text("""
            WITH RECURSIVE subtree(node_id) AS (
                SELECT :root_id
                UNION ALL
                SELECT ae.target_node_id
                FROM asset_edges ae
                JOIN subtree st ON ae.source_node_id = st.node_id
            )
            SELECT node_id FROM subtree WHERE node_id != :root_id
        """),
        {"root_id": node_id},
    )
    descendant_ids = [row[0] for row in result]

    if not descendant_ids:
        return {"node_id": node_id, "descendants": []}

    descendants = (
        db.query(AssetNode)
        .filter(AssetNode.node_id.in_(descendant_ids))
        .order_by(AssetNode.depth.asc(), AssetNode.created_at.asc())
        .all()
    )

    tags_map: Dict[str, List[NodeTag]] = {}
    tags_raw = db.query(NodeTag).filter(NodeTag.node_id.in_(descendant_ids)).all()
    for tag in tags_raw:
        tags_map.setdefault(tag.node_id, []).append(tag)

    return {
        "node_id": node_id,
        "descendants": [
            node_to_dict(n, tags_map.get(n.node_id, []))
            for n in descendants
        ],
    }


def compare_nodes(
    db: Session,
    node_a_id: str,
    node_b_id: str,
) -> Optional[Dict[str, Any]]:
    """
    对比两个节点。

    返回两节点的完整信息，以及连接 a→b 的操作边（如果存在）。
    若任一节点不存在返回 None。
    """
    node_a = get_node(db, node_a_id)
    node_b = get_node(db, node_b_id)
    if not node_a or not node_b:
        return None

    edge = (
        db.query(AssetEdge)
        .filter(
            AssetEdge.source_node_id == node_a_id,
            AssetEdge.target_node_id == node_b_id,
        )
        .first()
    )

    tags_a = get_node_tags(db, node_a_id)
    tags_b = get_node_tags(db, node_b_id)

    return {
        "node_a": node_to_dict(node_a, tags_a),
        "node_b": node_to_dict(node_b, tags_b),
        "edge": edge_to_dict(edge) if edge else None,
    }


# ============================================================
# NodeTag 操作
# ============================================================

def add_node_tag(
    db: Session,
    node_id: str,
    label: str,
    color: str = "#4A90E2",
) -> Optional[NodeTag]:
    """为节点添加标签。若节点不存在返回 None。"""
    node = get_node(db, node_id)
    if not node:
        return None
    tag = NodeTag(
        node_id=node_id,
        label=label,
        color=color,
    )
    db.add(tag)
    db.commit()
    db.refresh(tag)
    return tag


def remove_node_tag(db: Session, tag_id: str) -> bool:
    """删除标签。返回 True 表示成功，False 表示不存在。"""
    tag = db.query(NodeTag).filter(NodeTag.tag_id == tag_id).first()
    if not tag:
        return False
    db.delete(tag)
    db.commit()
    return True
