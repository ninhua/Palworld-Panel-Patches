# Upgrade v0.12.32-hotfix2 → v0.12.32-hotfix3

本次更新修复 `0034-add-pal-inventory-advanced-filters.patch` 无法应用到累计迁移工作区的问题，并在仓库根目录固化后续补丁维护规则。

## 原因

0034 的 `frontend/src/pages/Pals.tsx` section 不是基于锁定的官方 v1.3.0 文件生成。错误 preimage 的 blob 为：

```text
5d1fa8ad1ab15dd2d860258c88ef75891baf2b6b
```

而 stable 轨道实际使用的官方 v1.3.0 `Pals.tsx` blob 为：

```text
adc7c4d80073b33439a805475fc62ec8567d8b00
```

官方页面在数据表外保留加载态条件分支，旧 0034 hunk 缺少该结构，因此在 `frontend/src/pages/Pals.tsx:95` 冲突。

## 修正

- 只重建 0034 的 Pals.tsx section，其他后端、API 和类型功能保持不变；
- 高级筛选面板插入到 `SaveIndexStatusBar` 与原数据区之间；
- 原有 `loading && pals.length === 0` 分支完整保留；
- 0034 的 Pals.tsx old blob 锁定为官方 v1.3.0 blob；
- 测试使用官方固定夹具执行真实 `git apply --check`；
- 根目录新增 `PATCH-MAINTENANCE.md`，说明补丁生成和覆盖包交付硬规则；
- 仓库验证拒绝 `source/` 下出现任何子目录，防止再次产生 `source/source/`。

## 关键文件

```text
PATCH-MAINTENANCE.md
common/scripts/validate-repository.sh
projects/uitok-palworld-panel/automation/test-pal-inventory-advanced-filters.sh
projects/uitok-palworld-panel/automation/testdata/v1.3.0/frontend/src/pages/Pals.tsx
projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source/0034-add-pal-inventory-advanced-filters.patch
projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source/SHA256SUMS
```

## 版本

```text
仓库版本：0.12.32-hotfix3
当前已发布 stable patch：0.8.15
下一 stable patch：0.8.16
预期 Release：uitok-stable-v1.3.0-p0.8.16
```
