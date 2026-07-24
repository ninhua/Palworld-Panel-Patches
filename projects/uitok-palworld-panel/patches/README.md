# Patch workspaces

目录分为三类：

```text
dev-vX.Y.Z/          历史开发补丁链
bootstrap-vX.Y.Z/    不可变自包含发布输入
candidate-vX.Y.Z/    某次迁移结果，可不存在
stable-vX.Y.Z/       已通过验证并对应 immutable Release
```

bootstrap 源轨道不得与 candidate/stable 工作区共用路径。候选工作区不能声明 `verified=true`；失败候选只写入 `migration/vX.Y.Z` 分支。

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
