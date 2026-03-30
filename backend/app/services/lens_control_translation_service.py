from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any, Dict, Optional

import httpx
from dotenv import dotenv_values  # type: ignore[import-not-found]


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


_FILTER_PRESETS: Dict[str, Dict[str, str]] = {
    "ghibli": {
        "lora_name": "Studio Ghibli Style.safetensors",
        "prompt": "Studio Ghibli inspired hand-drawn animation aesthetic, soft warm natural lighting, clean colors, dreamy whimsical atmosphere, preserve the subject and composition",
    },
    "cyberpunk": {
        "lora_name": "cyberpunk style v3.safetensors",
        "prompt": "cyberpunk neon city atmosphere, futuristic lighting, glossy reflections, night scene mood, preserve the main subject and composition",
    },
    "clay": {
        "lora_name": "CLAYMATE_V2.03_.safetensors",
        "prompt": "claymation texture, handcrafted clay figure feel, soft studio lighting, preserve the subject and overall composition",
    },
    "vintage": {
        "lora_name": "Vintage_styleV2.safetensors",
        "prompt": "vintage hand-drawn illustration look, textured strokes, nostalgic warm tones, preserve the original scene and composition",
    },
}


def translate_lens_controls(
    *,
    lens_id: str,
    control_values: Dict[str, Any],
    current_params: Optional[Dict[str, Any]] = None,
    current_assets: Optional[Dict[str, str]] = None,
) -> Dict[str, Any]:
    current_params = dict(current_params or {})
    current_assets = dict(current_assets or {})

    translated_params: Dict[str, Any] = {}
    translated_assets: Dict[str, str] = {}
    explanations: list[str] = []

    if lens_id == "lens_sam2_matting":
        mask_asset = str(control_values.get("mask_asset") or "").strip()
        if mask_asset:
            translated_assets["mask"] = mask_asset
            explanations.append("使用用户手动涂抹后的遮罩资产作为后续局部编辑输入。")
        prompt_hint = str(control_values.get("prompt_hint") or "").strip()
        if prompt_hint:
            translated_params["prompt"] = prompt_hint
            explanations.append("将用户补充的目标描述继续作为分割提示词。")

    elif lens_id == "lens_relighting":
        light_orb = control_values.get("light_orb") or {}
        translated_params.update(_map_relighting_controls(light_orb, current_params=current_params))
        explanations.append("根据光球位置、强度和色温微调光影 prompt 与采样步数。")

    elif lens_id == "lens_depth_of_field":
        focus = control_values.get("tap_to_focus") or {}
        aperture = control_values.get("aperture_dial") or {}
        translated_params.update(_map_depth_of_field_controls(focus, aperture))
        explanations.append("根据对焦点和光圈控件联动景深参数。")

    elif lens_id == "lens_style":
        translated_params.update(_map_style_controls(control_values))
        explanations.append("根据风格强度和结构保留滑块更新风格迁移参数。")

    elif lens_id == "lens_lora_filter":
        translated_params.update(_map_lora_filter_controls(control_values))
        explanations.append("根据滤镜选择器和浓度滑块更新 LoRA 滤镜参数。")

    return {
        "translated_params": translated_params,
        "translated_assets": translated_assets,
        "merged_params": {**current_params, **translated_params},
        "merged_assets": {**current_assets, **translated_assets},
        "explanations": explanations,
    }


def _map_relighting_controls(light_orb: Dict[str, Any], *, current_params: Dict[str, Any]) -> Dict[str, Any]:
    x = _coerce_float(light_orb.get("x"), 0.5)
    y = _coerce_float(light_orb.get("y"), 0.25)
    z = _coerce_float(light_orb.get("z"), 0.75)
    intensity = _coerce_float(light_orb.get("intensity"), 0.8)
    color_temperature = _coerce_float(light_orb.get("color_temperature"), 5200)
    mood = str(light_orb.get("mood") or "").strip()
    scene_hint = str(light_orb.get("scene_hint") or current_params.get("prompt") or "").strip()

    prompt = _llm_generate_relighting_prompt(
        x=x,
        y=y,
        z=z,
        intensity=intensity,
        color_temperature=color_temperature,
        mood=mood,
        scene_hint=scene_hint,
    )
    if not prompt:
        prompt = _fallback_relighting_prompt(
            x=x,
            y=y,
            z=z,
            intensity=intensity,
            color_temperature=color_temperature,
            mood=mood,
            scene_hint=scene_hint,
        )

    steps = int(round(18 + intensity * 14))
    return {
        "prompt": prompt,
        "steps": max(16, min(36, steps)),
    }


