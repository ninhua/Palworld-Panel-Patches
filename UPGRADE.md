# Upgrade v0.12.19 → v0.12.20

本次更新修复 stable `0.8.9` 发布流程中的 `0018` 累计补丁冲突，不增加新的功能编号，也不修改一键部署脚本。

应用增量包后应确认以下文件已更新：

```text
projects/uitok-palworld-panel/automation/apply-source-patch.sh
projects/uitok-palworld-panel/automation/test-apply-source-patch.sh
projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source/0018-add-player-presence-history.patch
projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source/SHA256SUMS
```

`apply-source-patch.sh` 现在遵循：

- 补丁能直接应用时，仅执行标准 `git apply`；
- 补丁失败且不包含已登记的 pallocalize 测试 section 时，立即保留原始冲突并失败；
- 只有 0023 对应的固定测试 section 才允许精确重定位。

`0018` 的玩家页面改动仍必须直接应用，不能被排除。下一次 Release 标签保持：

```text
uitok-stable-v1.3.0-p0.8.9
```

重新运行 Action 后，兼容性报告应满足：

```json
{
  "excluded_features": [],
  "effective_features": [
    "player-presence-history",
    "global-inventory-browser"
  ]
}
```

并且 `reports/0018-add-player-presence-history.patch.log` 中不应再出现：

```text
已知测试路径必须在补丁中恰好出现一次，实际 0 次
```
