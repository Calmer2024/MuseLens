from app.services.router_service import RouterService
from app.schemas.router import (
    RouterAnswerRequest,
    RouterCompileRequest,
    RouterStatus,
)


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

