from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any, Dict, List, Optional

import httpx
from dotenv import dotenv_values  # type: ignore[import-not-found]

from app.schemas.planner import (
    MissingParam,
    PlannerInput,
    PlannerOutput,
    PlannerParamRef,
    PlannerQuestion,
)
from app.services.rag_client import tokenize_text


def _resolve_llm_dotenv_path() -> Path:
    here = Path(__file__).resolve()
    backend_root = here.parents[2] / ".env"
    if backend_root.is_file():
        return backend_root
    repo_root = here.parents[3] / ".env"
    if here.parents[3] != Path("/") and repo_root.is_file():
        return repo_root
    return backend_root


_ENV_PATH = _resolve_llm_dotenv_path()
_LLM_ENV_KEYS = {
    "MUSELENS_LLM_BASE_URL",
    "MUSELENS_LLM_API_KEY",
    "MUSELENS_LLM_MODEL",
    "MUSELENS_LLM_TIMEOUT_S",
}
if _ENV_PATH.is_file():
    _vals = dotenv_values(str(_ENV_PATH))
    for _k in _LLM_ENV_KEYS:
        if not os.getenv(_k) and _k in _vals:
            _v = _vals.get(_k)
            if _v is not None:
                os.environ[_k] = str(_v).strip()


class PlannerService:
    def __init__(
        self,
        *,
        base_url: Optional[str] = None,
        api_key: Optional[str] = None,
        model: Optional[str] = None,
        timeout_s: Optional[float] = None,
    ) -> None:
        self._base_url = (
            base_url or os.getenv("MUSELENS_LLM_BASE_URL") or "https://api.openai.com/v1"
        ).rstrip("/")
        self._api_key = api_key or os.getenv("MUSELENS_LLM_API_KEY", "")
        self._model = model or os.getenv("MUSELENS_LLM_MODEL", "")
        self._timeout_s = float(timeout_s or os.getenv("MUSELENS_LLM_TIMEOUT_S", "30"))

    def is_configured(self) -> bool:
        return bool(self._api_key and self._model)

    def plan(self, planner_input: PlannerInput) -> PlannerOutput:
        if not self._api_key or not self._model:
            raise RuntimeError("PlannerService 需要配置 MUSELENS_LLM_API_KEY 和 MUSELENS_LLM_MODEL")

        system = _build_planner_system_prompt()

        user = {
            "task_desc": planner_input.task_desc,
            "base_image_meta": planner_input.base_image_meta,
            "candidates": planner_input.candidates,
            "session_context": planner_input.session_context,
        }

        tool_schema: Dict[str, Any] = {
            "type": "function",
            "function": {
                "name": "produce_plan",
                "description": "Return a MuseLens plan as JSON.",
                "parameters": PlannerOutput.model_json_schema(),
            },
        }

        payload: Dict[str, Any] = {
            "model": self._model,
            "messages": [
                {"role": "system", "content": system},
                {"role": "user", "content": json.dumps(user, ensure_ascii=False)},
            ],
            "tools": [tool_schema],
            "tool_choice": {"type": "function", "function": {"name": "produce_plan"}},
        }

        headers = {"Authorization": f"Bearer {self._api_key}"}
        url = f"{self._base_url}/chat/completions"

        with httpx.Client(timeout=self._timeout_s) as client:
            resp = client.post(url, headers=headers, json=payload)
            resp.raise_for_status()
            data = resp.json()

        try:
            choice0 = data["choices"][0]
            msg = choice0["message"]
            tool_calls = msg.get("tool_calls") or []
            if tool_calls:
                args = tool_calls[0]["function"]["arguments"]
                obj = json.loads(args) if isinstance(args, str) else args
                out = PlannerOutput.model_validate(obj)
                if out.blueprint is None and not out.missing_params and not out.clarification_questions:
                    out = _fallback_missing_questions(out, planner_input)
                return out

            content = msg.get("content") or ""
            obj = json.loads(content)
            out = PlannerOutput.model_validate(obj)
            if out.blueprint is None and not out.missing_params and not out.clarification_questions:
                out = _fallback_missing_questions(out, planner_input)
            return out
        except Exception as exc:
            raise RuntimeError(f"PlannerService 输出解析失败：{exc}; raw={data}") from exc


class MockPlannerService:
    def __init__(self, output: PlannerOutput) -> None:
        self._output = output

    def plan(self, planner_input: PlannerInput) -> PlannerOutput:
        return self._output

    def is_configured(self) -> bool:
        return True


class SequenceMockPlannerService:
    def __init__(self, outputs: List[PlannerOutput]) -> None:
        self._outputs = list(outputs)
        self._idx = 0

    def plan(self, planner_input: PlannerInput) -> PlannerOutput:
        out = self._outputs[self._idx]
        if self._idx < len(self._outputs) - 1:
            self._idx += 1
        return out

    def is_configured(self) -> bool:
        return True


def _fallback_missing_questions(out: PlannerOutput, planner_input: PlannerInput) -> PlannerOutput:
    """
    Conservative fallback:
    - if the LLM clearly indicates incompatibility/no suitable lens, do not fabricate a question
    - only synthesize a clarification question when a candidate has non-trivial lexical compatibility
    """
    if _planner_thought_indicates_incompatibility(out.thought):
        return out

    chosen = _pick_fallback_candidate(planner_input)
    if not chosen:
        return out

    chosen_lens_id, chosen_param_name = chosen
    out.missing_params = [
        MissingParam(
            lens_id=chosen_lens_id,
            param_name=chosen_param_name,
            reason="LLM 输出不完整：未提供 missing_params/clarification_questions，已按最匹配候选自动补全。",
        )
    ]
    out.clarification_questions = [
        PlannerQuestion(
            param_ref=PlannerParamRef(
                lens_id=chosen_lens_id,
                param_name=chosen_param_name,
            ),
            question_text=f"请输入{chosen_param_name}",
            required=True,
        )
    ]
    return out


