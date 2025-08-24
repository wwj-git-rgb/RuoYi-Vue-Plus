#!/bin/bash
# RuoYi-Vue-Plus 环境配置脚本
# 管理不同环境的配置变量

# 默认环境
DEFAULT_ENV="dev"
CURRENT_ENV="${DEPLOY_ENV:-$DEFAULT_ENV}"

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# 日志函数
log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $1" >&2
}

# 开发环境配置
configure_dev_env() {
    log_info "配置开发环境..."
    
    # 数据库配置
    export DB_HOST="localhost"
    export DB_PORT="3306"
    export DB_NAME="ry-vue"
    export DB_USERNAME="root"
    export DB_PASSWORD="root"
    export DB_TYPE="mysql"
    
    # Redis配置
    export REDIS_HOST="localhost"
    export REDIS_PORT="6379"
    export REDIS_PASSWORD=""
    export REDIS_DATABASE="0"
    
    # MinIO配置
    export MINIO_ENDPOINT="http://localhost:9000"
    export MINIO_ACCESS_KEY="ruoyi"
    export MINIO_SECRET_KEY="ruoyi123"
    export MINIO_BUCKET_NAME="ruoyi"
    
    # 应用配置
    export SERVER_PORT="8080"
    export SPRING_PROFILES_ACTIVE="dev"
    export LOG_LEVEL="debug"
    
    # 监控配置
    export MONITOR_ENABLED="true"
    export PROMETHEUS_PORT="9090"
    export GRAFANA_PORT="3000"
    
    # JVM配置
    export JAVA_OPTS="-Xms256m -Xmx512m -XX:+UseG1GC"
    
    log_info "开发环境配置完成"
}

# 生产环境配置
configure_prod_env() {
    log_info "配置生产环境..."
    
    # 数据库配置
    export DB_HOST="${DB_HOST:-localhost}"
    export DB_PORT="${DB_PORT:-3306}"
    export DB_NAME="${DB_NAME:-ry-vue}"
    export DB_USERNAME="${DB_USERNAME:-root}"
    export DB_PASSWORD="${DB_PASSWORD:-root}"
    export DB_TYPE="${DB_TYPE:-mysql}"
    
    # Redis配置
    export REDIS_HOST="${REDIS_HOST:-localhost}"
    export REDIS_PORT="${REDIS_PORT:-6379}"
    export REDIS_PASSWORD="${REDIS_PASSWORD:-ruoyi123}"
    export REDIS_DATABASE="${REDIS_DATABASE:-0}"
    
    # MinIO配置
    export MINIO_ENDPOINT="${MINIO_ENDPOINT:-http://localhost:9000}"
    export MINIO_ACCESS_KEY="${MINIO_ACCESS_KEY:-ruoyi}"
    export MINIO_SECRET_KEY="${MINIO_SECRET_KEY:-ruoyi123456}"
    export MINIO_BUCKET_NAME="${MINIO_BUCKET_NAME:-ruoyi}"
    
    # 应用配置
    export SERVER_PORT="${SERVER_PORT:-8080}"
    export SPRING_PROFILES_ACTIVE="prod"
    export LOG_LEVEL="${LOG_LEVEL:-info}"
    
    # 监控配置
    export MONITOR_ENABLED="${MONITOR_ENABLED:-true}"
    export PROMETHEUS_PORT="${PROMETHEUS_PORT:-9090}"
    export GRAFANA_PORT="${GRAFANA_PORT:-3000}"
    
    # JVM配置
    export JAVA_OPTS="${JAVA_OPTS:--Xms1g -Xmx2g -XX:+UseG1GC -XX:+UseContainerSupport}"
    
    # 安全配置
    export SECURITY_ENABLED="true"
    export SSL_ENABLED="${SSL_ENABLED:-false}"
    
    log_info "生产环境配置完成"
}

# 测试环境配置
configure_test_env() {
    log_info "配置测试环境..."
    
    # 数据库配置
    export DB_HOST="localhost"
    export DB_PORT="3306"
    export DB_NAME="ry-vue-test"
    export DB_USERNAME="root"
    export DB_PASSWORD="root"
    export DB_TYPE="mysql"
    
    # Redis配置
    export REDIS_HOST="localhost"
    export REDIS_PORT="6379"
    export REDIS_PASSWORD=""
    export REDIS_DATABASE="1"
    
    # MinIO配置
    export MINIO_ENDPOINT="http://localhost:9000"
    export MINIO_ACCESS_KEY="ruoyi"
    export MINIO_SECRET_KEY="ruoyi123"
    export MINIO_BUCKET_NAME="ruoyi-test"
    
    # 应用配置
    export SERVER_PORT="8080"
    export SPRING_PROFILES_ACTIVE="test"
    export LOG_LEVEL="info"
    
    # 监控配置
    export MONITOR_ENABLED="false"
    
    # JVM配置
    export JAVA_OPTS="-Xms256m -Xmx512m -XX:+UseG1GC"
    
    log_info "测试环境配置完成"
}

