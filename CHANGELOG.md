# Changelog

## v0.2.3

### Fixed

- 将 `actions/checkout` 升级为 `v6`。
- 将 `actions/setup-python` 升级为 `v6`。
- 消除 GitHub Actions 的 Node.js 20 弃用警告。
- 保留 `requirements-ci.txt` 作为 pip 缓存依赖文件。
- 增加临时源码版本别名机制，允许以 v1.2.1 源码测试 v1.2.2 兼容性。
- 禁止在 manifest 中把 v1.2.1 源码虚报为 v1.2.2 上游源码。

## v0.2.2

- 修复 pip 缓存依赖文件探测。
- 建立本地保留 v1.2.2 的来源锁定模板。

## v0.2.1

- 增加 JSON Schema、YAML、版本、LF 换行和可执行权限校验。
