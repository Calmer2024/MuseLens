---
lens_id: lens_pose_extract
layer: A1
description: |
  从输入图像中提取人物姿态骨架与关节点信息，输出 pose map，用于后续严格锁定主体动作或重定姿态。

examples:
  - nl_desc: "先提取人物姿态骨架，后面我想基于这个动作继续生成。"
    params_example: {}
---

使用建议（可选正文）：
- 适合人像、全身照、舞蹈动作等对姿态一致性要求较高的场景。
- 当用户强调“保留动作”“锁定姿势”“只改风格不改姿态”时，这个 lens 很有用。
