---
lens_id: lens_flux_inpaint
layer: A2
description: |
  基于 FLUX.2 的局部遮罩重绘。输入原图与遮罩后，仅对白色遮罩区域执行语义重建，其余区域尽量保持不变，适合精确局部替换或补画。

params:
  prompt:
    description: |
      描述遮罩区域希望被重绘成的内容，包括物体、材质、色彩和局部光照。
    required: true
    default: ""
    decision_rules: |
      如果用户只说“修一下这里”“把这块改掉”但没有说明改成什么，应判定为 missing。
      当用户已经明确给出替换目标或局部视觉要求时，可直接使用。
    format_rules: |
      建议用一句话描述：替换内容 + 局部光影 + 与周围环境的融合要求。
  steps:
    description: |
      控制局部重绘的采样步数。
    required: false
    default: 20
    format_rules: |
      输出为正整数。
  cfg:
    description: |
      控制文本提示对局部重绘的引导强度。
    required: false
    default: 5
    format_rules: |
      输出为正数。
  noise_seed:
    description: |
      控制局部重绘的随机种子。
    required: false
    default: 478053097682713
    format_rules: |
      输出为整数。

examples:
  - nl_desc: "把遮罩里的天空补成晚霞，并让颜色和周围环境自然融合。"
    params_example:
      prompt: "warm sunset sky, soft clouds, natural color transition, blend with surrounding lighting"
      steps: 20
      cfg: 5
      noise_seed: 478053097682713
  - nl_desc: "把被遮住的物体替换成一束白色郁金香，保留原有光照方向。"
    params_example:
      prompt: "a bouquet of white tulips, realistic texture, keep original lighting direction"
      steps: 24
      cfg: 5.5
      noise_seed: 478053097682714
---

使用建议（可选正文）：
- 适合与 `lens_sam2_matting` 或其他遮罩生成 lens 串联使用。
- 当用户明确指定了局部区域并希望“只改这里”，这个 lens 通常比全局重绘更合适。