# Docker环境配置
configure_docker_env() {
    log_info "配置Docker环境..."
    
    # Docker网络配置
    export DOCKER_NETWORK="ruoyi-network"
    export DOCKER_REGISTRY="${DOCKER_REGISTRY:-registry.cn-hangzhou.aliyuncs.com}"
    export DOCKER_NAMESPACE="${DOCKER_NAMESPACE:-ruoyi-vue-plus}"
    
    # 容器资源限制
    export CONTAINER_MEMORY_LIMIT="${CONTAINER_MEMORY_LIMIT:-2g}"
    export CONTAINER_CPU_LIMIT="${CONTAINER_CPU_LIMIT:-1000m}"
    export CONTAINER_MEMORY_REQUEST="${CONTAINER_MEMORY_REQUEST:-512m}"
    export CONTAINER_CPU_REQUEST="${CONTAINER_CPU_REQUEST:-500m}"
    
    # 存储卷配置
    export MYSQL_DATA_PATH="${MYSQL_DATA_PATH:-/docker/mysql/data}"
    export REDIS_DATA_PATH="${REDIS_DATA_PATH:-/docker/redis/data}"
    export MINIO_DATA_PATH="${MINIO_DATA_PATH:-/docker/minio/data}"
    export LOGS_PATH="${LOGS_PATH:-/docker/logs}"
    
    log_info "Docker环境配置完成"
}

# 监控环境配置
configure_monitoring_env() {
    log_info "配置监控环境..."
    
    # Prometheus配置
    export PROMETHEUS_CONFIG_PATH="$SCRIPT_DIR/../monitoring/prometheus.yml"
    export PROMETHEUS_DATA_PATH="/docker/prometheus/data"
    export PROMETHEUS_RETENTION_TIME="${PROMETHEUS_RETENTION_TIME:-15d}"
    
    # Grafana配置
    export GRAFANA_DATA_PATH="/docker/grafana/data"
    export GRAFANA_ADMIN_PASSWORD="${GRAFANA_ADMIN_PASSWORD:-admin123}"
    export GRAFANA_CONFIG_PATH="$SCRIPT_DIR/../monitoring/grafana"
    
    # 告警配置
    export ALERTMANAGER_ENABLED="${ALERTMANAGER_ENABLED:-false}"
    export ALERT_WEBHOOK_URL="${ALERT_WEBHOOK_URL:-}"
    
    log_info "监控环境配置完成"
}

# 根据环境类型配置
configure_environment() {
    local env=${1:-$CURRENT_ENV}
    
    log_info "配置环境: $env"
    
    case "$env" in
        "dev"|"development")
            configure_dev_env
            ;;
        "prod"|"production")
            configure_prod_env
            ;;
        "test"|"testing")
            configure_test_env
            ;;
        *)
            log_error "不支持的环境类型: $env"
            return 1
            ;;
    esac
    
    # 通用配置
    configure_docker_env
    configure_monitoring_env
    
    # 设置时区
    export TZ="${TZ:-Asia/Shanghai}"
    
    # 设置构建信息
    export BUILD_TIME="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    export BUILD_VERSION="${BUILD_VERSION:-5.4.1}"
    export GIT_COMMIT="${GIT_COMMIT:-$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')}"
    
    log_info "环境配置完成: $env"
}

