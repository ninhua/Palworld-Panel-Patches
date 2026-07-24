# Changelog

## v0.12.4

### Changed

- 发布可直接作为仓库根目录使用的完整包，不再要求先安装旧版本或叠加升级包。
- 唯一活动轨道为自包含 `candidate-v1.3.0`；完整包中删除全部旧版本轨道目录。
- 12 个功能补丁、SHA256SUMS、构建脚本、manifest 和许可文件全部归入 v1.3.0 轨道。
- 保持 stable patch version `0.8.1` 和 exact v1.3.0 兼容规则。

### Validation

- Validate 与 stable Release 共用完整 preflight。
- 保留累计补丁检查点、clean-room merged-patch 验证、五文件 Release 白名单和统一 SHA-256 解析。
- 空差异目标按 `no-release-needed` 成功结束，不生成空 Release。

## v0.12.3

- 将活动稳定维护轨道改为 self-contained。
- 取消活动 dev workflow 和固定历史测试路径。

## v0.12.2

- 增加累计编译检查点、无变更成功跳过和统一 Release checksum 工具。

## v0.12.1

- 修复相对输出路径测试的 npm lint/test/build 夹具。

## v0.12.0

- 引入 candidate/stable 工作区状态机、逐补丁兼容报告、merged patch 和 clean-room 发布链路。
