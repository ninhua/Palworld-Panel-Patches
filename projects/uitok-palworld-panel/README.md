# uitok-palworld-panel

这是当前实际面板的源码补丁目标。

## 职责

- 维护针对精确上游版本的源码 patch；
- 构建补丁版 Linux amd64 面板；
- 生成 manifest 和 SHA-256；
- 测试启动参数、API、静态资源和回滚兼容性。

## 不包含

- Wine 安装；
- PalServer.exe 生命周期管理；
- Docker CLI shim；
- 简幻欢容器启动逻辑。

以上内容属于 `projects/host-wine-aio/`。

## 稳定版自动发布

`automation/` 每天检查上游正式 Release，构建验证成功后直接创建稳定补丁 Release。补丁迁移或 clean-room 验证被阻断时不发布，并创建或更新同版本 Issue；candidate 工作区成功持久化时同时创建或更新 Draft PR。稳定版本匹配只使用 PalPanel 版本号，commit 仅保留用于源码追踪。

## 当前稳定扩展

`new-player-starter-gift` 基于玩家在线历史和服务器 save index 识别新玩家，通过 PalDefender 分批发放可配置物品与帕鲁模板，并持久化每位玩家的进度；页面提供侧栏入口、物品/模板图标、精细分类、Tab 工作区、行内数量编辑和固定保存摘要；模板帕鲁名称与头像读取 JSON 内 `PalID`，不再从文件名推断；单项选择不会改变当前列表顺序或滚动位置。

`unattended-inventory-delta` 复用玩家在线采样和全服库存索引，按 WorldID 记录至少 5 分钟的无人时段及物品正向净变化；采样中断时重建基线，页面明确该指标不等同于生产量。
`global-inventory-browser` 的页面路径为 `/inventory`，左侧入口位于“存档管理工具 → 库存管理”；`unattended-inventory-delta` 状态卡显示在该页面顶部。

## 玩家存档概览

`player-summary` 通过 `/player-summary` 页面复用现有玩家、帕鲁、坐标和在线历史数据，展示只读玩家摘要与宽泛中文区域估算。当前索引未提供的深层进度字段不会被猜测。
