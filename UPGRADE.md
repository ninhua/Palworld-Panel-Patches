# Upgrade v0.12.22 → v0.12.23

本次更新修复 stable `0.8.9` clean-room Go 测试中的两个兼容性故障，不增加功能编号，也不修改一键部署脚本。

应用增量包后应确认：

```text
projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source/0021-capture-audit-response-details.patch
projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source/0022-add-host-save-migrator.patch
projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source/SHA256SUMS
projects/uitok-palworld-panel/automation/test-apply-source-patch.sh
```

修复内容：

- 单路径参数审计目标恢复为参数原始值，例如 `steam_1`，兼容上游 GM 幂等审计测试；
- 多路径参数继续输出 `key=value`，不丢失参数名；
- `/save-sources/import` 的 `application/json` Schema 继续顶层引用 `SaveImportCommitRequest`；
- `SaveImportCommitRequest` 增加 `migration_source_id`、`steam_id`、`confirm`，并以 `oneOf.required` 区分普通归档提交和主机迁移提交；
- 不修改上游测试，也不放宽断言。

下一次 Release 标签仍为：

```text
uitok-stable-v1.3.0-p0.8.9
```

重新运行 Action 后，以下测试应通过：

```text
TestPalDefenderGMIdempotencyAndWriteAudit
TestOpenAPIAuthenticationAndModImportSchemas
```

兼容性报告应满足：

```json
{
  "first_failure": null,
  "excluded_features": [],
  "effective_features": [
    "player-presence-history",
    "host-save-migrator",
    "global-inventory-browser"
  ]
}
```

运行日志中的 `save import inspection cleanup path is invalid` 是测试清理告警；只要相关测试没有 `FAIL`，不应将其单独视为发布阻断。
