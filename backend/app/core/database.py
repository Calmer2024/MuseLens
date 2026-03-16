"""
数据库连接配置（SQLAlchemy + SQLite）

- 开发阶段使用 SQLite，数据库文件默认生成在 backend/ 目录下（muselens.db）。
- 如需迁移至 PostgreSQL，只需修改 SQLALCHEMY_DATABASE_URL 即可，其余代码无感。
"""

import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, DeclarativeBase

# 数据库文件存放在 backend/ 目录（即本文件向上两级）
_BACKEND_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SQLALCHEMY_DATABASE_URL = f"sqlite:///{os.path.join(_BACKEND_DIR, 'muselens.db')}"

engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    # SQLite 多线程访问需要显式允许（FastAPI 默认多线程）
    connect_args={"check_same_thread": False},
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


class Base(DeclarativeBase):
    pass


def get_db():
    """FastAPI Depends 注入用的数据库 Session 生成器。"""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db() -> None:
    """创建所有表（幂等，已存在则跳过）。在 main.py 的 lifespan 中调用。"""
    # 必须在 create_all 之前导入所有 Model，让 Base 能感知到表定义
    from app.models import lens_model  # noqa: F401
    Base.metadata.create_all(bind=engine)