def _planner_thought_indicates_incompatibility(thought: str) -> bool:
    text = (thought or "").lower()
    markers = [
        "不支持",
        "无法",
        "没有可用",
        "候选lens为空",
        "candidates 为空",
        "无法继续",
        "等待系统提供",
        "不适合",
        "cannot",
        "no suitable",
        "no candidate",
    ]
    return any(marker in text for marker in markers)


def _pick_fallback_candidate(planner_input: PlannerInput) -> tuple[str, str] | None:
    query_tokens = set(tokenize_text(planner_input.task_desc or ""))
    if not query_tokens:
        return None

    best: tuple[float, str, str] | None = None

    for cand in planner_input.candidates or []:
        lens_id = str(cand.get("lens_id") or "").strip()
        if not lens_id:
            continue

        params = cand.get("params") or []
        param_name = _pick_candidate_param(params)
        if not param_name:
            continue

        candidate_tokens = set(tokenize_text(_candidate_text(cand)))
        overlap = len(query_tokens & candidate_tokens)
        score = float(cand.get("score") or 0.0) + overlap

        if overlap <= 0:
            continue

        if best is None or score > best[0]:
            best = (score, lens_id, param_name)

    if best is None:
        return None
    return best[1], best[2]


def _pick_candidate_param(params: List[Dict[str, Any]]) -> str | None:
    for p in params:
        name = str(p.get("name") or "").strip()
        if name and bool(p.get("required", False)):
            return name
    for p in params:
        name = str(p.get("name") or "").strip()
        if name:
            return name
    return None


def _candidate_text(cand: Dict[str, Any]) -> str:
    parts: List[str] = [
        str(cand.get("lens_id") or ""),
        str(cand.get("layer") or ""),
        str(cand.get("description") or ""),
    ]

    for p in cand.get("params") or []:
        parts.append(str(p.get("name") or ""))
        parts.append(str(p.get("description") or ""))

    for ex in cand.get("examples") or []:
        parts.append(str(ex.get("nl_desc") or ""))
        params_example = ex.get("params_example") or {}
        if params_example:
            parts.append(json.dumps(params_example, ensure_ascii=False))

    return " ".join(parts)


def _build_planner_system_prompt() -> str:
    return (
        "你是 MuseLens 的 Planner（智能编排器）。\n"
        "你将收到：用户任务描述 task_desc、候选 Lens 列表 candidates（含 layer、description、inputs、outputs、params、examples）、以及会话上下文 session_context。\n"
        "你的目标：仅从 candidates 中选择合适的 Lens，生成可执行 DAGBlueprint，并填充参数；若信息不足，则返回 clarification_questions 与 missing_params。\n"
        "\n"
        "关于透镜库的全局职责分层：\n"
        "- A1 通常是视觉解析/约束提取层：负责从原图中提取 mask、depth、canny、pose 等中间资产，不直接完成最终生成。\n"
        "- A2 通常是像素修改与语义重构层：负责 text2image、global edit、reference edit、inpaint 等生成或重绘任务。\n"
        "- A3 通常是光影/光学层：负责 relighting、depth of field 等物理或视觉效果重构。\n"
        "- A4 通常是风格化层：负责 style transfer、LoRA filter 等风格映射。\n"
        "- A5 通常是终端交付层：负责 watermark、upscale 等收尾和交付处理。\n"
        "\n"
        "编排原则：\n"
        "- 如果单个 Lens 无法完成任务，优先组合多个 Lens 形成多步 DAG，而不是过早 failed。\n"
        "- 如果某个候选 Lens 的 inputs 依赖 mask、depth_map、canny_map、pose_map 等中间资产，应优先在 candidates 中寻找能产出对应 outputs 的上游 Lens。\n"
        "- 优先依据 inputs/outputs 资产兼容性来决定串联关系，而不是只看 layer 名称。\n"
        "- 对“局部替换、只改某个对象、替换主体、补画局部”一类任务，优先考虑『解析/提取约束资产 + 局部重绘』的链式方案。\n"
        "- 对“全局风格、整体光影、整体材质、整体氛围”一类任务，优先考虑单步全局编辑或风格化 Lens；仅在确有必要时再增加上游约束 Lens。\n"
        "- 对“最终交付、版权、水印、放大”一类任务，优先放在链路末端作为后处理步骤，而不是主编辑步骤。\n"
        "\n"
        "追问原则：\n"
        "- 只有在存在合适 Lens 但关键参数不足时，才提出 clarification_questions。\n"
        "- 如果用户意图已经足以确定步骤，只缺少具体参数值，应直接追问参数，不要先 failed。\n"
        "- 如果 candidates 确实不足以完成任务，才返回 failed；failed 时不要伪造不相关 Lens 的参数追问。\n"
        "\n"
        "严格要求：\n"
        "- 只能使用 candidates 中出现的 lens_id，不得虚构 Lens。\n"
        "- 只能使用候选 Lens 的 params schema 中存在的参数名，不得虚构参数。\n"
        "- 如果返回 blueprint，steps 必须满足资产依赖自洽：下游 input_links 只能引用 initial_inputs 或上游 step.outputs。\n"
        "- 只输出结构化 JSON。"
    )
