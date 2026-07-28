# Upgrade v0.12.34-hotfix4 → v0.12.34-hotfix5

本次更新修复稳定补丁迁移失败，并把未发布的同功能修正合并回 `0038`。由于需要删除旧 `0039` 文件，不能只依赖 ZIP 覆盖；请使用更新包内的应用脚本。

## 根因

失败位置：

```text
frontend/src/components/gm/PalWorkspace.tsx:35
```

旧 `0038` 的该文件 section 是基于裁剪测试夹具生成的，hunk 中包含官方源码不存在的：

```text
// filler a
// filler b
// filler c
```

因此局部测试可以通过，但在官方 `uitok/palworld-panel v1.3.0` 累计工作区上无法应用。

## 补丁合并

最终补丁链只保留：

```text
0038-add-starter-gift-debug-console-and-rich-template-indexes.patch
```

以下补丁已删除，其功能已合并进 `0038`：

```text
0039-scan-only-index-keyword-json.patch
```

合并后的 `0038` 同时包含：

- 新玩家判定可视化、人工 next-login 标记、补发和完整重发；
- 发放阶段、百分比和事件时间线；
- 丰富 Pal 模板索引与帕鲁图片；
- 仅解析文件名包含 `index` 或 `索引` 的索引 JSON。

## 应用

在当前仓库根目录执行：

```bash
tmpdir="$(mktemp -d)"
unzip -o Palworld-Panel-Patches-overlay-v0.12.34-hotfix4-to-v0.12.34-hotfix5.zip -d "${tmpdir}"
bash "${tmpdir}/apply-overlay.sh" .
rm -rf "${tmpdir}"
```

应用脚本会先校验增量包，再删除旧 `0039`、覆盖变更文件，并核对目标版本与源码补丁 SHA-256。

## 版本

```text
仓库版本：0.12.34-hotfix5
当前已发布 stable patch：0.8.17
下一 stable patch：0.8.18
预期 Release：uitok-stable-v1.3.0-p0.8.18
```

## 覆盖后验证

```bash
bash common/scripts/validate-release-metadata.sh
bash common/scripts/validate-repository.sh
```
