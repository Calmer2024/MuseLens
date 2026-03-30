from app.schemas.planner import PlannerInput, PlannerOutput
from app.services import planner_service
from app.services.planner_service import _postprocess_planner_output


def test_postprocess_builds_relighting_blueprint_from_task_desc():
    planner_input = PlannerInput(
        task_desc="调整图片中的光影，调整为黄昏的光从图片的右上角照下",
        base_image_meta={},
        candidates=[
            {
                "lens_id": "lens_relighting",
                "score": 0.9,
                "layer": "A3",
                "description": "全局光影重构",
                "notes": "",
                "inputs": [
                    {"name": "base_image", "type": "image"},
                    {"name": "depth_map", "type": "depth_map"},
                ],
                "outputs": [{"name": "result_image", "type": "image"}],
                "params": [
                    {"name": "prompt", "type": "text", "required": True},
                ],
                "examples": [],
            },
            {
                "lens_id": "lens_depth_extract",
                "score": 0.6,
                "layer": "A1",
                "description": "深度提取",
                "notes": "",
                "inputs": [{"name": "base_image", "type": "image"}],
                "outputs": [{"name": "depth_map", "type": "depth_map"}],
                "params": [],
                "examples": [],
            },
        ],
        session_context={},
    )

    out = _postprocess_planner_output(
        PlannerOutput(blueprint=None, missing_params=[], clarification_questions=[], thought=""),
        planner_input,
    )

    assert out.blueprint is not None
    assert out.missing_params == []
    assert out.clarification_questions == []
    assert [step.lens_id for step in out.blueprint.steps] == [
        "lens_depth_extract",
        "lens_relighting",
    ]
    assert out.blueprint.steps[1].params["prompt"] == planner_input.task_desc


def test_postprocess_builds_local_replace_blueprint_from_task_desc():
    planner_input = PlannerInput(
        task_desc="把图中的女人替换成一只猪",
        base_image_meta={},
        candidates=[
            {
                "lens_id": "lens_flux_inpaint",
                "score": 0.95,
                "layer": "A2",
                "description": "局部遮罩重绘，用于主体替换",
                "notes": "",
                "inputs": [
                    {"name": "base_image", "type": "image"},
                    {"name": "mask", "type": "mask"},
                ],
                "outputs": [{"name": "result_image", "type": "image"}],
                "params": [
                    {"name": "prompt", "type": "text", "required": True},
                ],
                "examples": [],
            },
            {
                "lens_id": "lens_sam2_matting",
                "score": 0.8,
                "layer": "A1",
                "description": "文本分割并输出遮罩",
                "notes": "",
                "inputs": [{"name": "base_image", "type": "image"}],
                "outputs": [{"name": "mask_result", "type": "image"}],
                "params": [
                    {"name": "prompt", "type": "text", "required": True},
                ],
                "examples": [],
            },
        ],
        session_context={},
    )

    out = _postprocess_planner_output(
        PlannerOutput(blueprint=None, missing_params=[], clarification_questions=[], thought=""),
        planner_input,
    )

    assert out.blueprint is not None
    assert out.missing_params == []
    assert out.clarification_questions == []
    assert [step.lens_id for step in out.blueprint.steps] == [
        "lens_sam2_matting",
        "lens_flux_inpaint",
    ]
    assert out.blueprint.steps[0].params["prompt"] == "女人"
    assert out.blueprint.steps[1].params["prompt"] == planner_input.task_desc


def test_postprocess_prefers_global_edit_for_background_replacement():
    planner_input = PlannerInput(
        task_desc="将图片中女人的背景替换为法国巴黎的埃菲尔铁塔",
        base_image_meta={},
        candidates=[
            {
                "lens_id": "lens_flux_inpaint",
                "score": 0.95,
                "layer": "A2",
                "description": "局部遮罩重绘，用于局部替换",
                "notes": "",
                "inputs": [
                    {"name": "base_image", "type": "image"},
                    {"name": "mask", "type": "mask"},
                ],
                "outputs": [{"name": "result_image", "type": "image"}],
                "params": [{"name": "prompt", "type": "text", "required": True}],
                "examples": [],
            },
            {
                "lens_id": "lens_flux_edit",
                "score": 0.8,
                "layer": "A2",
                "description": "全局语义重绘，适合整体背景和场景改写",
                "notes": "",
                "inputs": [{"name": "base_image", "type": "image"}],
                "outputs": [{"name": "result_image", "type": "image"}],
                "params": [{"name": "prompt", "type": "text", "required": True}],
                "examples": [],
            },
            {
                "lens_id": "lens_sam2_matting",
                "score": 0.7,
                "layer": "A1",
                "description": "文本分割并输出遮罩",
                "notes": "",
                "inputs": [{"name": "base_image", "type": "image"}],
                "outputs": [{"name": "mask_result", "type": "image"}],
                "params": [{"name": "prompt", "type": "text", "required": True}],
                "examples": [],
            },
        ],
        session_context={},
    )

    out = _postprocess_planner_output(
        PlannerOutput(blueprint=None, missing_params=[], clarification_questions=[], thought=""),
        planner_input,
    )

    assert out.blueprint is not None
    assert [step.lens_id for step in out.blueprint.steps] == ["lens_flux_edit"]
    assert out.blueprint.steps[0].params["prompt"] == planner_input.task_desc


