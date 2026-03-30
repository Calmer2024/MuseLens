---
lens_id: lens_upscale_4x
layer: A5
description: |
  交付阶段的清晰化与放大透镜。输入结果图后，使用 Ultimate SD Upscale 和放大模型提升分辨率、补充细节，并输出更适合交付的高清图。
params:
  upscale_by:
    description: |
      放大倍数。
    required: false
    format_rules: |
      输出正数。
  prompt:
    description: |
      描述放大时希望补充的细节方向，例如皮肤纹理、布料纹理、建筑细节或写实程度。
    required: false
    format_rules: |
      建议写细节增强方向，不要写大幅语义改图指令。
  denoise:
    description: |
      放大过程中的重绘幅度，值越高越容易补新细节，也越可能改变原图。
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
  tile_width:
    description: |
      分块宽度。
    required: false
    format_rules: |
      输出正整数。
  tile_height:
    description: |
      分块高度。
    required: false
    format_rules: |
      输出正整数。
  seed:
    description: |
      随机种子。
    required: false
    format_rules: |
      输出整数。
examples:
  - nl_desc: 把最终成图放大并补充皮肤和服装细节，尽量保持原画面不变
    params_example:
      upscale_by: 4
      prompt: enhance skin texture and clothing details, preserve the original composition
      denoise: 0.25
      steps: 20
      cfg: 4.5
      tile_width: 1024
      tile_height: 1024
      seed: 9001
  - nl_desc: 把建筑场景图做高清放大，补充砖墙和窗框细节
    params_example:
      upscale_by: 4
      prompt: enhance brick texture and window details, keep architectural structure
      denoise: 0.3
      steps: 20
      cfg: 4.8
      tile_width: 1024
      tile_height: 1024
      seed: 9002
---

## 适用任务

- 作为链路末端的高清交付、清晰化和细节补充。
- 用户要求“放大”“更清晰”“补细节”时优先考虑。

## 不适用任务

- 不适合承担主语义编辑任务。
- 不适合替换主体、修改光线方向或局部重绘。

## 上下游衔接

- 通常放在主生成或主编辑透镜之后。
- 之后若还要版权标识，可继续接 `lens_watermark`。

## 实现依据

- config 只有 `base_image` 输入。
- workflow 中包含 `UpscaleModelLoader` 和 `UltimateSDUpscale`，符合“交付增强”定位。
