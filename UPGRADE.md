# Upgrade v0.12.34-hotfix1 → v0.12.34-hotfix2

本次更新修复仓库版本元数据不同步，并将该规则固化为自动门禁；不修改 PalPanel 功能补丁或运行时行为。

## 原因

上一提交只更新了根目录 `VERSION`，但没有在同一提交更新：

```text
README.md
CHANGELOG.md
UPGRADE.md
```

因此仓库校验报告：

```text
README.md 中的骨架版本与 VERSION 不一致
```

## 修正

- `VERSION`、README 顶部仓库版本、CHANGELOG 首个版本标题和 UPGRADE 目标版本统一为 `0.12.34-hotfix2`；
- 新增 `common/scripts/validate-release-metadata.sh`；
- `common/scripts/validate-repository.sh` 在其他验证前先运行版本同步门禁；
- README 和 `PATCH-MAINTENANCE.md` 加入醒目的版本同步硬规则。

## 强制规则

任何后续覆盖包只要修改 `VERSION`，必须同时包含：

```text
VERSION
README.md
CHANGELOG.md
UPGRADE.md
```

提交前必须在仓库根目录执行：

```bash
bash common/scripts/validate-release-metadata.sh
bash common/scripts/validate-repository.sh
```

第一条命令必须输出：

```text
[OK] 仓库版本元数据一致：0.12.34-hotfix2
```

## 版本

```text
仓库版本：0.12.34-hotfix2
当前已发布 stable patch：0.8.16
下一 stable patch：0.8.17
预期 Release：uitok-stable-v1.3.0-p0.8.17
```
