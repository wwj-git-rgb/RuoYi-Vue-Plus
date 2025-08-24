#!/bin/bash
# RuoYi-Vue-Plus 构建辅助脚本
# 提供通用的构建和部署辅助函数

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1" >&2
}

log_debug() {
    if [ "${DEBUG:-false}" = "true" ]; then
        echo -e "${BLUE}[DEBUG]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
    fi
}

# 错误处理
handle_error() {
    local exit_code=$?
    local line_number=$1
    log_error "脚本在第 $line_number 行失败，退出码: $exit_code"
    exit $exit_code
}

# 设置错误陷阱
trap 'handle_error $LINENO' ERR

# 检查命令是否存在
check_command() {
    local cmd=$1
    local desc=${2:-$cmd}
    
    if ! command -v "$cmd" >/dev/null 2>&1; then
        log_error "$desc 未安装或不在PATH中"
        return 1
    fi
    
    log_debug "$desc 检查通过"
    return 0
}

# 检查Docker服务状态
check_docker() {
    log_info "检查Docker服务状态..."
    
    if ! check_command docker "Docker"; then
        return 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker服务未运行"
        return 1
    fi
    
    log_info "Docker服务运行正常"
    return 0
}

# 检查Maven环境
check_maven() {
    log_info "检查Maven环境..."
    
    if ! check_command mvn "Maven"; then
        return 1
    fi
    
    local maven_version=$(mvn -version | head -n 1)
    log_info "Maven版本: $maven_version"
    
    return 0
}

# 检查Java环境
check_java() {
    log_info "检查Java环境..."
    
    if ! check_command java "Java"; then
        return 1
    fi
    
    local java_version=$(java -version 2>&1 | head -n 1)
    log_info "Java版本: $java_version"
    
    # 检查Java版本是否为17或更高
    local version_number=$(java -version 2>&1 | head -n 1 | cut -d'"' -f2 | cut -d'.' -f1)
    if [ "$version_number" -lt 17 ]; then
        log_warn "建议使用Java 17或更高版本，当前版本: $version_number"
    fi
    
    return 0
}

# 检查Git环境
check_git() {
    log_info "检查Git环境..."
    
    if ! check_command git "Git"; then
        return 1
    fi
    
    local git_version=$(git --version)
    log_info "Git版本: $git_version"
    
    return 0
}

# 检查所有依赖
check_all_dependencies() {
    log_info "开始检查所有依赖..."
    
    local failed=0
    
    check_java || failed=1
    check_maven || failed=1
    check_docker || failed=1
    check_git || failed=1
    
    if [ $failed -eq 1 ]; then
        log_error "依赖检查失败"
        return 1
    fi
    
    log_info "所有依赖检查通过"
    return 0
}

# 等待服务启动
wait_for_service() {
    local service_name=$1
    local check_command=$2
    local max_attempts=${3:-30}
    local interval=${4:-10}
    
    log_info "等待 $service_name 服务启动..."
    
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        if eval "$check_command" >/dev/null 2>&1; then
            log_info "$service_name 服务启动成功"
            return 0
        fi
        
        log_debug "等待 $service_name 启动... ($attempt/$max_attempts)"
        sleep $interval
        ((attempt++))
    done
    
    log_error "$service_name 服务启动超时"
    return 1
}

# 等待HTTP服务
wait_for_http() {
    local url=$1
    local service_name=${2:-"HTTP服务"}
    local max_attempts=${3:-30}
    local interval=${4:-10}
    
    wait_for_service "$service_name" "curl -f $url" $max_attempts $interval
}

# 等待TCP端口
wait_for_port() {
    local host=$1
    local port=$2
    local service_name=${3:-"TCP服务"}
    local max_attempts=${4:-30}
    local interval=${5:-5}
    
    wait_for_service "$service_name" "nc -z $host $port" $max_attempts $interval
}

# 清理Docker资源
cleanup_docker() {
    log_info "清理Docker资源..."
    
    # 停止所有相关容器
    local containers=$(docker ps -q --filter "name=ruoyi" --filter "name=mysql" --filter "name=redis" --filter "name=minio" --filter "name=prometheus" --filter "name=grafana" 2>/dev/null || true)
    if [ -n "$containers" ]; then
        log_info "停止相关容器..."
        docker stop $containers || log_warn "停止容器失败"
    fi
    
    # 清理未使用的镜像
    docker image prune -f >/dev/null 2>&1 || log_warn "清理镜像失败"
    
    # 清理未使用的卷
    docker volume prune -f >/dev/null 2>&1 || log_warn "清理卷失败"
    
    log_info "Docker资源清理完成"
}

# 备份数据
backup_data() {
    local backup_dir=${1:-"/tmp/ruoyi-backup-$(date +%Y%m%d-%H%M%S)"}
    
    log_info "开始数据备份到: $backup_dir"
    mkdir -p "$backup_dir"
    
    # 备份MySQL数据
    if docker ps | grep -q mysql; then
        log_info "备份MySQL数据..."
        docker exec mysql mysqldump -uroot -proot --all-databases > "$backup_dir/mysql-backup.sql" 2>/dev/null || log_warn "MySQL备份失败"
    fi
    
    # 备份Redis数据
    if docker ps | grep -q redis; then
        log_info "备份Redis数据..."
        docker exec redis redis-cli BGSAVE >/dev/null 2>&1 || log_warn "Redis备份失败"
        docker cp redis:/redis/data/dump.rdb "$backup_dir/redis-dump.rdb" 2>/dev/null || log_warn "Redis数据复制失败"
    fi
    
    # 备份MinIO数据
    if [ -d "/docker/minio/data" ]; then
        log_info "备份MinIO数据..."
        tar -czf "$backup_dir/minio-data.tar.gz" -C "/docker/minio" data 2>/dev/null || log_warn "MinIO备份失败"
    fi
    
    log_info "数据备份完成: $backup_dir"
    echo "$backup_dir"
}

