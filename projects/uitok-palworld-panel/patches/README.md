# Patch workspaces

目录分为三类：

```text
dev-vX.Y.Z/          历史开发补丁链，只作首次 bootstrap
candidate-vX.Y.Z/    尚未通过完整 clean-room 验证
stable-vX.Y.Z/       已通过验证并对应 immutable Release
```

候选工作区不能声明 `verified=true`。失败候选只写入 `migration/vX.Y.Z` 分支，不进入 main。

稳定工作区必须包含：

- `workspace.json`
- `compatibility-report.json`
- `source-chain/`
- `active-source/`
- `merged/`
- `reports/`
- `manifest.template.json`
- `derivation.json`

安装和下一版本派生仍以已发布 stable Release 为权威来源；仓库工作区用于审计、排错和维护。
