# 更新日志

所有 notable 变化都会记录在此文件。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/)，
版本号遵循 [Semantic Versioning](https://semver.org/lang/zh-CN/)。

## [Unreleased]

### 新增

- 转发日志跟踪功能（`natmgr trace`）
- conntrack 工具自动检测和安装管理
- 实时查看 NAT 连接追踪（IN/OUT/双向）
- 支持按目标端口查询连接映射关系

## [2.0.0] - 2026-02-16

### 新增

- 完整 IPv6 双栈支持（`-6` 参数）
- IPv6 配置文件独立存储（`/etc/nat-manager.conf.v6`）
- IPv6 方括号表示法支持（`[::1]:80`）
- 卸载功能（`natmgr uninstall` 或菜单选项 7）
- 配置自动备份（保留最近 5 个版本）
- 端口占用检查（添加前检测本机端口占用）
- 规则去重（添加前检查是否已存在）

### 修复

- **修复规则恢复功能**：`load_rules` 根据用户选择动态使用 `-n` 参数
- **修复配置文件格式**：`save_rules` 移除多余的 `sed` 处理，避免 `-A PREROUTING PREROUTING` 重复

### 改进

- 增强输入验证和净化（`sanitize_input`）
- 改进错误处理和用户提示
- 优化日志记录（10MB 自动轮转）
- 增强并发安全（锁机制）

### 文档

- 添加 CLAUDE.md 开发者文档
- 添加 Docker 测试环境说明
- 更新所有使用文档

## [1.0.0] - 2024-01-15

### 初始版本

- 交互式 TUI 菜单
- 命令行快速操作
- iptables NAT 规则管理（添加/删除/查看）
- 配置持久化（保存/加载）
- 操作审计日志
- 批量端口范围支持
- systemd 开机自动恢复
- 彩色终端输出

[Unreleased]: https://github.com/UselessWater/natmgr/compare/v2.0.0...HEAD
[2.0.0]: https://github.com/UselessWater/natmgr/compare/v1.0.0...v2.0.0
[1.0.0]: https://github.com/UselessWater/natmgr/releases/tag/v1.0.0
