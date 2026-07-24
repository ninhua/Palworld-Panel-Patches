# Upgrade v0.12.6 → v0.12.7

本次更新修复 active source track 被 candidate 工作区覆盖或删除后，`Auto release uitok stable patch` 在 preflight 阶段报错停止的问题。

## 新目录职责

```text
patches/bootstrap-v1.3.0/   不可变发布输入，包含 source/build/manifest/license
patches/candidate-v1.3.0/   迁移失败或 no-change 工作区，可不存在
patches/stable-v1.3.0/      已验证并发布的稳定工作区
```

`config.json.bootstrap_source_track` 现在指向 `bootstrap-v1.3.0`。失败候选仍写入 `migration/v1.3.0` 并由 Issue/Draft PR 跟踪，但不会影响下一次 workflow 的发布输入。

## 覆盖方式

增量 ZIP 根目录与仓库根目录一一对应：

```bash
unzip -o Palworld-Panel-Patches-overlay-v0.12.6-to-v0.12.7.zip \
  -d /path/to/Palworld-Panel-Patches
```

提交时必须使用 `git add -A`，确保新增的 `bootstrap-v1.3.0/source/*.patch` 被纳入提交：

```bash
cd /path/to/Palworld-Panel-Patches
python3 -m pip install -r requirements-ci.txt
bash common/scripts/validate-all.sh
git add -A
git status --short
git commit -m "v0.12.7: separate bootstrap source track from candidate workspaces"
git push origin main
```
