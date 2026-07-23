# Jiaayu feature ports

该目录用于记录从 `Jiaayu/palworld-panel` 研究和移植功能的过程。

它不是 Jiaayu 面板构建目录，也不直接产出 Jiaayu 面板发行版。

每个功能建议使用：

```text
<feature-id>/
├── feature.port.json
├── source-notes.md
├── api-mapping.md
├── ui-mapping.md
└── tests.md
```

实现优先级：只读数据侧车 → 后端适配 → 前端页面 → 写操作和服务端控制。

第三方源码必须先检查许可证。优先采用重新实现或接口适配，而不是直接复制。
