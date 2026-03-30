---
lens_id: lens_flux_two_reference
layer: A2
description: |
  基于 FLUX 的双参考约束重绘。输入原图和两张参考图，在重绘时同时保留两类结构或语义约束，例如同时锁定深度和边缘，或同时锁定姿态和轮廓。
params:
  prompt:
    description: |
      描述在双参考约束下最终想得到的画面方向。
    required: true
    decision_rules: |
      如果用户只强调“别变形”却没有说明最终目标效果，应判定为 missing。
      当任务需要同时保留两类约束且有明确目标风格或光影方向时，可直接使用。
    format_rules: |
      建议写成一句话，明确保留结构约束前提下的目标视觉效果。
  steps:
    description: |
      采样步数。
    required: false
    format_rules: |
      输出正整数。
  cfg:
    description: |
      文本引导强度。
    required: false
    format_rules: |
      输出正数。
  noise_seed:
    description: |
      随机种子。
    required: false
    format_rules: |
      输出整数。
examples:
  - nl_desc: 同时保留原有深度和轮廓边缘，把画面改成工业风暗色电影海报
    params_example:
      prompt: preserve depth and edge structure, dark industrial cinematic poster, dramatic shadows
      steps: 24
      cfg: 5.5
      noise_seed: 5201
  - nl_desc: 保留人物姿态和整体空间关系，把画面改成高饱和二次元风格
    params_example:
      prompt: preserve pose and spatial composition, vibrant anime style, clean shading
      steps: 24
      cfg: 5.0
      noise_seed: 5202
---

## 适用任务

- 一个参考还不够，需要同时锁两类约束。
- 适合“既要保留空间结构，又要保留轮廓/姿态”的图生图重绘。

## 不适用任务

- 不适合纯局部替换，因为没有 `mask`。
- 如果只需要一张参考图，优先用 `lens_flux_reference`，链路更简单。

## 上下游衔接

- 上游常见组合是 `lens_depth_extract` + `lens_canny_extract`，或 `lens_depth_extract` + `lens_pose_extract`。
- 下游可接 A5 交付类透镜。

## 实现依据

- config 真实输入为 `base_image`、`ref_image_1`、`ref_image_2`。
- workflow 中存在两张独立参考图加载与缩放节点，说明它确实支持双参考链路。
