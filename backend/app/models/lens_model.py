"""
Lens 数据库模型（ORM）

每一行记录对应一个已注册的 Lens，保存其元数据与 ComfyUI 工作流文件的本地路径。
工作流 JSON 本身不入库，始终从磁盘读取，保持数据与文件的分离。

字段说明：
  lens_id           — 全局唯一标识符，如 'lens_sam2_matting'
  layer             — 所属功能层级，如 'A1' ~ 'A5'
  description       — 可读描述，供人类和 LLM 理解
  workflow_file_path — 本地 ComfyUI 工作流 JSON 的绝对路径（或相对 backend/lens/ 的文件名）
  inputs_json       — 输入资产插槽定义，序列化为 JSON 字符串
  outputs_json      — 输出资产插槽定义，序列化为 JSON 字符串
  params_json       — 可调参数插槽定义，序列化为 JSON 字符串
  created_at        — 首次注册时间
  updated_at        — 最近一次更新时间
"""

from datetime import datetime, timezone
from sqlalchemy import Column, String, Text, DateTime
from app.core.database import Base


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class LensRecord(Base):
    __tablename__ = "lenses"

    lens_id = Column(String, primary_key=True, index=True, comment="Lens 唯一 ID")
    layer = Column(String(8), nullable=False, comment="功能层级 A1~A5")
    description = Column(Text, default="", comment="功能描述")
    workflow_file_path = Column(
        String, nullable=False,
        comment="工作流 JSON 的本地路径（绝对路径或相对 backend/lens/ 的文件名）"
    )
    inputs_json = Column(Text, default="[]", comment="输入资产插槽 JSON")
    outputs_json = Column(Text, default="[]", comment="输出资产插槽 JSON")
    params_json = Column(Text, default="[]", comment="可调参数插槽 JSON")
    created_at = Column(DateTime(timezone=True), default=_utcnow)
    updated_at = Column(DateTime(timezone=True), default=_utcnow, onupdate=_utcnow)

    def __repr__(self) -> str:
        return f"<LensRecord lens_id={self.lens_id!r} layer={self.layer!r}>"
