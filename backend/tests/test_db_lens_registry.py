"""
数据库驱动 Lens 注册表的单元测试。

覆盖以下功能：
  1. 数据库表初始化（init_db）
  2. 注册新透镜（register_lens）
  3. 从数据库重载注册表（reload_registry）
  4. 查询透镜（get_lens）
  5. 注销透镜（unregister_lens）
  6. 工作流路径解析（绝对路径 / 相对路径 / 不存在的路径）
  7. 覆盖已有透镜（更新场景）
"""

import json
import os
import tempfile

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database import Base
from app.lenses import registry
from app.models.lens_model import LensRecord


# ============================================================
# 测试夹具：临时数据库与测试工作流文件
# ============================================================

@pytest.fixture(scope="function")
def temp_db():
    """为每个测试创建独立的临时 SQLite 数据库。"""
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    db = SessionLocal()
    yield db
    db.close()
    engine.dispose()


@pytest.fixture(scope="function")
def temp_workflow_dir():
    """创建临时目录并生成测试用的工作流 JSON 文件。"""
    with tempfile.TemporaryDirectory() as tmpdir:
        # 生成一个简单的 ComfyUI 工作流 JSON（最小化示例）
        workflow_content = {
            "1": {"inputs": {"image": "placeholder.png"}, "class_type": "LoadImage"},
            "2": {"inputs": {"text": "a beautiful scene"}, "class_type": "CLIPTextEncode"},
        }
        workflow_path = os.path.join(tmpdir, "test_lens_workflow.json")
        with open(workflow_path, "w", encoding="utf-8") as f:
            json.dump(workflow_content, f)
        yield tmpdir, workflow_path


# ============================================================
# 测试：注册与查询基础流程
# ============================================================

