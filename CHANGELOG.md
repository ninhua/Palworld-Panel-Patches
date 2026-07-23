# Changelog

## v0.5.1

### Fixed

- 修复 `base_custom_names_test.go` 调用不存在的 `newQueryContext`，导致 `palpanel/internal/api` 测试无法编译。
- 改为使用上游实际 Gin 测试方式：`gin.CreateTestContext`、`httptest.NewRecorder` 和 GET 请求查询参数。
- 更新 `0002-add-base-custom-names.patch` 及 `source/SHA256SUMS`。

### Validation

- `git diff --check` 通过。
- 两个补丁可按顺序应用到锁定上游源码。
- 仓库结构、YAML、Shell 和补丁 SHA 校验通过。
- 完整 Go 1.25.12 测试仍由 GitHub Actions 执行。

## v0.5.0

### Added

- 新增独立实现的 `base-custom-names` 功能。
- 新增 `PUT /api/bases/{id}/name` 与 `DELETE /api/bases/{id}/name`。
- 自定义名称持久化到 PalPanel SQLite KV，并按活动存档源隔离。
- 基地列表、详情和搜索支持自定义名称，同时保留原始名称字段。
- 基地前端页面增加编辑名称与恢复原名操作。
- 新增后端持久化、隔离、校验和权限测试，以及前端 API 测试。
- 补丁版本升级为 `0.2.0-dev.1`，功能列表增加 `base-custom-names`。
- 构建脚本支持按顺序应用多个补丁并验证补丁 SHA-256。

### Changed

- 新预发布标签为 `uitok-dev-v1.2.2-p0.2.0-dev.1`。
- Release 工作流不再覆盖已存在的同名标签。
- 脚本集成代码不属于本次功能补丁交付范围。

### Limitations

- 仍基于固定 dev commit，兼容状态保持 `source-alias`、`verified=false`。
- 本地环境缺少 Go 1.25.12 和完整依赖缓存，完整编译测试需由 GitHub Actions 执行。

## v0.4.2

### Added

- 新增 `Release uitok dev patch` 手动发布工作流。
- 构建通过后自动创建或更新固定 GitHub 预发布。
- Release 同时发布二进制包、完整对应源码、manifest、补丁、许可证、冒烟日志和 `SHA256SUMS`。
- 新增 Host Wine AIO `v1.0.40` 完整脚本。
- 新增固定补丁通道元数据 `patch-channel.json`。
- AIO 支持远程 Release 下载以及本地补丁包测试。
- AIO 对补丁包执行外层、内层、manifest 和二进制四层校验。
- AIO 支持原子替换、原版备份、状态记录和失败放行。
- AIO 记录功能补丁后二进制 SHA 与 PalDefender URL 运行时补丁后的最终 SHA。

### Compatibility

- 当前允许面板版本：`v1.2.1,v1.2.2`。
- 补丁源码：`uitok/palworld-panel:dev@5e3c0bce9d33091b3261f82b3e4da062fc35a8a1`。
- 兼容目标仍为未精确验证的 `v1.2.2`。

## v0.4.1

### Fixed

- 修复 `build-palpanel.sh` 在 `backend/` 中执行 `go build` 时错误解析相对输出路径。
- 将目标二进制路径转换为绝对路径后再传给 `go build -o`。
- 将总构建输出目录转换为绝对路径，避免后续打包步骤受当前工作目录影响。
- 在 `go build` 后强制检查目标文件是否存在、非空且可执行。
- 构建失败时输出明确的目标路径和源码目录。
- 增加相对输出路径回归测试，并纳入 `Validate repository`。

## v0.4.0

### Added

- 基于 `uitok/palworld-panel:dev` commit `5e3c0bce9d33091b3261f82b3e4da062fc35a8a1` 建立第一个真实补丁。
- 新增公开接口 `GET /api/patch/info`。
- 新增 PatchInfo OpenAPI 契约和生成的 TypeScript 类型。
- 新增 API 单元测试和路由契约测试。
- 新增确定性 Linux amd64 `palpanel` 构建脚本。
- 新增原版与补丁版 SHA-256 生成。
- 新增运行时 API 冒烟测试。
- 新增补丁构建 GitHub Actions。
- 新增补丁后完整源码归档和 GPL-3.0 许可证材料。

### Limitations

- 兼容目标 `v1.2.2` 仍标记为 `verified=false`。
- CI 生成的原版 SHA-256 是该 dev commit 的可重复构建结果，不保证等于已删除的官方 v1.2.2 Release 二进制。
- 在接入 AIO 前仍需获取用户本地 v1.2.2 `palpanel` 的 SHA-256。

## v0.3.0

- 新增 dev 源码探测工作流并锁定真实源码结构。

## v0.2.4

- 修复版本元数据同步。
