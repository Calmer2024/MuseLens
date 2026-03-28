-- ============================================================
-- MuseLens PostgreSQL 数据库初始化脚本
-- ============================================================
-- 使用方法：
--   1. 创建数据库：createdb muselens_db
--   2. 执行本脚本：psql -d muselens_db -f scripts/init_db.sql
-- ============================================================

-- 启用 UUID 生成扩展（pgcrypto 或 uuid-ossp）
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================
-- 1. Lenses 表（透镜注册表）
-- ============================================================

CREATE TABLE IF NOT EXISTS lenses (
    lens_id             VARCHAR(100) PRIMARY KEY,
    layer               VARCHAR(8) NOT NULL,
    description         TEXT DEFAULT '',
    workflow_file_path  VARCHAR(500) NOT NULL,
    inputs              JSONB DEFAULT '[]'::JSONB,
    outputs             JSONB DEFAULT '[]'::JSONB,
    params              JSONB DEFAULT '[]'::JSONB,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE lenses IS '透镜注册表';
COMMENT ON COLUMN lenses.lens_id IS 'Lens 唯一 ID';
COMMENT ON COLUMN lenses.layer IS '功能层级 A1~A5';
COMMENT ON COLUMN lenses.inputs IS '输入资产插槽定义（JSONB）';
COMMENT ON COLUMN lenses.outputs IS '输出资产插槽定义（JSONB）';
COMMENT ON COLUMN lenses.params IS '可调参数插槽定义（JSONB）';

CREATE INDEX IF NOT EXISTS idx_lenses_layer ON lenses (layer);


-- ============================================================
-- 2. Projects 表（修图项目）
-- ============================================================

CREATE TABLE IF NOT EXISTS projects (
    project_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name             VARCHAR(200) NOT NULL,
    description      TEXT DEFAULT '',
    cover_url        VARCHAR(500),
    root_node_id     UUID,
    current_node_id  UUID,
    node_count       INTEGER DEFAULT 0,
    branch_count     INTEGER DEFAULT 0,
    created_at       TIMESTAMPTZ DEFAULT NOW(),
    updated_at       TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE projects IS '修图项目表';
COMMENT ON COLUMN projects.root_node_id IS '根节点 ID';
COMMENT ON COLUMN projects.current_node_id IS '当前活跃节点 ID（编辑器聚焦位置）';
COMMENT ON COLUMN projects.node_count IS '总节点数（缓存）';
COMMENT ON COLUMN projects.branch_count IS '产生分支的节点数（缓存）';

CREATE INDEX IF NOT EXISTS idx_projects_created_at ON projects (created_at DESC);


-- ============================================================
-- 3. AssetNodes 表（资产节点）
-- ============================================================

CREATE TABLE IF NOT EXISTS asset_nodes (
    node_id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id          UUID NOT NULL REFERENCES projects(project_id) ON DELETE CASCADE,
    image_url           VARCHAR(500) NOT NULL,
    thumbnail_url       VARCHAR(500),
    node_type           VARCHAR(20) DEFAULT 'generated' CHECK (node_type IN ('original', 'generated', 'uploaded')),
    width               INTEGER,
    height              INTEGER,
    file_size           BIGINT,
    format              VARCHAR(10),
    muse_dna            JSONB,
    generation_params   JSONB,
    depth               INTEGER DEFAULT 0,
    path                UUID[] DEFAULT ARRAY[]::UUID[],
    status              VARCHAR(20) DEFAULT 'completed' CHECK (status IN ('generating', 'completed', 'failed')),
    label               VARCHAR(100),
    metadata            JSONB,
    created_at          TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE asset_nodes IS '资产节点表（图片版本）';
COMMENT ON COLUMN asset_nodes.node_type IS 'original=用户上传原图, generated=AI生成图, uploaded=参考图';
COMMENT ON COLUMN asset_nodes.muse_dna IS '生成该节点所用的完整 MuseDNA（JSONB）';
COMMENT ON COLUMN asset_nodes.depth IS '节点深度（根节点为 0）';
COMMENT ON COLUMN asset_nodes.path IS '从根节点到本节点的有序 node_id 数组（含自身）';
COMMENT ON COLUMN asset_nodes.status IS 'generating=生成中, completed=已完成, failed=失败';

CREATE INDEX IF NOT EXISTS idx_asset_nodes_project_id ON asset_nodes (project_id);
CREATE INDEX IF NOT EXISTS idx_asset_nodes_project_depth ON asset_nodes (project_id, depth);
CREATE INDEX IF NOT EXISTS idx_asset_nodes_path_gin ON asset_nodes USING GIN (path);


-- ============================================================
-- 4. AssetEdges 表（修图操作边）
-- ============================================================

CREATE TABLE IF NOT EXISTS asset_edges (
    edge_id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id          UUID NOT NULL REFERENCES projects(project_id) ON DELETE CASCADE,
    source_node_id      UUID NOT NULL REFERENCES asset_nodes(node_id) ON DELETE CASCADE,
    target_node_id      UUID NOT NULL REFERENCES asset_nodes(node_id) ON DELETE CASCADE,
    lens_id             VARCHAR(100),
    lens_name           VARCHAR(100),
    user_prompt         TEXT,
    parameters          JSONB DEFAULT '{}'::JSONB,
    muse_dna            JSONB,
    execution_time_ms   INTEGER,
    task_id             UUID,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT uq_edge_endpoints UNIQUE (source_node_id, target_node_id),
    CONSTRAINT chk_no_self_loop CHECK (source_node_id != target_node_id)
);

COMMENT ON TABLE asset_edges IS '修图操作边（记录从父图到子图的操作）';
COMMENT ON COLUMN asset_edges.lens_id IS '使用的透镜 ID';
COMMENT ON COLUMN asset_edges.lens_name IS '透镜名称冗余存储（防止透镜删除后无法追溯）';
COMMENT ON COLUMN asset_edges.parameters IS '具体参数值（JSONB）';
COMMENT ON COLUMN asset_edges.muse_dna IS '完整 DAGBlueprint 快照（JSONB）';

CREATE INDEX IF NOT EXISTS idx_asset_edges_project_id ON asset_edges (project_id);
CREATE INDEX IF NOT EXISTS idx_asset_edges_source_node_id ON asset_edges (source_node_id);
CREATE INDEX IF NOT EXISTS idx_asset_edges_target_node_id ON asset_edges (target_node_id);
CREATE INDEX IF NOT EXISTS idx_asset_edges_project_source ON asset_edges (project_id, source_node_id);


-- ============================================================
-- 5. NodeTags 表（节点标签）
-- ============================================================

CREATE TABLE IF NOT EXISTS node_tags (
    tag_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    node_id     UUID NOT NULL REFERENCES asset_nodes(node_id) ON DELETE CASCADE,
    label       VARCHAR(50) NOT NULL,
    color       VARCHAR(7) DEFAULT '#4A90E2',
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE node_tags IS '节点标签表（用户可为重要节点打标签）';
COMMENT ON COLUMN node_tags.label IS '标签文字，如「最终版」';
COMMENT ON COLUMN node_tags.color IS '标签颜色 HEX，如 #FF6B6B';

CREATE INDEX IF NOT EXISTS idx_node_tags_node_id ON node_tags (node_id);


-- ============================================================
-- 6. LensExamples 表（透镜 few-shot 示例）
-- ============================================================

CREATE TABLE IF NOT EXISTS lens_examples (
    id              SERIAL PRIMARY KEY,
    lens_id         VARCHAR(100) NOT NULL,
    nl_desc         TEXT DEFAULT '',
    params_example  JSONB DEFAULT '{}'::JSONB,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE lens_examples IS 'Lens few-shot 示例表（供 Planner RAG 使用）';
COMMENT ON COLUMN lens_examples.nl_desc IS '自然语言描述（示例场景）';
COMMENT ON COLUMN lens_examples.params_example IS '参数示例（JSONB）';

CREATE INDEX IF NOT EXISTS idx_lens_examples_lens_id ON lens_examples (lens_id);


-- ============================================================
-- 7. RouterSessions 表（Router 会话状态）
-- ============================================================

CREATE TABLE IF NOT EXISTS router_sessions (
    session_id          VARCHAR(36) PRIMARY KEY,
    user_id             VARCHAR(100) NOT NULL,
    original_prompt     TEXT DEFAULT '',
    base_image          TEXT DEFAULT '',
    base_image_meta     JSONB DEFAULT '{}'::JSONB,
    history_summary     TEXT DEFAULT '',
    lens_history        JSONB DEFAULT '[]'::JSONB,
    pending_blueprint   JSONB,
    pending_questions   JSONB DEFAULT '[]'::JSONB,
    collected_params    JSONB DEFAULT '{}'::JSONB,
    created_at          TIMESTAMPTZ DEFAULT NOW(),
    updated_at          TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE router_sessions IS 'Router 会话状态表（多轮对话）';
COMMENT ON COLUMN router_sessions.lens_history IS '已执行 Lens 及结果概要（JSONB）';
COMMENT ON COLUMN router_sessions.pending_blueprint IS '待执行/待补齐的 Blueprint（JSONB）';

CREATE INDEX IF NOT EXISTS idx_router_sessions_user_id ON router_sessions (user_id);
CREATE INDEX IF NOT EXISTS idx_router_sessions_created_at ON router_sessions (created_at DESC);


-- ============================================================
-- 初始化完成提示
-- ============================================================

DO $$ 
BEGIN 
    RAISE NOTICE '✓ MuseLens 数据库初始化完成！';
    RAISE NOTICE '  - 已创建 7 张表：lenses, projects, asset_nodes, asset_edges, node_tags, lens_examples, router_sessions';
    RAISE NOTICE '  - 已创建性能优化索引';
    RAISE NOTICE '  - 可以启动应用：uvicorn app.main:app --reload';
END $$;
