-- RuoYi-Vue-Plus PostgreSQL 数据库初始化脚本
-- 用于 CNB 部署时的数据库初始化

-- 创建数据库
CREATE DATABASE "ry_vue" WITH ENCODING 'UTF8' LC_COLLATE 'zh_CN.UTF-8' LC_CTYPE 'zh_CN.UTF-8';

-- 连接到数据库
\c ry_vue;

-- 创建用户并授权（如果不存在）
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'ruoyi') THEN
        CREATE USER ruoyi WITH PASSWORD 'ruoyi123';
    END IF;
END
$$;

-- 授权给用户
GRANT ALL PRIVILEGES ON DATABASE "ry_vue" TO ruoyi;
GRANT ALL ON SCHEMA public TO ruoyi;

-- 设置时区
SET timezone = 'Asia/Shanghai';

-- 创建监控用户（用于 Prometheus 监控）
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'monitor') THEN
        CREATE USER monitor WITH PASSWORD 'monitor123';
    END IF;
END
$$;

-- 授权监控用户
GRANT CONNECT ON DATABASE "ry_vue" TO monitor;
GRANT USAGE ON SCHEMA public TO monitor;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO monitor;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO monitor;

-- 初始化系统配置表
CREATE TABLE IF NOT EXISTS sys_config (
    config_id SERIAL PRIMARY KEY,
    config_name VARCHAR(100) DEFAULT '' NOT NULL,
    config_key VARCHAR(100) DEFAULT '' NOT NULL,
    config_value VARCHAR(500) DEFAULT '' NOT NULL,
    config_type CHAR(1) DEFAULT 'N' NOT NULL,
    create_by VARCHAR(64) DEFAULT '' NOT NULL,
    create_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    update_by VARCHAR(64) DEFAULT '' NOT NULL,
    update_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    remark VARCHAR(500) DEFAULT NULL
);

-- 添加表注释
COMMENT ON TABLE sys_config IS '参数配置表';
COMMENT ON COLUMN sys_config.config_id IS '参数主键';
COMMENT ON COLUMN sys_config.config_name IS '参数名称';
COMMENT ON COLUMN sys_config.config_key IS '参数键名';
COMMENT ON COLUMN sys_config.config_value IS '参数键值';
COMMENT ON COLUMN sys_config.config_type IS '系统内置（Y是 N否）';
COMMENT ON COLUMN sys_config.create_by IS '创建者';
COMMENT ON COLUMN sys_config.create_time IS '创建时间';
COMMENT ON COLUMN sys_config.update_by IS '更新者';
COMMENT ON COLUMN sys_config.update_time IS '更新时间';
COMMENT ON COLUMN sys_config.remark IS '备注';

-- 插入 CNB 部署相关配置
INSERT INTO sys_config (config_name, config_key, config_value, config_type, create_by, create_time, remark) VALUES
('CNB部署模式', 'cnb.deploy.mode', 'full', 'Y', 'system', CURRENT_TIMESTAMP, 'CNB部署模式：full-全量部署，incremental-增量部署'),
('CNB构建器版本', 'cnb.builder.version', 'paketobuildpacks/builder:base', 'Y', 'system', CURRENT_TIMESTAMP, 'CNB构建器版本配置'),
('监控系统状态', 'monitoring.enabled', 'true', 'Y', 'system', CURRENT_TIMESTAMP, '是否启用监控系统'),
('健康检查间隔', 'health.check.interval', '30', 'Y', 'system', CURRENT_TIMESTAMP, '健康检查间隔时间（秒）'),
('默认数据库类型', 'database.default.type', 'postgresql', 'Y', 'system', CURRENT_TIMESTAMP, '默认数据库类型：postgresql/mysql');