def test_postprocess_allows_a5_as_main_for_upscale_request():
    planner_input = PlannerInput(
        task_desc="把这张图片放大成高清图",
        base_image_meta={},
        candidates=[
            {
                "lens_id": "lens_upscale_4x",
                "score": 0.7,
                "layer": "A5",
                "description": "高清放大和细节增强",
                "notes": "",
                "inputs": [{"name": "base_image", "type": "image"}],
                "outputs": [{"name": "result_image", "type": "image"}],
                "params": [{"name": "prompt", "type": "text", "required": False}],
                "examples": [],
            },
            {
                "lens_id": "lens_flux_edit",
                "score": 0.9,
                "layer": "A2",
                "description": "全局语义重绘",
                "notes": "",
                "inputs": [{"name": "base_image", "type": "image"}],
                "outputs": [{"name": "result_image", "type": "image"}],
                "params": [{"name": "prompt", "type": "text", "required": True}],
                "examples": [],
            },
        ],
        session_context={},
    )

    out = _postprocess_planner_output(
        PlannerOutput(blueprint=None, missing_params=[], clarification_questions=[], thought=""),
        planner_input,
    )

    assert out.blueprint is not None
    assert [step.lens_id for step in out.blueprint.steps] == ["lens_upscale_4x"]


def test_postprocess_allows_a5_as_main_for_watermark_request():
    planner_input = PlannerInput(
        task_desc="给这张图添加品牌水印 MuseLens",
        base_image_meta={},
        candidates=[
            {
                "lens_id": "lens_watermark",
                "score": 0.7,
                "layer": "A5",
                "description": "添加文字水印",
                "notes": "",
                "inputs": [{"name": "base_image", "type": "image"}],
                "outputs": [{"name": "result_image", "type": "image"}],
                "params": [{"name": "text", "type": "text", "required": True}],
                "examples": [],
            },
            {
                "lens_id": "lens_flux_edit",
                "score": 0.9,
                "layer": "A2",
                "description": "全局语义重绘",
                "notes": "",
                "inputs": [{"name": "base_image", "type": "image"}],
                "outputs": [{"name": "result_image", "type": "image"}],
                "params": [{"name": "prompt", "type": "text", "required": True}],
                "examples": [],
            },
        ],
        session_context={},
    )

    out = _postprocess_planner_output(
        PlannerOutput(blueprint=None, missing_params=[], clarification_questions=[], thought=""),
        planner_input,
    )

    assert out.blueprint is not None
    assert [step.lens_id for step in out.blueprint.steps] == ["lens_watermark"]


def test_postprocess_builds_reference_pipeline_for_background_replacement():
    planner_input = PlannerInput(
        task_desc="把图中女人的背景替换为法国的埃菲尔铁塔",
        base_image_meta={},
        candidates=[
            {
                "lens_id": "lens_flux_reference",
                "score": 0.92,
                "layer": "A2",
                "description": "单参考约束重绘",
                "notes": "",
                "inputs": [
                    {"name": "base_image", "type": "image"},
                    {"name": "ref_image_1", "type": "image"},
                ],
                "outputs": [{"name": "result_image", "type": "image"}],
                "params": [{"name": "prompt", "type": "text", "required": True}],
                "examples": [],
            },
            {
                "lens_id": "lens_pose_extract",
                "score": 0.75,
                "layer": "A1",
                "description": "提取人物姿态图",
                "notes": "",
                "inputs": [{"name": "base_image", "type": "image"}],
                "outputs": [{"name": "pose_map", "type": "image"}],
                "params": [],
                "examples": [],
            },
        ],
        session_context={},
    )

    out = _postprocess_planner_output(
        PlannerOutput(blueprint=None, missing_params=[], clarification_questions=[], thought=""),
        planner_input,
    )

    assert out.blueprint is not None
    assert [step.lens_id for step in out.blueprint.steps] == [
        "lens_pose_extract",
        "lens_flux_reference",
    ]
    assert out.blueprint.steps[1].input_links["ref_image_1"] == "$step_1_pose_extract.pose_map"


