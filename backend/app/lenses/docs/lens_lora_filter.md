---
lens_id: lens_lora_filter
layer: A4
description: |
  基于 LoRA 和内部深度约束的滤镜化重绘。输入原图后，workflow 会在内部提取深度并结合 ControlNet 保护结构，再通过指定的 LoRA 模型覆盖材质、笔触、色彩和氛围。
params:
  lora_name:
    description: |
      要加载的 LoRA 模型名称。
    required: true
    decision_rules: |
      如果系统没有可用的 LoRA 名单，或用户没有选择滤镜型号，应判定为 missing。
    format_rules: |
      输出系统中可加载的 LoRA 文件名或注册名称。
  prompt:
    description: |
      补充说明希望叠加的风格、材质和氛围。
    required: false
    format_rules: |
      建议写滤镜风格补充词，不要写局部替换指令。
  strength_model:
    description: |
      LoRA 对模型侧的影响强度。
    required: false
    format_rules: |
      输出浮点数。
  strength_clip:
    description: |
      LoRA 对文本编码侧的影响强度。
    required: false
    format_rules: |
      输出浮点数。
  denoise:
    description: |
      重绘幅度。
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
  - nl_desc: 给照片叠加复古胶片滤镜，颗粒感更明显，色彩偏暖
    params_example:
      lora_name: vintage_film_filter.safetensors
      prompt: warm vintage film look, subtle grain, nostalgic atmosphere
      strength_model: 0.8
      strength_clip: 0.8
      denoise: 0.35
      steps: 24
      cfg: 5.0
      seed: 6101
  - nl_desc: 把画面做成水彩插画滤镜，尽量保留原始构图
    params_example:
      lora_name: watercolor_filter.safetensors
      prompt: watercolor texture, soft pigment edges, preserve composition
      strength_model: 0.75
      strength_clip: 0.75
      denoise: 0.3
      steps: 24
      cfg: 5.0
      seed: 6102
---

## 适用任务

- 已知要使用某个具体 LoRA 滤镜模型。
- 希望在尽量保留原图结构的前提下，叠加统一的材质和笔触风格。

## 不适用任务

- 不适合没有 LoRA 型号可选的开放式任务。
- 不适合精确主体替换或局部区域编辑。
- 它更像“套滤镜重绘”，不是“理解场景再做复杂编排”的主透镜。

## 上下游衔接

- 该透镜本身会在 workflow 内部生成深度图，因此不需要外部 `depth_map` 输入。
- 下游可继续接 `lens_upscale_4x` 或 `lens_watermark`。

## 实现依据

- config 只有 `base_image` 输入，但 workflow 内部包含 `DepthAnythingV2Preprocessor`、`ControlNetLoader` 和 `LoraLoader`。
- 这说明深度约束是在透镜内部完成的，不需要前置 A1 深度提取透镜。
