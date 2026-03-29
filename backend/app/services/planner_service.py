from __future__ import annotations

import json
import os
from typing import Any, Dict, Optional

import httpx
from pathlib import Path
from dotenv import dotenv_values  # type: ignore[import-not-found]

from app.schemas.planner import (
    PlannerInput,
    PlannerOutput,
    MissingParam,
    PlannerParamRef,
    PlannerQuestion,
)


# 让 `.env` 内的 LLM 配置在当前进程里生效，避免 os.getenv 读不到。
# 注意：这里**只注入** MUSELENS_LLM_*，不注入数据库/pgvector，避免环境缺少 psycopg 时导致导入阶段崩溃。
_ENV_PATH = Path(__file__).resolve().parents[2] / ".env"
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
    """
    LLM 智能编排器（Planner）。

    OpenAI 兼容 API 约定（chat.completions）：
    - 通过 tools/function calling 优先拿到结构化 JSON
    - 若不支持 tools，则回退解析 assistant.content 中的纯 JSON

    环境变量：
    - MUSELENS_LLM_BASE_URL（可选）：OpenAI 兼容网关地址，默认 https://api.openai.com/v1
    - MUSELENS_LLM_API_KEY：API Key
    - MUSELENS_LLM_MODEL：模型名（例如 gpt-4.1-mini / gpt-4.1 等，取决于你的网关）
    - MUSELENS_LLM_TIMEOUT_S：请求超时（秒），默认 30
    """

    def __init__(
        self,
        *,
        base_url: Optional[str] = None,
        api_key: Optional[str] = None,
        model: Optional[str] = None,
        timeout_s: Optional[float] = None,
    ) -> None:
        self._base_url = (base_url or os.getenv("MUSELENS_LLM_BASE_URL") or "https://api.openai.com/v1").rstrip("/")
        self._api_key = api_key or os.getenv("MUSELENS_LLM_API_KEY", "")
        self._model = model or os.getenv("MUSELENS_LLM_MODEL", "")
        self._timeout_s = float(timeout_s or os.getenv("MUSELENS_LLM_TIMEOUT_S", "30"))

        if not self._api_key or not self._model:
            # 允许在单测/离线场景下初始化，但 plan() 时会报错
            pass

    def is_configured(self) -> bool:
        return bool(self._api_key and self._model)

    def plan(self, planner_input: PlannerInput) -> PlannerOutput:
        if not self._api_key or not self._model:
            raise RuntimeError("PlannerService 需要配置 MUSELENS_LLM_API_KEY 与 MUSELENS_LLM_MODEL")

        # 重要：让模型只在 candidates 内选 Lens，不得臆造 lens_id/param
        system = (
            "你是MuseLens的Planner（智能编排器）。\n"
            "你将收到：用户任务描述(task_desc)、候选Lens列表(candidates，含参数schema与示例)、以及会话上下文(session_context)。\n"
            "你的目标：从 candidates 中选择合适的Lens，产出可执行的DAGBlueprint（steps按拓扑顺序），并填充参数。\n"
            "如果关键信息不足，必须在 clarification_questions 中提出需要用户回答的问题，并在 missing_params 标记缺失参数。\n"
            "严格要求：\n"
            "- 只能使用 candidates 中出现的 lens_id；不得虚构 lens。\n"
            "- 只能使用候选Lens的 params schema 中存在的参数名；不得虚构参数。\n"
            "- 只输出结构化JSON（通过工具调用返回）。"
        )

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

        # 兼容 tool_calls / function_call 两种格式
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

            # 回退：直接从 content 取 JSON
            content = msg.get("content") or ""
            obj = json.loads(content)
            out = PlannerOutput.model_validate(obj)
            if out.blueprint is None and not out.missing_params and not out.clarification_questions:
                out = _fallback_missing_questions(out, planner_input)
            return out
        except Exception as exc:
            raise RuntimeError(f"PlannerService 输出解析失败：{exc}; raw={data}") from exc


class MockPlannerService:
    """
    测试用 Planner：直接返回预置输出，避免依赖真实 LLM。
    """

    def __init__(self, output: PlannerOutput) -> None:
        self._output = output

    def plan(self, planner_input: PlannerInput) -> PlannerOutput:
        return self._output

    def is_configured(self) -> bool:
        return True


def _fallback_missing_questions(out: PlannerOutput, planner_input: PlannerInput) -> PlannerOutput:
    """
    LLM 可能在 blueprint=None 时“没有补 missing_params/clarification_questions”。
    单测要求在无法就绪时至少返回一种追问/缺失参数，故在解析后做兜底补全。
    """
    # 从 candidates 中找一个 required 参数；若没有 required，则退化为第一个 params 的 name
    chosen_lens_id: str | None = None
    chosen_param_name: str | None = None

    for cand in planner_input.candidates or []:
        lens_id = cand.get("lens_id")
        for p in cand.get("params") or []:
            name = p.get("name") or ""
            required = p.get("required", False)
            if required:
                chosen_lens_id = str(lens_id) if lens_id is not None else None
                chosen_param_name = str(name) if name else "param"
                break
        if chosen_lens_id and chosen_param_name:
            break

    if not chosen_lens_id:
        # 退化：取第一个 candidate/param
        cand0 = (planner_input.candidates or [None])[0]
        if cand0:
            chosen_lens_id = cand0.get("lens_id")
            params0 = cand0.get("params") or []
            if params0:
                chosen_param_name = params0[0].get("name") or "param"

    if chosen_lens_id and chosen_param_name:
        out.missing_params = [
            MissingParam(
                lens_id=str(chosen_lens_id),
                param_name=str(chosen_param_name),
                reason="LLM 输出不完整：未提供 missing_params/clarification_questions，已自动兜底补全。",
            )
        ]
        out.clarification_questions = [
            PlannerQuestion(
                param_ref=PlannerParamRef(
                    lens_id=str(chosen_lens_id),
                    param_name=str(chosen_param_name),
                ),
                question_text=f"请输入{chosen_param_name}",
                required=True,
            )
        ]

    return out

