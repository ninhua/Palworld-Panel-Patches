# Upgrade v0.12.32 → v0.12.32-hotfix1

本次更新修复 stable 迁移在 validation checkpoint `0032-read-starter-gift-template-indexes.patch` 被 Go 编译阻断的问题。

## 问题

`0032` 在 `backend/internal/api/starter_gift.go` 新增了：

```go
func firstNonEmpty(values ...string) string
```

同一 `api` 包的 `save_index.go` 已存在同名函数，因此累计补丁应用后出现：

```text
firstNonEmpty redeclared in this block
```

## 修正

```text
firstNonEmpty
→ starterGiftFirstNonEmpty
```

仅修改 0032 内部辅助函数名称及其调用点，不改变索引解析、中文名、分类或筛选行为。

更新文件：

```text
projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source/0032-read-starter-gift-template-indexes.patch
projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source/SHA256SUMS
projects/uitok-palworld-panel/automation/test-starter-gift-template-indexes.sh
```

## 版本

```text
仓库版本：0.12.32-hotfix1
当前已发布 stable patch：0.8.15
下一 stable patch：0.8.16
预期 Release：uitok-stable-v1.3.0-p0.8.16
```
