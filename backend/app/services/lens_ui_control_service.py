from __future__ import annotations

from typing import Any, Dict, List


_LENS_TWEAK_SPECS: Dict[str, List[Dict[str, Any]]] = {
    "lens_relighting": [
        {
            "control_id": "light_orb",
            "label": "3D光球",
            "control_type": "light_orb",
            "description": "拖拽光源位置并调整强度、色温，后端映射为更细致的 prompt 与采样强度。",
            "stage": "refine",
            "bindings": [
                {
                    "target_type": "param",
                    "target_name": "prompt",
                    "mapping_strategy": "synthesize_relighting_prompt_from_light_orb",
                },
                {
                    "target_type": "param",
                    "target_name": "steps",
                    "mapping_strategy": "adjust_steps_by_light_strength",
                },
            ],
        }
    ],
    "lens_depth_of_field": [
        {
            "control_id": "tap_to_focus",
            "label": "触控对焦",
            "control_type": "point_picker",
            "description": "点击图像位置，对应深度值映射为 dof_focus_point。",
            "stage": "refine",
            "bindings": [
                {
                    "target_type": "param",
                    "target_name": "dof_focus_point",
                    "mapping_strategy": "sample_depth_value_at_xy",
                }
            ],
        },
        {
            "control_id": "aperture_dial",
            "label": "光圈转盘",
            "control_type": "dial",
            "description": "通过一个光圈控件联动虚化强度和清晰范围。",
            "stage": "refine",
            "bindings": [
                {
                    "target_type": "param",
                    "target_name": "dof_intensity",
                    "mapping_strategy": "map_aperture_to_blur_strength",
                },
                {
                    "target_type": "param",
                    "target_name": "dof_sharpness_radius",
                    "mapping_strategy": "map_aperture_to_focus_radius",
                },
            ],
        },
    ],
    "lens_style": [
        {
            "control_id": "style_intensity",
            "label": "风格强度",
            "control_type": "slider",
            "description": "控制参考风格对结果的覆盖程度。",
            "stage": "refine",
            "bindings": [
                {
                    "target_type": "param",
                    "target_name": "ipadapter_weight",
                    "mapping_strategy": "direct_float",
                }
            ],
        },
        {
            "control_id": "structure_preservation",
            "label": "结构保留",
            "control_type": "slider",
            "description": "控制结构约束和重绘幅度的平衡。",
            "stage": "refine",
            "bindings": [
                {
                    "target_type": "param",
                    "target_name": "controlnet_strength",
                    "mapping_strategy": "direct_float",
                },
                {
                    "target_type": "param",
                    "target_name": "denoise",
                    "mapping_strategy": "inverse_float_pair",
                },
            ],
        },
    ],
    "lens_lora_filter": [
        {
            "control_id": "filter_selector",
            "label": "滤镜选择器",
            "control_type": "preset_selector",
            "description": "选择预置滤镜，并自动带出对应的 LoRA 名称和建议 prompt。",
            "stage": "refine",
            "bindings": [
                {
                    "target_type": "param",
                    "target_name": "lora_name",
                    "mapping_strategy": "preset_to_lora_name",
                },
                {
                    "target_type": "param",
                    "target_name": "prompt",
                    "mapping_strategy": "preset_to_prompt",
                },
            ],
        },
        {
            "control_id": "filter_opacity",
            "label": "滤镜浓度",
            "control_type": "slider",
            "description": "联动控制 LoRA 对模型侧和文本侧的影响强度。",
            "stage": "refine",
            "bindings": [
                {
                    "target_type": "param",
                    "target_name": "strength_model",
                    "mapping_strategy": "direct_float",
                },
                {
                    "target_type": "param",
                    "target_name": "strength_clip",
                    "mapping_strategy": "direct_float",
                },
            ],
        },
    ],
}


def get_lens_tweak_controls(lens_id: str) -> List[Dict[str, Any]]:
    return list(_LENS_TWEAK_SPECS.get(lens_id, []))
