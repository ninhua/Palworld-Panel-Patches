# Upgrade v0.12.26 → v0.12.27

本次更新新增 stable patch `0.8.12`，修复玩家在线历史和新玩家初始礼包跨存档串档，并重做初始礼包选择界面。不修改一键部署脚本的 Release、manifest schema 或资产命名契约。

## 新增补丁

```text
projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source/0025-fix-starter-gift-ui-and-save-scope.patch
```

## 存档作用域

- 优先读取 `Pal/Saved/Config/WindowsServer/GameUserSettings.ini` 的 `DedicatedServerName`，定位真实活动 `SaveGames/0/<WorldID>`；配置缺失时才回退到最新 `Level.sav`。
- 在线累计时长、当前会话、最近上线/下线事件和最近会话列表按 WorldID 独立保存。
- 初始礼包配置、已见玩家、在线状态、重置标记、冻结计划和批次进度按同一 WorldID 独立保存。
- 新世界会继承最近保存的礼包配置模板，随后保存为本世界独立配置；已有世界不会被其他世界的配置修改覆盖。
- 检测到多个世界目录时不迁移旧全局历史；仅有一个世界时执行一次兼容迁移，避免把旧档状态带入新档。
- 配置已启用后创建新世界，首次在线玩家会立即进入礼包队列，不再被首次采样错误标记为老玩家。

## 前端变化

- 玩家中心增加“初始礼包”入口。
- 物品改为目录点击选择，支持名称/ItemID 搜索、启发式分类、多选、当前筛选全选/取消和数量调整。
- PalDefender 模板支持搜索、多选、当前筛选全选/取消。
- 物品目录、模板目录、已选物品和发放记录均限制高度并使用内部滚动条。
- 页面显示当前活动 WorldID，便于确认正在管理的存档。

## 版本

```text
仓库版本：0.12.27
当前已发布 stable patch：0.8.11
下一 stable patch：0.8.12
预期 Release：uitok-stable-v1.3.0-p0.8.12
```

重新运行稳定发布 Workflow 后重点确认：

```text
0025-fix-starter-gift-ui-and-save-scope.patch:
  apply_status=passed
  compile_status=passed
  included_in_merged=true
```

完整 clean-room 仍必须通过 Go 测试、OpenAPI 类型生成、前端 typecheck/build、Linux amd64 构建和 `/api/patch/info` smoke validation 后才能创建 immutable Release。
