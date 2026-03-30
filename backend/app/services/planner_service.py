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
        str(cand.get("notes") or ""),
    ]

    for asset in cand.get("inputs") or []:
        parts.append(str(asset.get("name") or ""))
        parts.append(str(asset.get("type") or ""))

    for asset in cand.get("outputs") or []:
        parts.append(str(asset.get("name") or ""))
        parts.append(str(asset.get("type") or ""))

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
        "You are the MuseLens Planner.\n"
        "You receive task_desc, candidates, and session_context.\n"
        "Each candidate may include layer, description, notes, inputs, outputs, params, and examples.\n"
        "Your job is to select only from the provided candidates and return a valid structured plan.\n"
        "\n"
        "Global library rules:\n"
        "- A1 usually extracts intermediate constraints such as mask, depth, canny, pose.\n"
        "- A2 usually performs image generation or semantic editing such as text2image, global edit, reference edit, inpaint.\n"
        "- A3 usually performs relighting or optical effects.\n"
        "- A4 usually performs style transfer or LoRA-based stylization.\n"
        "- A5 usually performs delivery-stage operations such as watermark or upscale.\n"
        "\n"
        "Planning rules:\n"
        "- If one lens is insufficient, prefer a multi-step DAG rather than failing early.\n"
        "- If a candidate depends on assets like mask, depth_map, canny_map, or pose_map, first look for upstream candidates whose outputs can provide those assets.\n"
        "- Prefer chaining by asset compatibility using inputs and outputs, not just by layer names.\n"
        "- For local replacement, subject replacement, replace-only-this-object, or partial repaint tasks, prefer a pipeline like constraint extraction plus local inpaint.\n"
        "- For global style, global lighting, global material, or global mood tasks, prefer a single global edit or style lens unless extra constraints are clearly needed.\n"
        "- For final delivery tasks such as watermark or upscale, place them near the end of the chain rather than as the main edit step.\n"
        "- candidates.notes comes from the lens documentation body and may contain usage boundaries, failure modes, and handoff guidance; use it actively.\n"
        "\n"
        "Clarification rules:\n"
        "- Ask clarification questions only when suitable candidates exist but important parameters are missing.\n"
        "- If the task can be planned and only parameter values are missing, ask for those values instead of failing.\n"
        "- Fail only when the candidates are truly insufficient.\n"
        "- When failing, do not invent unrelated clarification questions for a mismatched lens.\n"
        "\n"
        "Strict rules:\n"
        "- Only use lens_id values that appear in candidates.\n"
        "- Only use parameter names that appear in the chosen candidate params schema.\n"
        "- If you return a blueprint, asset dependencies must be valid: each input_link must reference initial_inputs or an upstream step output.\n"
        "- Output structured JSON only."
    )
