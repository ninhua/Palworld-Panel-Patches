# Upgrade v0.12.32-hotfix3 → v0.12.32-hotfix4

本次更新修复玩家概览页面的 TypeScript 严格类型编译失败。

## 错误

```text
src/pages/PlayerSummary.tsx(69,77): error TS2345:
Argument of type 'string | undefined' is not assignable to parameter of type 'string'.
```

`Pal.instance_id` 是可选字段，但旧实现直接将其传给 `Map<string, Pal>.set`。

## 修正

新增：

```text
projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source/0035-fix-player-summary-optional-pal-id.patch
```

玩家帕鲁关联键现在按以下顺序生成：

```text
instance_id → id → character_id → 空
```

只有得到非空字符串键后才写入 `Map<string, Pal>`；同一规则也用于列表去重，避免两个缺少 `instance_id` 的帕鲁被错误视为同一实例。

## 版本

```text
仓库版本：0.12.32-hotfix4
当前已发布 stable patch：0.8.15
下一 stable patch：0.8.16
预期 Release：uitok-stable-v1.3.0-p0.8.16
```

## 提交前检查

```bash
cd projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source
sha256sum -c SHA256SUMS
cd ../../../..
bash common/scripts/validate-repository.sh
```
