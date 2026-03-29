---
lens_id: lens_flux_text2image
layer: A2
description: |
  基于 FLUX.2 的纯文本生图透镜。不依赖输入原图，直接根据文字描述生成全新画面，适合作为从零生成的起点。

params:
  prompt:
    description: |
      描述希望生成的主体、场景、风格、构图和光照。
    required: true
    default: ""
    decision_rules: |
      如果用户没有给出主体或场景，只说“来一张图”“帮我生成一下”，应判定为 missing。
      当用户已经说明主体、场景或风格要求时，可以直接使用。
    format_rules: |
      建议用一句完整描述，包含主体 + 场景 + 风格或光照关键词。
  width:
    description: |
      生成图像宽度。
    required: false
    default: 1024
    format_rules: |
      输出为正整数。
  height:
    description: |
      生成图像高度。
    required: false
    default: 1024
    format_rules: |
      输出为正整数。
  steps:
    description: |
      控制采样步数。
    required: false
    default: 20
    format_rules: |
      输出为正整数。
  cfg:
    description: |
      控制文本提示对生成结果的引导强度。
    required: false
    default: 5
    format_rules: |
      输出为正数。
  noise_seed:
    description: |
      控制随机种子，用于复现结果或探索不同构图。
    required: false
    default: 280988996286171
    format_rules: |
      输出为整数。

examples:
  - nl_desc: "生成一张雨夜街头的赛博朋克少女海报，纵向构图。"
    params_example:
      prompt: "cyberpunk girl on a rainy night street, neon reflections, poster composition, cinematic lighting"
      width: 1024
      height: 1536
      steps: 20
      cfg: 5
      noise_seed: 280988996286171
  - nl_desc: "生成一张极简白底产品图，主体是一只陶瓷花瓶。"
    params_example:
      prompt: "minimal ceramic vase product shot, clean white background, soft studio lighting"
      width: 1024
      height: 1024
      steps: 18
      cfg: 4.5
      noise_seed: 280988996286172
---

使用建议（可选正文）：
- 当用户没有上传底图，而是希望从零开始生成画面时，通常触发这个 lens。
- `width` 与 `height` 可以用于控制比例，例如海报、方图或横幅。
