"""
Lens 管理 API 的集成测试。

测试端点：
  POST   /api/v1/lenses/register
  GET    /api/v1/lenses/
  GET    /api/v1/lenses/{lens_id}
  DELETE /api/v1/lenses/{lens_id}
  POST   /api/v1/lenses/reload
"""

import json
import os
import tempfile

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database import Base, get_db
from app.lenses import registry
from app.main import app


# ============================================================
# 测试夹具：独立数据库与覆盖依赖注入
# ============================================================

@pytest.fixture(scope="function")
def test_db():
    """为每个测试创建独立的内存数据库。"""
    # 关键：SQLite 的 ":memory:" 是“每个连接一份”，测试请求会产生多个连接；
    # 用 StaticPool 让整个测试函数复用同一连接，避免出现 “no such table”。
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

    def override_get_db():
        db = TestingSessionLocal()
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[get_db] = override_get_db

    db = TestingSessionLocal()
    yield db
    db.close()
    engine.dispose()

    # 清理：恢复原依赖并清空内存注册表
    app.dependency_overrides.clear()
    registry.LENS_REGISTRY.clear()
    registry.load_builtin_lenses_into_memory()


@pytest.fixture(scope="function")
def client(test_db):
    """FastAPI 测试客户端。"""
    return TestClient(app)


@pytest.fixture(scope="function")
def temp_workflow_file():
    """创建临时工作流 JSON 文件。"""
    with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False, encoding="utf-8") as f:
        workflow_content = {
            "1": {"inputs": {"image": "test.png"}, "class_type": "LoadImage"},
            "2": {"inputs": {"text": "test prompt"}, "class_type": "CLIPTextEncode"},
        }
        json.dump(workflow_content, f)
        temp_path = f.name

    yield temp_path

    # 清理临时文件
    if os.path.exists(temp_path):
        os.remove(temp_path)


# ============================================================
# 测试：POST /api/v1/lenses/register
# ============================================================

def test_register_lens_via_api_creates_record(client, temp_workflow_file):
    """通过 API 注册透镜应成功创建数据库记录和内存条目。"""
    payload = {
        "lens_id": "lens_api_test_1",
        "layer": "A1",
        "description": "API 测试透镜",
        "workflow_file_path": temp_workflow_file,
        "inputs": [
            {"name": "base_image", "type": "image", "mapping": {"node_id": "1", "field_name": "image"}}
        ],
        "outputs": [
            {"name": "result_image", "type": "image", "mapping": {"node_id": "1", "field_name": "images"}}
        ],
        "params": [
            {"name": "prompt", "type": "text", "description": "提示词", "mapping": {"node_id": "2", "field_name": "text"}}
        ],
    }

    response = client.post("/api/v1/lenses/register", json=payload)

    assert response.status_code == 200
    data = response.json()
    assert data["lens_id"] == "lens_api_test_1"
    assert data["layer"] == "A1"
    assert data["description"] == "API 测试透镜"
    assert "created_at" in data
    assert "updated_at" in data


def test_register_lens_with_invalid_workflow_path_returns_422(client):
    """注册时提供不存在的工作流路径应返回 422 错误。"""
    payload = {
        "lens_id": "lens_api_bad_path",
        "layer": "A1",
        "description": "坏路径测试",
        "workflow_file_path": "/nonexistent/workflow.json",
        "inputs": [],
        "outputs": [],
        "params": [],
    }

    response = client.post("/api/v1/lenses/register", json=payload)

    assert response.status_code == 422
    assert "未找到" in response.json()["detail"]


def test_register_lens_twice_updates_existing(client, temp_workflow_file):
    """对同一 lens_id 注册两次应覆盖，而非报错。"""
    payload_v1 = {
        "lens_id": "lens_api_update",
        "layer": "A1",
        "description": "初始版本",
        "workflow_file_path": temp_workflow_file,
        "inputs": [],
        "outputs": [],
        "params": [],
    }

    response1 = client.post("/api/v1/lenses/register", json=payload_v1)
    assert response1.status_code == 200

    payload_v2 = {
        "lens_id": "lens_api_update",
        "layer": "A2",
        "description": "更新版本",
        "workflow_file_path": temp_workflow_file,
        "inputs": [],
        "outputs": [],
        "params": [
            {"name": "new_param", "type": "float", "description": "新参数", "mapping": {"node_id": "2", "field_name": "value"}}
        ],
    }

    response2 = client.post("/api/v1/lenses/register", json=payload_v2)
    assert response2.status_code == 200

    data = response2.json()
    assert data["layer"] == "A2"
    assert data["description"] == "更新版本"


# ============================================================
# 测试：GET /api/v1/lenses/
# ============================================================

