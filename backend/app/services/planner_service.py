from __future__ import annotations

import json
import os
import re
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple

import httpx
from dotenv import dotenv_values  # type: ignore[import-not-found]

from app.schemas.lens import DAGBlueprint, DAGStep
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


_STYLE_LORA_MAPPINGS: List[Tuple[Tuple[str, ...], str]] = [
    (
        (
            "宫崎骏",
            "吉卜力",
            "ghibli",
            "日本动漫",
            "日漫",
            "anime",
        ),
        "Studio Ghibli Style.safetensors",
    ),
    (
        (
            "赛博朋克",
            "cyberpunk",
        ),
        "cyberpunk style v3.safetensors",
    ),
    (
        (
            "粘土",
            "黏土",
            "clay",
            "claymation",
        ),
        "CLAYMATE_V2.03_.safetensors",
    ),
    (
        (
            "手绘",
            "复古手绘",
            "vintage",
            "复古",
        ),
        "Vintage_styleV2.safetensors",
    ),
]


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
            raise RuntimeError(
                "PlannerService requires MUSELENS_LLM_API_KEY and MUSELENS_LLM_MODEL"
            )

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
                return _postprocess_planner_output(out, planner_input)

            content = msg.get("content") or ""
            obj = json.loads(content)
            out = PlannerOutput.model_validate(obj)
            if out.blueprint is None and not out.missing_params and not out.clarification_questions:
                out = _fallback_missing_questions(out, planner_input)
            return _postprocess_planner_output(out, planner_input)
        except Exception as exc:
            raise RuntimeError(
                f"PlannerService output parse failed: {exc}; raw={data}"
            ) from exc


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
            reason="LLM output was incomplete, so fallback missing params were inferred from the best candidate.",
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


def _postprocess_planner_output(out: PlannerOutput, planner_input: PlannerInput) -> PlannerOutput:
    semantic_cache: Dict[Tuple[str, str, str], Dict[str, Any]] = {}
    out = _autofill_existing_blueprint_params(out, planner_input, semantic_cache=semantic_cache)
    if out.blueprint is not None and not out.missing_params and not out.clarification_questions:
        return out

    heuristic_blueprint = _build_heuristic_blueprint(
        planner_input,
        semantic_cache=semantic_cache,
    )
    if heuristic_blueprint is not None:
        out.blueprint = heuristic_blueprint
        out.missing_params = []
        out.clarification_questions = []
        suffix = "Heuristic asset-based recovery built an executable blueprint from candidates."
        out.thought = f"{out.thought}\n\n{suffix}".strip() if out.thought else suffix
        return out

    filtered_missing, filtered_questions = _filter_autofillable_missing(
        out,
        planner_input,
        semantic_cache=semantic_cache,
    )
    out.missing_params = filtered_missing
    out.clarification_questions = filtered_questions
    return out


def _autofill_existing_blueprint_params(
    out: PlannerOutput,
    planner_input: PlannerInput,
    *,
    semantic_cache: Optional[Dict[Tuple[str, str, str], Dict[str, Any]]] = None,
) -> PlannerOutput:
    if out.blueprint is None:
        return out

    candidates_by_id = {
        str(c.get("lens_id") or ""): c
        for c in (planner_input.candidates or [])
        if c.get("lens_id")
    }
    filled = False
    for step in out.blueprint.steps:
        cand = candidates_by_id.get(step.lens_id) or {}
        for param in cand.get("params") or []:
            name = str(param.get("name") or "")
            if not name or name in step.params:
                continue
            value = _resolve_step_param_value(
                lens_id=step.lens_id,
                param_name=name,
                task_desc=planner_input.task_desc,
                candidate=cand,
                semantic_cache=semantic_cache,
            )
            if value:
                step.params[name] = value
                filled = True

    if filled:
        filtered_missing, filtered_questions = _filter_autofillable_missing(
            out,
            planner_input,
            semantic_cache=semantic_cache,
        )
        out.missing_params = filtered_missing
        out.clarification_questions = filtered_questions
    return out


