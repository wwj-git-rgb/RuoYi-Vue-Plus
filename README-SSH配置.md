# SSH免密登录配置指南

## 问题描述
部署脚本需要多次SSH连接服务器，每次都要输入密码很麻烦。

## 解决方案

### 方案1：安装sshpass（推荐，最简单）

在macOS上安装sshpass：
```bash
# 使用Homebrew安装
brew install sshpass
```

安装完成后，直接运行部署脚本即可：
```bash
./deploy.sh
```

### 方案2：配置SSH密钥认证（推荐，最安全）

#### 自动配置（推荐）
```bash
# 运行自动配置脚本
./setup-ssh.sh
```

#### 手动配置
1. 生成SSH密钥对：
```bash
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
```

2. 复制公钥到服务器：
```bash
ssh-copy-id root@1.15.3.137
```

3. 测试免密登录：
```bash
ssh root@1.15.3.137
```

## 验证配置

配置完成后，运行以下命令测试：
```bash
# 测试SSH连接
ssh root@1.15.3.137 "echo 'SSH连接成功'"

# 运行部署脚本
./deploy.sh
```

## 部署脚本功能

配置好免密登录后，部署脚本支持以下功能：

```bash
./deploy.sh          # 完整部署流程
./deploy.sh build    # 构建并上传
./deploy.sh deploy   # 部署服务
./deploy.sh check    # 检查状态
./deploy.sh logs     # 查看日志
./deploy.sh cleanup  # 清理资源
```

## 服务访问地址

部署完成后可访问：
- RuoYi应用: http://1.15.3.137:8080
- PostgreSQL: 1.15.3.137:5432
- Redis: 1.15.3.137:6379
- MinIO: http://1.15.3.137:9001