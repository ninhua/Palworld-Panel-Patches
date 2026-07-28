# Upgrade v0.12.34-hotfix3 → v0.12.34-hotfix4

本次覆盖包收紧 Pal 模板索引扫描策略，避免 Templates 目录中数百个普通模板 JSON 被逐个读取和反序列化。直接在仓库根目录覆盖即可。

## 新增补丁

```text
projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source/0039-scan-only-index-keyword-json.patch
```

## 索引文件命名

索引 JSON 与模板 JSON 仍共同放在：

```text
Pal/Binaries/Win64/PalDefender/Pals/Templates
```

只有文件名包含以下任一关键字的 `.json` 会被读取为索引候选：

```text
index   # 大小写不敏感
索引
```

推荐命名：

```text
pal-template-index.json
帕鲁模板索引.json
```

普通模板，例如 `BATTLE__Anubis.json`、`WORK__Anubis.json` 和 `MOUNT__JetDragon.json`，不会被打开进行索引解析。目录文件名枚举仍会执行，用于列出模板，但其成本远低于读取并解析全部 JSON。

## 版本

```text
仓库版本：0.12.34-hotfix4
当前已发布 stable patch：0.8.17
下一 stable patch：0.8.18
预期 Release：uitok-stable-v1.3.0-p0.8.18
```

## 覆盖后验证

```bash
bash common/scripts/validate-release-metadata.sh
bash common/scripts/validate-repository.sh
```
