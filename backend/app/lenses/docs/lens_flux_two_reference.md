---
lens_id: lens_flux_two_reference
layer: A2
description: |
  基于 FLUX.2 的双参考约束重绘。输入原图与两张参考资产，在重绘时同时锁定多维结构或语义特征，适合要求更强约束的复杂改图任务。

params:
  prompt:
    description: |
      描述在双重参考约束下希望得到的最终视觉效果。
    required: true
    default: ""
    decision_rules: |
      如果用户只说明“两张参考图都要保留”但没有交代最终风格或修改目标，应判定为 missing。
      当用户明确说明要保留哪些特征并给出目标风格时，可直接使用。
    format_rules: |
      建议用一句话描述：保留哪些约束 + 最终风格或光影目标。
  steps:
    description: |
      控制采样步数。
    required: false
    default: 20
    format_rules: |
      输出为正整数。
  cfg:
    description: |
      控制文本提示的引导强度。
    required: false
    default: 5
    format_rules: |
      输出为正数。
  noise_seed:
    description: |
      控制随机种子。
    required: false
    default: 478053097682713
    format_rules: |
      输出为整数。

examples:
  - nl_desc: "同时保留原图的人物结构和参考图里的空间深度关系，把画面改成舞台追光氛围。"
    params_example:
      prompt: "dramatic stage spotlight atmosphere, preserve subject structure and depth relationship"
      steps: 20
      cfg: 5
      noise_seed: 478053097682713
---

使用建议（可选正文）：
- 适合“既要保留形体，又要保留另一种结构线索”的场景。
- 当单一参考约束不够时，可以升级为这个 lens。
