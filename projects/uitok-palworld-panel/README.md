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
