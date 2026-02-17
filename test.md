# NAT Manager 测试文档

完整的 Docker 测试方案（Ubuntu 24.04），复制以下命令即可开始。

---

## 快速开始

### 1. 准备测试目录并启动容器

```bash
# 进入项目目录（假设你在 natmgr 仓库根目录）
cd /path/to/natmgr

# 启动特权容器（Ubuntu 24.04）
docker run --rm -it \
  --name natmgr-test \
  --privileged \
  --cgroupns=host \
  -v "$(pwd):/natmgr" \
  -w /natmgr \
  ubuntu:24.04 bash
```

### 2. 在容器内安装依赖

```bash
apt-get update && apt-get install -y iptables iputils-ping netcat-openbsd conntrack
```

### 3. 开始测试

```bash
# 查看当前规则
./natmgr list

# 添加测试规则
./natmgr add tcp 8080 80

# 查看帮助
./natmgr help
```

---

## 项目概述

NAT Manager (natmgr) 是一个基于 Bash 编写的 Linux NAT 端口转发管理工具。它提供了 iptables 的简化封装，支持交互式菜单和命令行两种操作界面。

### 核心文件

- **natmgr** (约 1900+ 行): 单文件架构，包含所有业务逻辑：
  - iptables 规则管理（添加/删除/查看）
  - 配置持久化（保存/加载）
  - 交互式 TUI 菜单和命令行解析
  - 输入验证和净化
  - IPv4/IPv6 双栈支持
  - 转发日志跟踪（conntrack 集成）

- **install.sh**: 安装脚本，自动检测包管理器、安装 iptables，并创建 systemd 服务用于开机时恢复规则。

### 代码组织

主脚本按功能划分为以下区域：

```
第 1-33 行   : 常量和全局变量（CONFIG_FILE、IPT_CMD 等）
第 35-127 行 : 基础设施（锁、权限检查、依赖、日志）
第 135-381 行: 输入验证（协议、端口范围、IPv4/IPv6、目标地址）
第 384-589 行: 核心规则操作和规则管理（apply_rule、list_rules、add_rule、del_rule）
第 591-728 行: 交互式功能（add_rule、del_rule）
第 789-1005 行: 配置持久化（backup_config、save_rules、load_rules）
第 1006-1015 行: 日志查看（view_log）
第 1016-1235 行: conntrack 工具管理（check_conntrack、install_conntrack、uninstall_conntrack）
第 1236-1548 行: 转发日志跟踪（parse_conntrack_line、display_conntrack_result、query_trace_*、view_trace_menu）
第 1549-1653 行: 卸载功能（uninstall_natmgr）
第 1654-1700 行: 命令行快速操作（quick_add）
第 1701-1787 行: 主菜单和帮助
第 1788-1900+ 行: 入口点（check_root、解析选项、命令分发）
```

### 关键设计模式

**双栈 IP 支持**: 使用 `USE_IPV6` 标志和 `IPT_CMD`/`IP6T_CMD` 变量在 iptables 和 ip6tables 之间切换。IPv6 目标地址使用方括号表示法 `[addr]:port`。

**锁机制**: 使用 `mkdir` 在 `/var/run/natmgr.lock` 实现原子锁获取，防止并发操作。

**临时文件处理**: 使用 `mktemp` 实现原子配置写入。通过 `trap release_lock EXIT INT TERM HUP` 处理清理。

**入口点流程**:

1. 执行 `check_root` 和 `check_dependencies`
2. 设置信号陷阱，然后获取锁
3. 解析全局选项（`-4`、`-6`）
4. 通过 `case "$1" in ... esac` 分发命令（第 1815-1900+ 行）
5. 如果标准输入是终端则进入交互式菜单，否则显示帮助

**验证层级**:

- 协议: 仅支持 tcp/udp/both
- 端口: 1-65535，支持范围（如 20000-30000）
- IPv4: 4 个八位组，不允许前导零
- IPv6: 支持压缩形式（::）和完整形式，端口使用方括号表示法

### 运行时文件

| 文件                       | 用途                               |
| -------------------------- | ---------------------------------- |
| `/etc/nat-manager.conf`    | IPv4 规则（iptables-restore 格式） |
| `/etc/nat-manager.conf.v6` | IPv6 规则（可选）                  |
| `/var/log/nat-manager.log` | 操作审计日志（10MB 自动轮转）      |
| `/etc/nat-manager.conf.d/` | 备份目录（最多保留 5 个备份）      |
| `/var/run/natmgr.lock/`    | 运行时锁目录                       |

