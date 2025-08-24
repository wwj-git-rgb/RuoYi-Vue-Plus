#!/bin/bash
# RuoYi-Vue-Plus 全量部署脚本
# 支持完整基础设施和应用的一键部署

set -e

# 脚本配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOG_FILE="$SCRIPT_DIR/logs/deploy-full-$(date +%Y%m%d-%H%M%S).log"

# 创建日志目录
mkdir -p "$SCRIPT_DIR/logs"

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$LOG_FILE" >&2
    exit 1
}

# 检查依赖
check_dependencies() {
    log "检查部署依赖..."
    
    command -v docker >/dev/null 2>&1 || error "Docker 未安装"
    command -v docker-compose >/dev/null 2>&1 || error "Docker Compose 未安装"
    command -v mvn >/dev/null 2>&1 || error "Maven 未安装"
    
    log "依赖检查完成"
}

# 构建应用
build_application() {
    log "开始构建应用..."
    
    cd "$PROJECT_ROOT"
    
    # 清理并编译
    mvn clean package -DskipTests=true -Pprod || error "Maven 构建失败"
    
    # 检查构建产物
    if [ ! -f "ruoyi-admin/target/ruoyi-admin.jar" ]; then
        error "构建产物不存在: ruoyi-admin.jar"
    fi
    
    log "应用构建完成"
}

# 构建Docker镜像
build_docker_images() {
    log "开始构建Docker镜像..."
    
    cd "$PROJECT_ROOT"
    
    # 构建主应用镜像
    docker build -f script/docker/Dockerfile -t ruoyi/ruoyi-server:5.4.1 . || error "Docker镜像构建失败"
    
    # 构建监控镜像
    if [ -f "ruoyi-extend/ruoyi-monitor-admin/target/ruoyi-monitor-admin.jar" ]; then
        docker build -f script/cnb/monitoring/Dockerfile.monitor -t ruoyi/ruoyi-monitor-admin:5.4.1 . || log "监控镜像构建失败，跳过"
    fi
    
    # 构建任务调度镜像
    if [ -f "ruoyi-extend/ruoyi-snailjob-server/target/ruoyi-snailjob-server.jar" ]; then
        docker build -f script/cnb/monitoring/Dockerfile.snailjob -t ruoyi/ruoyi-snailjob-server:5.4.1 . || log "任务调度镜像构建失败，跳过"
    fi
    
    log "Docker镜像构建完成"
}

# 部署基础设施
deploy_infrastructure() {
    log "开始部署基础设施..."
    
    cd "$PROJECT_ROOT/script/docker"
    
    # 停止现有服务
    docker-compose down || log "停止现有服务失败，继续部署"
    
    # 启动基础设施服务
    docker-compose up -d mysql redis minio || error "基础设施部署失败"
    
    # 等待服务启动
    log "等待基础设施服务启动..."
    sleep 30
    
    # 检查服务状态
    docker-compose ps | grep -E "(mysql|redis|minio)" | grep -v "Exit" || error "基础设施服务启动失败"
    
    log "基础设施部署完成"
}

# 初始化数据库
initialize_database() {
    log "开始初始化数据库..."
    
    # 等待MySQL完全启动
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if docker exec mysql mysql -uroot -proot -e "SELECT 1" >/dev/null 2>&1; then
            log "MySQL连接成功"
            break
        fi
        log "等待MySQL启动... ($attempt/$max_attempts)"
        sleep 10
        ((attempt++))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        error "MySQL启动超时"
    fi
    
    # 执行数据库初始化脚本
    if [ -f "$PROJECT_ROOT/script/sql/ry_vue_5.X.sql" ]; then
        docker exec -i mysql mysql -uroot -proot ry-vue < "$PROJECT_ROOT/script/sql/ry_vue_5.X.sql" || error "数据库初始化失败"
        log "主数据库初始化完成"
    fi
    
    # 初始化任务调度数据库
    if [ -f "$PROJECT_ROOT/script/sql/ry_job.sql" ]; then
        docker exec -i mysql mysql -uroot -proot ry-vue < "$PROJECT_ROOT/script/sql/ry_job.sql" || log "任务调度数据库初始化失败，跳过"
    fi
    
    # 初始化工作流数据库
    if [ -f "$PROJECT_ROOT/script/sql/ry_workflow.sql" ]; then
        docker exec -i mysql mysql -uroot -proot ry-vue < "$PROJECT_ROOT/script/sql/ry_workflow.sql" || log "工作流数据库初始化失败，跳过"
    fi
    
    log "数据库初始化完成"
}

# 部署应用服务
deploy_application() {
    log "开始部署应用服务..."
    
    cd "$PROJECT_ROOT/script/docker"
    
    # 启动应用服务
    docker-compose up -d ruoyi-server1 ruoyi-server2 || error "应用服务部署失败"
    
    # 启动监控服务
    docker-compose up -d ruoyi-monitor-admin || log "监控服务启动失败，跳过"
    
    # 启动任务调度服务
    docker-compose up -d ruoyi-snailjob-server || log "任务调度服务启动失败，跳过"
    
    log "应用服务部署完成"
}

# 部署监控系统
deploy_monitoring() {
    log "开始部署监控系统..."
    
    # 启动Prometheus
    if [ -f "$SCRIPT_DIR/monitoring/prometheus.yml" ]; then
        docker run -d \
            --name prometheus \
            --network host \
            -v "$SCRIPT_DIR/monitoring/prometheus.yml:/etc/prometheus/prometheus.yml" \
            -v "/docker/prometheus/data:/prometheus" \
            prom/prometheus:latest || log "Prometheus启动失败，跳过"
    fi
    
    # 启动Grafana
    docker run -d \
        --name grafana \
        --network host \
        -e "GF_SECURITY_ADMIN_PASSWORD=admin123" \
        -v "/docker/grafana/data:/var/lib/grafana" \
        -v "$SCRIPT_DIR/monitoring/grafana:/etc/grafana/provisioning" \
        grafana/grafana:latest || log "Grafana启动失败，跳过"
    
    log "监控系统部署完成"
}

# 健康检查
health_check() {
    log "开始健康检查..."
    
    local max_attempts=30
    local attempt=1
    
    # 检查主应用
    while [ $attempt -le $max_attempts ]; do
        if curl -f http://localhost:8080/actuator/health >/dev/null 2>&1; then
            log "主应用健康检查通过"
            break
        fi
        log "等待主应用启动... ($attempt/$max_attempts)"
        sleep 10
        ((attempt++))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        error "主应用健康检查失败"
    fi
    
    # 检查数据库连接
    curl -f http://localhost:8080/actuator/health/db >/dev/null 2>&1 || log "数据库连接检查失败"
    
    # 检查Redis连接
    curl -f http://localhost:8080/actuator/health/redis >/dev/null 2>&1 || log "Redis连接检查失败"
    
    log "健康检查完成"
}

# 主函数
main() {
    log "开始RuoYi-Vue-Plus全量部署..."
    
    check_dependencies
    build_application
    build_docker_images
    deploy_infrastructure
    initialize_database
    deploy_application
    deploy_monitoring
    health_check
    
    log "全量部署完成！"
    log "访问地址："
    log "  - 主应用: http://localhost:8080"
    log "  - 监控管理: http://localhost:9090"
    log "  - Prometheus: http://localhost:9090"
    log "  - Grafana: http://localhost:3000 (admin/admin123)"
    log "  - MinIO控制台: http://localhost:9001 (ruoyi/ruoyi123)"
}

# 执行主函数
main "$@"