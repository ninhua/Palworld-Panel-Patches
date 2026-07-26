# Upgrade v0.12.30-hotfix1 → v0.12.31

本次更新增加只读“玩家存档概览”与宽泛中文区域定位。

## 新增补丁

```text
projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source/0030-add-player-summary-and-landmarks.patch
```

## 页面入口

```text
世界管理 → 玩家与世界 → 世界档案 → 玩家概览
```

直接路径：

```text
/player-summary
```

## 展示内容

- 玩家等级、公会和在线状态；
- 本次或上次在线、累计在线和最近上线；
- 玩家持有帕鲁数量、种类、平均等级和最高等级；
- 原始世界坐标；
- 依据实时地图同一投影算法估算的宽泛中文区域。

中文区域仅用于快速定位。当前 `sav-cli` 未输出的科技、配方、图鉴和首领进度不会显示猜测值。

## 版本

```text
仓库版本：0.12.31
当前已发布 stable patch：0.8.15
下一 stable patch：0.8.16
预期 Release：uitok-stable-v1.3.0-p0.8.16
```
