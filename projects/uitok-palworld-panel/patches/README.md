# Patch versions

正常补丁目录使用精确上游版本：

```text
patches/v1.2.1/
patches/v1.2.2/
```

临时兼容测试不得伪造上游版本，应使用：

```text
patches/v1.2.2-compat-v1.2.1/
```

其中 manifest 必须保持：

```json
{
  "upstream": {
    "version": "v1.2.1"
  },
  "compatibility": {
    "mode": "source-alias",
    "target_version": "v1.2.2",
    "verified": false,
    "notes": "Temporary compatibility test only."
  }
}
```

只有在真实 v1.2.2 环境完成测试后，才可以建立真正的：

```text
patches/v1.2.2/
```

并将兼容性标记设为 `exact`。
