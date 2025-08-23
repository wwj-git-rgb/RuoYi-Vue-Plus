# RuoYi-Vue-Plus 项目配置优化和数据库管理工具

## 📋 项目概述

本文档记录了对RuoYi-Vue-Plus项目进行的配置优化和数据库管理改进，主要包括：
- 配置PostgreSQL为默认数据库
- 优化多数据源配置结构
- 创建Docker部署配置
- 整理项目文件结构

## 🗂️ 文件结构优化

### 已完成的配置文件整理

```
RuoYi-Vue-Plus/
├── database/                           # 数据库配置管理目录
│   └── config/
│       ├── application/               # 应用数据源配置
│       │   ├── datasource-config.yml
│       │   ├── application-datasource-dev.yml
│       │   ├── application-datasource-prod.yml
│       │   └── application-datasource-test.yml
│       ├── datasource/               # 各数据库连接配置
│       │   ├── mysql.yml
│       │   ├── postgresql.yml
│       │   ├── oracle.yml
│       │   └── sqlserver.yml
│       ├── flyway/                   # 数据库迁移配置
│       │   ├── flyway-mysql.conf
│       │   └── flyway-postgresql.conf
│       └── java/                     # Java配置类
│           └── DatabaseSwitchConfig.java
├── docker/                            # Docker配置目录
│   ├── environments/                  # 多环境配置
│   │   ├── development/
│   │   │   ├── docker-compose.yml
│   │   │   └── .env
│   │   ├── testing/
│   │   │   ├── docker-compose.yml
│   │   │   └── .env
│   │   └── production/
│   │       ├── docker-compose.yml
│   │       └── .env
│   ├── nginx/
│   │   └── nginx.conf
│   ├── postgres/
│   │   └── postgresql.conf
│   ├── redis/
│   │   └── redis.conf
│   └── README.md
├── ruoyi-admin/
│   ├── Dockerfile                     # 应用Docker镜像
│   └── src/main/resources/db/migration/
│       └── postgresql/                # PostgreSQL迁移脚本
│           └── V1.0.0__Initial_PostgreSQL_Schema.sql
├── docker-compose-server.yml          # 腾讯云服务器部署配置
└── deploy.sh                          # 自动化部署脚本
```

## 🔧 配置优化详情

### 1. 数据库配置优化

#### PostgreSQL 设为默认数据库
- **开发环境** (`application-dev.yml`): 
  - 主数据源: PostgreSQL (1.15.3.137:5432)
  - 备用数据源: MySQL, Oracle, SQL Server
- **生产环境** (`application-prod.yml`): 
  - 同样配置PostgreSQL为主数据源

#### 多数据源支持
```yaml
spring:
  datasource:
    dynamic:
      primary: master  # 默认使用PostgreSQL
      datasource:
        master:  # PostgreSQL主库
          driverClassName: org.postgresql.Driver
          url: jdbc:postgresql://1.15.3.137:5432/ry_vue
        mysql:   # MySQL备用库
          driverClassName: com.mysql.cj.jdbc.Driver
          url: jdbc:mysql://1.15.3.137:3306/ry-vue
        oracle:  # Oracle备用库
          driverClassName: oracle.jdbc.OracleDriver
        sqlserver: # SQL Server备用库
          driverClassName: com.microsoft.sqlserver.jdbc.SQLServerDriver
```

### 2. Docker 配置优化

#### 服务组件
- **PostgreSQL**: 主数据库服务
- **Redis**: 缓存服务
- **MinIO**: 对象存储服务
- **MySQL**: 备用数据库
- **Nginx**: 反向代理
- **RuoYi-App**: 应用服务

#### 网络配置
- 自定义网络: `ruoyi-network`
- 子网: `172.20.0.0/16`
- 健康检查: 所有服务都配置了健康检查

### 3. 依赖管理优化

#### Maven依赖调整
```xml
<!-- PostgreSQL驱动包 - 主要数据库 -->
<dependency>
    <groupId>org.postgresql</groupId>
    <artifactId>postgresql</artifactId>
</dependency>

<!-- 其他数据库驱动 - 备用支持 -->
<dependency>
    <groupId>com.mysql</groupId>
    <artifactId>mysql-connector-j</artifactId>
</dependency>
```

