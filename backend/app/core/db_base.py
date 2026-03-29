"""
SQLAlchemy Declarative Base（与 engine/session 解耦）。

将 `Base` 单独放在此模块中，避免出现：
- Model 导入 `Base`（需要它作为 declarative base）
- database 模块又在导入期为了“注册表”反向导入 Model

从而引发循环导入。
"""

from sqlalchemy.orm import DeclarativeBase


class Base(DeclarativeBase):
    pass

