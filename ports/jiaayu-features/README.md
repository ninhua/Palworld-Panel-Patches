# Jiaayu feature ports

该目录用于记录从 `Jiaayu/palworld-panel` 研究和移植功能的过程。

它不是 Jiaayu 面板的构建目录，也不直接产出 Jiaayu 面板发行版。

## 每个功能目录

```text
<feature-id>/
├── feature.port.json
├── source-notes.md
├── api-mapping.md
├── ui-mapping.md
└── tests.md
```

## 推荐实现优先级

1. 只读数据侧车；
2. 后端适配层；
3. 前端页面；
4. 写操作和服务端控制。

第三方源码不能未经许可证检查直接复制。优先采用重新实现或接口适配。
