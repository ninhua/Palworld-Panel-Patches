# Changelog

## v0.2.1

### Fixed

- 将 `patch_type` 设为 patch manifest 必填字段。
- CI 实际执行 JSON Schema 校验，不再只检查 JSON 语法。
- 增加 YAML 语法检查。
- 增加 `.gitattributes`，强制脚本和配置使用 LF。
- 增加 `requirements-ci.txt`，固定 CI 校验依赖范围。
- 增加根目录 MIT `LICENSE`。
- 校验 `VERSION` 与 README、CHANGELOG 最新版本是否一致。
- 增加可执行权限、占位值和目录结构检查。

## v0.2.0

- 将 `projects/jiaayu-palworld-panel/` 改为 `ports/jiaayu-features/`。
- 明确 Jiaayu 当前是功能移植来源，不是独立运行目标。
- 将运行时兼容层命名为 `projects/host-wine-aio/`。
- 增加功能移植映射模板、来源记录和许可证审查清单。
- 增加骨架版本文件 `VERSION`。

## v0.1.0

- 初始多项目补丁仓库骨架。
