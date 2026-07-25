# Upgrade v0.12.15 → v0.12.16

本次更新发布目标提升为 stable patch `0.8.7`，同时修复玩家在线历史被 Action 静默排除，以及操作审计详情只有 `ok` 等泛化摘要的问题。

## 变更

- `player-presence-history` 从 optional feature 改为 required feature；补丁应用、编译或 clean-room 验证失败时禁止创建 Release。
- `apply-source-patch.sh` 为 `0018-add-player-presence-history.patch` 增加严格语义迁移，只适配四个已知上下文冲突文件；其他文件仍必须通过标准 `git apply --check`。
- 新增 `0021-capture-audit-response-details.patch`，将写操作实际 `data` / `error` 响应记录到现有审计 `message` 字段。
- 敏感键、Bearer Token、Cookie、Authorization、密码和凭据会递归脱敏；最终响应记录限制在 32 KiB。
- 不修改一键部署脚本，不修改 Palworld 存档，也不新增审计数据库列。

## 覆盖

```bash
cd /path/to/Palworld-Panel-Patches
unzip -o Palworld-Panel-Patches-overlay-v0.12.15-to-v0.12.16.zip -d .
```

## 验证与提交

```bash
python3 -m pip install -r requirements-ci.txt
bash common/scripts/validate-all.sh

git add -A
git commit -m "v0.12.16: require player history and capture audit responses"
git push origin main
```

随后运行 `Auto release uitok stable patch`，目标版本填写 `v1.3.0`。
预期 Release tag 为 `uitok-stable-v1.3.0-p0.8.7`。

发布前兼容性报告必须满足：

```json
{
  "excluded_features": [],
  "effective_features": ["player-presence-history", "audit-log-response-display"]
}
```