---

## 常用命令

### 测试更改

```bash
# 使用 root 权限运行（iptables 需要）
sudo ./natmgr

# 测试特定命令
sudo ./natmgr list
sudo ./natmgr add tcp 8080 80
sudo ./natmgr del 1
sudo ./natmgr save

# IPv6 模式
sudo ./natmgr -6 list
sudo ./natmgr -6 add tcp 8080 [::1]:80
```

### 语法和静态分析

```bash
# 检查 bash 语法
bash -n natmgr
bash -n install.sh

# 使用 shellcheck 进行静态分析（如果已安装）
shellcheck natmgr
shellcheck install.sh

# 使用跟踪模式调试
sudo bash -x ./natmgr list
```

### 测试单个函数

```bash
# 导入脚本（跳过主执行）后测试函数
# 注意：这需要修改脚本或使用测试包装器

# 替代方案：提取并独立测试函数
validate_port_range() {
    local port_range="$1"
    local min_port=1
    local max_port=65535
    if echo "$port_range" | grep -qE '^[0-9]+$'; then
        if [ "$port_range" -ge "$min_port" ] && [ "$port_range" -le "$max_port" ]; then
            return 0
        fi
    fi
    return 1
}

# 测试
validate_port_range "8080" && echo "有效" || echo "无效"
validate_port_range "99999" && echo "有效" || echo "无效"
```

### 调试技巧

```bash
# 查看操作日志
sudo tail -f /var/log/nat-manager.log

# 检查原始 iptables 规则
sudo iptables -t nat -L PREROUTING -n --line-numbers
sudo ip6tables -t nat -L PREROUTING -n --line-numbers

# 不使用 natmgr 测试 iptables 语法
sudo iptables -t nat -C PREROUTING -p tcp --dport 8080 -j DNAT --to-destination :80 2>&1

# 检查锁是否被持有
ls -la /var/run/natmgr.lock/ 2>/dev/null && echo "已锁定" || echo "未锁定"

# 手动释放锁（如需）
sudo rm -rf /var/run/natmgr.lock/
```

---

## Docker 测试环境

### ⚠️ 重要安全提示

**所有开发和测试工作必须在 Docker 容器中进行，禁止直接在生产或主机环境操作 iptables！**

使用特权容器测试（推荐用于开发验证，避免影响主机 iptables）：

### 标准容器启动（无 systemd 支持）

适用于测试 natmgr 核心功能（添加/删除/查看规则、保存/加载配置）：

```bash
# 启动特权容器（Ubuntu 24.04）
docker run --rm -it \
  --name natmgr-test \
  --privileged \
  --cgroupns=host \
  -v "$(pwd):/natmgr" \
  -w /natmgr \
  ubuntu:24.04 bash

# 进入容器后安装依赖
apt-get update && apt-get install -y iptables iputils-ping netcat-openbsd conntrack

# 然后运行测试命令
./natmgr list
./natmgr add tcp 8080 80
```

### 带 systemd 支持的容器启动（可选）

如需测试 systemd 服务相关功能，使用以下方式启动容器：

```bash
# 启动支持 systemd 的容器（需要更多特权）
docker run --rm -it \
  --name natmgr-test \
  --privileged \
  --cgroupns=host \
  --tmpfs /tmp \
  --tmpfs /run \
  --tmpfs /run/lock \
  -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
  -v "$(pwd):/natmgr" \
  -w /natmgr \
  jrei/systemd-ubuntu:24.04 bash

# 注意：某些环境可能需要改为：
# --cgroupns=host 改为 --cgroup parent=docker.slice
```

**注意**：即使使用 systemd 容器，`systemctl status` 等命令也可能需要手动启动服务后才能正常工作。

---

## 开发后测试流程

**⚠️ 警告：以下所有测试步骤必须在 Docker 容器中执行，禁止在主机环境直接操作 iptables！**

启动测试容器：

```bash
docker run --rm -it \
  --name natmgr-test \
  --privileged \
  --cgroupns=host \
  -v "$(pwd):/natmgr" \
  -w /natmgr \
  ubuntu:24.04 bash

# 在容器内安装依赖
apt-get update && apt-get install -y iptables iputils-ping netcat-openbsd conntrack
```

