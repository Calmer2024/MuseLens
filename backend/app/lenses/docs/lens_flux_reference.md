---
lens_id: lens_flux_reference
layer: A2
description: |
  基于 FLUX 的单参考约束重绘。输入原图和 1 张参考图，在重绘时额外锁定一类结构或物理特征。参考图可以是深度图、边缘图、姿态图，或其他由上游透镜提供的引导资产。
params:
  prompt:
    description: |
      描述在保留参考约束前提下，最终希望得到的视觉变化。
    required: true
    decision_rules: |
      如果用户只说“参考这张图改一下”但没说明最终要改成什么，应判定为 missing。
      如果用户既说明了目标效果，又说明要保留某种结构约束，可直接使用。
    format_rules: |
      建议写成“保留某类结构约束 + 目标风格/光影/材质”的一句话。
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
  - nl_desc: 保留原有深度结构，把画面改成清晨薄雾中的电影感场景
    params_example:
      prompt: preserve the spatial structure, cinematic early morning mist, soft cool lighting
      steps: 22
      cfg: 5.0
      noise_seed: 4101
  - nl_desc: 保留人物姿态轮廓，把画面改成赛博朋克夜景
    params_example:
      prompt: preserve the pose silhouette, cyberpunk night scene, neon reflections
      steps: 24
      cfg: 5.5
      noise_seed: 4102
---

## 适用任务

- 需要保留一类明确结构约束，同时做重绘。
- 只有一种关键参考资产就够用，例如只锁深度、只锁姿态、只锁边缘。
- 适合“结构尽量别变，但整体风格/光影要变”的需求。

## 不适用任务

- 不适合需要同时锁定两种以上结构约束的任务，那类场景更适合 `lens_flux_two_reference`。
- 不适合局部替换，因为没有 `mask`。
- 参考图为空时无法发挥单参考约束价值。

## 上下游衔接

- 上游可来自 `lens_depth_extract`、`lens_canny_extract`、`lens_pose_extract` 等 A1 透镜。
- 下游通常继续接交付透镜，如 `lens_upscale_4x`。

## 实现依据

- config 真实输入为 `base_image` 和 `ref_image_1`。
- workflow 中确实存在第二张加载图像节点，用于单参考重绘。
- 参考输入类型在配置层是通用 `image`，因此可承接多类引导图。
