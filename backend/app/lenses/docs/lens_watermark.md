---
lens_id: lens_watermark
layer: A5
description: |
  最终交付阶段的水印叠加透镜。它不会改变图像语义，只会在成图上叠加文本型标识，例如签名、品牌名或版权声明。
params:
  text:
    description: |
      水印文字内容。
    required: true
    decision_rules: |
      如果用户明确要求加签名、品牌名、版权信息，但没有提供具体文字，应判定为 missing。
    format_rules: |
      输出简短文本，不要写成长段提示词。
  font_name:
    description: |
      字体文件名。
    required: false
  font_size:
    description: |
      字号大小。
    required: false
    format_rules: |
      输出正整数。
  font_color_hex:
    description: |
      文字颜色，十六进制格式。
    required: false
    format_rules: |
      输出类似 #FFFFFF 的颜色值。
  align:
    description: |
      垂直对齐位置。
    required: false
  justify:
    description: |
      水平对齐方式。
    required: false
  margins:
    description: |
      距离边缘的像素留白。
    required: false
    format_rules: |
      输出非负整数。
examples:
  - nl_desc: 在右下角加上品牌名水印 MuseLens Studio
    params_example:
      text: MuseLens Studio
      font_name: Arial.ttf
      font_size: 36
      font_color_hex: "#FFFFFF"
      align: bottom
      justify: right
      margins: 32
  - nl_desc: 在左下角加上版权所有说明
    params_example:
      text: Copyright 2026 MuseLens
      font_name: Arial.ttf
      font_size: 28
      font_color_hex: "#EAEAEA"
      align: bottom
      justify: left
      margins: 24
---

## 适用任务

- 最终成图加签名、Logo 文本、版权声明。
- 作为链路末端的交付保护步骤。

## 不适用任务

- 不适合任何语义编辑、风格化、局部重绘或放大任务。
- 如果用户请求是“把女人换成猪”“改成黄昏光”，绝不能把当前透镜当成主编辑透镜。

## 上下游衔接

- 一般放在所有生成、重绘、放大步骤之后。
- 它只消费 `base_image`，不接受结构图、遮罩或参考图。

## 实现依据

- config 真实参数集中在文本排版字段。
- workflow 使用 `CR Overlay Text`，说明它是纯文本叠加，而不是图像编辑透镜。
