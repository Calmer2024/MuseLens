---
lens_id: lens_flux_reference
layer: A2
description: |
  基于 FLUX.2 的单参考约束重绘。除了输入原图，还接收一张参考资产，在重绘时锁定额外结构特征，例如深度、边缘或其他引导图信息。

params:
  prompt:
    description: |
      描述希望在保留参考约束前提下实现的视觉变化，例如风格、氛围、光照和材质方向。
    required: true
    default: ""
    decision_rules: |
      如果用户只说“参考这张图改一下”但没有说明最终想达到的风格或效果，应判定为 missing。
      如果用户给出了明确的画面方向，则可以直接使用。
    format_rules: |
      建议用一句话描述：保留参考约束 + 目标风格或光照方向。
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
  - nl_desc: "保留深度结构不变，把原图改成清晨薄雾中的电影感场景。"
    params_example:
      prompt: "cinematic early morning mist, soft cool lighting, preserve spatial structure"
      steps: 20
      cfg: 5
      noise_seed: 478053097682713
---

使用建议（可选正文）：
- 适合与 `lens_depth_extract` 等 A1 透镜产物联动，用来锁住结构信息。
- 当用户既想改风格，又明确要求“保持原有深度/结构/轮廓”时，可以优先考虑这个 lens。