def _filter_autofillable_missing(
    out: PlannerOutput,
    planner_input: PlannerInput,
    *,
    semantic_cache: Optional[Dict[Tuple[str, str, str], Dict[str, Any]]] = None,
) -> Tuple[List[MissingParam], List[PlannerQuestion]]:
    candidates_by_id = {
        str(c.get("lens_id") or ""): c
        for c in (planner_input.candidates or [])
        if c.get("lens_id")
    }

    kept_missing: List[MissingParam] = []
    for mp in out.missing_params or []:
        cand = candidates_by_id.get(mp.lens_id) or {}
        value = _resolve_step_param_value(
            lens_id=mp.lens_id,
            param_name=mp.param_name,
            task_desc=planner_input.task_desc,
            candidate=cand,
            semantic_cache=semantic_cache,
        )
        if not value:
            kept_missing.append(mp)

    kept_questions: List[PlannerQuestion] = []
    for q in out.clarification_questions or []:
        lens_id = q.param_ref.lens_id
        param_name = q.param_ref.param_name
        cand = candidates_by_id.get(lens_id) or {}
        value = _resolve_step_param_value(
            lens_id=lens_id,
            param_name=param_name,
            task_desc=planner_input.task_desc,
            candidate=cand,
            semantic_cache=semantic_cache,
        )
        if not value:
            kept_questions.append(q)

    return kept_missing, kept_questions


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


def _build_heuristic_blueprint(
    planner_input: PlannerInput,
    *,
    semantic_cache: Optional[Dict[Tuple[str, str, str], Dict[str, Any]]] = None,
) -> DAGBlueprint | None:
    candidates = list(planner_input.candidates or [])
    if not candidates:
        return None

    main = _pick_main_candidate(planner_input.task_desc or "", candidates)
    if not main:
        return None

    steps: List[DAGStep] = []
    step_by_lens: Dict[str, DAGStep] = {}
    step_counter = 1

    def ensure_step(
        candidate: Dict[str, Any],
        *,
        downstream_candidate: Optional[Dict[str, Any]] = None,
    ) -> DAGStep | None:
        nonlocal step_counter
        lens_id = str(candidate.get("lens_id") or "")
        if not lens_id:
            return None
        if lens_id in step_by_lens:
            return step_by_lens[lens_id]

        input_links: Dict[str, str] = {}
        for asset in candidate.get("inputs") or []:
            asset_name = str(asset.get("name") or "")
            asset_type = str(asset.get("type") or "")
            if _is_user_supplied_input(asset_name, asset_type):
                if asset_name == "base_image":
                    input_links[asset_name] = "$user_base_image"
                continue

            provider = _find_provider_candidate(
                asset_name,
                asset_type,
                candidates,
                task_desc=planner_input.task_desc,
                exclude={lens_id},
            )
            if provider is None:
                return None

            provider_step = ensure_step(provider, downstream_candidate=candidate)
            if provider_step is None:
                return None

            output_ref = _find_output_ref(provider_step, provider, asset_name, asset_type)
            if output_ref is None:
                return None
            input_links[asset_name] = output_ref

        params: Dict[str, Any] = {}
        for p in candidate.get("params") or []:
            param_name = str(p.get("name") or "")
            if not param_name:
                continue
            value = _resolve_step_param_value(
                lens_id=lens_id,
                param_name=param_name,
                task_desc=planner_input.task_desc,
                candidate=candidate,
                downstream_candidate=downstream_candidate,
                semantic_cache=semantic_cache,
            )
            if value not in [None, ""]:
                params[param_name] = value
            elif bool(p.get("required", False)):
                return None

        step = DAGStep(
            step_id=f"step_{step_counter}_{_safe_step_suffix(lens_id)}",
            lens_id=lens_id,
            input_links=input_links,
            params=params,
        )
        step_counter += 1
        steps.append(step)
        step_by_lens[lens_id] = step
        return step

    if ensure_step(main) is None:
        return None

    return DAGBlueprint(
        initial_inputs={"user_base_image": "user_base_image"},
        steps=steps,
    )


