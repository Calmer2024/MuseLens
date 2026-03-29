---
lens_id: lens_sam2_matting
layer: A1
description: |
  先做主体/目标的分割与抠图（matting）。它的输出会作为后续替换背景（inpaint）所需的 mask 或分割结果。

params:
  prompt:
    description: |
      要抠出的目标物体的自然语言描述（例如“水杯/人物/猫”等）。
    required: true
    default: ""
    decision_rules: |
      仅当 prompt 能明确指向“画面中要替换的目标物体”时才认为足够确定。
      如果用户只说“换背景/重绘一下”，但没有说明要抠出的具体对象，则返回 missing，并要求用户指出目标物体。
    format_rules: |
      用中文或英文都可以，但尽量具体到物体类别（避免模糊形容词）。
examples:
  - nl_desc: "把水杯从照片里抠出来，后面用新背景替换。"
    params_example:
      prompt: "a glass cup"
---

使用建议（正文可选）：
- prompt 应尽量贴近用户“想替换掉画面中哪个物体”的描述。
- 如果出现误抠，通常需要追问更精确的对象（例如“左边的水杯/桌上的杯子”等）。