功能开发完成后，按以下流程进行手动测试验证：

### 1. 基础功能测试

- 运行 `./natmgr` 确认交互式菜单正常显示
- 选择菜单项 1（查看规则），确认无错误输出
- 检查彩色输出是否正常显示

### 2. 添加规则测试

- 执行 `./natmgr add tcp 8080 80`，确认规则添加成功
- 执行 `./natmgr add udp 10000-10010 443`，确认端口范围添加成功
- 执行 `./natmgr add both 8443 443`，确认 TCP+UDP 同时添加
- 每次添加后执行 `./natmgr list` 验证规则显示正确
- 检查 `iptables -t nat -L PREROUTING -n` 确认规则实际写入

### 3. 删除规则测试

- 执行 `./natmgr del 1`，确认可删除指定序号规则
- 执行 `./natmgr del all`，确认提示确认后清空所有规则
- 验证删除后 `./natmgr list` 显示为空

### 4. 配置持久化测试

- 添加若干测试规则后执行 `./natmgr save`
- 验证 `/etc/nat-manager.conf` 文件生成且权限为 600
- 执行 `iptables -t nat -F PREROUTING` 清空规则
- 执行 `./natmgr load` 恢复规则
- 验证 `./natmgr list` 显示与保存前一致

### 5. IPv6 测试（如修改了 IPv6 相关代码）

- 执行 `./natmgr -6 add tcp 8080 [::1]:80`
- 执行 `./natmgr -6 list` 确认 IPv6 规则显示正常
- 执行 `./natmgr -6 save` 确认 IPv6 配置文件生成

### 6. 输入验证测试

- 测试无效端口：`./natmgr add tcp 99999 80`（应报错）
- 测试无效协议：`./natmgr add xxx 8080 80`（应报错）
- 测试无效 IP：`./natmgr add tcp 8080 999.999.999.999:80`（应报错）
- 测试重复规则：重复添加相同规则，确认去重提示

### 7. 日志和审计测试

- 执行若干操作后检查 `/var/log/nat-manager.log`
- 确认每条操作都有时间戳记录

### 8. 转发日志跟踪测试

**注意**：conntrack 需要内核支持，在某些 Docker 环境（如 Docker Desktop）中可能无法正常工作。

```bash
# 安装 conntrack（如未安装）
apt-get install -y conntrack

# 添加测试规则
./natmgr add udp 20000-20005 :12345

# 模拟 UDP 流量（在后台启动监听）
nc -u -l -p 12345 &

# 发送测试数据到转发端口
echo "test" | nc -u -w1 127.0.0.1 20003
sleep 1

# 测试 trace 命令行入口
./natmgr trace

# 在交互菜单中测试：
# 1. 运行 ./natmgr
# 2. 选择 8) 查看转发日志跟踪
# 3. 选择 1) 查看进入(IN)的流量
# 4. 输入目标端口 12345
# 5. 选择协议 UDP
# 6. 验证显示包含 127.0.0.1 的连接信息

# 测试 conntrack 管理菜单：
# 1. 选择 4) 重新安装/管理 conntrack
# 2. 验证显示当前版本
# 3. 测试卸载功能（选择 2）
# 4. 确认卸载后状态变为"未安装"
# 5. 重新安装 conntrack（选择 1）
```

**conntrack 测试排错**：

- 如果 `conntrack -L` 返回空，检查内核模块是否加载：`lsmod | grep conntrack`
- 某些容器环境可能需要手动加载模块：`modprobe nf_conntrack`
- Docker Desktop 由于 VM 架构限制，conntrack 可能完全无法工作

### 9. 安装脚本测试

**注意**：标准容器内无法运行 systemd，以下测试仅验证安装脚本是否正确创建文件。

```bash
# 在容器中测试安装（仅验证文件创建）
./install.sh

# 检查文件是否正确创建
ls -la /usr/local/bin/natmgr
ls -la /etc/nat-manager.conf
ls -la /var/log/nat-manager.log
ls -la /etc/systemd/system/nat-restore.service 2>/dev/null && echo "服务文件已创建" || echo "服务文件未创建（容器内预期行为）"

# 验证 natmgr 可执行
natmgr list
natmgr add tcp 9090 90
natmgr save

# 注意：以下命令在标准容器内会失败，这是预期行为
# systemctl status nat-restore.service
# systemctl is-enabled nat-restore.service
```

