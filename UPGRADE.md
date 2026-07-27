# Upgrade v0.12.31-hotfix3 → v0.12.31-hotfix4

本次更新修复新玩家已被识别但实际礼包未发放、或配置保存后新玩家被提前写入已见基线的问题。

## 新增补丁

```text
projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source/0033-fix-starter-gift-runtime-dispatch.patch
```

## 修正行为

- 只有礼包从“禁用”切换到“启用”时才导入已有玩家基线；已启用状态下调整物品、模板或批次参数不会再次把当前存档玩家标记为老玩家。
- 创建任务后，先使用官方 Palworld REST 返回的 PlayerUID/SteamID，在 PalDefender 在线玩家列表中解析实际发放目标。
- 新玩家刚进入、PalDefender 尚未完成登记时，任务保持“等待发放”，后续 15 秒采样自动重试，不立即转为永久失败。
- 自动恢复旧版本中 `PLAYER_NOT_FOUND` / `player was not found` 导致的失败任务。
- 异步发放 worker 不再继承可提前取消的采样上下文，并保留三小时安全上限。

## 验证位置

进入“新玩家礼包 → 发放记录”。新玩家第一次被官方 REST 观察到后应出现记录；PalDefender 未就绪时记录保持等待，就绪后自动进入发放并完成。

## 版本

```text
仓库版本：0.12.31-hotfix4
当前已发布 stable patch：0.8.15
下一 stable patch：0.8.16
预期 Release：uitok-stable-v1.3.0-p0.8.16
```