def test_register_lens_creates_db_record_and_memory_entry(temp_db, temp_workflow_dir):
    """注册一个新透镜应同时写入数据库和内存注册表。"""
    _, workflow_path = temp_workflow_dir

    data = {
        "lens_id": "lens_test_basic",
        "layer": "A1",
        "description": "测试用透镜",
        "workflow_file_path": workflow_path,
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

    template = registry.register_lens(temp_db, data)

    # 验证返回的 LensTemplate
    assert template.lens_id == "lens_test_basic"
    assert template.layer.value == "A1"
    assert len(template.inputs) == 1
    assert len(template.outputs) == 1
    assert len(template.params) == 1

    # 验证数据库记录
    record = temp_db.query(LensRecord).filter(LensRecord.lens_id == "lens_test_basic").first()
    assert record is not None
    assert record.layer == "A1"
    assert record.description == "测试用透镜"

    # 验证内存注册表
    assert "lens_test_basic" in registry.LENS_REGISTRY
    assert registry.LENS_REGISTRY["lens_test_basic"].lens_id == "lens_test_basic"


def test_get_lens_retrieves_from_memory(temp_db, temp_workflow_dir):
    """get_lens() 应从内存注册表中获取透镜。"""
    _, workflow_path = temp_workflow_dir

    data = {
        "lens_id": "lens_test_get",
        "layer": "A2",
        "description": "测试查询",
        "workflow_file_path": workflow_path,
        "inputs": [],
        "outputs": [],
        "params": [],
    }

    registry.register_lens(temp_db, data)

    template = registry.get_lens("lens_test_get")
    assert template.lens_id == "lens_test_get"
    assert template.layer.value == "A2"


def test_get_lens_raises_keyerror_for_nonexistent(temp_db):
    """对不存在的 lens_id 调用 get_lens() 应抛出 KeyError。"""
    # 清空内存注册表
    registry.LENS_REGISTRY.clear()

    with pytest.raises(KeyError) as exc_info:
        registry.get_lens("nonexistent_lens")
    assert "nonexistent_lens" in str(exc_info.value)


# ============================================================
# 测试：注销透镜
# ============================================================

def test_unregister_lens_removes_from_db_and_memory(temp_db, temp_workflow_dir):
    """注销透镜应同时删除数据库记录和内存条目。"""
    _, workflow_path = temp_workflow_dir

    data = {
        "lens_id": "lens_test_unregister",
        "layer": "A1",
        "description": "将被注销",
        "workflow_file_path": workflow_path,
        "inputs": [],
        "outputs": [],
        "params": [],
    }

    registry.register_lens(temp_db, data)
    assert "lens_test_unregister" in registry.LENS_REGISTRY

    success = registry.unregister_lens(temp_db, "lens_test_unregister")
    assert success is True

    # 验证数据库中已删除
    record = temp_db.query(LensRecord).filter(LensRecord.lens_id == "lens_test_unregister").first()
    assert record is None

    # 验证内存注册表中已移除
    assert "lens_test_unregister" not in registry.LENS_REGISTRY


def test_unregister_nonexistent_lens_returns_false(temp_db):
    """注销不存在的透镜应返回 False。"""
    success = registry.unregister_lens(temp_db, "nonexistent_lens")
    assert success is False


# ============================================================
# 测试：重载注册表
# ============================================================

def test_reload_registry_loads_all_lenses_from_db(temp_db, temp_workflow_dir):
    """reload_registry 应从数据库全量加载所有透镜到内存。"""
    _, workflow_path = temp_workflow_dir

    # 先直接在数据库中插入几条记录（绕过 register_lens，模拟冷启动场景）
    for i in range(3):
        record = LensRecord(
            lens_id=f"lens_reload_test_{i}",
            layer="A1",
            description=f"测试透镜 {i}",
            workflow_file_path=workflow_path,
            inputs_json="[]",
            outputs_json="[]",
            params_json="[]",
        )
        temp_db.add(record)
    temp_db.commit()

    # 清空内存注册表，模拟应用启动前状态
    registry.LENS_REGISTRY.clear()
    assert len(registry.LENS_REGISTRY) == 0

    # 重载
    result = registry.reload_registry(temp_db)

    # 验证内存注册表已加载全部 3 个透镜
    assert len(registry.LENS_REGISTRY) == 3
    assert "lens_reload_test_0" in registry.LENS_REGISTRY
    assert "lens_reload_test_1" in registry.LENS_REGISTRY
    assert "lens_reload_test_2" in registry.LENS_REGISTRY

    # 验证返回值（副本）
    assert len(result) == 3


# ============================================================
# 测试：覆盖已有透镜（更新场景）
# ============================================================

def test_register_existing_lens_updates_record(temp_db, temp_workflow_dir):
    """对已存在的 lens_id 再次调用 register_lens 应更新记录，而非新建。"""
    _, workflow_path = temp_workflow_dir

    data_v1 = {
        "lens_id": "lens_test_update",
        "layer": "A1",
        "description": "初始版本",
        "workflow_file_path": workflow_path,
        "inputs": [],
        "outputs": [],
        "params": [],
    }

    registry.register_lens(temp_db, data_v1)

    # 更新描述和层级
    data_v2 = {
        "lens_id": "lens_test_update",
        "layer": "A2",
        "description": "更新后版本",
        "workflow_file_path": workflow_path,
        "inputs": [],
        "outputs": [],
        "params": [
            {"name": "new_param", "type": "float", "description": "新增参数", "mapping": {"node_id": "2", "field_name": "value"}}
        ],
    }

    registry.register_lens(temp_db, data_v2)

    # 验证数据库中只有一条记录，且为更新后的值
    records = temp_db.query(LensRecord).filter(LensRecord.lens_id == "lens_test_update").all()
    assert len(records) == 1
    assert records[0].layer == "A2"
    assert records[0].description == "更新后版本"

    # 验证内存注册表已更新
    template = registry.get_lens("lens_test_update")
    assert template.layer.value == "A2"
    assert len(template.params) == 1
    assert template.params[0].name == "new_param"


# ============================================================
# 测试：工作流路径解析
# ============================================================

def test_register_lens_with_absolute_path(temp_db, temp_workflow_dir):
    """workflow_file_path 为绝对路径时应正常加载。"""
    _, workflow_path = temp_workflow_dir

    data = {
        "lens_id": "lens_test_abs_path",
        "layer": "A1",
        "description": "绝对路径测试",
        "workflow_file_path": workflow_path,  # 绝对路径
        "inputs": [],
        "outputs": [],
        "params": [],
    }

    template = registry.register_lens(temp_db, data)
    assert template.lens_id == "lens_test_abs_path"
    assert template.raw_workflow is not None


def test_register_lens_with_nonexistent_path_raises_error(temp_db):
    """workflow_file_path 指向不存在的文件应抛出 FileNotFoundError。"""
    data = {
        "lens_id": "lens_test_bad_path",
        "layer": "A1",
        "description": "不存在的路径",
        "workflow_file_path": "/nonexistent/path/to/workflow.json",
        "inputs": [],
        "outputs": [],
        "params": [],
    }

    with pytest.raises(FileNotFoundError) as exc_info:
        registry.register_lens(temp_db, data)
    assert "workflow.json" in str(exc_info.value)


# ============================================================
# 测试：单个透镜加载失败不阻塞整个注册表
# ============================================================

def test_reload_registry_skips_broken_lenses(temp_db, temp_workflow_dir):
    """reload_registry 时某个透镜加载失败应跳过该透镜，不影响其它透镜加载。"""
    _, valid_workflow_path = temp_workflow_dir

    # 插入一条正常记录
    good_record = LensRecord(
        lens_id="lens_good",
        layer="A1",
        description="正常透镜",
        workflow_file_path=valid_workflow_path,
        inputs_json="[]",
        outputs_json="[]",
        params_json="[]",
    )
    temp_db.add(good_record)

    # 插入一条指向不存在文件的记录（会导致加载失败）
    bad_record = LensRecord(
        lens_id="lens_bad",
        layer="A1",
        description="坏透镜",
        workflow_file_path="/path/to/nonexistent.json",
        inputs_json="[]",
        outputs_json="[]",
        params_json="[]",
    )
    temp_db.add(bad_record)
    temp_db.commit()

    registry.LENS_REGISTRY.clear()

    # 重载（不应抛出异常）
    result = registry.reload_registry(temp_db)

    # 应只加载成功的那一个
    assert len(result) == 1
    assert "lens_good" in result
    assert "lens_bad" not in result
