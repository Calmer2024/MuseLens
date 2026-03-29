"""
Lens 注册表与配置加载的自动化测试。

覆盖本阶段新增的 lens 配置：lens_depth_extract、lens_inpaint_bg、lens_sam2_matting。
"""

import pytest

from app.lenses.registry import LENS_REGISTRY, get_lens


# 本阶段新增的 lens_id（与 config/*.lens.json 一致）
EXPECTED_NEW_LENS_IDS = {"lens_depth_extract", "lens_inpaint_bg", "lens_sam2_matting"}


def test_registry_contains_new_lens_configs():
    """LENS_REGISTRY 应包含本阶段新增的三个透镜配置。"""
    for lens_id in EXPECTED_NEW_LENS_IDS:
        assert lens_id in LENS_REGISTRY, f"注册表中应包含 {lens_id}"


def test_registry_lens_templates_have_required_fields():
    """每个透镜模板应具备 lens_id、layer、description、inputs/outputs/params。"""
    for lens_id in EXPECTED_NEW_LENS_IDS:
        tmpl = LENS_REGISTRY[lens_id]
        assert tmpl.lens_id == lens_id
        assert tmpl.layer is not None
        assert tmpl.description is not None
        assert tmpl.raw_workflow is not None
        assert isinstance(tmpl.inputs, list)
        assert isinstance(tmpl.outputs, list)
        assert isinstance(tmpl.params, list)


def test_lens_depth_extract_schema():
    """lens_depth_extract 为 A1 层，无 params，输出 depth_map。"""
    tmpl = LENS_REGISTRY["lens_depth_extract"]
    assert tmpl.layer.value == "A1"
    assert tmpl.params == []
    out_names = [o.name for o in tmpl.outputs]
    assert "depth_map" in out_names


def test_lens_inpaint_bg_schema():
    """lens_inpaint_bg 为 A2 层，含 positive_prompt 参数，输出 result_image。"""
    tmpl = LENS_REGISTRY["lens_inpaint_bg"]
    assert tmpl.layer.value == "A2"
    param_names = [p.name for p in tmpl.params]
    assert "positive_prompt" in param_names
    out_names = [o.name for o in tmpl.outputs]
    assert "result_image" in out_names


def test_lens_sam2_matting_schema():
    """lens_sam2_matting 为 A1 层，含 prompt 参数，输出 mask_result。"""
    tmpl = LENS_REGISTRY["lens_sam2_matting"]
    assert tmpl.layer.value == "A1"
    param_names = [p.name for p in tmpl.params]
    assert "prompt" in param_names
    out_names = [o.name for o in tmpl.outputs]
    assert "mask_result" in out_names


def test_get_lens_returns_template_for_known_id():
    """get_lens 对已知 lens_id 应返回对应 LensTemplate。"""
    for lens_id in EXPECTED_NEW_LENS_IDS:
        tmpl = get_lens(lens_id)
        assert tmpl.lens_id == lens_id


def test_get_lens_raises_for_unknown_id():
    """get_lens 对未知 lens_id 应抛出 KeyError。"""
    with pytest.raises(KeyError) as exc_info:
        get_lens("nonexistent_lens_id")
    assert "nonexistent_lens_id" in str(exc_info.value)