def _pick_main_candidate(task_desc: str, candidates: List[Dict[str, Any]]) -> Dict[str, Any] | None:
    background_task = _looks_like_background_replacement(task_desc)
    local_task = _looks_like_local_replacement(task_desc)
    pose_shape_task = _looks_like_pose_or_shape_edit(task_desc)
    relight_task = _looks_like_relighting(task_desc)
    delivery_task = _looks_like_delivery_task(task_desc)
    style_task = _looks_like_style_transfer(task_desc)

    best: Tuple[float, Dict[str, Any]] | None = None
    for cand in candidates:
        lens_id = str(cand.get("lens_id") or "")
        layer = str(cand.get("layer") or "")
        if not lens_id or layer == "A1":
            continue
        if layer == "A5" and not delivery_task:
            continue

        lens_id_lower = lens_id.lower()
        score = float(cand.get("score") or 0.0)
        inputs = cand.get("inputs") or []
        outputs = cand.get("outputs") or []
        text_blob = _candidate_text(cand).lower()
        input_kinds = {
            _asset_kind(i.get("name", ""), i.get("type", ""))
            for i in inputs
        }
        has_base_image = "base_image" in input_kinds
        has_no_inputs = len(inputs) == 0
        has_style_reference_input = "style_reference" in input_kinds
        matched_lora_name = _match_style_lora_name(task_desc, cand)

        if any(str(o.get("name") or "") == "result_image" for o in outputs):
            score += 0.3
        if _has_content_param(cand):
            score += 0.2
        if layer == "A5":
            score -= 1.5
            if delivery_task:
                score += 6.0

        if background_task:
            if layer == "A2":
                score += 3.0
            if any(_asset_kind(i.get("name", ""), i.get("type", "")) == "mask" for i in inputs):
                score -= 4.0
            else:
                score += 1.5
            if any(
                _asset_kind(i.get("name", ""), i.get("type", "")) in {"depth", "canny", "pose", "generic_reference"}
                for i in inputs
            ):
                score += 1.0
            if "reference" in text_blob or "reference" in lens_id_lower:
                score += 0.8

        if local_task:
            if any(_asset_kind(i.get("name", ""), i.get("type", "")) == "mask" for i in inputs):
                score += 5.0
            if "inpaint" in text_blob or "inpaint" in lens_id_lower:
                score += 2.0

        if pose_shape_task:
            if any(_asset_kind(i.get("name", ""), i.get("type", "")) == "mask" for i in inputs):
                score -= 4.5
            if "inpaint" in text_blob or "inpaint" in lens_id_lower:
                score -= 2.0
            if any(
                _asset_kind(i.get("name", ""), i.get("type", "")) in {"pose", "depth", "generic_reference"}
                for i in inputs
            ):
                score += 3.0
            if "reference" in text_blob or "reference" in lens_id_lower:
                score += 2.5
            if "flux_edit" in lens_id_lower or "global edit" in text_blob:
                score += 1.8

        if relight_task:
            if "relight" in text_blob or "relight" in lens_id_lower or "lighting" in text_blob:
                score += 5.0
            if any(_asset_kind(i.get("name", ""), i.get("type", "")) == "depth" for i in inputs):
                score += 2.0
            if "depth_of_field" in lens_id_lower or "depth of field" in text_blob:
                score -= 3.0

        if style_task:
            if has_base_image:
                score += 4.0
            if has_no_inputs:
                score -= 5.0
            if has_style_reference_input:
                score -= 8.0
            if layer == "A4":
                score += 3.5
            elif layer == "A2":
                score += 1.2
            if "lora" in lens_id_lower or "lora" in text_blob:
                score += 2.5
                if matched_lora_name:
                    score += 5.0
                else:
                    score -= 2.5
            if "flux_edit" in lens_id_lower or "global edit" in text_blob:
                score += 2.2
            if "text2image" in lens_id_lower or "text2image" in text_blob:
                score -= 6.0
            if "style" in lens_id_lower or "style" in text_blob:
                score += 1.5

        if best is None or score > best[0]:
            best = (score, cand)

    return best[1] if best else None


def _find_provider_candidate(
    input_name: str,
    input_type: str,
    candidates: List[Dict[str, Any]],
    *,
    task_desc: str,
    exclude: Set[str],
) -> Dict[str, Any] | None:
    target_kind = _asset_kind(input_name, input_type)
    best: Tuple[float, Dict[str, Any]] | None = None
    for cand in candidates:
        lens_id = str(cand.get("lens_id") or "")
        if not lens_id or lens_id in exclude:
            continue
        for out in cand.get("outputs") or []:
            out_name = str(out.get("name") or "")
            out_type = str(out.get("type") or "")
            score = _provider_match_score(
                task_desc=task_desc,
                input_name=input_name,
                input_type=input_type,
                output_name=out_name,
                output_type=out_type,
            )
            if score <= 0:
                continue
            score += float(cand.get("score") or 0.0)
            if best is None or score > best[0]:
                best = (score, cand)
    return best[1] if best else None


