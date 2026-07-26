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

`new-player-starter-gift` 基于玩家在线历史和服务器 save index 识别新玩家，通过 PalDefender 分批发放可配置物品与帕鲁模板，并持久化每位玩家的进度；页面提供侧栏入口、物品/模板图标、精细分类、Tab 工作区、行内数量编辑和固定保存摘要。
