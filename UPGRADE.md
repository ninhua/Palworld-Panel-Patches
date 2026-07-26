# Upgrade v0.12.29-hotfix1 → v0.12.30

本次更新新增 stable patch `0.8.15`，修复库存管理页面缺少左侧导航入口的问题。

## 新增补丁

```text
projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source/0028-fix-global-inventory-sidebar-entry.patch
```

## 行为

- 左侧“存档管理工具”增加“库存管理”。
- 点击后进入 `/inventory`。
- “无人时段库存净增加”继续显示在库存管理页面顶部。
- 不修改后端 API、统计状态、WorldID 隔离或 Palworld 存档。

## 版本

```text
仓库版本：0.12.30
当前已发布 stable patch：0.8.14
下一 stable patch：0.8.15
预期 Release：uitok-stable-v1.3.0-p0.8.15
```

重新运行稳定发布 Workflow 后，确认左侧菜单包含：

```text
存档管理工具
├─ 存档中心
├─ 库存管理
├─ 帕鲁仓库
├─ 配种实验室
└─ 实时地图
```
