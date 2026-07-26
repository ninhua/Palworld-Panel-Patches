# Upgrade v0.12.30 → v0.12.30-hotfix1

本次更新修复新玩家礼包列表在单项选择后回弹到顶部的问题。

## 新增补丁

```text
projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source/0029-fix-starter-gift-selection-scroll.patch
```

## 行为

- 礼包物品列表按名称保持稳定顺序。
- 帕鲁模板列表按展示名称保持稳定顺序。
- 选择或取消单项时不再把该条目移动到列表顶部。
- “只看已选”、批量选择、数量调整和保存行为不变。

## 版本

```text
仓库版本：0.12.30-hotfix1
当前已发布 stable patch：0.8.14
下一 stable patch：0.8.15
预期 Release：uitok-stable-v1.3.0-p0.8.15
```
