# Upgrade v0.12.24 → v0.12.25

本次更新新增 stable patch `0.8.10` 的新玩家初始礼包功能，不修改一键部署脚本。

应用增量包后应新增或更新：

```text
projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source/0024-add-new-player-starter-gifts.patch
projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source/SHA256SUMS
projects/uitok-palworld-panel/automation/config.json
projects/uitok-palworld-panel/automation/patch-catalog.json
projects/uitok-palworld-panel/automation/test-apply-source-patch.sh
projects/uitok-palworld-panel/automation/test-build-release-layout.sh
projects/uitok-palworld-panel/automation/tests/test-automation.sh
projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/manifest.template.json
```

功能行为：

- 页面路径：`/starter-gift`；
- API：`GET/PUT /api/security/paldefender/starter-gift`；
- 可配置物品、数量、多个 PalDefender 帕鲁模板、物品批大小、模板批大小和批次间隔；
- 模板支持全选；
- 首次启用会基于玩家在线历史与当前服务器 save index 建立已有玩家基线；无法安全读取现有存档时拒绝启用；
- 每个新玩家的领取计划在创建时冻结，配置变更不会改变进行中的计划；
- 失败进度持久化并暂停自动重试；管理员点击重试后从未完成批次续传；
- 重置玩家记录后，必须等该玩家离线并再次进入才会重新发放。

下一次 Release 标签：

```text
uitok-stable-v1.3.0-p0.8.10
```

重新运行 Action 后应确认：

```text
0024-add-new-player-starter-gifts.patch:
  apply_status=passed
  compile_status=passed
  included_in_merged=true
```

兼容性报告应包含：

```json
{
  "first_failure": null,
  "excluded_features": [],
  "effective_features": [
    "player-presence-history",
    "host-save-migrator",
    "global-inventory-browser",
    "new-player-starter-gift"
  ]
}
```

完整 clean-room 仍必须通过 Go 测试、OpenAPI 类型生成、前端 typecheck/build、Linux amd64 构建和 `/api/patch/info` smoke validation 后才能创建 immutable Release。
