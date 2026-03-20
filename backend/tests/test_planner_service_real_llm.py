import os

import pytest

from app.schemas.planner import PlannerInput
from app.services.planner_service import PlannerService


def _require_env(name: str) -> str:
    val = os.getenv(name, "").strip()
    if not val:
        raise RuntimeError(f"环境变量缺失：{name}")
    return val


def _build_planner_input_for_lens_pair() -> PlannerInput:
    """
    组织一个与 RouterService 传给 PlannerService 一致的 candidates 结构（LensKnowledge.model_dump）。
    目标：让 LLM 在“信息足够”时直接输出 blueprint。
    """
    candidates = [
        {
            "lens_id": "lens_sam2_matting",
            "score": 0.95,
            "layer": "A1",
            "description": "目标物体抠图/分割（matting），输出 mask_result。",
            "params": [
                {
                    "name": "prompt",
                    "type": "text",
                    "description": "要抠出的目标物体描述，例如“杯子/人物/猫”。",
                    "required": True,
                    "default": "",
                }
            ],
            "examples": [],
        },
        {
            "lens_id": "lens_inpaint_bg",
            "score": 0.9,
            "layer": "A2",
            "description": "基于 mask 进行局部重绘/换背景（inpaint），输出 result_image。",
            "params": [
                {
                    "name": "positive_prompt",
                    "type": "text",
                    "description": "你希望替换后的新背景/新内容的一句话描述。",
                    "required": True,
                    "default": "",
                }
            ],
            "examples": [],
        },
    ]

    return PlannerInput(
        task_desc="请把杯子换成一盆多肉植物（主体保持不变）。",
        base_image_meta={},
        candidates=candidates,
        session_context={},
    )


@pytest.mark.integration
def test_planner_service_real_llm_produces_valid_output():
    """
    真正调用 LLM（不需要 comfyui），验证 PlannerService 能否：
    1) 调用 `/chat/completions` 成功；
    2) 返回的内容能被 PlannerOutput 校验解析；
    3) 如生成 blueprint，则 lens_id 必须来自 candidates。

    为了避免误触发真实联网/计费，默认要求显式设置：
    - MUSELENS_TEST_REAL_LLM=1
    并且提供：
    - MUSELENS_LLM_API_KEY
    - MUSELENS_LLM_MODEL
    """

    if os.getenv("MUSELENS_TEST_REAL_LLM", "").strip() != "1":
        pytest.skip("未开启真实 LLM 测试：设置 MUSELENS_TEST_REAL_LLM=1 后再运行。")

    _require_env("MUSELENS_LLM_API_KEY")
    _require_env("MUSELENS_LLM_MODEL")

    planner = PlannerService(timeout_s=30)
    planner_input = _build_planner_input_for_lens_pair()
    out = planner.plan(planner_input)

    assert out is not None
    assert isinstance(out.thought, str)

    candidate_lens_ids = {c["lens_id"] for c in planner_input.candidates}

    # 至少应该返回一种“可继续推进”的结构：
    # - 要么直接给 blueprint（ready）
    # - 要么给出需要澄清/缺失的参数（need_clarification）
    if out.blueprint is not None:
        assert out.blueprint.steps, "LLM 返回 blueprint 但 steps 为空"
        used_lens_ids = {step.lens_id for step in out.blueprint.steps}
        assert used_lens_ids.issubset(candidate_lens_ids)
    else:
        assert out.missing_params or out.clarification_questions, (
            "LLM 未返回 blueprint，同时也没有给 missing_params/clarification_questions，"
            "导致无法继续推进。"
        )

        # 校验 missing/clarification 仍然引用了 candidates 中的 lens_id
        for mp in out.missing_params:
            assert mp.lens_id in candidate_lens_ids
        for q in out.clarification_questions:
            assert q.param_ref.lens_id in candidate_lens_ids