def _find_output_ref(
    dep_step: DAGStep,
    candidate: Dict[str, Any],
    input_name: str,
    input_type: str,
) -> str | None:
    target_kind = _asset_kind(input_name, input_type)
    for out in candidate.get("outputs") or []:
        out_name = str(out.get("name") or "")
        out_type = str(out.get("type") or "")
        if (
            out_name == input_name
            or _asset_kind(out_name, out_type) == target_kind
            or _output_can_feed_input(out_name, out_type, input_name, input_type)
        ):
            return f"${dep_step.step_id}.{out_name}"
    return None


def _provider_match_score(
    *,
    task_desc: str,
    input_name: str,
    input_type: str,
    output_name: str,
    output_type: str,
) -> float:
    target_kind = _asset_kind(input_name, input_type)
    output_kind = _asset_kind(output_name, output_type)

    if output_name == input_name:
        return 4.0
    if output_kind and output_kind == target_kind:
        return 3.0
    if target_kind == "generic_reference":
        if output_kind in {"pose", "depth", "canny"}:
            return _reference_constraint_priority(task_desc, output_kind)
        if output_kind == "style_reference":
            return 3.2
        if output_kind == "generic_image":
            return 2.2
    if target_kind == "style_reference":
        if output_kind == "style_reference":
            return 3.6
        if output_kind == "generic_image":
            return 2.2
    if _output_can_feed_input(output_name, output_type, input_name, input_type):
        return 2.5
    if target_kind == "mask" and output_name.endswith("_result") and output_kind == "mask":
        return 2.0
    return 0.0


def _reference_constraint_priority(task_desc: str, output_kind: str) -> float:
    if _looks_like_relighting(task_desc):
        priorities = {"depth": 3.8, "pose": 3.2, "canny": 2.6}
        return priorities.get(output_kind, 0.0)

    if _looks_like_background_replacement(task_desc):
        priorities = {"pose": 3.9, "depth": 3.5, "canny": 2.4}
        return priorities.get(output_kind, 0.0)

    if _looks_like_style_structure_preservation(task_desc):
        priorities = {"canny": 3.9, "pose": 3.1, "depth": 2.9}
        return priorities.get(output_kind, 0.0)

    if _looks_like_subject_preservation(task_desc):
        priorities = {"pose": 3.9, "depth": 3.3, "canny": 2.7}
        return priorities.get(output_kind, 0.0)

    priorities = {"pose": 3.6, "depth": 3.5, "canny": 3.1}
    return priorities.get(output_kind, 0.0)


def _output_can_feed_input(
    output_name: str,
    output_type: str,
    input_name: str,
    input_type: str,
) -> bool:
    input_kind = _asset_kind(input_name, input_type)
    output_kind = _asset_kind(output_name, output_type)

    if input_kind == "generic_reference":
        return output_kind in {"pose", "depth", "canny", "generic_image", "style_reference"}

    if input_kind == "style_reference":
        return output_kind in {"style_reference", "generic_image"}

    return False


def _resolve_step_param_value(
    *,
    lens_id: str,
    param_name: str,
    task_desc: str,
    candidate: Dict[str, Any],
    downstream_candidate: Optional[Dict[str, Any]] = None,
    semantic_cache: Optional[Dict[Tuple[str, str, str], Dict[str, Any]]] = None,
) -> Optional[Any]:
    if not task_desc:
        return None

    mapped_value = _derive_non_content_param_value(
        lens_id=lens_id,
        param_name=param_name,
        task_desc=task_desc,
        candidate=candidate,
    )
    if mapped_value not in [None, ""]:
        return mapped_value

    if not _is_content_param(param_name):
        return None

    llm_values = _llm_fill_step_content_params(
        task_desc=task_desc,
        candidate=candidate,
        downstream_candidate=downstream_candidate,
        semantic_cache=semantic_cache,
    )
    llm_value = llm_values.get(param_name)
    if llm_value not in [None, ""]:
        return llm_value

    return _derive_param_value(
        lens_id=lens_id,
        param_name=param_name,
        task_desc=task_desc,
        candidate=candidate,
    )


