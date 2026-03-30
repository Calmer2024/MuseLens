---
lens_id: lens_flux_text2image
layer: A2
description: |
  纯文本生图透镜。它不依赖原图，直接根据 prompt、分辨率和采样参数生成全新的结果图，适合作为无中生有的起点。
params:
  prompt:
    description: |
      描述希望生成的主体、场景、风格、镜头和光照。
    required: true
    decision_rules: |
      如果用户只说“随便生成一张”而没有给出主题，应判定为 missing。
    format_rules: |
      建议用一句完整提示词描述主体、环境和视觉风格。
  width:
    description: |
      生成图像宽度。
    required: false
    format_rules: |
      输出正整数像素值。
  height:
    description: |
      生成图像高度。
    required: false
    format_rules: |
      输出正整数像素值。
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
  - nl_desc: 生成一张黄昏海边的电影感人像海报
    params_example:
      prompt: cinematic portrait by the seaside at dusk, warm golden light, detailed skin, soft wind
      width: 1024
      height: 1536
      steps: 24
      cfg: 5.0
      noise_seed: 5001
  - nl_desc: 生成一张赛博朋克雨夜街道场景图
    params_example:
      prompt: cyberpunk rainy street at night, neon signs, wet reflections, cinematic composition
      width: 1536
      height: 1024
      steps: 26
      cfg: 5.5
      noise_seed: 5002
---

## 适用任务

- 用户没有上传原图，只想根据文字直接生成图片。
- 作为新画面的起点，再接后续风格化、放大或水印透镜。

## 不适用任务

- 不适合“修改这张图”“保留原图构图”这类图生图任务。
- 不能消费 `base_image`、`mask`、`depth_map` 等任何上游资产。

## 上下游衔接

- 当前透镜可作为生成起点，后续可接 `lens_upscale_4x`、`lens_watermark` 等 A5 透镜。

## 实现依据

- config 没有任何输入资产，只接受参数。
- workflow 是标准文本到图像生成链，不依赖原图。
