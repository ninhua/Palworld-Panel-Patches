# Upgrade v0.12.20 → v0.12.21

本次更新修复 stable `0.8.9` 发布流程中的 `0022-add-host-save-migrator.patch` 前端累计补丁冲突，不增加功能编号，也不修改一键部署脚本。

应用增量包后应确认：

```text
projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source/0022-add-host-save-migrator.patch
projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source/SHA256SUMS
projects/uitok-palworld-panel/automation/test-apply-source-patch.sh
projects/uitok-palworld-panel/automation/testdata/palpanel-v1.3.0/frontend/src/pages/SaveSources.tsx
```

修复后的 0022 以 PalPanel v1.3.0 正式 `SaveSources.tsx` 为前像，保留原有存档检查、导入、激活、重建、删除和重命名流程，只增加主机迁移状态、预检与执行入口。

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

`reports/0022-add-host-save-migrator.patch.log` 中不应再出现：

```text
frontend/src/pages/SaveSources.tsx: patch does not apply
```

Draft PR 创建失败与补丁兼容性无关。需要在仓库 Settings → Actions → General → Workflow permissions 中启用 “Allow GitHub Actions to create and approve pull requests”。
