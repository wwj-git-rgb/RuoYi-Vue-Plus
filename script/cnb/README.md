# RuoYi-Vue-Plus Cloud Native Buildpacks 部署指南

## 概述

本指南介绍如何使用 Cloud Native Buildpacks (CNB) 配置文件部署 RuoYi-Vue-Plus 项目。支持全量部署和增量部署两种模式，集成完整的基础设施和监控系统。

## 目录结构

```
script/cnb/
├── README.md                           # 本文档
├── .cnb.yml                           # CNB 主配置文件
├── deploy-full.sh                     # 全量部署脚本
├── deploy-incremental.sh              # 增量部署脚本
├── database/                          # 数据库配置
│   ├── mysql-init.sql
│   └── migration-scripts/
├── monitoring/                        # 监控配置
│   ├── prometheus.yml
│   ├── alert_rules.yml
│   ├── docker-compose-monitoring.yml
│   └── grafana/
└── scripts/                          # 辅助脚本
    ├── git-deploy-trigger.sh
    ├── build-helper.sh
    └── env-config.sh
```

## 快速开始

### 1. 环境准备

确保系统已安装以下工具：

```bash
# Docker 和 Docker Compose
docker --version
docker-compose --version

# Pack CLI (CNB 构建工具)
pack --version

# Git (用于提交消息解析)
git --version
```

### 2. 配置环境变量

复制并编辑环境配置文件：

```bash
# 复制环境配置模板
cp script/cnb/scripts/env-config.sh.example script/cnb/scripts/env-config.sh

# 编辑配置文件
vim script/cnb/scripts/env-config.sh
```

主要配置项：

```bash
# 数据库配置
export DB_HOST="localhost"
export DB_PORT="3306"
export DB_NAME="ry-vue"
export DB_USERNAME="root"
export DB_PASSWORD="root"

# Redis 配置
export REDIS_HOST="localhost"
export REDIS_PORT="6379"
export REDIS_PASSWORD=""

# MinIO 配置
export MINIO_ENDPOINT="http://localhost:9000"
export MINIO_ACCESS_KEY="minioadmin"
export MINIO_SECRET_KEY="minioadmin"

# 镜像仓库配置
export DOCKER_REGISTRY="your-registry.com"
export IMAGE_NAME="ruoyi-vue-plus"
```

## 部署模式

### 全量部署模式

全量部署将部署所有基础设施组件，包括：
- RuoYi-Vue-Plus 应用
- MySQL 数据库
- Redis 缓存
- MinIO 对象存储
- Prometheus 监控
- Grafana 可视化

#### 使用方法

1. **通过脚本部署**：
```bash
# 执行全量部署
./script/cnb/deploy-full.sh

# 指定环境部署
./script/cnb/deploy-full.sh prod
```

2. **通过 Git 提交触发**：
```bash
# 在提交消息中包含 [FULL] 标签
git commit -m "[FULL] 初始化完整部署环境"
git push origin main
```

#### 部署流程

1. 环境检查和配置加载
2. Maven 项目编译和测试
3. Docker 镜像构建
4. 基础设施服务启动
5. 应用部署和健康检查
6. 监控系统初始化

### 增量部署模式

增量部署支持独立更新特定模块，支持以下模块：

- `[BACKEND]` - 后端服务更新
- `[DB-MYSQL]` - MySQL 数据库迁移
- `[DB-POSTGRES]` - PostgreSQL 数据库迁移
- `[REDIS]` - Redis 配置更新
- `[MINIO]` - MinIO 配置更新
- `[MONITOR]` - 监控组件更新

#### 使用方法

1. **通过脚本部署**：
```bash
# 更新后端服务
./script/cnb/deploy-incremental.sh backend

# 更新数据库
./script/cnb/deploy-incremental.sh database mysql

# 更新监控组件
./script/cnb/deploy-incremental.sh monitoring
```

2. **通过 Git 提交触发**：
```bash
# 更新后端服务
git commit -m "[BACKEND] 修复用户登录问题"

# 更新数据库
git commit -m "[DB-MYSQL] 添加新的用户表字段"

# 更新监控配置
git commit -m "[MONITOR] 优化告警规则配置"
```

## 监控系统

### Prometheus 监控

