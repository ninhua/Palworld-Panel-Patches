# Upgrade v0.12.3 → v0.12.5

本次增量更新修复 PalPanel `v1.3.0` stable Release 在迁移 `0009-add-base-feed-box-summary.patch` 时被错误阻断的问题。

## 根因

旧迁移器在每个源码补丁应用后立即执行 Axios mock 适配器。`0008` 和 `0009` 都修改 `frontend/src/api/bases.test.ts`；适配器提前改写 `0008` 的结果后，`0009` 仍按原始补丁上下文应用，因此出现：

```text
patch failed: frontend/src/api/bases.test.ts
patch does not apply
```

## 修复结果

```text
源码补丁：保持原始顺序累计应用
检查点适配：仅用于临时 lint/compile 验证，验证后恢复
最终适配：全部补丁完成后统一执行并进入 merged patch
Release：继续执行 clean-room 验证和五文件发布
```

## 覆盖方式

增量 ZIP 根目录与仓库根目录一一对应，不包含 `payload/`。在仓库根目录直接解压覆盖：

```bash
unzip -o Palworld-Panel-Patches-overlay-v0.12.3-to-v0.12.5.zip \
  -d /path/to/Palworld-Panel-Patches
```

然后验证并提交：

```bash
cd /path/to/Palworld-Panel-Patches
python3 -m pip install -r requirements-ci.txt
bash common/scripts/validate-all.sh
git add -A
git commit -m "v0.12.5: preserve patch context during checkpoint adaptation"
git push origin main
```

重新运行 `Auto release uitok stable patch`，输入 `v1.3.0`。
