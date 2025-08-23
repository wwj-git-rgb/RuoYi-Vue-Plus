-- RuoYi-Vue-Plus PostgreSQL 更新脚本
-- 版本: 5.4.1 -> 5.4.2
-- 更新日期: 2025-01-23

-- 开始事务
BEGIN;

-- 添加版本记录表（如果不存在）
CREATE TABLE IF NOT EXISTS sys_version_log (
    id SERIAL PRIMARY KEY,
    version_from VARCHAR(20) NOT NULL,
    version_to VARCHAR(20) NOT NULL,
    update_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    update_desc TEXT,
    update_status VARCHAR(10) DEFAULT 'SUCCESS'
);

-- 记录本次更新
INSERT INTO sys_version_log (version_from, version_to, update_desc) 
VALUES ('5.4.1', '5.4.2', 'PostgreSQL数据库配置优化，支持动态数据源切换');

-- 优化索引（如果需要）
-- CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_sys_user_tenant_id ON sys_user (tenant_id);
-- CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_sys_role_tenant_id ON sys_role (tenant_id);

-- 更新配置参数（如果需要）
-- UPDATE sys_config SET config_value = 'new_value' WHERE config_key = 'some_key';

-- 提交事务
COMMIT;

-- 输出更新完成信息
\echo '数据库更新完成！版本: 5.4.1 -> 5.4.2'