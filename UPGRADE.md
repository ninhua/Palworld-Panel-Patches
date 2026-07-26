# Upgrade v0.12.31-hotfix2 → v0.12.31-hotfix3

本次更新为新玩家礼包的 PalDefender 模板列表增加运行时索引读取、分类显示和索引文件筛选。

## 新增补丁

```text
projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source/0032-read-starter-gift-template-indexes.patch
```

## 索引目录

索引文件与 PalDefender 模板放在同一目录：

```text
Pal/Binaries/Win64/PalDefender/Pals/Templates/
```

文件名包含 `索引`、`清单`、`常用`、`毕业`、`index`、`catalog` 或 `list` 时，面板会尝试按索引解析。有效索引支持顶层 `模板`、`清单`、`列表`、`templates` 或 `items` 数组。

条目可包含：

```json
{
  "分类": "战斗",
  "模板名": "BATTLE__Anubis",
  "文件名": "BATTLE__Anubis.json",
  "中文名": "阿努比斯",
  "PalID": "Anubis",
  "英文名": "Anubis"
}
```

关联优先使用 `文件名`，同时兼容无扩展名的 `模板名`。索引只负责显示和筛选；模板 JSON 顶层 `PalID` 仍决定实际帕鲁身份和头像。未命中索引时显示原模板文件名。

## 界面

- 按“分类 · 帕鲁名”显示并稳定排序；
- 按索引文件筛选，可直接选择“常用毕业帕鲁清单”；
- 按分类筛选；
- 搜索分类、中文名、英文名、PalID、昵称、索引名和模板文件名；
- 索引 JSON 自身不会作为可发放模板显示。

## 版本

```text
仓库版本：0.12.31-hotfix3
当前已发布 stable patch：0.8.15
下一 stable patch：0.8.16
预期 Release：uitok-stable-v1.3.0-p0.8.16
```