def test_postprocess_uses_llm_semantic_fill_for_segmentation_prompt(monkeypatch):
    planner_input = PlannerInput(
        task_desc="把图中女人替换为一只狗",
        base_image_meta={},
        candidates=[
            {
                "lens_id": "lens_flux_inpaint",
                "score": 0.95,
                "layer": "A2",
                "description": "局部遮罩重绘",
                "notes": "",
                "inputs": [
                    {"name": "base_image", "type": "image"},
                    {"name": "mask", "type": "mask"},
                ],
                "outputs": [{"name": "result_image", "type": "image"}],
                "params": [{"name": "prompt", "type": "text", "required": True}],
                "examples": [],
            },
            {
                "lens_id": "lens_sam2_matting",
                "score": 0.8,
                "layer": "A1",
                "description": "自动分割并输出遮罩",
                "notes": "",
                "inputs": [{"name": "base_image", "type": "image"}],
                "outputs": [{"name": "mask_result", "type": "image"}],
                "params": [{"name": "prompt", "type": "text", "required": True}],
                "examples": [],
            },
        ],
        session_context={},
    )

    def fake_llm_fill(*, task_desc, candidate, downstream_candidate, content_param_names):
        lens_id = candidate.get("lens_id")
        if lens_id == "lens_sam2_matting":
            return {"prompt": "女人"}
        if lens_id == "lens_flux_inpaint":
            return {"prompt": task_desc}
        return {}

    monkeypatch.setattr(planner_service, "_semantic_fill_is_configured", lambda: True)
    monkeypatch.setattr(planner_service, "_call_llm_semantic_param_fill", fake_llm_fill)
    monkeypatch.setattr(
        planner_service,
        "_derive_param_value",
        lambda **kwargs: None,
    )

    out = _postprocess_planner_output(
        PlannerOutput(blueprint=None, missing_params=[], clarification_questions=[], thought=""),
        planner_input,
    )

    assert out.blueprint is not None
    assert [step.lens_id for step in out.blueprint.steps] == [
        "lens_sam2_matting",
        "lens_flux_inpaint",
    ]
    assert out.blueprint.steps[0].params["prompt"] == "女人"
    assert out.blueprint.steps[1].params["prompt"] == planner_input.task_desc


def test_postprocess_normalizes_lora_filter_prompt_to_english(monkeypatch):
    planner_input = PlannerInput(
        task_desc="帮我把这张图片转成宫崎骏风格",
        base_image_meta={},
        candidates=[
            {
                "lens_id": "lens_lora_filter",
                "score": 0.95,
                "layer": "A4",
                "description": "基于 LoRA 的整图风格滤镜",
                "notes": "SDXL style transfer lens",
                "inputs": [{"name": "base_image", "type": "image"}],
                "outputs": [{"name": "result_image", "type": "image"}],
                "params": [
                    {"name": "lora_name", "type": "text", "required": True},
                    {"name": "prompt", "type": "text", "required": False},
                ],
                "examples": [],
            },
        ],
        session_context={},
    )

    def fake_llm_fill(*, task_desc, candidate, downstream_candidate, content_param_names):
        return {"prompt": "宫崎骏动画风格，温暖治愈，保留主体构图"}

    monkeypatch.setattr(planner_service, "_semantic_fill_is_configured", lambda: True)
    monkeypatch.setattr(planner_service, "_call_llm_semantic_param_fill", fake_llm_fill)

    out = _postprocess_planner_output(
        PlannerOutput(blueprint=None, missing_params=[], clarification_questions=[], thought=""),
        planner_input,
    )

    assert out.blueprint is not None
    step = out.blueprint.steps[0]
    assert step.lens_id == "lens_lora_filter"
    assert step.params["lora_name"] == "Studio Ghibli Style.safetensors"
    assert "Studio Ghibli" in step.params["prompt"]
    assert "preserve the subject and composition" in step.params["prompt"]


def test_postprocess_falls_back_to_english_prompt_for_lens_style(monkeypatch):
    planner_input = PlannerInput(
        task_desc="参考这张风格图，把原图改成柔和绘本风",
        base_image_meta={},
        candidates=[
            {
                "lens_id": "lens_style",
                "score": 0.95,
                "layer": "A4",
                "description": "基于参考风格图的风格迁移透镜",
                "notes": "SDXL style reference transfer",
                "inputs": [
                    {"name": "base_image", "type": "image"},
                    {"name": "style_reference_image", "type": "image"},
                ],
                "outputs": [{"name": "result_image", "type": "image"}],
                "params": [{"name": "prompt", "type": "text", "required": False}],
                "examples": [],
            },
        ],
        session_context={},
    )

    monkeypatch.setattr(planner_service, "_semantic_fill_is_configured", lambda: True)
    monkeypatch.setattr(
        planner_service,
        "_call_llm_semantic_param_fill",
        lambda **kwargs: {"prompt": "柔和绘本风，保留主体"},
    )

    out = _postprocess_planner_output(
        PlannerOutput(blueprint=None, missing_params=[], clarification_questions=[], thought=""),
        planner_input,
    )

    assert out.blueprint is not None
    step = out.blueprint.steps[0]
    assert step.lens_id == "lens_style"
    assert "follow the style reference image" in step.params["prompt"]
    assert "preserve the main subject and overall composition" in step.params["prompt"]