def _derive_non_content_param_value(
    *,
    lens_id: str,
    param_name: str,
    task_desc: str,
    candidate: Dict[str, Any],
) -> Optional[Any]:
    lens_id_lower = lens_id.lower()
    param_name_lower = param_name.lower()

    if param_name_lower == "lora_name" or (
        "lora" in lens_id_lower and param_name_lower.endswith("lora_name")
    ):
        return _match_style_lora_name(task_desc, candidate)

    return None


def _match_style_lora_name(task_desc: str, candidate: Dict[str, Any]) -> Optional[str]:
    candidate_text = _candidate_text(candidate).lower()
    if "lora" not in candidate_text and "lora" not in str(candidate.get("lens_id") or "").lower():
        return None

    text = (task_desc or "").lower()
    for keywords, lora_name in _STYLE_LORA_MAPPINGS:
        if any(keyword.lower() in text for keyword in keywords):
            return lora_name
    return None


def _semantic_fill_is_configured() -> bool:
    return bool(os.getenv("MUSELENS_LLM_API_KEY") and os.getenv("MUSELENS_LLM_MODEL"))


def _llm_fill_step_content_params(
    *,
    task_desc: str,
    candidate: Dict[str, Any],
    downstream_candidate: Optional[Dict[str, Any]] = None,
    semantic_cache: Optional[Dict[Tuple[str, str, str], Dict[str, Any]]] = None,
) -> Dict[str, Any]:
    if not _semantic_fill_is_configured():
        return {}

    lens_id = str(candidate.get("lens_id") or "")
    downstream_lens_id = str((downstream_candidate or {}).get("lens_id") or "")
    cache_key = (task_desc, lens_id, downstream_lens_id)
    if semantic_cache is not None and cache_key in semantic_cache:
        return semantic_cache[cache_key]

    content_param_names = [
        str(p.get("name") or "")
        for p in (candidate.get("params") or [])
        if _is_content_param(str(p.get("name") or ""))
    ]
    if not content_param_names:
        return {}

    values = _call_llm_semantic_param_fill(
        task_desc=task_desc,
        candidate=candidate,
        downstream_candidate=downstream_candidate,
        content_param_names=content_param_names,
    )
    if semantic_cache is not None:
        semantic_cache[cache_key] = values
    return values


