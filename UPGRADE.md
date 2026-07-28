# Upgrade v0.12.34-hotfix2 → v0.12.34-hotfix3

本次覆盖包新增新玩家礼包调试控制台和数据驱动的 Pal 模板索引展示。直接在仓库根目录覆盖即可，不会修改已发布的 `stable-v1.3.0` 历史工作区。

## 新增补丁

```text
projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source/0038-add-starter-gift-debug-console-and-rich-template-indexes.patch
```

## 新玩家判定与调试

- “玩家判定”页逐人显示 `seen / online / rearm / grant` 证据和判定原因。
- 可标记“下次进入视为新玩家”；在线玩家需先离线，再进入时触发。
- 已有失败或中断任务可“补发未完成”，已完成任务或需要重复验证时可“完整重发”。
- 发放记录显示百分比、当前阶段、PalDefender 实际 UserId 和逐批事件日志。

## Pal 模板索引

索引 JSON 与模板 JSON 一起放入：

```text
Pal/Binaries/Win64/PalDefender/Pals/Templates
```

索引文件名可使用任意 ASCII 或中文名称，不需要包含 `index`、`索引` 等关键字。普通模板 JSON 会被自动忽略。支持用户提供格式中的 `模板` 数组及分类、用途、毕业标记、词条等字段。

## 版本

```text
仓库版本：0.12.34-hotfix3
当前已发布 stable patch：0.8.17
下一 stable patch：0.8.18
预期 Release：uitok-stable-v1.3.0-p0.8.18
```

## 覆盖后验证

```bash
bash common/scripts/validate-release-metadata.sh
bash common/scripts/validate-repository.sh
```
