#!/bin/bash

# RuoYi-Vue-Plus 腾讯云服务器部署脚本
# 服务器信息
SERVER_HOST="1.15.3.137"
SERVER_USER="root"
SERVER_PASSWORD="Wwj182."
SERVER_PORT="22"

# 项目配置
PROJECT_NAME="ruoyi-vue-plus"
REMOTE_DIR="/opt/ruoyi"
DOCKER_COMPOSE_FILE="script/docker/docker-compose-server.yml"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 执行远程命令
execute_remote() {
    local command="$1"
    
    # 检查是否配置了SSH密钥
    if ssh -o BatchMode=yes -o ConnectTimeout=5 ${SERVER_USER}@${SERVER_HOST} "echo 'SSH key auth test'" >/dev/null 2>&1; then
        # 使用SSH密钥认证
        ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 ${SERVER_USER}@${SERVER_HOST} "$command"
    elif command -v sshpass &> /dev/null; then
        # 使用sshpass
        sshpass -p "${SERVER_PASSWORD}" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 ${SERVER_USER}@${SERVER_HOST} "$command"
    else
        log_info "请手动输入SSH密码..."
        ssh -o ConnectTimeout=10 ${SERVER_USER}@${SERVER_HOST} "$command"
    fi
}

# 测试SSH连接
test_ssh_connection() {
    log_info "测试SSH连接到 ${SERVER_HOST}..."
    
    if command -v sshpass &> /dev/null; then
        log_info "使用sshpass进行自动连接..."
        if sshpass -p "${SERVER_PASSWORD}" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 ${SERVER_USER}@${SERVER_HOST} "echo 'SSH连接成功'"; then
            log_success "SSH连接测试成功"
            return 0
        else
            log_error "SSH连接失败，请检查服务器地址、用户名和密码"
            return 1
        fi
    else
        log_info "请手动输入SSH密码进行连接测试..."
        if ssh -o ConnectTimeout=10 ${SERVER_USER}@${SERVER_HOST} "echo 'SSH连接成功'"; then
            log_success "SSH连接测试成功"
            return 0
        else
            log_error "SSH连接失败"
            return 1
        fi
    fi
}

# 检查本地依赖
check_dependencies() {
    log_info "检查本地依赖..."
    
    # 检查 Maven
    if ! command -v mvn &> /dev/null; then
        log_error "Maven 未安装，请先安装 Maven"
        exit 1
    fi
    
    # 检查 sshpass (用于自动化SSH)
    if ! command -v sshpass &> /dev/null; then
        log_warning "sshpass 未安装，将使用交互式SSH"
    fi
    
    log_success "本地依赖检查完成"
}

# 检查服务器环境
check_server_environment() {
    log_info "检查服务器环境..."
    
    # 检查服务器连接
    log_info "测试服务器连接..."
    if ! execute_remote "echo 'Server connection test'"; then
        log_error "无法连接到服务器 ${SERVER_HOST}"
        exit 1
    fi
    log_success "服务器连接正常"
    
    # 检查服务器Docker
    log_info "检查Docker安装..."
    if ! execute_remote "which docker >/dev/null 2>&1 && echo 'Docker found' || echo 'Docker not found'"; then
        log_error "检查Docker时出现错误"
        exit 1
    fi
    
    # 检查Docker服务状态
    log_info "检查Docker服务状态..."
    execute_remote "systemctl is-active docker >/dev/null 2>&1 && echo 'Docker service is running' || echo 'Docker service is not running'"
    
    # 检查服务器Docker Compose
    log_info "检查Docker Compose安装..."
    execute_remote "which docker-compose >/dev/null 2>&1 && echo 'Docker Compose found' || echo 'Docker Compose not found'"
    
    log_success "服务器环境检查完成"
}

# 构建项目
build_project() {
    log_info "开始构建项目..."
    
    # 清理之前的构建
    mvn clean
    
    # 构建项目
    mvn package -DskipTests
    
    if [ $? -eq 0 ]; then
        log_success "项目构建完成"
    else
        log_error "项目构建失败"
        exit 1
    fi
}

# 上传文件到服务器
upload_files() {
    log_info "上传文件到服务器..."
    
    # 使用scp上传项目文件
    if command -v sshpass &> /dev/null; then
        # 创建远程目录
        sshpass -p "${SERVER_PASSWORD}" ssh -o StrictHostKeyChecking=no ${SERVER_USER}@${SERVER_HOST} "mkdir -p ${REMOTE_DIR}"
        
        # 上传整个项目目录
        sshpass -p "${SERVER_PASSWORD}" scp -r -o StrictHostKeyChecking=no . ${SERVER_USER}@${SERVER_HOST}:${REMOTE_DIR}/
    else
        log_info "请手动输入SSH密码..."
        ssh ${SERVER_USER}@${SERVER_HOST} "mkdir -p ${REMOTE_DIR}"
        scp -r . ${SERVER_USER}@${SERVER_HOST}:${REMOTE_DIR}/
    fi
    
    if [ $? -eq 0 ]; then
        log_success "文件上传完成"
    else
        log_error "文件上传失败"
        exit 1
    fi
}