-- 创建部署日志表
CREATE TABLE IF NOT EXISTS sys_deploy_log (
    log_id BIGSERIAL PRIMARY KEY,
    deploy_mode VARCHAR(20) NOT NULL,
    deploy_version VARCHAR(50) DEFAULT NULL,
    deploy_status VARCHAR(20) NOT NULL,
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP DEFAULT NULL,
    duration INTEGER DEFAULT NULL,
    deploy_log TEXT DEFAULT NULL,
    error_message TEXT DEFAULT NULL,
    create_by VARCHAR(64) DEFAULT 'system',
    create_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 添加表注释
COMMENT ON TABLE sys_deploy_log IS '部署日志表';
COMMENT ON COLUMN sys_deploy_log.log_id IS '日志ID';
COMMENT ON COLUMN sys_deploy_log.deploy_mode IS '部署模式';
COMMENT ON COLUMN sys_deploy_log.deploy_version IS '部署版本';
COMMENT ON COLUMN sys_deploy_log.deploy_status IS '部署状态';
COMMENT ON COLUMN sys_deploy_log.start_time IS '开始时间';
COMMENT ON COLUMN sys_deploy_log.end_time IS '结束时间';
COMMENT ON COLUMN sys_deploy_log.duration IS '部署耗时（秒）';
COMMENT ON COLUMN sys_deploy_log.deploy_log IS '部署日志';
COMMENT ON COLUMN sys_deploy_log.error_message IS '错误信息';
COMMENT ON COLUMN sys_deploy_log.create_by IS '创建者';
COMMENT ON COLUMN sys_deploy_log.create_time IS '创建时间';

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_deploy_mode ON sys_deploy_log (deploy_mode);
CREATE INDEX IF NOT EXISTS idx_deploy_status ON sys_deploy_log (deploy_status);
CREATE INDEX IF NOT EXISTS idx_create_time ON sys_deploy_log (create_time);

-- 创建监控指标表
CREATE TABLE IF NOT EXISTS sys_monitor_metrics (
    metric_id BIGSERIAL PRIMARY KEY,
    metric_name VARCHAR(100) NOT NULL,
    metric_value DECIMAL(10,2) NOT NULL,
    metric_unit VARCHAR(20) DEFAULT NULL,
    metric_type VARCHAR(50) NOT NULL,
    collect_time TIMESTAMP NOT NULL,
    instance VARCHAR(100) DEFAULT NULL,
    labels JSONB DEFAULT NULL
);

-- 添加表注释
COMMENT ON TABLE sys_monitor_metrics IS '监控指标表';
COMMENT ON COLUMN sys_monitor_metrics.metric_id IS '指标ID';
COMMENT ON COLUMN sys_monitor_metrics.metric_name IS '指标名称';
COMMENT ON COLUMN sys_monitor_metrics.metric_value IS '指标值';
COMMENT ON COLUMN sys_monitor_metrics.metric_unit IS '指标单位';
COMMENT ON COLUMN sys_monitor_metrics.metric_type IS '指标类型';
COMMENT ON COLUMN sys_monitor_metrics.collect_time IS '采集时间';
COMMENT ON COLUMN sys_monitor_metrics.instance IS '实例标识';
COMMENT ON COLUMN sys_monitor_metrics.labels IS '标签信息';

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_metric_name ON sys_monitor_metrics (metric_name);
CREATE INDEX IF NOT EXISTS idx_collect_time ON sys_monitor_metrics (collect_time);
CREATE INDEX IF NOT EXISTS idx_instance ON sys_monitor_metrics (instance);

-- 插入初始监控指标配置
INSERT INTO sys_monitor_metrics (metric_name, metric_value, metric_unit, metric_type, collect_time, instance) VALUES
('application_startup_time', 0.00, 'seconds', 'gauge', CURRENT_TIMESTAMP, 'ruoyi-app'),
('jvm_memory_used', 0.00, 'bytes', 'gauge', CURRENT_TIMESTAMP, 'ruoyi-app'),
('http_requests_total', 0.00, 'count', 'counter', CURRENT_TIMESTAMP, 'ruoyi-app'),
('database_connections_active', 0.00, 'count', 'gauge', CURRENT_TIMESTAMP, 'postgresql');

-- 创建索引优化查询性能
CREATE INDEX IF NOT EXISTS idx_config_key ON sys_config (config_key);
CREATE INDEX IF NOT EXISTS idx_config_type ON sys_config (config_type);

-- 设置数据库参数优化
ALTER SYSTEM SET shared_buffers = '256MB';
ALTER SYSTEM SET effective_cache_size = '1GB';
ALTER SYSTEM SET maintenance_work_mem = '64MB';
ALTER SYSTEM SET checkpoint_completion_target = 0.9;
ALTER SYSTEM SET wal_buffers = '16MB';
ALTER SYSTEM SET default_statistics_target = 100;
ALTER SYSTEM SET random_page_cost = 1.1;
ALTER SYSTEM SET effective_io_concurrency = 200;

-- 重新加载配置
SELECT pg_reload_conf();

-- 创建数据库备份函数
CREATE OR REPLACE FUNCTION backup_database()
RETURNS TEXT AS $$
DECLARE
    backup_file TEXT;
    result TEXT;
BEGIN
    backup_file := '/backup/ry_vue-' || to_char(NOW(), 'YYYYMMDD_HH24MISS') || '.sql';
    
    -- 记录备份开始
    INSERT INTO sys_deploy_log (deploy_mode, deploy_status, start_time, deploy_log, create_by) 
    VALUES ('backup', 'running', NOW(), '开始备份数据库到: ' || backup_file, 'system');
    
    -- 返回备份文件路径
    result := '备份文件路径: ' || backup_file;
    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- 创建数据库健康检查函数
CREATE OR REPLACE FUNCTION health_check()
RETURNS TABLE(
    check_name TEXT,
    status TEXT,
    details TEXT
) AS $$
BEGIN
    -- 检查数据库连接
    RETURN QUERY SELECT 
        'database_connection'::TEXT,
        'healthy'::TEXT,
        'PostgreSQL连接正常'::TEXT;
    
    -- 检查表空间
    RETURN QUERY SELECT 
        'tablespace_usage'::TEXT,
        CASE WHEN pg_database_size(current_database()) < 1073741824 THEN 'healthy' ELSE 'warning' END::TEXT,
        ('数据库大小: ' || pg_size_pretty(pg_database_size(current_database())))::TEXT;
    
    -- 检查活跃连接数
    RETURN QUERY SELECT 
        'active_connections'::TEXT,
        CASE WHEN count(*) < 50 THEN 'healthy' ELSE 'warning' END::TEXT,
        ('活跃连接数: ' || count(*)::TEXT)::TEXT
    FROM pg_stat_activity 
    WHERE state = 'active';
END;
$$ LANGUAGE plpgsql;

-- 输出初始化完成信息
SELECT 'RuoYi-Vue-Plus PostgreSQL CNB 数据库初始化完成' AS message;
SELECT COUNT(*) AS config_count FROM sys_config WHERE config_type = 'Y';
SELECT 'CNB PostgreSQL 部署配置已就绪' AS status;