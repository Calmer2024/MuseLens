---
lens_id: lens_depth_of_field
layer: A3
description: |
  基于原图和深度图做纯光学景深模拟。该透镜不会改写主体语义，而是根据 depth_map 控制焦平面、虚化范围、暗角和高光晕染，输出更接近真实镜头效果的结果图。
params:
  dof_focus_point:
    description: |
      对焦平面在 depth_map 中的位置，通常使用 0.0 到 1.0 的浮点数。
    required: false
    decision_rules: |
      用户明确说“前景清晰”“背景清晰”“对焦在人物/眼睛/前排物体上”时，可映射到该参数。
    format_rules: |
      输出 0.0 到 1.0 之间的浮点数。
  dof_intensity:
    description: |
      景深虚化强度，值越大，离焦区域越明显。
    required: false
    format_rules: |
      输出非负浮点数。
  dof_sharpness_radius:
    description: |
      清晰区域宽度，值越大，焦内范围越宽。
    required: false
    format_rules: |
      输出 0.0 到 1.0 之间的浮点数。
  vignette_intensity:
    description: |
      画面边缘暗角强度。
    required: false
    format_rules: |
      输出非负浮点数。
  halation_strength:
    description: |
      高光晕染强度，适合夜景、逆光或梦幻感镜头。
    required: false
    format_rules: |
      输出非负浮点数。
examples:
  - nl_desc: 让人物面部附近保持清晰，背景明显虚化，略带电影感暗角
    params_example:
      dof_focus_point: 0.42
      dof_intensity: 0.55
      dof_sharpness_radius: 0.2
      vignette_intensity: 0.18
      halation_strength: 0.08
  - nl_desc: 让远处建筑更清楚，前景轻微虚化，高光稍微软一点
    params_example:
      dof_focus_point: 0.78
      dof_intensity: 0.25
      dof_sharpness_radius: 0.3
      vignette_intensity: 0.1
      halation_strength: 0.15
---

## 适用任务

- 模拟单反景深、焦距感、散景和镜头味。
- 保留原图语义，只调整清晰范围、虚化层次和镜头氛围。
- 适合“背景虚一点”“前景清楚、后景柔化”“更像摄影镜头”的需求。

## 不适用任务

- 不负责替换主体、改造服装、改写风格或生成新物体。
- 没有 `prompt`，不能靠文字直接改变内容语义。
- 没有 `depth_map` 时不能发挥作用，通常需要先接 `lens_depth_extract`。

## 上下游衔接

- 上游通常是 `lens_depth_extract`，为当前透镜提供 `depth_map`。
- 下游可继续接 `lens_upscale_4x` 或 `lens_watermark` 作为交付阶段处理。

## 实现依据

- config 真实输入为 `base_image` 和 `depth_map`，输出为 `result_image`。
- workflow 使用外部传入的深度图，不在当前透镜内部重新估计深度。
- 该透镜属于光学后处理，不是扩散式重绘链路。
