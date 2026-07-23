# dev → v1.2.2 patch line

该目录用于维护基于 `uitok/palworld-panel:dev` 精确 commit、面向运行版本 v1.2.2 的补丁。

预计结构：

```text
dev-v1.2.2/
├── upstream-lock.json
├── manifest.json
├── source/
│   └── 0001-add-patch-info-api.patch
├── build/
│   └── build.sh
├── overlay/
└── tests/
    └── smoke.sh
```

当前阶段只生成源码探测结果。取得真实源码快照后再写 patch。