# 恢复数据
restore_data() {
    local backup_dir=$1
    
    if [ ! -d "$backup_dir" ]; then
        log_error "备份目录不存在: $backup_dir"
        return 1
    fi
    
    log_info "开始从备份恢复数据: $backup_dir"
    
    # 恢复MySQL数据
    if [ -f "$backup_dir/mysql-backup.sql" ] && docker ps | grep -q mysql; then
        log_info "恢复MySQL数据..."
        docker exec -i mysql mysql -uroot -proot < "$backup_dir/mysql-backup.sql" || log_warn "MySQL恢复失败"
    fi
    
    # 恢复Redis数据
    if [ -f "$backup_dir/redis-dump.rdb" ] && docker ps | grep -q redis; then
        log_info "恢复Redis数据..."
        docker cp "$backup_dir/redis-dump.rdb" redis:/redis/data/dump.rdb || log_warn "Redis恢复失败"
        docker restart redis || log_warn "Redis重启失败"
    fi
    
    # 恢复MinIO数据
    if [ -f "$backup_dir/minio-data.tar.gz" ]; then
        log_info "恢复MinIO数据..."
        mkdir -p "/docker/minio"
        tar -xzf "$backup_dir/minio-data.tar.gz" -C "/docker/minio" || log_warn "MinIO恢复失败"
    fi
    
    log_info "数据恢复完成"
}

# 获取服务状态
get_service_status() {
    local service_name=$1
    
    case "$service_name" in
        "mysql")
            if docker ps | grep -q mysql && docker exec mysql mysql -uroot -proot -e "SELECT 1" >/dev/null 2>&1; then
                echo "running"
            else
                echo "stopped"
            fi
            ;;
        "redis")
            if docker ps | grep -q redis && docker exec redis redis-cli ping | grep -q "PONG"; then
                echo "running"
            else
                echo "stopped"
            fi
            ;;
        "minio")
            if docker ps | grep -q minio && curl -f http://localhost:9000/minio/health/live >/dev/null 2>&1; then
                echo "running"
            else
                echo "stopped"
            fi
            ;;
        "ruoyi-server")
            if curl -f http://localhost:8080/actuator/health >/dev/null 2>&1; then
                echo "running"
            else
                echo "stopped"
            fi
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# 显示服务状态
show_service_status() {
    log_info "服务状态检查:"
    
    local services=("mysql" "redis" "minio" "ruoyi-server")
    
    for service in "${services[@]}"; do
        local status=$(get_service_status "$service")
        case "$status" in
            "running")
                echo -e "  ${GREEN}✓${NC} $service: 运行中"
                ;;
            "stopped")
                echo -e "  ${RED}✗${NC} $service: 已停止"
                ;;
            *)
                echo -e "  ${YELLOW}?${NC} $service: 状态未知"
                ;;
        esac
    done
}

# 生成部署报告
generate_deploy_report() {
    local report_file=${1:-"deploy-report-$(date +%Y%m%d-%H%M%S).txt"}
    
    log_info "生成部署报告: $report_file"
    
    {
        echo "RuoYi-Vue-Plus 部署报告"
        echo "========================"
        echo "生成时间: $(date)"
        echo ""
        
        echo "系统信息:"
        echo "  操作系统: $(uname -s)"
        echo "  架构: $(uname -m)"
        echo "  内核版本: $(uname -r)"
        echo ""
        
        echo "环境信息:"
        java -version 2>&1 | head -n 3 | sed 's/^/  /'
        echo "  Maven: $(mvn -version | head -n 1)"
        echo "  Docker: $(docker --version)"
        echo "  Git: $(git --version)"
        echo ""
        
        echo "服务状态:"
        show_service_status | sed 's/^/  /'
        echo ""
        
        echo "Docker容器:"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | sed 's/^/  /'
        echo ""
        
        echo "磁盘使用:"
        df -h | grep -E "(Filesystem|/docker|/tmp)" | sed 's/^/  /'
        
    } > "$report_file"
    
    log_info "部署报告已生成: $report_file"
}

# 如果脚本被直接执行，显示帮助信息
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    echo "RuoYi-Vue-Plus 构建辅助脚本"
    echo "此脚本提供通用的构建和部署辅助函数"
    echo ""
    echo "可用函数:"
    echo "  check_all_dependencies  - 检查所有依赖"
    echo "  wait_for_http <url>     - 等待HTTP服务"
    echo "  wait_for_port <host> <port> - 等待TCP端口"
    echo "  cleanup_docker          - 清理Docker资源"
    echo "  backup_data [dir]       - 备份数据"
    echo "  restore_data <dir>      - 恢复数据"
    echo "  show_service_status     - 显示服务状态"
    echo "  generate_deploy_report [file] - 生成部署报告"
    echo ""
    echo "使用方法:"
    echo "  source $0"
    echo "  check_all_dependencies"
fi