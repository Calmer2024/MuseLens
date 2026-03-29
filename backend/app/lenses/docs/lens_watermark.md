---
lens_id: lens_watermark
layer: A5
description: |
  在最终成片上叠加签名、Logo 或版权文字，完成交付前的标识保护。该透镜不做扩散重绘，主要负责排版与覆盖输出。

params:
  text:
    description: |
      水印文字内容，例如品牌名、作者签名或版权声明。
    required: true
    default: ""
    decision_rules: |
      如果用户只说“加个水印”但没有提供文字内容，应判定为 missing。
      当用户已经给出具体签名、品牌名或版权语句时，可以直接使用。
    format_rules: |
      输出为简短文本，避免换行过多。
  font_name:
    description: |
      字体文件名。
    required: false
    default: "Caveat-VariableFont_wght.ttf"
    format_rules: |
      输出为字体文件名字符串。
  font_size:
    description: |
      水印字号大小。
    required: false
    default: 50
    format_rules: |
      输出为正整数。
  font_color_hex:
    description: |
      水印颜色的十六进制值。
    required: false
    default: "#FFFFFF"
    format_rules: |
      输出为标准十六进制颜色字符串，例如 #FFFFFF。
  align:
    description: |
      水印在画面中的垂直对齐位置。
    required: false
    default: "bottom"
    format_rules: |
      输出为对齐关键词，例如 top、center、bottom。
  justify:
    description: |
      水印在画面中的水平对齐方式。
    required: false
    default: "right"
    format_rules: |
      输出为对齐关键词，例如 left、center、right。
  margins:
    description: |
      水印与边缘之间的留白距离。
    required: false
    default: 30
    format_rules: |
      输出为非负整数。

examples:
  - nl_desc: "在成片右下角加上品牌名 MuseLens，白色小字，留一点边距。"
    params_example:
      text: "MuseLens"
      font_name: "Caveat-VariableFont_wght.ttf"
      font_size: 42
      font_color_hex: "#FFFFFF"
      align: "bottom"
      justify: "right"
      margins: 30
---

使用建议（可选正文）：
- 适合放在最终成片链路的末端，作为交付前最后一步。
- 如果用户强调品牌署名、版权声明或防盗标识，通常可以触发这个 lens。
