# Palworld Panel Patches

仓库版本：`v0.10.1`

用于维护 `uitok/palworld-panel` 的可重复源码补丁、构建测试和 Release 资产。
一键部署脚本由独立流程维护，本仓库只提供明确的补丁接入契约。

## 当前开发基线

```text
源码仓库：uitok/palworld-panel
源码分支：dev
源码提交：5e3c0bce9d33091b3261f82b3e4da062fc35a8a1
兼容目标：v1.2.2
补丁版本：0.7.0-dev.1
兼容状态：source-alias / verified=false
```

## 当前功能

```text
patch-info-api
base-custom-names
base-storage-browser
player-notes
guild-detail-browser
base-worker-browser
base-feed-box-summary
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
- 按容器中文名、容器类型、本地化物品名或内部 ID 搜索；
- 显示容器类型和本地化容器名称；
- 使用内置 WebP 物品图标，缺图时显示 SVG 占位图标；
- 按容器展示槽位、数量和耐久；
- 存档索引过期提示与失败重试；
- 调用只读 `GET /api/bases/{id}/storage`，并兼容通过基地 `containers` 关联的地图对象容器；
- 不写入存档。

`player-notes` 提供：

- 在玩家详情中保存最多 500 字的管理备注；
- 为玩家添加最多 8 个标签，每个标签最多 24 个字符；
- 玩家列表显示标签，移动端卡片显示备注摘要；
- 玩家搜索支持备注和标签；
- 数据按存档源隔离并持久化在 PalPanel SQLite KV 中；
- 写操作要求 `players:write` 权限；
- 不修改 Palworld 玩家存档。

API：

```http
PUT /api/players/{id}/annotation
DELETE /api/players/{id}/annotation
```

`guild-detail-browser` 提供：

- 公会列表增加桌面端和移动端“查看详情”入口；
- 公会详情展示会长、成员在线状态、等级、最后在线时间；
- 复用 `player-notes` 展示成员备注和标签；
- 展示公会关联基地、自定义基地名称、坐标、建筑数和工作帕鲁数；
- 详情数据来自只读存档索引与 PalPanel 元数据，不修改游戏存档。

API：

```http
GET /api/guilds/{id}
```

`base-worker-browser` 提供：

- 基地页面增加桌面端图标和移动端“工作帕鲁”入口；
- 调用只读 `GET /api/bases/{id}/workers`；
- 按实例 ID 合并工作帕鲁与存档索引中的详细帕鲁数据；
- 展示帕鲁种类、昵称、等级、性别、Rank、状态、远征状态和被动词条；
- 提供总数、平均等级、最高等级和种类数统计；
- 支持按昵称、种类、内部 ID、实例 ID 或被动词条搜索；
- 仅显示索引真实提供的数据，不伪造饱食度、SAN 或工作适性；
- 不修改帕鲁或基地存档。

API：

```http
GET /api/bases/{id}/workers
```


`base-feed-box-summary` 提供：

- 基地页面增加桌面端苹果图标和移动端“饲料箱”入口；
- 调用只读 `GET /api/bases/{id}/feed-boxes`；
- 识别普通饲料箱与低温保鲜饲料箱，排除普通仓库和冰箱；
- 汇总相同物品在多个饲料箱中的总数量和分布箱数；
- 展示饲料箱数、空箱数、占用格、物品种类和物品总量；
- 支持按物品、饲料箱名称、类型或内部 ID 搜索；
- 使用内置物品图标并保留按箱查看；
- 不推断当前索引未提供的腐败时间、营养或保质期数据；
- 不修改容器或 Palworld 存档。

API：

```http
GET /api/bases/{id}/feed-boxes
```

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
│   ├── 0005-enhance-base-storage-display.patch
│   ├── 0006-add-player-notes.patch
│   ├── 0007-add-guild-detail-browser.patch
│   ├── 0008-add-base-worker-browser.patch
│   ├── 0009-add-base-feed-box-summary.patch
│   ├── 0010-fix-missing-base-worker-handler.patch
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
uitok-dev-v1.2.2-patch-0.7.0-dev.1-5e3c0bce9d33
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
uitok-dev-v1.2.2-p0.7.0-dev.1
```

Release 标签不可变；标签已存在时工作流应失败，不覆盖旧资产。

## 验证

```bash
python3 -m pip install -r requirements-ci.txt
bash common/scripts/validate-repository.sh
```

完整 Go、前端和二进制冒烟测试在 GitHub Actions 的 Go 1.25.12 / Node 22 环境执行。
