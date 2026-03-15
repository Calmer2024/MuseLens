## MuseLens RAG（PostgreSQL + pgvector）接入与扩展指南

本指南说明如何在 **无需关心当前透镜数量多少** 的前提下，直接落地基于
PostgreSQL + pgvector 的 Lens 检索能力；后续只要按照现有 Lens 规范新增透镜，
并重新跑一次同步脚本即可完成扩展。

---

## 一、整体架构概览

- **向量存储**：PostgreSQL + pgvector，表名默认 `lens_embeddings`
- **编码来源**：从 `LENS_REGISTRY` 中的 `LensTemplate` 抽取语料（`lens_id`、`layer`、
  `description`、参数名称与描述），经 `encode_text_to_vector` 编码为固定维度向量
- **落库工具**：`app/services/lens_embedding_sync.py`
  - `ensure_lens_embeddings_schema`：确保扩展和表结构存在
  - `sync_lens_embeddings`：将当前所有透镜的向量写入 / 更新到数据库
- **在线检索**：`PgVectorLensRAGClient.search_lenses`（在 `app/services/rag_client.py`）
- **Router 接入**：`RouterService` 通过环境变量自动选择
  - 默认：内存版 `InMemoryLensRAGClient`
  - 配置为 `pgvector` 时：使用 `PgVectorLensRAGClient`

> 设计原则：**Router 只依赖 RAG 抽象接口**，透镜的增加/修改只需要动配置与同步脚本，
> 无需改 Router 代码。

---

## 二、数据库准备（PostgreSQL + pgvector）

### 使用 Docker（推荐）

```bash
docker run --name muselens-pg -e POSTGRES_PASSWORD=1234 -p 5432:5432 -d ankane/pgvector
```

默认数据库为 `postgres`，DSN 示例：`postgresql://postgres:1234@localhost:5432/postgres`。

### 一键建表 + 同步向量

在 `backend` 目录下执行（需先 `pip install -r requirements.txt`）：

```bash
# Windows PowerShell
$env:PYTHONPATH = "."; python -m app.scripts.sync_lens_embeddings_cli

# Linux / macOS
PYTHONPATH=. python -m app.scripts.sync_lens_embeddings_cli
```

脚本会：创建 pgvector 扩展、创建 `lens_embeddings` 表与索引，并将当前 `LENS_REGISTRY` 中所有透镜向量写入/更新到该表。若尚未在 `backend/app/lenses/config/` 下添加任何 `*.lens.json` 配置，同步条数为 0 属正常；添加透镜配置后重新执行即可。

### 本机安装 pgvector（以 Debian/Ubuntu 为例）

1. 安装 pgvector 扩展：

```bash
sudo apt install postgresql-16-pgvector
```

2. 在目标数据库中启用扩展并初始化向量表（也可以直接调用代码中的
   `ensure_lens_embeddings_schema`，这里给出等价 SQL）：

```sql
CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE IF NOT EXISTS lens_embeddings (
    lens_id    TEXT PRIMARY KEY,
    embedding  VECTOR(256) NOT NULL,
    description TEXT,
    layer       TEXT
);

CREATE INDEX IF NOT EXISTS idx_lens_embeddings_embedding
ON lens_embeddings
USING ivfflat (embedding vector_l2_ops)
WITH (lists = 100);
```

- 当前内置实现使用 **256 维** 向量（`EMBEDDING_DIM = 256`），后续如果接入真实
  embedding 服务（如 1536 维），需要同时：
  - 修改 `EMBEDDING_DIM`
  - 更新 SQL 中的 `VECTOR(256)` 为对应维度
  - 重新跑一次 `sync_lens_embeddings`

---

## 三、后端依赖与环境变量

### 1. 依赖

在 `backend/requirements.txt` 中已添加：

```text
psycopg[binary]
```

安装方式（在 `backend/` 目录）：

```bash
pip install -r requirements.txt
```

### 2. 关键环境变量

- `MUSELENS_RAG_BACKEND`
  - 可选值：
    - 空 / 未设置：使用内存版 `InMemoryLensRAGClient`
    - `pgvector`：启用 PostgreSQL + pgvector 实现
- `MUSELENS_PG_DSN`
  - PostgreSQL 连接串，例如：
  - `postgresql://user:password@localhost:5432/muselens`
- `MUSELENS_RAG_PGVECTOR_TABLE`（可选）
  - 默认：`lens_embeddings`

