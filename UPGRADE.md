# Upgrade v0.12.5 → v0.12.6

本次增量更新改变 `Auto release uitok stable patch` 的 blocked migration 处理方式。

## 新行为

当源码补丁无法迁移、检查点编译失败或 clean-room 验证失败时：

```text
记录 migration_failed=true
→ 持久化 candidate 到 migration/vX.Y.Z
→ 创建或更新 Issue
→ 创建或更新 Draft PR（candidate 已成功持久化时）
→ 跳过 Release
→ workflow 以 success 正常结束
```

Actions Summary 和 Issue 中会包含首个失败补丁、失败阶段、完整原因、candidate 分支以及本次运行链接。

重复运行同一目标版本不会重复创建跟踪项。迁移成功、无需发布或 Release 已存在时，workflow 会自动关闭对应 Issue 和 Draft PR。

## 权限

workflow 使用：

```yaml
permissions:
  contents: write
  issues: write
  pull-requests: write
```

GitHub 仓库还需要允许 Actions 创建 Pull Request：

```text
Settings → Actions → General
→ Workflow permissions
→ Allow GitHub Actions to create and approve pull requests
```

如果该选项未启用，Issue 和 candidate 分支仍会正常生成，Draft PR 创建失败只会写入 Summary，不会让 workflow 失败。

## 覆盖方式

增量 ZIP 根目录与仓库根目录一一对应，不包含 `payload/`：

```bash
unzip -o Palworld-Panel-Patches-overlay-v0.12.5-to-v0.12.6.zip \
  -d /path/to/Palworld-Panel-Patches
```

验证并提交：

```bash
cd /path/to/Palworld-Panel-Patches
python3 -m pip install -r requirements-ci.txt
bash common/scripts/validate-all.sh
git add -A
git commit -m "v0.12.6: report blocked migrations without failing workflow"
git push origin main
```
