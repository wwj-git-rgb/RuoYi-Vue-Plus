#!/bin/bash
# RuoYi-Vue-Plus 增量部署脚本
# 支持单个模块的独立更新部署

set -e

# 脚本配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOG_FILE="$SCRIPT_DIR/logs/deploy-incremental-$(date +%Y%m%d-%H%M%S).log"

# 创建日志目录
mkdir -p "$SCRIPT_DIR/logs"

# 部署模块类型
DEPLOY_MODULE=""
GIT_COMMIT_MSG=""

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$LOG_FILE" >&2
    exit 1
}

# 显示帮助信息
show_help() {
    cat << EOF
RuoYi-Vue-Plus 增量部署脚本

用法: $0 [选项]

选项:
  -m, --module MODULE     指定部署模块 (backend|database|redis|minio|monitoring)
  -c, --commit-msg MSG    Git提交消息（用于自动识别部署模块）
  -h, --help             显示此帮助信息

支持的模块:
  backend     - 后端应用服务
  database    - 数据库迁移脚本
  redis       - Redis缓存配置
  minio       - MinIO存储配置
  monitoring  - 监控组件

示例:
  $0 -m backend                    # 部署后端服务
  $0 -c "[BACKEND] 修复用户登录问题"  # 根据提交消息自动识别
  $0 -m database                   # 执行数据库迁移

EOF
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -m|--module)
                DEPLOY_MODULE="$2"
                shift 2
                ;;
            -c|--commit-msg)
                GIT_COMMIT_MSG="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                error "未知参数: $1"
                ;;
        esac
    done
}

# 从Git提交消息识别部署模块
detect_module_from_commit() {
    if [ -z "$GIT_COMMIT_MSG" ]; then
        # 尝试获取最新的提交消息
        if command -v git >/dev/null 2>&1; then
            GIT_COMMIT_MSG=$(git log -1 --pretty=%B 2>/dev/null || echo "")
        fi
    fi
    
    if [ -n "$GIT_COMMIT_MSG" ]; then
        log "分析提交消息: $GIT_COMMIT_MSG"
        
        if echo "$GIT_COMMIT_MSG" | grep -q "\[BACKEND\]"; then
            DEPLOY_MODULE="backend"
        elif echo "$GIT_COMMIT_MSG" | grep -q "\[DB\]\|\[DB-MYSQL\]\|\[DB-POSTGRES\]"; then
            DEPLOY_MODULE="database"
        elif echo "$GIT_COMMIT_MSG" | grep -q "\[REDIS\]"; then
            DEPLOY_MODULE="redis"
        elif echo "$GIT_COMMIT_MSG" | grep -q "\[MINIO\]"; then
            DEPLOY_MODULE="minio"
        elif echo "$GIT_COMMIT_MSG" | grep -q "\[MONITOR\]"; then
            DEPLOY_MODULE="monitoring"
        fi
        
        if [ -n "$DEPLOY_MODULE" ]; then
            log "自动识别部署模块: $DEPLOY_MODULE"
        fi
    fi
}

# 部署后端服务
deploy_backend() {
    log "开始部署后端服务..."
    
    cd "$PROJECT_ROOT"
    
    # 构建应用
    mvn clean package -DskipTests=true -Pprod || error "Maven构建失败"
    
    # 构建Docker镜像
    docker build -f script/docker/Dockerfile -t ruoyi/ruoyi-server:5.4.1 . || error "Docker镜像构建失败"
    
    # 重启应用服务
    cd "$PROJECT_ROOT/script/docker"
    docker-compose restart ruoyi-server1 ruoyi-server2 || error "应用服务重启失败"
    
    # 健康检查
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f http://localhost:8080/actuator/health >/dev/null 2>&1; then
            log "后端服务健康检查通过"
            break
        fi
        log "等待后端服务启动... ($attempt/$max_attempts)"
        sleep 10
        ((attempt++))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        error "后端服务健康检查失败"
    fi
    
    log "后端服务部署完成"
}

