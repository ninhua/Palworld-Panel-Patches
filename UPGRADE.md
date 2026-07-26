# Upgrade v0.12.31 → v0.12.31-hotfix1

本次更新修复新玩家礼包中 PalDefender 模板帕鲁名称和头像错误依赖文件名的问题。

## 新增补丁

```text
projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source/0031-read-starter-gift-template-pal-id.patch
```

## 行为

- 模板文件名继续作为 PalDefender 发放参数和配置主键；
- 帕鲁名称、头像和搜索关键字改为读取模板 JSON 顶层 `PalID`；
- 同时展示模板中的 `Nickname` 和 `Level`；
- JSON 无效、缺少 `PalID` 或文件路径异常时显示“模板解析失败”，不再使用文件名伪造帕鲁 ID；
- 读取目录固定为 `Pal/Binaries/Win64/PalDefender/Pals/Templates`，单文件最大 1 MiB。

## 版本

```text
仓库版本：0.12.31-hotfix1
当前已发布 stable patch：0.8.15
下一 stable patch：0.8.16
预期 Release：uitok-stable-v1.3.0-p0.8.16
```
