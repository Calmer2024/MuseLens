---
lens_id: lens_flux_edit
layer: A2
description: |
  基于 FLUX.2 的无遮罩全局语义重绘。输入原图后，通过参考潜空间尽量保留原有构图，再按文字指令整体改写风格、光影、材质或画面气质。

params:
  prompt:
    description: |
      描述希望重绘后的整体视觉方向，例如艺术风格、时间氛围、材质、色彩和光照方式。
    required: true
    default: ""
    decision_rules: |
      如果用户只说“改一下”“更高级一点”“更好看”而没有给出可落地的视觉方向，应判定为 missing。
      当用户明确给出风格、材质、灯光或时代感时，可直接使用。
    format_rules: |
      建议用一句话描述：主体保留要求 + 风格方向 + 光影或材质关键词。
  steps:
    description: |
      控制采样步数，步数越高，文本意图通常覆盖得更充分。
    required: false
    default: 20
    format_rules: |
      输出为正整数。
  cfg:
    description: |
      控制文本提示的引导强度。值越高，结果越贴近 prompt。
    required: false
    default: 5
    format_rules: |
      输出为正数。
  noise_seed:
    description: |
      控制随机种子，用于复现结果或探索不同细节变化。
    required: false
    default: 38564433706143
    format_rules: |
      输出为整数。

examples:
  - nl_desc: "把这张人像改成杂志封面风格，保持人物姿态和构图不变。"
    params_example:
      prompt: "fashion magazine cover style, dramatic studio lighting, premium texture, keep original composition"
      steps: 20
      cfg: 5
      noise_seed: 38564433706143
  - nl_desc: "把原图整体改成雨夜霓虹电影感，构图保持一致。"
    params_example:
      prompt: "rainy neon night cinematic look, reflective surfaces, moody contrast, keep original framing"
      steps: 24
      cfg: 5.5
      noise_seed: 38564433706144
---

使用建议（可选正文）：
- 适合“整体改风格但不想抠局部”的场景。
- 如果用户强调的是全局气质、材质或灯光变化，而不是局部替换，通常优先考虑这个 lens。
