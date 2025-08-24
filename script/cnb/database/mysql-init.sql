-- RuoYi-Vue-Plus MySQL 数据库初始化脚本
-- 用于 CNB 部署时的数据库初始化

-- 创建数据库
CREATE DATABASE IF NOT EXISTS `ry-vue` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;

-- 使用数据库
USE `ry-vue`;

-- 创建用户并授权（如果不存在）
CREATE USER IF NOT EXISTS 'ruoyi'@'%' IDENTIFIED BY 'ruoyi123';
GRANT ALL PRIVILEGES ON `ry-vue`.* TO 'ruoyi'@'%';
FLUSH PRIVILEGES;

-- 设置时区
SET time_zone = '+8:00';

-- 创建监控用户（用于 Prometheus 监控）
CREATE USER IF NOT EXISTS 'monitor'@'%' IDENTIFIED BY 'monitor123';
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'monitor'@'%';
FLUSH PRIVILEGES;

-- 初始化系统配置表
CREATE TABLE IF NOT EXISTS `sys_config` (
  `config_id` int(5) NOT NULL AUTO_INCREMENT COMMENT '参数主键',
  `config_name` varchar(100) DEFAULT '' COMMENT '参数名称',
  `config_key` varchar(100) DEFAULT '' COMMENT '参数键名',
  `config_value` varchar(500) DEFAULT '' COMMENT '参数键值',
  `config_type` char(1) DEFAULT 'N' COMMENT '系统内置（Y是 N否）',
  `create_by` varchar(64) DEFAULT '' COMMENT '创建者',
  `create_time` datetime DEFAULT NULL COMMENT '创建时间',
  `update_by` varchar(64) DEFAULT '' COMMENT '更新者',
  `update_time` datetime DEFAULT NULL COMMENT '更新时间',
  `remark` varchar(500) DEFAULT NULL COMMENT '备注',
  PRIMARY KEY (`config_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='参数配置表';

-- 插入 CNB 部署相关配置
INSERT INTO `sys_config` (`config_name`, `config_key`, `config_value`, `config_type`, `create_by`, `create_time`, `remark`) VALUES
('CNB部署模式', 'cnb.deploy.mode', 'full', 'Y', 'system', NOW(), 'CNB部署模式：full-全量部署，incremental-增量部署'),
('CNB构建器版本', 'cnb.builder.version', 'paketobuildpacks/builder:base', 'Y', 'system', NOW(), 'CNB构建器版本配置'),
('监控系统状态', 'monitoring.enabled', 'true', 'Y', 'system', NOW(), '是否启用监控系统'),
('健康检查间隔', 'health.check.interval', '30', 'Y', 'system', NOW(), '健康检查间隔时间（秒）');

-- 创建部署日志表
CREATE TABLE IF NOT EXISTS `sys_deploy_log` (
  `log_id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '日志ID',
  `deploy_mode` varchar(20) NOT NULL COMMENT '部署模式',
  `deploy_version` varchar(50) DEFAULT NULL COMMENT '部署版本',
  `deploy_status` varchar(20) NOT NULL COMMENT '部署状态',
  `start_time` datetime NOT NULL COMMENT '开始时间',
  `end_time` datetime DEFAULT NULL COMMENT '结束时间',
  `duration` int(11) DEFAULT NULL COMMENT '部署耗时（秒）',
  `deploy_log` text COMMENT '部署日志',
  `error_message` text COMMENT '错误信息',
  `create_by` varchar(64) DEFAULT 'system' COMMENT '创建者',
  `create_time` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`log_id`),
  KEY `idx_deploy_mode` (`deploy_mode`),
  KEY `idx_deploy_status` (`deploy_status`),
  KEY `idx_create_time` (`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='部署日志表';

-- 创建监控指标表
CREATE TABLE IF NOT EXISTS `sys_monitor_metrics` (
  `metric_id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '指标ID',
  `metric_name` varchar(100) NOT NULL COMMENT '指标名称',
  `metric_value` decimal(10,2) NOT NULL COMMENT '指标值',
  `metric_unit` varchar(20) DEFAULT NULL COMMENT '指标单位',
  `metric_type` varchar(50) NOT NULL COMMENT '指标类型',
  `collect_time` datetime NOT NULL COMMENT '采集时间',
  `instance` varchar(100) DEFAULT NULL COMMENT '实例标识',
  `labels` json DEFAULT NULL COMMENT '标签信息',
  PRIMARY KEY (`metric_id`),
  KEY `idx_metric_name` (`metric_name`),
  KEY `idx_collect_time` (`collect_time`),
  KEY `idx_instance` (`instance`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='监控指标表';

-- 插入初始监控指标配置
INSERT INTO `sys_monitor_metrics` (`metric_name`, `metric_value`, `metric_unit`, `metric_type`, `collect_time`, `instance`) VALUES
('application_startup_time', 0.00, 'seconds', 'gauge', NOW(), 'ruoyi-app'),
('jvm_memory_used', 0.00, 'bytes', 'gauge', NOW(), 'ruoyi-app'),
('http_requests_total', 0.00, 'count', 'counter', NOW(), 'ruoyi-app'),
('database_connections_active', 0.00, 'count', 'gauge', NOW(), 'mysql');

-- 创建索引优化查询性能
CREATE INDEX IF NOT EXISTS `idx_config_key` ON `sys_config` (`config_key`);
CREATE INDEX IF NOT EXISTS `idx_config_type` ON `sys_config` (`config_type`);

-- 设置数据库参数优化
SET GLOBAL innodb_buffer_pool_size = 1073741824; -- 1GB
SET GLOBAL max_connections = 200;
SET GLOBAL query_cache_size = 67108864; -- 64MB
SET GLOBAL slow_query_log = 1;
SET GLOBAL long_query_time = 2;

-- 创建数据库备份存储过程
DELIMITER $$
CREATE PROCEDURE IF NOT EXISTS `backup_database`()
BEGIN
    DECLARE backup_file VARCHAR(255);
    SET backup_file = CONCAT('/backup/ry-vue-', DATE_FORMAT(NOW(), '%Y%m%d_%H%i%s'), '.sql');
    
    -- 记录备份开始
    INSERT INTO `sys_deploy_log` (`deploy_mode`, `deploy_status`, `start_time`, `deploy_log`, `create_by`) 
    VALUES ('backup', 'running', NOW(), CONCAT('开始备份数据库到: ', backup_file), 'system');
    
    -- 这里可以添加实际的备份逻辑
    -- 由于存储过程限制，实际备份通过外部脚本执行
    
END$$
DELIMITER ;

-- 输出初始化完成信息
SELECT 'RuoYi-Vue-Plus CNB 数据库初始化完成' AS message;
SELECT COUNT(*) AS config_count FROM sys_config WHERE config_type = 'Y';
SELECT 'CNB 部署配置已就绪' AS status;