def _call_llm_semantic_param_fill(
    *,
    task_desc: str,
    candidate: Dict[str, Any],
    downstream_candidate: Optional[Dict[str, Any]],
    content_param_names: List[str],
) -> Dict[str, Any]:
    api_key = os.getenv("MUSELENS_LLM_API_KEY", "")
    model = os.getenv("MUSELENS_LLM_MODEL", "")
    base_url = (os.getenv("MUSELENS_LLM_BASE_URL") or "https://api.openai.com/v1").rstrip("/")
    timeout_s = float(os.getenv("MUSELENS_LLM_TIMEOUT_S", "30"))
    if not api_key or not model:
        return {}

    tool_schema: Dict[str, Any] = {
        "type": "function",
        "function": {
            "name": "fill_semantic_params",
            "description": "Fill only semantic text parameters for one lens step.",
            "parameters": {
                "type": "object",
                "properties": {
                    "param_values": {
                        "type": "object",
                        "additionalProperties": {
                            "type": ["string", "number", "boolean", "null"]
                        },
                    }
                },
                "required": ["param_values"],
            },
        },
    }

    system = (
        "You fill only semantic text-like parameters for a single MuseLens lens step.\n"
        "Never invent asset links, step ids, file names, masks, or structural bindings.\n"
        "Return values only for the requested content parameters.\n"
        "If the lens is a segmentation or matting step, output a concise localization target phrase, not the whole user instruction.\n"
        "If a value cannot be inferred confidently from the task and lens docs, omit it from param_values."
    )
    user = {
        "task_desc": task_desc,
        "candidate": {
            "lens_id": candidate.get("lens_id"),
            "layer": candidate.get("layer"),
            "description": candidate.get("description"),
            "notes": candidate.get("notes"),
            "params": candidate.get("params"),
            "examples": candidate.get("examples"),
        },
        "downstream_candidate": {
            "lens_id": downstream_candidate.get("lens_id"),
            "layer": downstream_candidate.get("layer"),
            "description": downstream_candidate.get("description"),
            "notes": downstream_candidate.get("notes"),
            "inputs": downstream_candidate.get("inputs"),
            "params": downstream_candidate.get("params"),
        }
        if downstream_candidate
        else None,
        "content_param_names": content_param_names,
    }

    payload: Dict[str, Any] = {
        "model": model,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": json.dumps(user, ensure_ascii=False)},
        ],
        "tools": [tool_schema],
        "tool_choice": {"type": "function", "function": {"name": "fill_semantic_params"}},
    }

    headers = {"Authorization": f"Bearer {api_key}"}
    url = f"{base_url}/chat/completions"

    try:
        with httpx.Client(timeout=timeout_s) as client:
            resp = client.post(url, headers=headers, json=payload)
            resp.raise_for_status()
            data = resp.json()

        choice0 = data["choices"][0]
        msg = choice0["message"]
        tool_calls = msg.get("tool_calls") or []
        if tool_calls:
            args = tool_calls[0]["function"]["arguments"]
            obj = json.loads(args) if isinstance(args, str) else args
        else:
            content = msg.get("content") or "{}"
            obj = json.loads(content)

        values = obj.get("param_values") or {}
        if not isinstance(values, dict):
            return {}
        return {
            str(k): v
            for k, v in values.items()
            if str(k) in content_param_names and v not in [None, ""]
        }
    except Exception:
        return {}


def _derive_param_value(
    *,
    lens_id: str,
    param_name: str,
    task_desc: str,
    candidate: Dict[str, Any],
) -> Optional[Any]:
    if not task_desc or not _is_content_param(param_name):
        return None

    lens_id_lower = lens_id.lower()
    candidate_text = _candidate_text(candidate).lower()

    if param_name == "text":
        watermark_text = _extract_watermark_text(task_desc)
        return watermark_text or task_desc.strip()

    if "sam2" in lens_id_lower or "matting" in lens_id_lower or "segment" in candidate_text:
        target = _extract_edit_target(task_desc)
        return target or None

    return task_desc.strip()


def _extract_edit_target(task_desc: str) -> str:
    text = (task_desc or "").strip()
    patterns = [
        r"把(?:这张图片|图片|图)?中(?:的)?(.+?)替换成",
        r"把(?:这张图片|图片|图)?中(?:的)?(.+?)换成",
        r"将(?:这张图片|图片|图)?中(?:的)?(.+?)替换为",
        r"将(?:这张图片|图片|图)?中(?:的)?(.+?)换为",
        r"把(.+?)抠出来",
        r"选中(.+?)(?:，|。|,|$)",
    ]
    for pattern in patterns:
        match = re.search(pattern, text)
        if match:
            return match.group(1).strip(" ，。,.")
    return ""


def _extract_watermark_text(task_desc: str) -> str:
    text = (task_desc or "").strip()
    patterns = [
        r"水印[:：]?\s*(.+)$",
        r"签名[:：]?\s*(.+)$",
        r"版权(?:信息|声明)?[:：]?\s*(.+)$",
    ]
    for pattern in patterns:
        match = re.search(pattern, text)
        if match:
            return match.group(1).strip()
    return ""


def _looks_like_local_replacement(task_desc: str) -> bool:
    keywords = [
        "替换",
        "换成",
        "换为",
        "局部",
        "主体",
        "只改",
        "抠",
        "去掉",
        "移除",
    ]
    return any(k in (task_desc or "") for k in keywords) and not _looks_like_background_replacement(task_desc)


def _looks_like_background_replacement(task_desc: str) -> bool:
    text = task_desc or ""
    background_keywords = [
        "背景",
        "天空",
        "场景",
        "环境",
        "远景",
        "后景",
    ]
    replace_keywords = [
        "替换",
        "换成",
        "换为",
        "改成",
        "改为",
    ]
    return any(k in text for k in background_keywords) and any(k in text for k in replace_keywords)


