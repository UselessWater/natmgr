完整的 Docker 测试方案（Ubuntu 24.04），复制以下命令即可开始：

## 1. 准备测试目录并启动容器

```bash
# 创建工作目录
mkdir -p ~/natmgr-test && cd ~/natmgr-test

# 下载最新代码（或复制本地代码）
git clone https://github.com/UselessWater/natmgr.git
cd natmgr

# 启动特权容器（Ubuntu 24.04）
docker run --rm -it \
  --name natmgr-test \
  --privileged \
  --cgroupns=host \
  -v "$(pwd):/natmgr" \
  -w /natmgr \
  ubuntu:24.04 bash
```

## 2. 容器内完整测试流程

进入容器后，按顺序执行以下命令：

### 初始化环境
```bash
# 配置国内镜像源（可选，加速下载）
sed -i 's/archive.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list
sed -i 's/security.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list

# 安装必要依赖
apt-get update && apt-get install -y \
  iptables \
  iproute2 \
  net-tools \
  curl \
  systemd \
  && rm -rf /var/lib/apt/lists/*

# 验证 iptables 版本（Ubuntu 24 默认使用 nftables 后端）
iptables --version
# 预期输出：iptables v1.8.9 (nf_tables)
```

### 测试安装
```bash
# 执行安装脚本
chmod +x install.sh
./install.sh

# 验证文件创建
ls -la /usr/local/bin/natmgr
ls -la /etc/nat-manager.conf
ls -la /var/log/nat-manager.log
```

### 功能测试
```bash
# 1. 查看空规则列表
echo "=== 测试空列表 ==="
natmgr list

# 2. 添加 TCP 转发规则
echo "=== 添加 TCP 8080->80 ==="
natmgr add tcp 8080 80

# 3. 添加 UDP 端口范围（Hysteria2 端口跳跃场景）
echo "=== 添加 UDP 20000-30000->12345 ==="
natmgr add udp 20000-30000 12345

# 4. 查看规则
echo "=== 查看规则列表 ==="
natmgr list

# 5. 验证 iptables 实际规则
echo "=== 验证 iptables PREROUTING 链 ==="
iptables -t nat -L PREROUTING -n --line-numbers

echo "=== 验证 iptables POSTROUTING 链 ==="
iptables -t nat -L POSTROUTING -n --line-numbers
```

### 配置持久化测试
```bash
# 保存配置
echo "=== 保存配置 ==="
natmgr save
echo "配置文件内容："
cat /etc/nat-manager.conf

# 清空所有规则
echo "=== 清空规则 ==="
natmgr del all --force
natmgr list

# 重新加载配置
echo "=== 重新加载配置 ==="
natmgr load
natmgr list
```

### 规则管理测试
```bash
# 添加多条规则用于删除测试
natmgr add tcp 1111 11
natmgr add tcp 2222 22
natmgr add tcp 3333 33
natmgr list

# 删除第 2 条规则
echo "=== 删除第 2 条规则 ==="
natmgr del 2
natmgr list

# 测试重复添加（应提示已存在或自动去重）
echo "=== 测试重复添加 ==="
natmgr add tcp 1111 11

# 测试无效输入（应报错但不崩溃）
echo "=== 测试无效输入 ==="
natmgr add invalid 8080 80 || echo "正确捕获错误"
natmgr add tcp 99999 80 || echo "正确捕获无效端口"
```

### IPv6 测试（如果脚本支持）
```bash
# 检查 ip6tables
ip6tables -t nat -L 2>/dev/null && {
  echo "=== 测试 IPv6 ==="
  natmgr -6 add tcp 8080 [::1]:80
  natmgr -6 list
  ip6tables -t nat -L PREROUTING -n
}
```

### 卸载测试
```bash
# 卸载
echo "=== 卸载 natmgr ==="
natmgr uninstall

# 验证清理
echo "检查残留文件："
ls /usr/local/bin/natmgr 2>/dev/null && echo "失败：主程序未删除" || echo "成功：主程序已删除"
ls /etc/nat-manager.conf 2>/dev/null && echo "失败：配置未删除" || echo "成功：配置已删除"
```

## 3. 退出并清理容器

```bash
# 退出容器（自动删除）
exit
```

## 4. 一键自动化测试脚本

将以下内容保存为 `test-in-docker.sh` 放在项目根目录：

```bash
#!/bin/bash
set -e

echo "🚀 启动 Ubuntu 24.04 Docker 测试环境..."

docker run --rm -i \
  --name natmgr-test \
  --privileged \
  --cgroupns=host \
  -v "$(pwd):/natmgr" \
  -w /natmgr \
  ubuntu:24.04 bash -s <<'EOF'
set -e

echo "📦 安装依赖..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq >/dev/null 2>&1
apt-get install -y -qq iptables iproute2 net-tools curl systemd >/dev/null 2>&1

echo "🔧 iptables 版本: $(iptables --version)"

echo "📥 安装 natmgr..."
chmod +x install.sh
./install.sh >/dev/null 2>&1

echo "✅ 测试 1: 添加规则"
natmgr add tcp 8080 80
natmgr add udp 20000-30000 12345

echo "✅ 测试 2: 查看规则"
natmgr list | grep -q "8080" && echo "  ✓ TCP规则存在"
natmgr list | grep -q "20000" && echo "  ✓ UDP范围规则存在"

echo "✅ 测试 3: 验证 iptables"
iptables -t nat -L PREROUTING -n | grep -q "8080" && echo "  ✓ iptables PREROUTING 正确"
iptables -t nat -L POSTROUTING -n | grep -q "MASQUERADE" && echo "  ✓ MASQUERADE 规则正确"

echo "✅ 测试 4: 配置持久化"
natmgr save
[ -f /etc/nat-manager.conf ] && echo "  ✓ 配置文件已保存"
natmgr del all --force
natmgr load
natmgr list | grep -q "8080" && echo "  ✓ 配置加载成功"

echo "✅ 测试 5: 删除规则"
natmgr add tcp 9999 99
natmgr del 1
! natmgr list | grep -q "9999" && echo "  ✓ 单条删除成功"

echo "✅ 测试 6: 卸载"
natmgr uninstall
[ ! -f /usr/local/bin/natmgr ] && echo "  ✓ 卸载成功"

echo "🎉 所有测试通过！"
EOF

echo "✨ 测试完成，容器已自动清理"
```

**使用方式：**
```bash
chmod +x test-in-docker.sh
./test-in-docker.sh
```

## ⚠️ 重要提醒

1. **Ubuntu 24.04 使用 nftables 后端**：`iptables` 命令实际上是 `iptables-nft` 的兼容层，您的脚本无需修改即可工作，但底层使用的是 nftables。

2. **网络隔离限制**：Docker 容器有独立的网络命名空间，您只能验证规则是否被正确写入 iptables，**无法从外部访问测试转发的端口**。

3. **如需测试真实转发效果**，请在 VMware 虚拟机或临时云服务器上进行，参考之前的方案。

4. **测试完成后**，容器会自动删除（`--rm` 参数），不会污染宿主机。

现在可以直接复制执行了！需要我解释某个具体步骤吗？