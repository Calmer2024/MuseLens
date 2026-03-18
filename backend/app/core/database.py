"""
数据库连接配置（SQLAlchemy）

- 默认使用 SQLite：数据库文件生成在 backend/ 目录下（muselens.db）。
- 可通过环境变量切换到 PostgreSQL（或其它 SQLAlchemy 支持的后端）。

环境变量：
- MUSELENS_DB_URL：例如
  - sqlite:///D:/Repositories/MuseLens/backend/muselens.db
  - postgresql+psycopg://user:password@localhost:5432/muselens
"""

import os

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.db_base import Base

# 数据库文件存放在 backend/ 目录（即本文件向上两级）
_BACKEND_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
_DEFAULT_SQLITE_URL = f"sqlite:///{os.path.join(_BACKEND_DIR, 'muselens.db')}"

SQLALCHEMY_DATABASE_URL = os.getenv("MUSELENS_DB_URL", _DEFAULT_SQLITE_URL)

_connect_args = {}
if SQLALCHEMY_DATABASE_URL.startswith("sqlite:"):
    # SQLite 多线程访问需要显式允许（FastAPI 默认多线程）
    _connect_args = {"check_same_thread": False}

engine = create_engine(SQLALCHEMY_DATABASE_URL, connect_args=_connect_args)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


# 确保在导入 database 模块时，ORM 表定义已注册到 Base.metadata。
# 这能避免在测试里仅调用 Base.metadata.create_all() 时出现“没有建表”的情况。
#
# 这里**不要**吞掉异常：一旦模型导入失败，测试会出现“表不存在”的隐蔽错误，
# 反而更难定位。
#
# 另外，不直接 `import app.models`（它会再 import 多个模型模块），而是显式导入
# 当前项目用到的 ORM 模型，确保 Base.metadata 一定包含这些表。
from app.models.lens_model import LensRecord  # noqa: F401,E402
from app.models.lens_example_model import LensExampleRecord  # noqa: F401,E402
from app.models.router_session_model import RouterSessionRecord  # noqa: F401,E402


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
    from app.models.lens_model import LensRecord  # noqa: F401
    from app.models.lens_example_model import LensExampleRecord  # noqa: F401
    from app.models.router_session_model import RouterSessionRecord  # noqa: F401
    Base.metadata.create_all(bind=engine)
