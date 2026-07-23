# Palworld Panel Patches

仓库版本：`v0.6.2`

用于维护 `uitok/palworld-panel` 的可重复源码补丁、构建测试和 Release 资产。
一键部署脚本由独立流程维护，本仓库只提供明确的补丁接入契约。

## 当前开发基线

```text
源码仓库：uitok/palworld-panel
源码分支：dev
源码提交：5e3c0bce9d33091b3261f82b3e4da062fc35a8a1
兼容目标：v1.2.2
补丁版本：0.3.1-dev.1
兼容状态：source-alias / verified=false
```

## 当前功能

```text
patch-info-api
base-custom-names
base-storage-browser
```

`base-custom-names` 提供：

- 基地列表与详情返回自定义名称元数据；
- 按自定义名称搜索；
- 基地页面编辑名称和恢复原名；
- SQLite 持久化；
- 按当前存档源隔离；
- 不修改 Palworld `.sav` 文件。

API：

```http
PUT /api/bases/{id}/name
DELETE /api/bases/{id}/name
```

写操作要求 `server:control` 权限。

`base-storage-browser` 提供：

- 基地页面“查看仓库”入口；
- 容器数、占用格和物品总量汇总；
- 按本地化物品名或内部 ID 搜索；
- 按容器展示槽位、数量和耐久；
- 存档索引过期提示与失败重试；
- 调用只读 `GET /api/bases/{id}/storage`，并兼容通过基地 `containers` 关联的地图对象容器；
- 不写入存档。

## 补丁结构

```text
projects/uitok-palworld-panel/patches/dev-v1.2.2/
├── upstream-lock.json
├── manifest.template.json
├── source/
│   ├── 0001-add-patch-info-api.patch
│   ├── 0002-add-base-custom-names.patch
│   ├── 0003-add-base-storage-browser.patch
│   ├── 0004-fix-base-storage-container-resolution.patch
│   └── SHA256SUMS
├── build/
│   ├── build.sh
│   └── build-palpanel.sh
├── tests/
│   ├── smoke.sh
│   └── test-relative-output-path.sh
├── LICENSE
└── LICENSE-NOTICE.md
```

构建脚本按文件名顺序应用全部 `source/*.patch`，并先校验 `source/SHA256SUMS`。

## 构建

```text
Actions
→ Build uitok dev patch
→ Run workflow
```

预期 Artifact：

```text
uitok-dev-v1.2.2-patch-0.3.1-dev.1-5e3c0bce9d33
```

Artifact 包含二进制安装包、完整对应源码、manifest、全部补丁、许可证、构建元数据、冒烟日志和 SHA-256。

## 发布

```text
Actions
→ Release uitok dev patch
→ Run workflow
```

预期预发布标签：

```text
uitok-dev-v1.2.2-p0.3.1-dev.1
```

Release 标签不可变；标签已存在时工作流应失败，不覆盖旧资产。

## 验证

```bash
python3 -m pip install -r requirements-ci.txt
bash common/scripts/validate-repository.sh
```

完整 Go、前端和二进制冒烟测试在 GitHub Actions 的 Go 1.25.12 / Node 22 环境执行。
