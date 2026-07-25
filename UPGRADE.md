# Upgrade v0.12.21 → v0.12.22

本次更新修复 stable `0.8.9` 发布流程中的 `0023-add-global-inventory-browser.patch` 累计补丁冲突，不增加功能编号，也不修改一键部署脚本。

应用增量包后应确认：

```text
projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source/0023-add-global-inventory-browser.patch
projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source/SHA256SUMS
projects/uitok-palworld-panel/automation/test-apply-source-patch.sh
```

修复后的 0023：

- 不再修改 `backend/internal/api/patch_info.go`；
- 不再修改 `backend/internal/api/patch_info_test.go`；
- 通过新增库存实现文件的 `init()` 注册 `global-inventory-browser`；
- 以后端已有 storage、workers、feed-boxes 路由顺序为累计前像；
- 以累计 OpenAPI 路径、`ListSummary` Schema 和完整中英文路由字典为锚点；
- 仍由标准 `git apply --check` 直接应用。

下一次 Release 标签仍为：

```text
uitok-stable-v1.3.0-p0.8.9
```

重新运行 Action 后，兼容性报告应满足：

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

`reports/0023-add-global-inventory-browser.patch.log` 中不应再出现：

```text
backend/internal/api/patch_info.go: patch does not apply
backend/internal/api/patch_info_test.go: patch does not apply
backend/internal/api/routes.go: patch does not apply
docs/openapi.yaml: patch does not apply
frontend/src/i18n/index.tsx: patch does not apply
```

Draft PR `#2` 已成功创建，说明 Actions 的 PR 创建权限已经生效；它会在下一次迁移运行时由工作流更新。
