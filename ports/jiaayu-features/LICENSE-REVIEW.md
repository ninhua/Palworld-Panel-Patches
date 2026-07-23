# License review

## Reference repository

```text
Jiaayu/palworld-panel
```

Its user-facing documentation was used only to identify the behavior called “据点重命名”. An explicit source license has not been confirmed for this work item.

## Decision for `base-custom-names`

- Implementation mode: independent behavior reimplementation.
- Source copied from reference repository: none.
- Target source basis: `uitok/palworld-panel` GPL-3.0 source only.
- Persistence model: PalPanel SQLite KV metadata, not Palworld save mutation.
- New patch source and resulting binary: GPL-3.0 as a modification of the target project.

## Checklist

- [x] 已记录来源仓库。
- [ ] 已确认参考项目许可证。
- [x] 未复制参考仓库源码。
- [x] 已采用独立行为实现。
- [x] 已确认目标修改受 GPL-3.0 覆盖。
- [x] 未复制密钥、存档、用户数据或构建生成物。