def test_list_lenses_returns_all_registered(client, temp_workflow_file):
    """列出透镜应返回所有已注册透镜的概要信息。"""
    # 先注册两个透镜
    for i in range(2):
        payload = {
            "lens_id": f"lens_api_list_{i}",
            "layer": "A1",
            "description": f"列表测试 {i}",
            "workflow_file_path": temp_workflow_file,
            "inputs": [],
            "outputs": [],
            "params": [],
        }
        client.post("/api/v1/lenses/register", json=payload)

    response = client.get("/api/v1/lenses/")

    assert response.status_code == 200
    data = response.json()
    assert len(data) == 2
    assert data[0]["lens_id"] in ["lens_api_list_0", "lens_api_list_1"]


def test_list_lenses_empty_when_no_lenses(client):
    """无任何透镜时应返回空列表。"""
    response = client.get("/api/v1/lenses/")

    assert response.status_code == 200
    data = response.json()
    assert data == []


# ============================================================
# 测试：GET /api/v1/lenses/{lens_id}
# ============================================================

def test_get_lens_detail_returns_full_info(client, temp_workflow_file):
    """查看单个透镜详情应返回完整的 inputs/outputs/params 定义。"""
    payload = {
        "lens_id": "lens_api_detail",
        "layer": "A2",
        "description": "详情测试",
        "workflow_file_path": temp_workflow_file,
        "inputs": [
            {"name": "input_1", "type": "image", "mapping": {"node_id": "1", "field_name": "image"}}
        ],
        "outputs": [
            {"name": "output_1", "type": "image", "mapping": {"node_id": "1", "field_name": "images"}}
        ],
        "params": [
            {"name": "param_1", "type": "text", "description": "参数1", "mapping": {"node_id": "2", "field_name": "text"}}
        ],
    }

    client.post("/api/v1/lenses/register", json=payload)

    response = client.get("/api/v1/lenses/lens_api_detail")

    assert response.status_code == 200
    data = response.json()
    assert data["lens_id"] == "lens_api_detail"
    assert len(data["inputs"]) == 1
    assert len(data["outputs"]) == 1
    assert len(data["params"]) == 1
    assert data["inputs"][0]["name"] == "input_1"


def test_get_lens_detail_nonexistent_returns_404(client):
    """查看不存在的透镜应返回 404。"""
    response = client.get("/api/v1/lenses/nonexistent_lens")

    assert response.status_code == 404
    assert "不存在" in response.json()["detail"]


# ============================================================
# 测试：DELETE /api/v1/lenses/{lens_id}
# ============================================================

def test_delete_lens_removes_record(client, temp_workflow_file):
    """删除透镜应移除数据库记录和内存条目。"""
    payload = {
        "lens_id": "lens_api_delete",
        "layer": "A1",
        "description": "待删除",
        "workflow_file_path": temp_workflow_file,
        "inputs": [],
        "outputs": [],
        "params": [],
    }

    client.post("/api/v1/lenses/register", json=payload)

    # 确认注册成功
    assert "lens_api_delete" in registry.LENS_REGISTRY

    response = client.delete("/api/v1/lenses/lens_api_delete")

    assert response.status_code == 200
    assert "成功注销" in response.json()["detail"]

    # 确认已移除
    assert "lens_api_delete" not in registry.LENS_REGISTRY

    # 再次查询应返回 404
    response2 = client.get("/api/v1/lenses/lens_api_delete")
    assert response2.status_code == 404


def test_delete_nonexistent_lens_returns_404(client):
    """删除不存在的透镜应返回 404。"""
    response = client.delete("/api/v1/lenses/nonexistent_lens")

    assert response.status_code == 404
    assert "不存在" in response.json()["detail"]


# ============================================================
# 测试：POST /api/v1/lenses/reload
# ============================================================

def test_reload_registry_via_api(client, temp_workflow_file, test_db):
    """调用 reload 端点应从数据库重新加载注册表。"""
    from app.models.lens_model import LensRecord

    # 直接在数据库中插入一条记录（绕过 API，模拟外部数据源）
    record = LensRecord(
        lens_id="lens_api_reload_test",
        layer="A1",
        description="重载测试",
        workflow_file_path=temp_workflow_file,
        inputs_json="[]",
        outputs_json="[]",
        params_json="[]",
    )
    test_db.add(record)
    test_db.commit()

    # 清空内存注册表
    registry.LENS_REGISTRY.clear()

    response = client.post("/api/v1/lenses/reload")

    assert response.status_code == 200
    data = response.json()
    assert "已重载" in data["detail"]
    assert "lens_api_reload_test" in data["lens_ids"]
    assert len(data["lens_ids"]) == 1

    # 验证内存注册表已更新
    assert "lens_api_reload_test" in registry.LENS_REGISTRY
