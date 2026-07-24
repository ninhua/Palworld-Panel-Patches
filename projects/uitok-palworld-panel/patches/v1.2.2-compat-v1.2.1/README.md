# v1.2.2 compatibility development using v1.2.1 source

这是临时开发目标，不是真正的 v1.2.2 上游源码补丁。

## 规则

- `upstream.version` 必须写 `v1.2.1`。
- `compatibility.target_version` 写 `v1.2.2`。
- `compatibility.mode` 写 `source-alias`。
- `compatibility.verified` 保持 `false`。
- Release 标签必须包含 `compat` 或 `dev`。
- 不得发布为 `uitok-v1.2.2-pX.Y.Z`。

推荐开发标签：

```text
uitok-v1.2.2-compat-v1.2.1-p0.1.0-dev.1
```

真正取得并验证 v1.2.2 后，再迁移为精确补丁目录。