当你将 `MUSELENS_RAG_BACKEND` 设置为 `pgvector` 且提供了有效的 `MUSELENS_PG_DSN` 后，
`RouterService` 会自动使用 `PgVectorLensRAGClient`。

---

## 四、向量同步流程（与透镜数量无关）

只要透镜按照既有规范注册到 `LENS_REGISTRY`，即可通过下面步骤一次性同步：

1. 在确保数据库可访问、pgvector 已安装后，在任意脚本中调用：

```python
from app.services.lens_embedding_sync import sync_lens_embeddings

DSN = "postgresql://user:password@localhost:5432/muselens"

count = sync_lens_embeddings(dsn=DSN)
print(f"synced {count} lens embeddings")
```

2. `sync_lens_embeddings` 会为每个 `LensTemplate`：
   - 使用 `_build_lens_corpus` 构造语料
   - 调用 `encode_text_to_vector` 得到向量
   - 以 `lens_id` 为主键执行 upsert（INSERT ... ON CONFLICT DO UPDATE）

3. 后续新增透镜时，只需要：
   - 按照现有流程新增 ComfyUI JSON + `<lens_id>.lens.json`
   - 重启后端（让 `LENS_REGISTRY` 重新加载）
   - 再执行一次 `sync_lens_embeddings(dsn=...)`

整个过程与“当前透镜总数”无关，只与一次同步时 Registry 中的条目数有关，
PostgreSQL + pgvector 的索引可以自然扩展到大量透镜。

---

## 五、在线检索：PgVectorLensRAGClient 行为

在 `app/services/rag_client.py` 中：

- `PgVectorLensRAGClient` 默认参数：
  - `table_name="lens_embeddings"`
  - `top_k=5`
  - `encode_text_to_vector=default_encode_text_to_vector`
- 内置的 `default_encode_text_to_vector`：
  - 使用简单 hash-bucketing + L2 归一化，将文本编码为 256 维向量
  - 不依赖任何外部服务，保证“开箱即用”的真实向量检索链路

查询 SQL（简化说明）：

```sql
SELECT lens_id, 1 - (embedding <=> %(query_vec)s) AS score
FROM lens_embeddings
ORDER BY embedding <-> %(query_vec)s
LIMIT %(limit)s;
```

- Python 侧会把向量转换为 pgvector 的文本字面量，例如：`"[0.1,0.2,0.3]"`。
- 检索结果会被包装为 `LensCandidate`，并且只返回 Registry 中存在的透镜。

---

## 六、替换为真实 embedding 服务（可选升级）

当你准备接入真正的 embedding 模型时，只需要做三件事：

1. **实现你自己的编码函数**：

```python
from typing import List

def my_encode(text: str) -> List[float]:
    # 调用真实 embedding 服务，如 OpenAI / 自建模型
    ...
```

2. **在同步脚本中使用它**：

```python
from app.services.lens_embedding_sync import sync_lens_embeddings

sync_lens_embeddings(dsn=DSN, encode_text_to_vector=my_encode)
```

3. **在创建 PgVectorLensRAGClient 时传入相同实现**（如果你自建了 RouterService 实例）：

```python
from app.services.rag_client import PgVectorLensRAGClient

rag_client = PgVectorLensRAGClient(
    dsn=DSN,
    table_name="lens_embeddings",
    encode_text_to_vector=my_encode,
)
```

> 这样可以保证：**离线同步和在线检索使用同一套 embedding 语义空间**。

---

## 七、与 Router 的关系

- Router 对 RAG 的唯一依赖是 `BaseLensRAGClient` 协议；
- 通过 `_create_rag_client_from_env`，可以在不改 Router 对外接口的前提下：
  - 开发阶段：用内存版 InMemory RAG，零依赖数据库；
  - 上线后：切换到 PostgreSQL + pgvector 实现，享受真实向量检索能力；
- Router 把 RAG 结果作为辅助信号（`retrieved_lenses`）：
  - 未来可以用来动态选择 A1–A5 的透镜组合，而不仅仅是当前的固定管线。

---

## 八、小结

- 已经在后端落地了一条完整的 **PostgreSQL + pgvector RAG 通路**；
- 只要：
  - Lens 照既有规范注册到 `LENS_REGISTRY`
  - 数据库配置正确并运行一次 `sync_lens_embeddings`
  - 环境变量切到 `MUSELENS_RAG_BACKEND=pgvector`
- 就可以在“任意数量”的透镜上稳定扩展，后续增加透镜只需补配置 + 重新同步，
  无需再等到“透镜达到一定数量”后再重构。

