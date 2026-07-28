# Upgrade v0.12.34-hotfix6 → v0.12.34-hotfix7

本次更新只修复未发布 `0038` 的真实 preimage 上下文和错误回归夹具，不新增补丁编号。

## 根因

`PalWorkspace.tsx` 官方 `v1.3.0` 源码为：

```tsx
  const exportedQuery = useQuery({
    queryKey: ['paldefender-gm', 'exported-templates', identifier],
    queryFn: () => palDefenderGMApi.exportedPalTemplates(identifier),
    enabled: Boolean(identifier),
  });

  const directGrant = async () => {
    const level = Number(palLevel);
```

hotfix6 的第四个 hunk 却要求：

```tsx
  const directGrant = async () => {

```

即错误地把下一行写成空白行。旧回归又从补丁自身的 old-side context 生成测试文件，因此把同一个错误空行复制进夹具，造成测试通过但 Actions 必然失败。

## 修正

- 继续直接替换 `0038-add-starter-gift-debug-console-and-rich-template-indexes.patch`。
- `PalWorkspace.tsx` hunk 锁定为：

```text
@@ -1,6 +1,7 @@
@@ -30,4 +31,6 @@
@@ -71,4 +74,10 @@
@@ -77,4 +86,22 @@
@@ -270,4 +297,15 @@
```

- 第四个 hunk 以真实的 `const level = Number(palLevel);` 作为尾部 context。
- 测试夹具不再从补丁反向生成，改为独立声明官方 blob `b36deecc0ca8a0c0344ae244b3f49b6c8ecf1a44` 的精确相邻行和 423 行布局。

## 应用

在当前 `v0.12.34-hotfix6` 仓库根目录直接覆盖：

```bash
unzip -o Palworld-Panel-Patches-overlay-v0.12.34-hotfix6-to-v0.12.34-hotfix7.zip
bash common/scripts/validate-repository.sh
```

## 版本

```text
仓库版本：0.12.34-hotfix7
当前已发布 stable patch：0.8.17
下一 stable patch：0.8.18
预期 Release：uitok-stable-v1.3.0-p0.8.18
```
