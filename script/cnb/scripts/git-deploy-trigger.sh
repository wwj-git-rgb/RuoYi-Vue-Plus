#!/bin/bash
# Git提交消息解析和自动部署触发脚本
# 根据提交消息自动选择全量部署或增量部署

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CNB_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_FILE="$CNB_DIR/logs/git-deploy-$(date +%Y%m%d-%H%M%S).log"

# 创建日志目录
mkdir -p "$CNB_DIR/logs"

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$LOG_FILE" >&2
    exit 1
}

# 获取Git提交消息
get_commit_message() {
    local commit_msg=""
    
    # 从参数获取
    if [ $# -gt 0 ]; then
        commit_msg="$1"
    # 从环境变量获取（CI/CD环境）
    elif [ -n "$CI_COMMIT_MESSAGE" ]; then
        commit_msg="$CI_COMMIT_MESSAGE"
    elif [ -n "$GITHUB_EVENT_HEAD_COMMIT_MESSAGE" ]; then
        commit_msg="$GITHUB_EVENT_HEAD_COMMIT_MESSAGE"
    # 从Git获取最新提交
    elif command -v git >/dev/null 2>&1; then
        commit_msg=$(git log -1 --pretty=%B 2>/dev/null || echo "")
    fi
    
    echo "$commit_msg"
}

# 解析部署策略
parse_deploy_strategy() {
    local commit_msg="$1"
    
    log "分析提交消息: $commit_msg"
    
    # 检查全量部署标签
    if echo "$commit_msg" | grep -q "\[FULL\]"; then
        echo "full"
        return
    fi
    
    # 检查增量部署标签
    if echo "$commit_msg" | grep -qE "\[BACKEND\]|\[DB\]|\[DB-MYSQL\]|\[DB-POSTGRES\]|\[REDIS\]|\[MINIO\]|\[MONITOR\]"; then
        echo "incremental"
        return
    fi
    
    # 默认策略：如果包含关键词，触发对应的增量部署
    if echo "$commit_msg" | grep -qi "数据库\|database\|sql\|migration"; then
        echo "incremental:database"
        return
    fi
    
    if echo "$commit_msg" | grep -qi "redis\|缓存\|cache"; then
        echo "incremental:redis"
        return
    fi
    
    if echo "$commit_msg" | grep -qi "minio\|存储\|storage\|文件"; then
        echo "incremental:minio"
        return
    fi
    
    if echo "$commit_msg" | grep -qi "监控\|monitor\|prometheus\|grafana"; then
        echo "incremental:monitoring"
        return
    fi
    
    # 默认后端增量部署
    echo "incremental:backend"
}

# 执行部署
execute_deployment() {
    local strategy="$1"
    local commit_msg="$2"
    
    case "$strategy" in
        full)
            log "执行全量部署..."
            "$CNB_DIR/deploy-full.sh" || error "全量部署失败"
            ;;
        incremental)
            log "执行增量部署（自动识别模块）..."
            "$CNB_DIR/deploy-incremental.sh" -c "$commit_msg" || error "增量部署失败"
            ;;
        incremental:*)
            local module="${strategy#incremental:}"
            log "执行增量部署（模块: $module）..."
            "$CNB_DIR/deploy-incremental.sh" -m "$module" || error "增量部署失败"
            ;;
        *)
            error "未知的部署策略: $strategy"
            ;;
    esac
}

# 发送通知
send_notification() {
    local status="$1"
    local strategy="$2"
    local commit_msg="$3"
    
    local notification_msg=""
    if [ "$status" = "success" ]; then
        notification_msg="✅ RuoYi-Vue-Plus 部署成功\n策略: $strategy\n提交: $commit_msg"
    else
        notification_msg="❌ RuoYi-Vue-Plus 部署失败\n策略: $strategy\n提交: $commit_msg\n日志: $LOG_FILE"
    fi
    
    # 这里可以集成各种通知方式
    # 例如：钉钉、企业微信、邮件等
    log "通知消息: $notification_msg"
    
    # 示例：写入通知文件
    echo "$notification_msg" > "$CNB_DIR/logs/latest-notification.txt"
}

# 主函数
main() {
    log "Git自动部署触发器启动..."
    
    # 获取提交消息
    local commit_msg=$(get_commit_message "$@")
    
    if [ -z "$commit_msg" ]; then
        error "无法获取Git提交消息"
    fi
    
    # 解析部署策略
    local strategy=$(parse_deploy_strategy "$commit_msg")
    log "部署策略: $strategy"
    
    # 执行部署
    if execute_deployment "$strategy" "$commit_msg"; then
        log "部署成功完成"
        send_notification "success" "$strategy" "$commit_msg"
    else
        log "部署失败"
        send_notification "failure" "$strategy" "$commit_msg"
        exit 1
    fi
}

# 执行主函数
main "$@"