# 执行数据库迁移
deploy_database() {
    log "开始执行数据库迁移..."
    
    # 检查MySQL连接
    if ! docker exec mysql mysql -uroot -proot -e "SELECT 1" >/dev/null 2>&1; then
        error "MySQL连接失败"
    fi
    
    # 查找更新脚本
    local update_scripts_dir="$PROJECT_ROOT/script/sql/update"
    if [ -d "$update_scripts_dir" ]; then
        # 按版本顺序执行更新脚本
        for script in "$update_scripts_dir"/*.sql; do
            if [ -f "$script" ]; then
                log "执行数据库脚本: $(basename "$script")"
                docker exec -i mysql mysql -uroot -proot ry-vue < "$script" || error "数据库脚本执行失败: $script"
            fi
        done
    fi
    
    # 验证数据库状态
    local table_count=$(docker exec mysql mysql -uroot -proot ry-vue -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='ry-vue'" -s -N)
    log "数据库表数量: $table_count"
    
    log "数据库迁移完成"
}

# 更新Redis配置
deploy_redis() {
    log "开始更新Redis配置..."
    
    cd "$PROJECT_ROOT/script/docker"
    
    # 重启Redis服务
    docker-compose restart redis || error "Redis服务重启失败"
    
    # 等待Redis启动
    sleep 10
    
    # 检查Redis连接
    if docker exec redis redis-cli ping | grep -q "PONG"; then
        log "Redis连接检查通过"
    else
        error "Redis连接检查失败"
    fi
    
    log "Redis配置更新完成"
}

# 更新MinIO配置
deploy_minio() {
    log "开始更新MinIO配置..."
    
    cd "$PROJECT_ROOT/script/docker"
    
    # 重启MinIO服务
    docker-compose restart minio || error "MinIO服务重启失败"
    
    # 等待MinIO启动
    sleep 15
    
    # 检查MinIO服务
    if curl -f http://localhost:9000/minio/health/live >/dev/null 2>&1; then
        log "MinIO健康检查通过"
    else
        log "MinIO健康检查失败，但服务可能正常运行"
    fi
    
    log "MinIO配置更新完成"
}

# 更新监控组件
deploy_monitoring() {
    log "开始更新监控组件..."
    
    # 重启Prometheus
    if docker ps | grep -q prometheus; then
        docker restart prometheus || log "Prometheus重启失败"
        log "Prometheus已重启"
    fi
    
    # 重启Grafana
    if docker ps | grep -q grafana; then
        docker restart grafana || log "Grafana重启失败"
        log "Grafana已重启"
    fi
    
    # 重启监控管理服务
    cd "$PROJECT_ROOT/script/docker"
    docker-compose restart ruoyi-monitor-admin || log "监控管理服务重启失败"
    
    log "监控组件更新完成"
}

# 主函数
main() {
    log "开始RuoYi-Vue-Plus增量部署..."
    
    parse_args "$@"
    
    # 如果没有指定模块，尝试从提交消息识别
    if [ -z "$DEPLOY_MODULE" ]; then
        detect_module_from_commit
    fi
    
    # 如果仍然没有模块，显示帮助
    if [ -z "$DEPLOY_MODULE" ]; then
        error "未指定部署模块，请使用 -m 参数或在提交消息中包含模块标签"
    fi
    
    log "部署模块: $DEPLOY_MODULE"
    
    case "$DEPLOY_MODULE" in
        backend)
            deploy_backend
            ;;
        database)
            deploy_database
            ;;
        redis)
            deploy_redis
            ;;
        minio)
            deploy_minio
            ;;
        monitoring)
            deploy_monitoring
            ;;
        *)
            error "不支持的部署模块: $DEPLOY_MODULE"
            ;;
    esac
    
    log "增量部署完成！"
}

# 执行主函数
main "$@"