# 验证环境配置
validate_environment() {
    log_info "验证环境配置..."
    
    local errors=0
    
    # 检查必需的环境变量
    local required_vars=(
        "DB_HOST" "DB_PORT" "DB_NAME" "DB_USERNAME" "DB_PASSWORD"
        "REDIS_HOST" "REDIS_PORT"
        "MINIO_ENDPOINT" "MINIO_ACCESS_KEY" "MINIO_SECRET_KEY"
        "SERVER_PORT" "SPRING_PROFILES_ACTIVE"
    )
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            log_error "缺少必需的环境变量: $var"
            ((errors++))
        fi
    done
    
    # 检查端口是否被占用
    local ports=("$SERVER_PORT" "$DB_PORT" "$REDIS_PORT")
    for port in "${ports[@]}"; do
        if [ -n "$port" ] && netstat -ln 2>/dev/null | grep -q ":$port "; then
            log_error "端口 $port 已被占用"
            ((errors++))
        fi
    done
    
    if [ $errors -eq 0 ]; then
        log_info "环境配置验证通过"
        return 0
    else
        log_error "环境配置验证失败，发现 $errors 个错误"
        return 1
    fi
}

# 显示环境配置
show_environment() {
    echo "当前环境配置:"
    echo "=============="
    echo "环境类型: $CURRENT_ENV"
    echo "构建版本: $BUILD_VERSION"
    echo "构建时间: $BUILD_TIME"
    echo "Git提交: $GIT_COMMIT"
    echo ""
    echo "数据库配置:"
    echo "  主机: $DB_HOST:$DB_PORT"
    echo "  数据库: $DB_NAME"
    echo "  用户: $DB_USERNAME"
    echo ""
    echo "Redis配置:"
    echo "  主机: $REDIS_HOST:$REDIS_PORT"
    echo "  数据库: $REDIS_DATABASE"
    echo ""
    echo "MinIO配置:"
    echo "  端点: $MINIO_ENDPOINT"
    echo "  存储桶: $MINIO_BUCKET_NAME"
    echo ""
    echo "应用配置:"
    echo "  端口: $SERVER_PORT"
    echo "  配置文件: $SPRING_PROFILES_ACTIVE"
    echo "  日志级别: $LOG_LEVEL"
    echo "  JVM参数: $JAVA_OPTS"
}

# 导出环境配置到文件
export_environment() {
    local output_file=${1:-"$PROJECT_ROOT/.env"}
    
    log_info "导出环境配置到: $output_file"
    
    cat > "$output_file" << EOF
# RuoYi-Vue-Plus 环境配置
# 生成时间: $(date)
# 环境类型: $CURRENT_ENV

# 数据库配置
DB_HOST=$DB_HOST
DB_PORT=$DB_PORT
DB_NAME=$DB_NAME
DB_USERNAME=$DB_USERNAME
DB_PASSWORD=$DB_PASSWORD
DB_TYPE=$DB_TYPE

# Redis配置
REDIS_HOST=$REDIS_HOST
REDIS_PORT=$REDIS_PORT
REDIS_PASSWORD=$REDIS_PASSWORD
REDIS_DATABASE=$REDIS_DATABASE

# MinIO配置
MINIO_ENDPOINT=$MINIO_ENDPOINT
MINIO_ACCESS_KEY=$MINIO_ACCESS_KEY
MINIO_SECRET_KEY=$MINIO_SECRET_KEY
MINIO_BUCKET_NAME=$MINIO_BUCKET_NAME

# 应用配置
SERVER_PORT=$SERVER_PORT
SPRING_PROFILES_ACTIVE=$SPRING_PROFILES_ACTIVE
LOG_LEVEL=$LOG_LEVEL
JAVA_OPTS=$JAVA_OPTS

# 监控配置
MONITOR_ENABLED=$MONITOR_ENABLED
PROMETHEUS_PORT=$PROMETHEUS_PORT
GRAFANA_PORT=$GRAFANA_PORT

# 构建信息
BUILD_VERSION=$BUILD_VERSION
BUILD_TIME=$BUILD_TIME
GIT_COMMIT=$GIT_COMMIT
TZ=$TZ
EOF
    
    log_info "环境配置已导出"
}

# 主函数
main() {
    case "${1:-configure}" in
        "configure")
            configure_environment "${2:-$CURRENT_ENV}"
            ;;
        "validate")
            validate_environment
            ;;
        "show")
            show_environment
            ;;
        "export")
            export_environment "$2"
            ;;
        *)
            echo "用法: $0 {configure|validate|show|export} [参数]"
            echo ""
            echo "命令:"
            echo "  configure [env]  - 配置指定环境 (dev/prod/test)"
            echo "  validate         - 验证环境配置"
            echo "  show            - 显示当前环境配置"
            echo "  export [file]   - 导出环境配置到文件"
            exit 1
            ;;
    esac
}

# 如果脚本被直接执行
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
else
    # 如果被source，自动配置环境
    configure_environment
fi