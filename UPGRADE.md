# Upgrade v0.12.27-hotfix3 → v0.12.28

本次更新新增 stable patch `0.8.13`，只重构新玩家礼包前端入口和操作界面，不改变后端礼包协议、WorldID 隔离逻辑、Release schema 或资产命名。

## 新增补丁

```text
projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source/0026-redesign-starter-gift-ui.patch
```

## 界面变化

- 左侧“玩家与世界”展开后显示“新玩家礼包”。
- 顶部显示当前 WorldID、启用状态、已选物品/模板和发放任务摘要。
- 发放参数改为紧凑横向布局。
- 物品、帕鲁模板和发放记录使用三个独立 Tab。
- 物品显示本地化图标，并按实际管理用途细分分类；选中后直接在行内调整数量。
- 帕鲁模板显示头像和模板原文件名。
- 页面底部固定显示已选汇总、未保存状态、撤销和保存按钮。

## 版本

```text
仓库版本：0.12.28
当前已发布 stable patch：0.8.12
下一 stable patch：0.8.13
预期 Release：uitok-stable-v1.3.0-p0.8.13
```

重新运行稳定发布 Workflow 后重点确认：

```text
0026-redesign-starter-gift-ui.patch:
  apply_status=passed
  compile_status=passed
  included_in_merged=true
```

完整 clean-room 仍必须通过 Go 测试、OpenAPI 类型生成、前端 typecheck/build、Linux amd64 构建和 `/api/patch/info` smoke validation 后才能创建 immutable Release。
