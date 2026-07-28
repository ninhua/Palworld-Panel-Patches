# Upgrade v0.12.34-hotfix7 → v0.12.34-hotfix8

本次更新在现有 `0038` 内补全索引分类筛选，不新增补丁编号。

## 新增筛选

新玩家礼包和玩家中心的模板发放区域现在共用一套组合筛选器：

```text
索引文件
模板分类
综合分级
用途分类
分类标签
毕业用途
模板状态
```

“模板状态”包含：

```text
毕业帕鲁
当前模板为毕业用途
低阶与过渡
普通模板
未命中索引
```

多个筛选条件按“同时满足”组合。文本搜索同时覆盖模板名、中文名、英文名、PalID、分类、用途、毕业用途、词条中文和夜间工作方式。

## 索引文件

索引仍只读取文件名包含 `index` 或 `索引` 的 JSON，例如：

```text
pal-template-index.json
帕鲁模板索引.json
```

普通 `BATTLE__*.json`、`WORK__*.json` 和 `MOUNT__*.json` 不会作为索引解析。

## 补丁结构

```text
补丁链：0001–0038
修改补丁：0038-add-starter-gift-debug-console-and-rich-template-indexes.patch
新增补丁编号：无
```

## 应用

在当前 `v0.12.34-hotfix7` 仓库根目录直接覆盖：

```bash
unzip -o Palworld-Panel-Patches-overlay-v0.12.34-hotfix7-to-v0.12.34-hotfix8.zip
bash common/scripts/validate-repository.sh
```

## 版本

```text
仓库版本：0.12.34-hotfix8
当前已发布 stable patch：0.8.17
下一 stable patch：0.8.18
预期 Release：uitok-stable-v1.3.0-p0.8.18
```
