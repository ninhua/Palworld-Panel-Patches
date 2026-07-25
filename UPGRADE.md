# Upgrade v0.12.18 → v0.12.19

本次更新新增只读全服库存浏览器，stable patch 目标为 `0.8.9`。

应用增量包后应确认存在：

```text
projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source/0023-add-global-inventory-browser.patch
```

并确认 manifest 和 required features 包含：

```json
"global-inventory-browser"
```

下一次 Release 标签：

```text
uitok-stable-v1.3.0-p0.8.9
```

功能入口：

```text
世界管理 → 库存管理
```

接口：

```http
GET /api/inventory?q=&owner_type=all&category=&sort=count_desc&limit=200&offset=0
```

该功能直接读取现有 save index，不增加 sidecar 或新运行时依赖。现有一键部署脚本无需修改。

升级后的兼容性报告必须满足：

```json
{
  "excluded_features": [],
  "effective_features": [
    "global-inventory-browser"
  ]
}
```

`effective_features` 实际还会包含其他已启用功能；上例只列出本次新增项。
