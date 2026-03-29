---
lens_id: lens_relighting
layer: A3
description: |
  基于原图与深度图的全局光影重构透镜。通过 FLUX.2 参考潜空间，在尽量保持结构稳定的前提下，重写主光方向、环境光、色温和整体氛围。

params:
  prompt:
    description: |
      描述希望施加的光影变化，例如“暖金色逆光”“冷调月光”“室内钨丝灯氛围”等。
    required: true
    default: ""
    decision_rules: |
      如果用户只说“改一下光影”“更有氛围”而没有说明方向、色温或时间感，应判定为 missing。
      当用户说明了主光方向、色温或具体环境氛围时，可以直接使用。
    format_rules: |
      建议用一句摄影风格描述，包含方向 + 光强 + 色温或环境关键词。
  steps:
    description: |
      控制采样步数。
    required: false
    default: 20
    format_rules: |
      输出为正整数。
  cfg:
    description: |
      控制光影提示词对结果的引导强度。
    required: false
    default: 5
    format_rules: |
      输出为正数。
  noise_seed:
    description: |
      控制随机种子。
    required: false
    default: 364900178974343
    format_rules: |
      输出为整数。

examples:
  - nl_desc: "保持人物结构不变，把画面改成右上方暖金色逆光的傍晚氛围。"
    params_example:
      prompt: "strong warm golden backlight from upper right, sunset atmosphere, preserve subject structure"
      steps: 20
      cfg: 5
      noise_seed: 364900178974343
  - nl_desc: "把照片改成冷调月光夜景，环境光更柔和。"
    params_example:
      prompt: "soft cool moonlight, subtle ambient shadows, quiet night atmosphere"
      steps: 22
      cfg: 5.2
      noise_seed: 364900178974344
---

使用建议（可选正文）：
- 适合用户明确提出“改光线”“换成夜景光感”“做逆光/侧光”的需求。
- 如果任务依赖空间体积感，建议先提供可靠的深度图再进入这个 lens。
