# Changelog

## v0.3.0

### Added

- 新增 `Probe uitok dev source` 手动工作流。
- 自动检出 `uitok/palworld-panel` 的 `dev` 分支和递归子模块。
- 自动记录完整 commit、父提交、提交时间和工作区状态。
- 自动扫描 Go、前端、路由、API、嵌入资源和构建入口。
- 自动尝试 `go list`、Go 测试和可能的 Makefile 构建目标。
- 自动生成确定性源码快照及 SHA-256。
- 使用 `actions/upload-artifact@v7` 上传源码快照和分析报告。
- 新增 `dev` 源码基线说明，兼容目标保持为 v1.2.2。

### Changed

- 不再把 v1.2.1 当作长期源码代理。
- 后续补丁以 `dev` 的精确 commit 为源码基线。
- 只有取得真实源码结构后才生成 `0001-add-patch-info-api.patch`。

## v0.2.4

- 修复 README、VERSION 和 CHANGELOG 的版本同步。

## v0.2.3

- Actions 迁移到 Node.js 24。
