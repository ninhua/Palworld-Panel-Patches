# dev → v1.2.2 patch line

## Source lock

```text
repository: uitok/palworld-panel
ref: dev
commit: 5e3c0bce9d33091b3261f82b3e4da062fc35a8a1
target: v1.2.2
```

## Patch 0.1.0-dev.1

新增：

```http
GET /api/patch/info
```

返回示例：

```json
{
  "ok": true,
  "data": {
    "upstream": {
      "repository": "uitok/palworld-panel",
      "ref": "dev",
      "commit": "5e3c0bce9d33091b3261f82b3e4da062fc35a8a1"
    },
    "compatibility": {
      "target_version": "v1.2.2",
      "verified": false
    },
    "patch": {
      "version": "0.1.0-dev.1",
      "repository": "ninhua/Palworld-Panel-Patches",
      "features": ["patch-info-api"]
    },
    "build": {
      "version": "v1.2.2-compat-p0.1.0-dev.1",
      "commit": "5e3c0bce9d33091b3261f82b3e4da062fc35a8a1",
      "build_time": "2026-07-23T09:13:44Z"
    }
  }
}
```

## Build scope

本补丁只构建：

```text
bin/palpanel
```

不会重复构建：

```text
bin/sav-cli
bin/palcalc-bridge
```

现有 AIO 可继续使用原来的两个侧车。
