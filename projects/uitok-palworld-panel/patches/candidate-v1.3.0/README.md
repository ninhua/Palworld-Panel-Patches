# PalPanel v1.3.0 candidate track

当前补丁维护目标：`PalPanel v1.3.0`。

此目录是显式候选轨道，不表示已经通过稳定版验证：

- `target_version`: `v1.3.0`
- `status`: `candidate`
- 历史源码补丁链：继承 `../dev-v1.2.2`
- 实际应用基线：GitHub Actions 检出的官方 `uitok/palworld-panel` `v1.3.0` tag
- 发布条件：Go 测试、前端 lint/Vitest/build、官方二进制校验和运行时 smoke test 全部通过

首次成功发布后，后续上游版本迁移仍从最新的较旧 stable Release 派生，而不是长期从旧 dev 轨道派生。
