# Upgrade v0.12.34-hotfix5 → v0.12.34-hotfix6

本次更新只修复未发布 `0038` 中 `PalWorkspace.tsx` 的 unified-diff 行布局，不新增 `0039` 或其他功能补丁。

## 根因

旧 hotfix5 虽然去除了 `filler` 文本本身，但 diff 仍由删除大量中间源码的拼接文件生成。因此五个 hunk header 使用了不连续的伪造行号：

```text
1, 22, 57, 63, 83
```

官方 `uitok/palworld-panel v1.3.0` 文件中的真实起始行是：

```text
1, 28, 69, 75, 270
```

前几个 hunk 产生的 offset 会影响后续搜索，最终在真实查询区域失败。

## 修正

- 直接替换 `0038-add-starter-gift-debug-console-and-rich-template-indexes.patch`，没有新增补丁编号。
- `PalWorkspace.tsx` section 锁定以下 hunk：

```text
@@ -1,6 +1,7 @@
@@ -28,4 +29,6 @@
@@ -69,4 +72,10 @@
@@ -75,4 +84,22 @@
@@ -270,4 +297,15 @@
```

- 回归测试使用官方 Git blob `b36deecc0ca8a0c0344ae244b3f49b6c8ecf1a44` 的 421 行布局，不再使用紧凑拼接夹具。

## 应用

在当前 `v0.12.34-hotfix5` 仓库根目录直接覆盖：

```bash
unzip -o Palworld-Panel-Patches-overlay-v0.12.34-hotfix5-to-v0.12.34-hotfix6.zip
bash common/scripts/validate-repository.sh
```

## 版本

```text
仓库版本：0.12.34-hotfix6
当前已发布 stable patch：0.8.17
下一 stable patch：0.8.18
预期 Release：uitok-stable-v1.3.0-p0.8.18
```
