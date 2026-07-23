# uitok/palworld-panel v1.2.2 patch target

该目录绑定用户本地保留的 `v1.2.2`，不能假设远端 tag 或 Release 仍可重新下载。

## 开始制作补丁前必须完成

1. 保存完整 v1.2.2 源码快照。
2. 若源码目录包含 `.git`，记录：

```bash
git rev-parse HEAD
git submodule status --recursive
```

3. 生成源码快照：

```bash
tar --sort=name     --mtime='UTC 2026-01-01'     --owner=0 --group=0 --numeric-owner     -czf uitok-palworld-panel-v1.2.2-source.tar.gz     <源码目录>
```

4. 记录：

```bash
sha256sum uitok-palworld-panel-v1.2.2-source.tar.gz
sha256sum <本地原版palpanel二进制>
```

5. 将真实信息填入 `upstream-lock.json` 和 `manifest.json`。

## 目录规划

```text
v1.2.2/
├── upstream-lock.json
├── manifest.json
├── source/
│   └── 0001-add-patch-info-api.patch
├── overlay/
├── build/
└── tests/
```

## 重要限制

只有本地 `palpanel` 二进制而没有对应源码时，不能制作可维护的源码补丁。
此时只能：

- 先取得或恢复 v1.2.2 源码快照；或
- 将第一版定义为严格哈希绑定的 `compiled-overlay`，直接替换完整二进制。
