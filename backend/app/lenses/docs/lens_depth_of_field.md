---
lens_id: lens_depth_of_field
layer: A3
description: |
  基于原图与深度图进行纯光学景深模拟，控制焦平面、虚化范围、暗角和高光光晕，输出更接近真实镜头观感的结果图。

params:
  dof_focus_point:
    description: |
      对焦平面在深度图中的位置。通常取值 0.0 到 1.0，越接近 0 表示焦点越靠前，越接近 1 表示焦点越靠后。
    required: false
    default: 0.6
    decision_rules: |
      当用户明确指定“前景清晰”“背景清晰”或点选了某个主体位置时，可以直接映射为该参数。
      如果用户只说“加一点景深”而没有指定焦点对象，可以沿用默认值。
    format_rules: |
      输出为 0.0 到 1.0 的浮点数。
  dof_intensity:
    description: |
      控制景深虚化强度，值越大，离焦区域越明显。
    required: false
    default: 0.3
    format_rules: |
      输出为非负浮点数，常见范围可落在 0.0 到 1.0。
  dof_sharpness_radius:
    description: |
      控制清晰区域宽度，值越大，焦内范围越宽。
    required: false
    default: 0.35
    format_rules: |
      输出为 0.0 到 1.0 的浮点数。
  vignette_intensity:
    description: |
      控制画面边缘暗角强度，用于增强镜头包围感。
    required: false
    default: 0.15
    format_rules: |
      输出为非负浮点数。
  halation_strength:
    description: |
      控制高光区域的柔和外扩效果，适合增强夜景或逆光氛围。
    required: false
    default: 0.15
    format_rules: |
      输出为非负浮点数。

examples:
  - nl_desc: "让人物眼睛附近保持清晰，背景产生明显散景，并保留一点电影感暗角。"
    params_example:
      dof_focus_point: 0.45
      dof_intensity: 0.55
      dof_sharpness_radius: 0.22
      vignette_intensity: 0.2
      halation_strength: 0.12
---

使用建议（可选正文）：
- 适合接在 `lens_depth_extract` 之后使用，由深度图驱动镜头级景深模拟。
- 如果用户希望“更像单反”“更有散景”“背景虚一点”，通常可以优先考虑这个 lens。
