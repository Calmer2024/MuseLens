---
lens_id: lens_depth_extract
layer: A3
description: |
  从输入图提取深度信息（depth），为后续支持基于深度的分层/遮罩生成提供基础。

params:
  prompt:
    description: |
      可选的辅助描述，用于指导深度提取的风格/边界偏好（如果工作流支持）。
    required: false
    default: ""
    decision_rules: |
      如果用户没有任何与深度质量相关的偏好（如“更干净边缘/更平滑/更保留细节”），则不需要追问。
    format_rules: |
      若提供，尽量简短（1 句以内），描述你希望 depth 边界/纹理的偏好。
examples:
  - nl_desc: "提取一张适合分层处理的深度图，边缘要干净。"
    params_example:
      prompt: "clean edges, preserve subtle details"
---

使用建议（正文可选）：
- 典型用途是先获得深度，再给其它 lens 做分层遮罩或基于深度的替换。

