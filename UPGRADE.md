# Upgrade v0.12.28 → v0.12.29

本次更新新增 stable patch `0.8.14`，接入“无人时段库存净增加”。功能只读取当前服务器世界的在线状态与 save index，并将统计状态保存在 PalPanel SQLite KV；不会修改 Palworld 存档。

## 新增补丁

```text
projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source/0027-add-unattended-inventory-delta.patch
```

## 行为

- 当前世界无人在线且库存索引可用时建立基线。
- 无人时段持续至少 5 分钟后才成为可保留记录。
- 仅统计相对基线的正向净变化；减少的物品不会作为负数展示。
- 玩家重新上线后冻结最近一次完整结果。
- 采样中断超过 60 秒后重新建立基线。
- 统计按 WorldID 隔离，导入存档不参与实时统计。

## 版本

```text
仓库版本：0.12.29
当前已发布 stable patch：0.8.13
下一 stable patch：0.8.14
预期 Release：uitok-stable-v1.3.0-p0.8.14
```

重新运行稳定发布 Workflow 后重点确认：

```text
0027-add-unattended-inventory-delta.patch:
  apply_status=passed
  compile_status=passed
  included_in_merged=true
```

完整 clean-room 必须通过 Go 测试、OpenAPI 类型生成、前端 typecheck/build、Linux amd64 构建和 `/api/patch/info` smoke validation 后才能创建 immutable Release。
