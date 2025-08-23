#!/bin/bash

# SSH免密登录配置脚本
SERVER_HOST="1.15.3.137"
SERVER_USER="root"

echo "=========================================="
echo "SSH免密登录配置脚本"
echo "=========================================="

# 方案1：安装sshpass
echo "[方案1] 安装sshpass (推荐)"
echo "在macOS上安装sshpass:"
echo "brew install sshpass"
echo ""

# 方案2：配置SSH密钥
echo "[方案2] 配置SSH密钥认证"
echo "1. 生成SSH密钥对:"
echo "   ssh-keygen -t rsa -b 4096 -C \"your_email@example.com\""
echo ""
echo "2. 复制公钥到服务器:"
echo "   ssh-copy-id ${SERVER_USER}@${SERVER_HOST}"
echo ""
echo "3. 测试免密登录:"
echo "   ssh ${SERVER_USER}@${SERVER_HOST}"
echo ""

# 自动配置SSH密钥
read -p "是否要自动配置SSH密钥认证? (y/n): " choice
if [[ $choice == "y" || $choice == "Y" ]]; then
    echo "开始配置SSH密钥..."
    
    # 检查是否已有SSH密钥
    if [ ! -f ~/.ssh/id_rsa ]; then
        echo "生成SSH密钥..."
        ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
    else
        echo "SSH密钥已存在，跳过生成步骤"
    fi
    
    # 复制公钥到服务器
    echo "复制公钥到服务器 (需要输入一次密码)..."
    ssh-copy-id ${SERVER_USER}@${SERVER_HOST}
    
    if [ $? -eq 0 ]; then
        echo "SSH密钥配置成功！"
        echo "现在可以免密登录服务器了"
        
        # 测试免密登录
        echo "测试免密登录..."
        ssh ${SERVER_USER}@${SERVER_HOST} "echo 'SSH免密登录测试成功'"
    else
        echo "SSH密钥配置失败"
    fi
fi

echo ""
echo "=========================================="
echo "配置完成后，重新运行 ./deploy.sh 即可免密部署"
echo "=========================================="