监控指标包括：
- **应用指标**：HTTP 请求、响应时间、错误率
- **JVM 指标**：内存使用、GC 性能、线程状态
- **业务指标**：用户登录、数据操作、系统资源
- **基础设施指标**：数据库连接、Redis 性能、存储使用

访问地址：`http://localhost:9090`

### Grafana 可视化

预配置仪表板：
- **应用性能监控**：请求量、响应时间、错误率趋势
- **系统资源监控**：CPU、内存、磁盘、网络使用情况
- **业务指标监控**：用户活跃度、功能使用统计
- **基础设施监控**：数据库性能、缓存命中率、存储状态

访问地址：`http://localhost:3000`
默认账号：`admin/admin`

### 告警配置

预配置告警规则：
- 应用响应时间超过 2 秒
- 错误率超过 5%
- CPU 使用率超过 80%
- 内存使用率超过 85%
- 磁盘使用率超过 90%
- 数据库连接数超过阈值

## 高级配置

### 自定义构建器

修改 `.cnb.yml` 文件中的构建器配置：

```yaml
api: 0.7
buildpacks:
  - id: paketo-buildpacks/java
    version: "9.0.0"
  - id: paketo-buildpacks/executable-jar
    version: "6.0.0"

env:
  - name: BP_JVM_VERSION
    value: "17"
  - name: BP_MAVEN_BUILD_ARGUMENTS
    value: "-Dmaven.test.skip=true clean package"
```

### 多环境配置

支持 `dev`、`test`、`prod` 三种环境：

```bash
# 开发环境部署
./script/cnb/deploy-full.sh dev

# 生产环境部署
./script/cnb/deploy-full.sh prod
```

### 数据库迁移

支持自动数据库迁移：

```bash
# 执行数据库迁移
./script/cnb/scripts/database-migration.sh

# 回滚数据库
./script/cnb/scripts/database-rollback.sh
```

## 故障排除

### 常见问题

1. **构建失败**
```bash
# 检查构建日志
pack build ruoyi-vue-plus --builder paketobuildpacks/builder:base --verbose

# 清理构建缓存
pack build ruoyi-vue-plus --builder paketobuildpacks/builder:base --clear-cache
```

2. **服务启动失败**
```bash
# 检查容器日志
docker-compose logs ruoyi-app

# 检查健康状态
docker-compose ps
```

3. **监控数据缺失**
```bash
# 重启监控服务
docker-compose restart prometheus grafana

# 检查监控配置
docker-compose exec prometheus cat /etc/prometheus/prometheus.yml
```

### 日志查看

```bash
# 应用日志
docker-compose logs -f ruoyi-app

# 数据库日志
docker-compose logs -f mysql

# 监控日志
docker-compose logs -f prometheus grafana
```

### 性能调优

1. **JVM 参数优化**
```yaml
env:
  - name: JAVA_OPTS
    value: "-Xms2g -Xmx4g -XX:+UseG1GC -XX:MaxGCPauseMillis=200"
```

2. **数据库连接池优化**
```yaml
env:
  - name: SPRING_DATASOURCE_HIKARI_MAXIMUM_POOL_SIZE
    value: "20"
  - name: SPRING_DATASOURCE_HIKARI_MINIMUM_IDLE
    value: "5"
```

## 安全配置

### 容器安全

- 使用非 root 用户运行应用
- 启用只读文件系统
- 限制容器权限
- 定期更新基础镜像

### 网络安全

- 配置防火墙规则
- 使用 HTTPS 加密传输
- 限制端口暴露
- 配置网络隔离

### 数据安全

- 数据库连接加密
- 敏感信息环境变量化
- 定期备份数据
- 访问权限控制

## 维护和更新

### 定期维护

```bash
# 清理未使用的镜像
docker system prune -a

# 更新基础镜像
docker-compose pull

# 备份数据库
./script/cnb/scripts/backup-database.sh
```

### 版本升级

```bash
# 升级应用版本
git tag v1.1.0
git push origin v1.1.0

# 触发自动部署
git commit -m "[FULL] 升级到 v1.1.0 版本"
```

## 支持和反馈

如遇到问题或需要技术支持，请：

1. 查看本文档的故障排除部分
2. 检查项目 Issues 页面
3. 提交详细的问题报告
4. 联系技术支持团队

---

**注意**：首次部署前请仔细阅读本文档，确保环境配置正确。建议在测试环境中验证配置后再部署到生产环境。