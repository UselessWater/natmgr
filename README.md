# NAT Manager

Linux NAT 端口转发管理工具 - 基于 iptables 的简化封装，支持交互式菜单和命令行操作。

## 功能特性

- ✅ **可视化交互菜单** - 清晰的 TUI 界面，无需记忆复杂命令
- ✅ **动态规则管理** - 实时添加、删除、查看 NAT 转发规则
- ✅ **配置持久化** - 支持保存/恢复配置，重启后自动加载
- ✅ **操作审计日志** - 完整的操作记录，便于排查问题
- ✅ **批量端口支持** - 支持端口范围转发（如 20000-30000）
- ✅ **开机自动恢复** - 可选 systemd 服务，开机自动应用规则
- ✅ **命令行快速操作** - 支持非交互式脚本调用
- ✅ **彩色输出** - 友好的终端显示效果
- ✅ **IPv6 支持** - 通过 `-6` 参数支持 IPv6 规则管理
- ✅ **配置备份** - 自动保留最近 5 个配置备份
- ✅ **规则去重** - 添加前检查是否已存在相同规则
- ✅ **端口占用检查** - 添加前检查端口是否被本机服务占用

## 安装说明

### 方式一：Git 克隆后安装（推荐）

```bash
git clone https://github.com/UselessWater/natmgr.git
cd natmgr
sudo ./install.sh
```

### 方式二：直接下载单文件

```bash
wget https://raw.githubusercontent.com/UselessWater/natmgr/main/natmgr
chmod +x natmgr
sudo mv natmgr /usr/local/bin/
sudo touch /etc/nat-manager.conf /var/log/nat-manager.log
sudo chmod 600 /etc/nat-manager.conf
```

### 支持的系统

- Debian/Ubuntu (apt-get)
- RHEL/CentOS 7 (yum)
- RHEL/CentOS 8+, Fedora (dnf)
- Arch Linux (pacman)
- Alpine Linux (apk)
- openSUSE (zypper)

## 快速开始

```bash
# 启动交互式菜单
sudo natmgr

# 添加一条转发规则（TCP 8080 转发到本机 80）
sudo natmgr add tcp 8080 80

# 保存配置（重启后自动恢复）
sudo natmgr save
```

## 使用文档

### 命令行选项

```
natmgr [选项] [命令] [参数]

选项:
    -4                      使用 IPv4 (默认)
    -6                      使用 IPv6
```

### 常用命令

| 命令 | 说明 |
|------|------|
| `natmgr` | 启动交互式菜单 |
| `natmgr add <协议> <源端口> <目标>` | 快速添加规则 |
| `natmgr del <序号> [序号...]` | 删除指定规则（支持多个） |
| `natmgr del all` | 删除所有规则（需确认） |
| `natmgr list` | 查看当前规则 |
| `natmgr save` | 保存规则到配置文件 |
| `natmgr load` | 从配置文件恢复规则 |
| `natmgr log` | 查看操作日志 |
| `natmgr uninstall` | 卸载 NAT Manager |

### 示例

```bash
# UDP 端口范围转发到本机
natmgr add udp 20000-30000 12345

# TCP 转发到内网服务器
natmgr add tcp 8080 192.168.1.50:80

# TCP+UDP 同时转发到本机
natmgr add both 443 8443

# 删除第 1 条规则
natmgr del 1

# 删除所有规则（需确认）
natmgr del all

# 强制删除所有规则（无需确认）
natmgr del all --force

# IPv6 规则管理
natmgr -6 add tcp 8080 [::1]:80
```

## 文件结构

```
nat-manager/
├── natmgr          # 主程序脚本
├── install.sh      # 安装脚本
├── README.md       # 项目说明
├── USAGE.md        # 详细使用文档
└── .gitignore      # Git 忽略配置
```

## 安全说明

- 配置文件 `/etc/nat-manager.conf` 权限设置为 600（仅 root 可读写）
- 所有用户输入都经过严格验证（协议、端口、IP 格式）
- 删除所有规则需要确认，支持 `-f/--force` 强制模式
- 自动备份配置，保留最近 5 个版本

## 支持与反馈

- **问题报告**：如遇到问题，请在 GitHub Issues 提交反馈
- **功能建议**：欢迎提交 Pull Request 或 Issue
- **更多文档**：详细功能请参考 [USAGE.md](./USAGE.md)

## 许可证

MIT License
