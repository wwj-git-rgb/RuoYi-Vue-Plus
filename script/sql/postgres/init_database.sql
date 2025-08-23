-- RuoYi-Vue-Plus PostgreSQL 数据库初始化脚本
-- 用于腾讯云服务器部署
-- 服务器: 1.15.3.137

-- 创建数据库
CREATE DATABASE ry_vue WITH 
    ENCODING 'UTF8' 
    LC_COLLATE 'zh_CN.UTF-8' 
    LC_CTYPE 'zh_CN.UTF-8' 
    TEMPLATE template0;

-- 切换到新创建的数据库
\c ry_vue;

-- 创建扩展
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";

-- 设置时区
SET timezone = 'Asia/Shanghai';

-- 创建应用用户
CREATE USER ruoyi WITH PASSWORD 'ruoyi123';

-- 授权
GRANT ALL PRIVILEGES ON DATABASE ry_vue TO ruoyi;
GRANT ALL ON SCHEMA public TO ruoyi;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ruoyi;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ruoyi;

-- 设置默认权限
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ruoyi;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ruoyi;

-- 输出初始化完成信息
\echo '数据库初始化完成！'
\echo '数据库名: ry_vue'
\echo '用户名: ruoyi'
\echo '密码: ruoyi123'