# 在服务器上构建Docker镜像
build_docker_image_on_server() {
    log_info "在服务器上构建Docker镜像..."
    
    # 复制jar文件到Docker构建目录
    execute_remote "cd ${REMOTE_DIR} && cp ruoyi-admin/target/ruoyi-admin.jar script/docker/"
    
    # 在服务器上构建镜像
    execute_remote "cd ${REMOTE_DIR}/script/docker && docker build -t ${PROJECT_NAME}:latest ."
    
    if [ $? -eq 0 ]; then
        log_success "Docker镜像构建完成"
    else
        log_error "Docker镜像构建失败"
        exit 1
    fi
}

# 部署到服务器
deploy_to_server() {
    log_info "部署到服务器..."
    
    # 停止现有服务
    execute_remote "cd ${REMOTE_DIR} && docker-compose -f ${DOCKER_COMPOSE_FILE} down"
    
    # 启动新服务
    execute_remote "cd ${REMOTE_DIR} && docker-compose -f ${DOCKER_COMPOSE_FILE} up -d"
    
    if [ $? -eq 0 ]; then
        log_success "服务部署完成"
    else
        log_error "服务部署失败"
        exit 1
    fi
}

# 检查部署状态
check_deployment() {
    log_info "检查部署状态..."
    
    # 等待服务启动
    sleep 10
    
    # 检查容器状态
    execute_remote "cd ${REMOTE_DIR} && docker-compose -f ${DOCKER_COMPOSE_FILE} ps"
    
    # 检查应用健康状态
    log_info "检查应用健康状态..."
    execute_remote "curl -f http://localhost:8080/actuator/health || echo '应用可能还在启动中...'"
    
    log_success "部署状态检查完成"
}

# 查看日志
view_logs() {
    log_info "查看应用日志..."
    execute_remote "cd ${REMOTE_DIR} && docker-compose -f ${DOCKER_COMPOSE_FILE} logs --tail=50 ruoyi-app"
}

# 清理资源
cleanup() {
    log_info "清理服务器资源..."
    execute_remote "docker system prune -f"
    log_success "资源清理完成"
}

# 显示帮助信息
show_help() {
    echo "RuoYi-Vue-Plus 腾讯云服务器部署脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  build     构建项目并上传到服务器"
    echo "  deploy    在服务器上部署应用"
    echo "  check     检查部署状态"
    echo "  logs      查看应用日志"
    echo "  cleanup   清理服务器资源"
    echo "  help      显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0              # 完整部署流程"
    echo "  $0 build        # 仅构建和上传"
    echo "  $0 deploy       # 仅部署"
    echo "  $0 check        # 检查状态"
}

# 主函数
main() {
    echo ""
    echo "=========================================="
    echo "RuoYi-Vue-Plus 腾讯云服务器部署脚本"
    echo "=========================================="
    
    case "$1" in
        "build")
            log_info "开始构建流程..."
            check_dependencies
            check_server_environment
            build_project
            upload_files
            build_docker_image_on_server
            ;;
        "deploy")
            log_info "开始部署流程..."
            check_server_environment
            deploy_to_server
            ;;
        "check")
            log_info "开始检查流程..."
            check_deployment
            ;;
        "logs")
            view_logs
            ;;
        "cleanup")
            cleanup
            ;;
        "help")
            show_help
            ;;
        *)
            log_info "开始完整部署流程..."
            check_dependencies
            
            # 先测试SSH连接
            if ! test_ssh_connection; then
                log_error "SSH连接失败，请检查服务器信息"
                exit 1
            fi
            
            check_server_environment
            build_project
            upload_files
            build_docker_image_on_server
            deploy_to_server
            check_deployment
            ;;
    esac
    
    echo ""
    echo "=========================================="
    echo "部署完成！"
    echo "应用访问地址: http://${SERVER_HOST}:8080"
    echo "PostgreSQL: ${SERVER_HOST}:5432"
    echo "Redis: ${SERVER_HOST}:6379"
    echo "MinIO: http://${SERVER_HOST}:9001"
    echo "=========================================="
}

# 执行主函数
main "$@"