## 🚀 部署指南

### 自动化部署

使用提供的部署脚本进行一键部署：

```bash
# 完整部署流程
./deploy.sh

# 分步执行
./deploy.sh build    # 仅构建项目
./deploy.sh prepare  # 仅准备部署文件
./deploy.sh upload   # 仅上传文件
./deploy.sh check    # 检查部署状态
```

### 手动部署步骤

1. **构建项目**
```bash
mvn clean package -DskipTests
```

2. **启动服务**
```bash
docker-compose -f docker-compose-server.yml up -d
```

3. **检查服务状态**
```bash
docker-compose -f docker-compose-server.yml ps
```

## 🌐 服务访问信息

### 腾讯云服务器 (1.15.3.137)

| 服务 | 地址 | 用户名 | 密码 |
|------|------|--------|------|
| RuoYi应用 | http://1.15.3.137:8080 | admin | admin123 |
| MinIO控制台 | http://1.15.3.137:9001 | ruoyi | ruoyi123456 |
| PostgreSQL | 1.15.3.137:5432 | postgres | ruoyi123 |
| Redis | 1.15.3.137:6379 | - | ruoyi123 |
| MySQL (备用) | 1.15.3.137:3306 | root | ruoyi123 |

## 📊 数据库管理

### PostgreSQL 初始化
- 数据库名: `ry_vue`
- 字符集: `UTF8`
- 初始化脚本: `script/sql/postgres/postgres_ry_vue_5.X.sql`

### 数据库迁移
- 迁移脚本位置: `ruoyi-admin/src/main/resources/db/migration/postgresql/`
- 版本管理: 使用Flyway进行版本控制

### 动态数据源切换
项目支持运行时动态切换数据源，通过`@DS`注解指定：
```java
@DS("mysql")    // 切换到MySQL
@DS("oracle")   // 切换到Oracle
@DS("master")   // 使用默认PostgreSQL
```

## 🔍 监控和日志

### 应用监控
- 健康检查端点: `/actuator/health`
- 应用指标: `/actuator/metrics`
- 日志位置: `/ruoyi/logs`

### 服务监控
```bash
# 查看所有服务状态
docker-compose -f docker-compose-server.yml ps

# 查看服务日志
docker-compose -f docker-compose-server.yml logs -f [service_name]

# 查看资源使用情况
docker stats
```

## 🛠️ 故障排除

### 常见问题

1. **PostgreSQL连接失败**
   - 检查防火墙设置
   - 确认数据库服务是否启动
   - 验证连接参数

2. **Redis连接超时**
   - 检查Redis服务状态
   - 验证密码配置
   - 确认网络连通性

3. **应用启动失败**
   - 查看应用日志: `docker logs ruoyi-app`
   - 检查数据库连接
   - 验证配置文件

### 日志查看命令
```bash
# 应用日志
docker logs -f ruoyi-app

# 数据库日志
docker logs -f ruoyi-postgres

# Redis日志
docker logs -f ruoyi-redis

# 所有服务日志
docker-compose -f docker-compose-server.yml logs -f
```

## 📝 配置文件说明

### 环境变量配置
- 开发环境: `.env.dev`
- 测试环境: `.env.test`  
- 生产环境: `.env.prod`

### 数据库连接池配置
```yaml
hikari:
  maxPoolSize: 20          # 最大连接数
  minIdle: 10             # 最小空闲连接
  connectionTimeout: 30000 # 连接超时时间
  idleTimeout: 600000     # 空闲超时时间
```

## 🔄 版本更新

### 数据库版本管理
- 使用Flyway进行数据库版本控制
- 迁移脚本命名规范: `V{版本号}__{描述}.sql`
- 支持多数据库类型的迁移脚本

### 应用版本部署
1. 更新代码
2. 执行构建: `mvn clean package`
3. 重新部署: `./deploy.sh`
4. 验证服务: `./deploy.sh check`

## 📞 技术支持

如遇到问题，请检查：
1. 服务器连接状态
2. Docker服务运行状态  
3. 数据库连接配置
4. 防火墙和网络设置

---

**最后更新**: 2025-01-23  
**版本**: 1.0.0  
**维护者**: RuoYi开发团队