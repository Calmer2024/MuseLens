---
lens_id: lens_pose_extract
layer: A1
description: |
  从输入图像中提取人物姿态骨架，输出 `pose_map` 供下游重绘透镜锁定人物动作。它是人物动作约束透镜，不负责最终生成。
examples:
  - nl_desc: 提取人物骨架，后面重绘时保留当前动作
    params_example: {}
  - nl_desc: 先做 pose map，锁住人物姿态
    params_example: {}
---

## 适用任务

- 用户特别在意人物动作、站姿、手势或肢体轮廓时。
- 适合作为图生图重绘的姿态约束参考。

## 不适用任务

- 不适合无人像场景的普通风格化任务。
- 不负责抠主体、改风格、改光影或加水印。
- 没有参数可让用户指定局部语义修改。

## 上下游衔接

- 常作为 `lens_flux_reference` 或 `lens_flux_two_reference` 的参考输入之一。
- 可与 `lens_depth_extract` 组合，形成“姿态 + 空间”的双约束。

## 实现依据

- config 只有 `base_image` 输入，没有 params。
- workflow 输出为 `pose_map`，定位就是姿态分析资产。
