# Upgrade v0.12.31-hotfix4 → v0.12.31-hotfix5

本次更新只修正补丁源码校验清单，不修改 PalPanel 功能代码。

## 问题

`0022-add-host-save-migrator.patch` 在 `v0.12.26` 已更新，但后续增量包中的 `source/SHA256SUMS` 误恢复为旧文件的哈希，stable Workflow 因此报告：

```text
sha256sum: WARNING: 1 computed checksum did NOT match
Error: Process completed with exit code 1.
```

## 修正

```text
projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source/SHA256SUMS
```

`0022-add-host-save-migrator.patch` 的正确条目为：

```text
aee8e8e084e1b8dd4920aa571981e1ce501f15fee618de41dc66679b839fe58f  0022-add-host-save-migrator.patch
```

补丁文件本身不需要替换。

## 版本

```text
仓库版本：0.12.31-hotfix5
当前已发布 stable patch：0.8.15
下一 stable patch：0.8.16
预期 Release：uitok-stable-v1.3.0-p0.8.16
```
