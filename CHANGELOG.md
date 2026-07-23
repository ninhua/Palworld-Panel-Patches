# Changelog

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