**如需完整测试 systemd 服务**，请使用上述"带 systemd 支持的容器启动"方式，或在物理机/VM 上测试。

### 10. 边界情况测试

- 空规则时执行 `./natmgr save`（应提示无规则）
- 无配置文件时执行 `./natmgr load`（应报错）
- 并发测试：尝试同时运行两个 natmgr 实例（第二个应等待或提示）

---

## 代码风格

- **函数**: 使用 snake_case 命名（如 `validate_port_range`、`apply_rule`）
- **常量**: 文件顶部使用 UPPER_CASE
- **颜色**: 定义为 `RED`、`GREEN`、`YELLOW`、`BLUE`、`CYAN`、`NC`（无颜色）
- **错误处理**: 函数返回 0/1，使用 `if ! func; then` 检查
- **日志**: 使用 `log_msg "描述"` 记录审计日志

---

## 安全注意事项

- 所有用户输入通过 `sanitize_input()` 净化（移除控制字符，限制 256 字节）
- 配置文件创建权限为 0600
- 日志文件 10MB 自动轮转
- 防止命令注入：不在 `eval` 或未加引号的子 shell 中使用用户输入
- 锁机制防止竞态条件

---

## 添加功能

修改时：

1. **验证函数**: 添加到验证区域（第 135-381 行）
2. **命令行命令**: 在主 switch 语句中添加 case（第 1815-1900+ 行）
3. **菜单项**: 更新 `show_menu()`（第 1701 行）并在 case 语句中添加处理器
4. **IPv6 支持**: 确保 `IPT_CMD` 和 `IP6T_CMD` 路径都正常工作；使用方括号表示法 `[addr]:port`
5. **转发日志跟踪**: 使用 `conntrack -L` 查询连接追踪表，解析输出显示连接映射
6. **日志**: 对改变状态的操作始终调用 `log_msg`
7. **清理**: 在 `cleanup_temp_files()` 中注册新的临时文件，并确保陷阱处理器释放资源

---

## 参考

- README.md: 功能概述和快速开始
- USAGE-v1.0.0.md: 详细的 v1.0.0 文档
- USAGE-v2.0.0.md: v2.0.0 功能详情，包括 IPv6 支持和转发日志跟踪

---

## 转发日志跟踪实现说明

转发日志跟踪功能基于 Linux 内核的 conntrack（连接追踪）子系统：

### 核心命令

```bash
# 查看转发到目标端口的连接
conntrack -L -p udp --reply-port-src 12345

# 输出格式：
# udp  17 src=CLIENT_IP dst=SERVER_IP sport=CLIENT_PORT dport=HOP_PORT [UNREPLIED] src=SERVER_IP dst=CLIENT_IP sport=12345 dport=CLIENT_PORT
```

### 关键函数

| 函数 | 功能 | 位置 |
|------|------|------|
| `check_conntrack()` | 检测 conntrack 是否已安装 | 第 1016-1021 行 |
| `get_conntrack_status()` | 返回状态文本（用于菜单显示） | 第 1023-1030 行 |
| `get_pkg_manager()` | 检测系统包管理器 | 第 1032-1048 行 |
| `get_conntrack_pkg_name()` | 获取 conntrack 包名 | 第 1049-1070 行 |
| `install_conntrack()` | 安装/重新安装 conntrack | 第 1130-1233 行 |
| `uninstall_conntrack()` | 卸载 conntrack | 第 1071-1129 行 |
| `parse_conntrack_line()` | 解析 conntrack 输出行 | 第 1235-1282 行 |
| `display_conntrack_result()` | 格式化显示查询结果 | 第 1283-1378 行 |
| `query_trace_in/out/both()` | 查询不同方向的流量 | 第 1379-1422 行 |
| `view_trace_menu()` | 转发日志跟踪子菜单 | 第 1424-1546 行 |

### 方向说明

- **IN (进入)**: 使用 `--reply-port-src` 查询，显示外部客户端连接到本机服务端口的映射
- **OUT (发出)**: 使用 `--orig-port-src` 查询，显示本机服务端口向外部发起的连接
- **Both (双向)**: 等同于 IN 方向的查询

### 注意事项

- conntrack 需要 root 权限访问 `/proc/net/nf_conntrack`
- UDP 连接在收到回复前标记为 `[UNREPLIED]`
- 连接记录有过期时间，由系统 conntrack 超时参数控制
