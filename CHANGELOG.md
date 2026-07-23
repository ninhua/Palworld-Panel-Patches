# Changelog

## v0.2.2

### Fixed

- 修复 `actions/setup-python` 的 pip 缓存依赖文件探测错误。
- 为 `cache-dependency-path` 显式指定 `requirements-ci.txt`。
- 将首个真实补丁目标固定为本地保留的 `uitok/palworld-panel v1.2.2`。
- 增加 v1.2.2 本地来源锁定模板，避免把已删除的远端 tag 当成可重新获取来源。
- 明确只有二进制时不能制作源码补丁，必须先保留对应源码快照或可验证 commit。

## v0.2.1

- 增加 JSON Schema、YAML、版本、LF 换行和可执行权限校验。
- 增加 CI 依赖文件、许可证和 `patch_type`。
