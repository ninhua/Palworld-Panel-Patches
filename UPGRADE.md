# Upgrade v0.12.25 → v0.12.26

本次更新修复主机迁移对 Palworld v1.0+ Oodle/PlM 存档的解析，并把迁移结果自动部署为服务器实际启用世界。stable patch 升级为 `0.8.11`，不修改一键部署脚本。

应用增量包后应更新：

```text
projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source/0022-add-host-save-migrator.patch
projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source/SHA256SUMS
projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/build/build-palpanel.sh
projects/uitok-palworld-panel/automation/config.json
projects/uitok-palworld-panel/automation/patch-catalog.json
projects/uitok-palworld-panel/automation/test-apply-source-patch.sh
projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/manifest.template.json
```

新的主机迁移流程：

```text
只读预检导入源
→ 使用启用 Oodle 的 palworld-uid-remap 生成迁移世界
→ 检查服务器状态
→ 若正在运行则停止服务器
→ 复制迁移世界到 Pal/Saved/SaveGames/0/<32位世界名>
→ 原子修改 Pal/Saved/Config/WindowsServer/GameUserSettings.ini
→ DedicatedServerName=<32位世界名>
→ 将 PalPanel 活动源设为 server
→ 若迁移前正在运行则重新启动服务器
```

原受管导入源和迁移归档源均保留。出现复制、INI 写入、数据库登记或启动失败时，应恢复旧 `DedicatedServerName`、删除未提交的服务器世界并恢复原运行状态。

下一次 Release 标签：

```text
uitok-stable-v1.3.0-p0.8.11
```

重新运行 Action 后重点确认：

```text
0022-add-host-save-migrator.patch:
  apply_status=passed
  compile_status=passed
  included_in_merged=true

palworld-uid-remap 构建命令包含 --features oodle
Release 包包含 overlay/bin/palworld-uid-remap
```

完整 clean-room 仍必须通过 Go 测试、Rust helper 构建、OpenAPI 类型生成、前端 typecheck/build、Linux amd64 构建和 `/api/patch/info` smoke validation 后才能创建 immutable Release。
