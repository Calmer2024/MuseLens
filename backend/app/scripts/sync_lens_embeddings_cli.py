"""
一键同步 LENS_REGISTRY 中所有透镜到 PostgreSQL + pgvector。

用法（在 backend 目录下）：
  python -m app.scripts.sync_lens_embeddings_cli

或指定 DSN：
  MUSELENS_PG_DSN=postgresql://postgres:1234@localhost:5432/postgres python -m app.scripts.sync_lens_embeddings_cli
"""

from __future__ import annotations

import os
import sys


def main() -> int:
    dsn = os.environ.get(
        "MUSELENS_PG_DSN",
        "postgresql://postgres:1234@localhost:5432/postgres",
    )
    table_name = os.environ.get("MUSELENS_RAG_PGVECTOR_TABLE", "lens_embeddings")

    from app.services.lens_embedding_sync import ensure_lens_embeddings_schema, sync_lens_embeddings

    print("正在创建/检查 pgvector 扩展与 lens_embeddings 表...")
    ensure_lens_embeddings_schema(dsn, table_name=table_name)
    print("正在同步透镜向量...")
    count = sync_lens_embeddings(dsn=dsn, table_name=table_name)
    print(f"完成：已同步 {count} 条透镜向量到表 {table_name}。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
