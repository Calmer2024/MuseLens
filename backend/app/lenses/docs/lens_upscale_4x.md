---
lens_id: lens_upscale_4x
layer: A5
description: |
  对输入图像执行高清放大与细节增强。该透镜结合 Ultimate SD Upscale 与 UltraSharp 放大模型，在提升分辨率的同时补充纹理细节、改善模糊和噪点。

params:
  upscale_by:
    description: |
      控制放大倍数。
    required: false
    default: 2
    format_rules: |
      输出为大于 1 的数值。
  prompt:
    description: |
      正向细节增强提示词，用于引导放大时补充更理想的材质和纹理。
    required: false
    default: "masterpiece, best quality, ultra detailed, 8k, highres"
    decision_rules: |
      如果用户只是单纯想提高画质，不强调具体纹理方向，可以沿用默认值。
      如果用户明确提到“皮肤更细腻”“布料纹理更清楚”“建筑细节更清晰”等，可以补充到该参数。
    format_rules: |
      输出为简洁的纹理或细节增强描述。
  denoise:
    description: |
      控制放大时的重绘幅度，值越高，新增细节越多，但原图变化也可能更明显。
    required: false
    default: 0.2
    format_rules: |
      输出为 0.0 到 1.0 的浮点数，常见安全范围建议 0.15 到 0.35。
  steps:
    description: |
      控制采样步数。
    required: false
    default: 20
    format_rules: |
      输出为正整数。
  cfg:
    description: |
      控制提示词引导强度。
    required: false
    default: 8
    format_rules: |
      输出为正数。
  tile_width:
    description: |
      控制分块放大时的 tile 宽度。
    required: false
    default: 512
    format_rules: |
      输出为正整数。
  tile_height:
    description: |
      控制分块放大时的 tile 高度。
    required: false
    default: 512
    format_rules: |
      输出为正整数。
  seed:
    description: |
      控制随机种子。
    required: false
    default: 360100058416338
    format_rules: |
      输出为整数。

examples:
  - nl_desc: "把这张图放大并补一点真实细节，尽量不要改动原来的内容。"
    params_example:
      upscale_by: 2
      prompt: "high quality detail enhancement, preserve original content, clean texture"
      denoise: 0.2
      steps: 20
      cfg: 8
      tile_width: 512
      tile_height: 512
      seed: 360100058416338
  - nl_desc: "帮我做高清放大，衣服和头发的细节更清楚一点。"
    params_example:
      upscale_by: 2
      prompt: "sharp hair strands, clearer fabric texture, high quality details, preserve subject"
      denoise: 0.25
      steps: 22
      cfg: 8
      tile_width: 512
      tile_height: 512
      seed: 360100058416339
---

使用建议（可选正文）：
- 适合放在生成链路的末尾，作为交付前的清晰度增强步骤。
- 如果用户强调“高清化”“超清放大”“补细节”，可以优先考虑这个 lens。
