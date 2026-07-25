# Upgrade v0.12.23 → v0.12.24

本次更新修复 stable `0.8.9` 前端 TypeScript 构建中的 OpenAPI 生成契约缺失，不增加功能编号，也不修改一键部署脚本。

应用增量包后应确认：

```text
projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source/0022-add-host-save-migrator.patch
projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source/SHA256SUMS
projects/uitok-palworld-panel/automation/test-apply-source-patch.sh
```

修复内容：

- 在 OpenAPI components 中新增 `SaveSource` Schema；
- `HostMigrationResult.source` 继续使用 `$ref: '#/components/schemas/SaveSource'`，但该引用现在有真实定义；
- Schema 字段与 PalPanel v1.3.0 前端 `SaveSource` 类型对齐，包括 `id`、`name`、`kind`、`active`、时间字段及可选索引元数据；
- 新增组件引用闭包检查，并用 TypeScript 编译探针验证不会再次生成悬空索引类型。

下一次 Release 标签仍为：

```text
uitok-stable-v1.3.0-p0.8.9
```

重新运行 Action 后，以下阶段应通过：

```text
npm run generate:api-types
npm run typecheck
npm run build
```

重点确认不再出现：

```text
Property 'SaveSource' does not exist on type ...
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
