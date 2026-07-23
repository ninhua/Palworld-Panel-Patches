# Changelog

## v0.2.4

### Fixed

- 修复根目录 `README.md` 的骨架版本未随 `VERSION` 更新。
- 增加当前 v1.2.1 → v1.2.2 临时兼容开发目标说明。
- 保持 Node.js 24 Actions 和 pip 缓存修复不变。

## v0.2.3

- 将 `actions/checkout` 升级为 `v6`。
- 将 `actions/setup-python` 升级为 `v6`。
- 增加临时源码版本别名机制。
- 增加 `v1.2.2-compat-v1.2.1` 开发目录。

## v0.2.2

- 修复 pip 缓存依赖文件探测。
- 建立本地保留 v1.2.2 的来源锁定模板。

## v0.2.1

- 增加 JSON Schema、YAML、版本、LF 换行和可执行权限校验。
