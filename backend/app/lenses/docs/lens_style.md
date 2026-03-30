---
lens_id: lens_style
layer: A4
description: |
  基于参考风格图的风格迁移透镜。输入原图和一张 `style_reference_image` 后，workflow 会在内部提取深度并结合 IPAdapter 与 ControlNet，在保留主体结构的前提下完成整体风格化重绘。
params:
  prompt:
    description: |
      补充说明目标风格、氛围、主体保留要求或需要强调的视觉特征。
    required: false
    format_rules: |
      建议写成对风格图的补充说明，而不是完全替代风格图。
  ipadapter_weight:
    description: |
      风格参考图对结果的影响强度。
    required: false
    format_rules: |
      输出浮点数。
  controlnet_strength:
    description: |
      结构保持强度。
    required: false
    format_rules: |
      输出浮点数。
  denoise:
    description: |
      风格化重绘幅度。
    required: false
    format_rules: |
      输出 0 到 1 左右的浮点数。
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
  seed:
    description: |
      随机种子。
    required: false
    format_rules: |
      输出整数。
examples:
  - nl_desc: 参考上传的插画风格图，把原图重绘成柔和的绘本质感
    params_example:
      prompt: storybook illustration, soft color transitions, preserve the main subject
      ipadapter_weight: 0.8
      controlnet_strength: 0.7
      denoise: 0.4
      steps: 24
      cfg: 5.0
      seed: 8001
  - nl_desc: 参考一张油画作品，把原图改成厚涂油画风但保留人物结构
    params_example:
      prompt: oil painting texture, rich brush strokes, preserve the character silhouette
      ipadapter_weight: 0.85
      controlnet_strength: 0.75
      denoise: 0.45
      steps: 24
      cfg: 5.2
      seed: 8002
---

## 适用任务

- 用户提供了明确风格参考图，希望把原图改成类似画风。
- 既要“像参考图”，又要保留原图主体和大结构。

## 不适用任务

- 不适合没有风格参考图的纯文本风格化。
- 不适合精确局部替换，因为没有遮罩输入。
- 不适合简单加字、放大等交付阶段任务。

## 上下游衔接

- 该透镜内部会生成深度图并应用结构约束，因此无需外部 `depth_map`。
- 下游可接 `lens_upscale_4x` 和 `lens_watermark`。

## 实现依据

- config 真实输入为 `base_image` 和 `style_reference_image`。
- workflow 中包含 `DepthAnythingV2Preprocessor`、`IPAdapterModelLoader`、`IPAdapterAdvanced` 和 `ControlNetApplyAdvanced`。
- 说明它是“风格参考驱动 + 内部结构约束”的整体风格迁移透镜。
