# Upgrade v0.12.16 → v0.12.17

本次更新纠正 v0.12.16 本地修复包只修改补丁应用器、却没有实际替换 `0018-add-player-presence-history.patch` 的问题。stable patch 目标仍为 `0.8.7`。

## 变更

- 重新生成 `0018-add-player-presence-history.patch`，补丁包中现在可直接看到该文件发生变化。
- 修正 `patch_info.go`、`patch_info_test.go`、`Players.tsx` 和 `types/index.ts` 的真实累计上下文。
- 删除 `apply-source-patch.sh` 中的 0018 专用语义适配器。
- `player-presence-history` 继续作为 required feature；标准补丁应用失败时禁止创建 Release。
- `0021-capture-audit-response-details.patch` 和审计详细响应修复保持不变。

## 覆盖

已应用上一份 v0.12.16 包时：

```bash
cd /path/to/Palworld-Panel-Patches
unzip -o Palworld-Panel-Patches-overlay-v0.12.16-to-v0.12.17.zip -d .
```

仍在 v0.12.15 时，可以直接使用合并覆盖包：

```bash
unzip -o Palworld-Panel-Patches-overlay-v0.12.15-to-v0.12.17-corrected.zip -d .
```

## 验证与提交

```bash
python3 -m pip install -r requirements-ci.txt
bash common/scripts/validate-all.sh

git add -A
git commit -m "v0.12.17: regenerate player presence patch"
git push origin main
```

随后运行 `Auto release uitok stable patch`，目标版本填写 `v1.3.0`。预期 Release tag 仍为：

```text
uitok-stable-v1.3.0-p0.8.7
```

兼容性报告必须包含：

```json
{
  "excluded_features": [],
  "effective_features": ["player-presence-history", "audit-log-response-display"]
}
```
