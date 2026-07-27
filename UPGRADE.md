# Upgrade v0.12.31-hotfix5 → v0.12.32

本次更新为现有帕鲁仓库增加多项筛选、质量排序和终端位置显示。

## 新增补丁

```text
projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source/0034-add-pal-inventory-advanced-filters.patch
```

## 功能入口

```text
世界管理 → 存档管理工具 → 帕鲁仓库
页面：/pal-inventory
```

## 筛选与排序

- 最低等级：0–65；
- 最低星级：0–4，按存档 Rank 换算；
- 最低平均 IV：0–100；
- 性别：雄性、雌性、通配；
- 位置：帕鲁终端、队伍、据点工作、远征、未知；
- 被动词条：使用逗号分隔，多项条件必须全部命中；
- 排序：等级、平均 IV、星级或名称。

## 终端位置

帕鲁终端按每页 30 格、每行 6 格，将 `SlotIndex` 显示为“终端第 N 页 · 第 N 行第 N 列”。队伍、据点工作位和远征使用对应中文位置。该功能只读取现有 save index，不修改存档。

## 版本

```text
仓库版本：0.12.32
当前已发布 stable patch：0.8.15
下一 stable patch：0.8.16
预期 Release：uitok-stable-v1.3.0-p0.8.16
```