def _map_depth_of_field_controls(focus: Dict[str, Any], aperture: Dict[str, Any]) -> Dict[str, Any]:
    focus_depth = focus.get("focus_depth_value")
    if focus_depth is None:
        focus_depth = focus.get("depth_value")
    aperture_value = _coerce_float(aperture.get("value"), 0.5)

    out: Dict[str, Any] = {}
    if focus_depth is not None:
        out["dof_focus_point"] = max(0.0, min(1.0, _coerce_float(focus_depth, 0.5)))

    out["dof_intensity"] = round(0.1 + aperture_value * 0.9, 4)
    out["dof_sharpness_radius"] = round(max(0.02, 0.5 - aperture_value * 0.4), 4)
    return out


def _map_style_controls(control_values: Dict[str, Any]) -> Dict[str, Any]:
    intensity = _coerce_float(control_values.get("style_intensity"), 0.8)
    preservation = _coerce_float(control_values.get("structure_preservation"), 0.7)
    return {
        "ipadapter_weight": round(max(0.0, min(1.0, intensity)), 4),
        "controlnet_strength": round(max(0.0, min(1.0, preservation)), 4),
        "denoise": round(max(0.15, min(0.85, 0.9 - preservation * 0.5)), 4),
    }


def _map_lora_filter_controls(control_values: Dict[str, Any]) -> Dict[str, Any]:
    out: Dict[str, Any] = {}
    preset_key = str(control_values.get("filter_selector") or "").strip().lower()
    if preset_key and preset_key in _FILTER_PRESETS:
        out.update(_FILTER_PRESETS[preset_key])

    opacity = _coerce_float(control_values.get("filter_opacity"), 0.8)
    strength = round(max(0.0, min(1.2, opacity)), 4)
    out["strength_model"] = strength
    out["strength_clip"] = strength
    return out


def _fallback_relighting_prompt(
    *,
    x: float,
    y: float,
    z: float,
    intensity: float,
    color_temperature: float,
    mood: str,
    scene_hint: str,
) -> str:
    horizontal = "left" if x < 0.35 else "right" if x > 0.65 else "center"
    vertical = "top" if y < 0.35 else "bottom" if y > 0.65 else "mid-height"
    distance = "close dramatic key light" if z > 0.66 else "soft ambient light" if z < 0.33 else "natural medium-distance light"
    warmth = (
        "warm golden light"
        if color_temperature < 4200
        else "cool bluish light"
        if color_temperature > 6500
        else "neutral daylight"
    )
    strength = "strong contrast" if intensity > 0.75 else "soft gentle lighting" if intensity < 0.4 else "balanced cinematic lighting"
    mood_part = f", {mood}" if mood else ""
    hint_part = f", preserve the original scene while applying {scene_hint}" if scene_hint else ""
    return (
        f"{strength}, {warmth}, light coming from the {vertical} {horizontal}, "
        f"{distance}{mood_part}{hint_part}"
    )


def _llm_generate_relighting_prompt(
    *,
    x: float,
    y: float,
    z: float,
    intensity: float,
    color_temperature: float,
    mood: str,
    scene_hint: str,
) -> str:
    api_key = os.getenv("MUSELENS_LLM_API_KEY", "")
    model = os.getenv("MUSELENS_LLM_MODEL", "")
    base_url = (os.getenv("MUSELENS_LLM_BASE_URL") or "https://api.openai.com/v1").rstrip("/")
    timeout_s = float(os.getenv("MUSELENS_LLM_TIMEOUT_S", "30"))
    if not api_key or not model:
        return ""

    system = (
        "You translate a 3D light control widget into a concise English relighting prompt for an image model.\n"
        "Focus on light direction, intensity, color temperature, cinematic mood, and preservation of the original scene.\n"
        "Return JSON with a single field named prompt."
    )
    user = {
        "light_orb": {
            "x": x,
            "y": y,
            "z": z,
            "intensity": intensity,
            "color_temperature": color_temperature,
            "mood": mood,
        },
        "scene_hint": scene_hint,
    }

    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": json.dumps(user, ensure_ascii=False)},
        ],
        "response_format": {
            "type": "json_schema",
            "json_schema": {
                "name": "relighting_prompt",
                "schema": {
                    "type": "object",
                    "properties": {
                        "prompt": {"type": "string"},
                    },
                    "required": ["prompt"],
                    "additionalProperties": False,
                },
            },
        },
    }
    headers = {"Authorization": f"Bearer {api_key}"}
    url = f"{base_url}/chat/completions"

    try:
        with httpx.Client(timeout=timeout_s) as client:
            resp = client.post(url, headers=headers, json=payload)
            resp.raise_for_status()
            data = resp.json()
        content = data["choices"][0]["message"]["content"]
        obj = json.loads(content) if isinstance(content, str) else content
        prompt = str((obj or {}).get("prompt") or "").strip()
        return prompt
    except Exception:
        return ""


def _coerce_float(value: Any, default: float) -> float:
    try:
        return float(value)
    except Exception:
        return float(default)
