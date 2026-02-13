#!/bin/bash

set -e

# Color definitions
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Constants
CONFIG_FILE="/etc/nat-manager.conf"
LOG_FILE="/var/log/nat-manager.log"

# Check root privileges
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}错误：需要使用 root 权限运行${NC}"
    echo -e "请使用: ${BLUE}sudo ./install.sh${NC}"
    exit 1
fi

echo -e "${BLUE}=== NAT Manager 安装程序 ===${NC}\n"

# Detect package manager and install iptables
detect_and_install_iptables() {
    echo -e "${BLUE}正在检查依赖...${NC}"

    if command -v iptables &> /dev/null; then
        echo -e "${GREEN}✓ iptables 已安装${NC}"
        return 0
    fi

    echo -e "${YELLOW}未检测到 iptables，正在安装...${NC}"

    # Detect package manager
    if command -v apt-get &> /dev/null; then
        # Debian/Ubuntu
        apt-get update -qq
        apt-get install -y -qq iptables
    elif command -v yum &> /dev/null; then
        # RHEL/CentOS 7
        yum install -y iptables iptables-services
    elif command -v dnf &> /dev/null; then
        # RHEL/CentOS 8+, Fedora
        dnf install -y iptables iptables-services
    elif command -v pacman &> /dev/null; then
        # Arch Linux
        pacman -Sy --noconfirm iptables
    elif command -v apk &> /dev/null; then
        # Alpine Linux
        apk add --no-cache iptables
    elif command -v zypper &> /dev/null; then
        # openSUSE
        zypper install -y iptables
    else
        echo -e "${RED}错误：无法检测到支持的包管理器${NC}"
        echo -e "${YELLOW}请手动安装 iptables 后重试${NC}"
        exit 1
    fi

    echo -e "${GREEN}✓ iptables 安装完成${NC}"
}

# Check and fix config file permissions (cross-platform compatible)
check_config_permissions() {
    local file="$1"

    if [ -f "$file" ]; then
        local perms
        # Try GNU stat first (Linux), then BSD stat (macOS)
        perms=$(stat -c "%a" "$file" 2>/dev/null) || perms=$(stat -f "%Lp" "$file" 2>/dev/null)

        if [ -n "$perms" ] && [ "$perms" != "600" ]; then
            echo -e "${YELLOW}警告：配置文件 $file 权限为 $perms，建议设置为 600${NC}"
            chmod 600 "$file"
            echo -e "${GREEN}✓ 已修复配置文件权限${NC}"
        fi
    fi
}

# Install main program
install_main_program() {
    echo -e "\n${BLUE}正在安装主程序...${NC}"
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ ! -f "$SCRIPT_DIR/natmgr" ]; then
        echo -e "${RED}错误：未找到 natmgr 文件${NC}"
        exit 1
    fi

    cp "$SCRIPT_DIR/natmgr" /usr/local/bin/natmgr
    chmod 755 /usr/local/bin/natmgr
    echo -e "${GREEN}✓ 主程序已安装到 /usr/local/bin/natmgr${NC}"
}

# Create config file with proper permissions
create_config_file() {
    echo -e "\n${BLUE}正在创建配置文件...${NC}"

    # Check if file exists and fix permissions if needed
    check_config_permissions "$CONFIG_FILE"

    if [ ! -f "$CONFIG_FILE" ]; then
        touch "$CONFIG_FILE"
        chmod 600 "$CONFIG_FILE"
        echo -e "${GREEN}✓ 配置文件已创建: $CONFIG_FILE${NC}"
    else
        echo -e "${YELLOW}配置文件已存在: $CONFIG_FILE${NC}"
        chmod 600 "$CONFIG_FILE"
        echo -e "${GREEN}✓ 已确保配置文件权限正确${NC}"
    fi

    # IPv6 config file (optional, created when needed)
    # No need to create it now, will be created when saving rules with IPv6
}

# Create log file with proper permissions
create_log_file() {
    echo -e "\n${BLUE}正在创建日志文件...${NC}"

    if [ ! -f "$LOG_FILE" ]; then
        touch "$LOG_FILE"
        chmod 644 "$LOG_FILE"
        echo -e "${GREEN}✓ 日志文件已创建: $LOG_FILE${NC}"
    else
        echo -e "${YELLOW}日志文件已存在: $LOG_FILE${NC}"
        chmod 644 "$LOG_FILE"
        echo -e "${GREEN}✓ 已确保日志文件权限正确${NC}"
    fi
}

# Create systemd service
create_systemd_service() {
    echo -e "\n${BLUE}是否创建 systemd 开机自动恢复服务?${NC}"
    read -rp "请输入 [y/N]: " create_service

    if [[ "$create_service" =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}正在创建 systemd 服务...${NC}"

        cat > /etc/systemd/system/nat-restore.service << 'EOF'
[Unit]
Description=NAT Manager - Restore NAT Rules
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/natmgr load
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

        if ! systemctl daemon-reload 2>/dev/null; then
            echo -e "${YELLOW}警告：systemctl daemon-reload 失败${NC}"
        fi
        if ! systemctl enable nat-restore.service 2>/dev/null; then
            echo -e "${YELLOW}警告：启用 nat-restore.service 失败${NC}"
        fi

        # Wait a moment for systemd to process
        sleep 1

        echo -e "${GREEN}✓ systemd 服务已创建并启用${NC}"
        echo -e "  服务名: nat-restore.service"

        # Check service status with retry
        local status
        status=$(systemctl is-enabled nat-restore.service 2>/dev/null || echo 'unknown')
        if [ "$status" = "unknown" ]; then
            # Try again after a short delay
            sleep 1
            status=$(systemctl is-enabled nat-restore.service 2>/dev/null || echo 'unknown')
        fi
        echo -e "  状态: $status"
    else
        echo -e "${YELLOW}已跳过 systemd 服务创建${NC}"
    fi
}

# Main installation process
main() {
    detect_and_install_iptables
    install_main_program
    create_config_file
    create_log_file
    create_systemd_service

    # Installation complete
    echo ""
    echo -e "${GREEN}=================================${NC}"
    echo -e "${GREEN}    NAT Manager 安装成功！       ${NC}"
    echo -e "${GREEN}=================================${NC}"
    echo ""
    echo -e "使用方法:"
    echo -e "  ${BLUE}natmgr${NC}           启动交互式菜单"
    echo -e "  ${BLUE}natmgr help${NC}      查看帮助信息"
    echo ""
    echo -e "文件位置:"
    echo -e "  主程序:  ${BLUE}/usr/local/bin/natmgr${NC}"
    echo -e "  配置:    ${BLUE}$CONFIG_FILE${NC}"
    echo -e "  日志:    ${BLUE}$LOG_FILE${NC}"
    echo ""
    echo -e "快速开始:"
    echo -e "  ${BLUE}natmgr add tcp 8080 192.168.1.10:80${NC}  # 添加转发规则"
    echo -e "  ${BLUE}natmgr list${NC}                           # 查看规则"
    echo -e "  ${BLUE}natmgr save${NC}                           # 保存配置"
    echo ""
}

main "$@"