def _looks_like_relighting(task_desc: str) -> bool:
    keywords = [
        "光",
        "光影",
        "打光",
        "黄昏",
        "傍晚",
        "逆光",
        "色温",
        "照下",
        "阴影",
    ]
    return any(k in (task_desc or "") for k in keywords)


def _looks_like_delivery_task(task_desc: str) -> bool:
    keywords = [
        "放大",
        "超分",
        "高清",
        "清晰",
        "锐化",
        "水印",
        "签名",
        "版权",
    ]
    return any(k in (task_desc or "") for k in keywords)



def _looks_like_style_structure_preservation(task_desc: str) -> bool:
    text = task_desc or ""
    style_keywords = [
        "风格",
        "材质",
        "笔触",
        "纹理",
        "画风",
        "质感",
    ]
    preserve_keywords = [
        "保留结构",
        "结构不变",
        "轮廓不变",
        "边缘不变",
        "构图不变",
    ]
    return any(k in text for k in style_keywords) and any(k in text for k in preserve_keywords)


def _looks_like_subject_preservation(task_desc: str) -> bool:
    text = task_desc or ""
    preserve_keywords = [
        "保留人物",
        "保留主体",
        "主体不变",
        "人物不变",
        "保持人物",
        "保持主体",
    ]
    return any(k in text for k in preserve_keywords)


def _looks_like_pose_or_shape_edit(task_desc: str) -> bool:
    text = task_desc or ""
    keywords = [
        "姿势",
        "姿態",
        "坐姿",
        "站姿",
        "站直",
        "坐正",
        "坐端正",
        "端正",
        "抬手",
        "抬头",
        "低头",
        "转头",
        "转身",
        "侧身",
        "伸手",
        "伸展",
        "张开",
        "展开",
        "弯腰",
        "弯曲",
        "挺直",
        "体态",
        "形体",
        "轮廓",
        "衣服版型",
        "衣服廓形",
    ]
    return any(k in text for k in keywords)


def _looks_like_style_transfer(task_desc: str) -> bool:
    text = (task_desc or "").lower()
    keywords = [
        "风格",
        "画风",
        "滤镜",
        "吉卜力",
        "宫崎骏",
        "赛博朋克",
        "粘土",
        "手绘",
        "anime",
        "ghibli",
        "cyberpunk",
        "clay",
        "vintage",
        "lora",
        "style",
    ]
    return any(keyword in text for keyword in keywords)
def _has_content_param(candidate: Dict[str, Any]) -> bool:
    return any(_is_content_param(str(p.get("name") or "")) for p in (candidate.get("params") or []))


def _is_content_param(param_name: str) -> bool:
    return param_name in {"prompt", "positive_prompt", "negative_prompt", "text"}


def _is_user_supplied_input(name: str, asset_type: str) -> bool:
    kind = _asset_kind(name, asset_type)
    lname = (name or "").strip().lower()
    return kind == "base_image" or lname == "style_reference_image"


def _asset_kind(name: str, asset_type: str) -> str:
    tokens = f"{name} {asset_type}".lower()
    if "base_image" in tokens:
        return "base_image"
    if "mask" in tokens:
        return "mask"
    if "depth" in tokens:
        return "depth"
    if "canny" in tokens or "edge" in tokens:
        return "canny"
    if "pose" in tokens or "skeleton" in tokens:
        return "pose"
    if "style_reference" in tokens:
        return "style_reference"
    if "ref_image" in tokens:
        return "generic_reference"
    if "image" in tokens:
        return "generic_image"
    return tokens.strip()


def _safe_step_suffix(lens_id: str) -> str:
    return lens_id.replace("lens_", "").replace("-", "_")


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
        "- For delivery-only requests such as upscale, watermark, or copyright labeling, A5 may be the main lens.\n"
        "- For final delivery tasks such as watermark or upscale, place them near the end of the chain rather than as the main edit step when the user is primarily asking for semantic editing.\n"
        "- candidates.notes comes from the lens documentation body and may contain usage boundaries, failure modes, and handoff guidance; use it actively.\n"
        "- If the user's natural-language request already contains the needed prompt content, write it directly into the chosen step params instead of asking the user to repeat it.\n"
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
