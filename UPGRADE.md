# Upgrade v0.12.31-hotfix1 → v0.12.31-hotfix2

本次更新修复 `0.8.16` 候选的 TypeScript 与 ESLint 构建阻断。

## 修正补丁

```text
projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source/0030-add-player-summary-and-landmarks.patch
projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source/0031-read-starter-gift-template-pal-id.patch
```

## 修正内容

- 为玩家概览补充 `normalizeID(value?: string | null)`，统一处理可选 PlayerUID、SteamID 和帕鲁所有者 ID；
- 删除新玩家礼包中不再使用的 `itemByID`；
- stable patch 候选保持 `0.8.16`。

## 版本

```text
仓库版本：0.12.31-hotfix2
当前已发布 stable patch：0.8.15
下一 stable patch：0.8.16
预期 Release：uitok-stable-v1.3.0-p0.8.16
```
