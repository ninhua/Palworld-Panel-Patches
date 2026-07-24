# dev source baseline

## 定义

```text
source_repository = uitok/palworld-panel
source_ref        = dev
target_version    = v1.2.2
```

这里的 `target_version` 表示补丁计划适配的面板运行版本，不表示 `dev` 分支天然等于某个正式 tag。

每次开发必须锁定：

- 完整 40 位 commit；
- commit 时间；
- 子模块 commit；
- 源码快照 SHA-256；
- 原版构建产物 SHA-256；
- 补丁版构建产物 SHA-256。

## 第一个功能

```text
patch-info-api
```

目标接口：

```http
GET /api/patch/info
```

在没有确认实际 Web 框架、路由文件和认证中间件前，不生成猜测性的源码 patch。
