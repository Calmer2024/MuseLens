import pytest

from app.schemas.lens import DAGBlueprint, DAGStep
from app.schemas.router import (
    RouterAnswerRequest,
    RouterCompileRequest,
    RouterStatus,
)
from app.services.router_service import RouterService


def test_compile_or_ask_ready_when_prompt_complete():
    """
    当提示词中同时包含目标物体与替换内容时，应直接返回 READY 状态且 Blueprint 合法。
    """
    service = RouterService()
    req = RouterCompileRequest(
        user_id="u_test",
        user_prompt="把桌上的水杯换成一盆多肉，背景调暗点",
        base_image="upload_raw.png",
    )

    resp = service.compile_or_ask(req)

    assert resp.status == RouterStatus.READY
    assert resp.blueprint is not None
    assert len(resp.blueprint.steps) == 2
    step_ids = [s.step_id for s in resp.blueprint.steps]
    assert "step_1_matting" in step_ids
    assert "step_2_inpaint" in step_ids


def test_compile_or_ask_need_clarification_when_info_missing():
    """
    当提示词未明确目标物体与替换内容时，应返回 need_clarification 且包含追问。
    """
    service = RouterService()
    req = RouterCompileRequest(
        user_id="u_test",
        user_prompt="帮我把这张图改一改",
        base_image="upload_raw.png",
    )

    resp = service.compile_or_ask(req)

    assert resp.status == RouterStatus.NEED_CLARIFICATION
    assert resp.questions
    q_ids = {q.id for q in resp.questions}
    assert "q_target_object" in q_ids
    assert "q_replace_with" in q_ids


def test_answer_flow_fills_params_and_becomes_ready():
    """
    先触发追问，再通过 answer 回填答案，最终应得到 READY 状态且参数被正确填充。
    """
    service = RouterService()

    # 第一次调用，触发追问
    first = service.compile_or_ask(
        RouterCompileRequest(
            user_id="u_test",
            user_prompt="请把这张图改一下",
            base_image="upload_raw.png",
        )
    )
    assert first.status == RouterStatus.NEED_CLARIFICATION
    session_id = first.session_id

    # 回答追问
    answer_req = RouterAnswerRequest(
        session_id=session_id,
        answers={
            "q_target_object": "桌上的水杯",
            "q_replace_with": "一盆绿色多肉植物",
        },
    )

    second = service.answer(answer_req)

    assert second.status == RouterStatus.READY
    assert second.blueprint is not None
    steps = {s.step_id: s for s in second.blueprint.steps}
    assert steps["step_1_matting"].params.get("prompt") == "桌上的水杯"
    assert (
        steps["step_2_inpaint"].params.get("positive_prompt") == "一盆绿色多肉植物"
    )


def test_validate_links_raises_on_invalid_reference():
    """当 Blueprint 中存在引用不存在的变量时，_validate_links 应抛出 ValueError。"""
    blueprint = DAGBlueprint(
        initial_inputs={"user_base_image": "x.png"},
        steps=[
            DAGStep(
                step_id="step_1",
                lens_id="lens_sam2_matting",
                input_links={"base_image": "$user_base_image"},
                params={},
            ),
            DAGStep(
                step_id="step_2",
                lens_id="lens_inpaint_bg",
                input_links={
                    "base_image": "$user_base_image",
                    "mask_target": "$step_1.nonexistent_output",  # 不存在
                },
                params={},
            ),
        ],
    )
    # 当前实现只把 step_id.mask_result 和 step_id.result_image 加入 available，
    # 所以 $step_1.nonexistent_output 会找不到
    with pytest.raises(ValueError) as exc_info:
        RouterService._validate_links(blueprint)
    assert "step_2" in str(exc_info.value) or "nonexistent" in str(exc_info.value)


def test_validate_links_passes_when_refs_valid():
    """当所有 $ 引用均存在于 initial_inputs 或前序步骤约定输出时，不抛异常。"""
    blueprint = DAGBlueprint(
        initial_inputs={"user_base_image": "x.png"},
        steps=[
            DAGStep(
                step_id="step_1_matting",
                lens_id="lens_sam2_matting",
                input_links={"base_image": "$user_base_image"},
                params={},
            ),
            DAGStep(
                step_id="step_2_inpaint",
                lens_id="lens_inpaint_bg",
                input_links={
                    "base_image": "$user_base_image",
                    "mask_target": "$step_1_matting.mask_result",
                },
                params={},
            ),
        ],
    )
    RouterService._validate_links(blueprint)  # 不应抛出


def test_compile_or_ask_retrieved_lenses_in_extra():
    """compile_or_ask 的 extra 中应包含 retrieved_lenses 列表。"""
    service = RouterService()
    req = RouterCompileRequest(
        user_id="u_test",
        user_prompt="把水杯换成多肉",
        base_image="upload_raw.png",
    )
    resp = service.compile_or_ask(req)
    assert "retrieved_lenses" in resp.extra
    assert isinstance(resp.extra["retrieved_lenses"], list)


def test_answer_nonexistent_session_raises():
    """对不存在的 session_id 调用 answer 应抛出 ValueError。"""
    service = RouterService()
    with pytest.raises(ValueError) as exc_info:
        service.answer(
            RouterAnswerRequest(
                session_id="nonexistent-session-id",
                answers={"q_target_object": "x"},
            )
        )
    assert "不存在" in str(exc_info.value) or "过期" in str(exc_info.value)

