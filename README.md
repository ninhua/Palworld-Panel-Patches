# Palworld Panel Patches

仓库版本：`v0.12.4`

用于维护 `uitok/palworld-panel` 的可重复源码补丁、构建测试和 Release 资产。
一键部署脚本由独立流程维护，本仓库只提供明确的补丁接入契约。

## 当前维护基线

```text
上游项目：uitok/palworld-panel
当前维护目标：v1.3.0
仓库轨道：patches/candidate-v1.3.0
稳定补丁版本：0.8.1
候选状态：candidate / 未发布前 verified=false
```

`candidate-v1.3.0` 是当前日常维护入口，并且是自包含轨道。它拥有自己的 `source/`、
`build/`、manifest 和许可文件；所有补丁应用、测试和构建均以官方 `v1.3.0` tag 为基线。只有完整 stable Workflow
通过后，Release manifest 才会写入 `mode=exact`、`target_version=v1.3.0` 和
`verified=true`。

本完整包不包含旧版本活动轨道。`candidate-v1.3.0` 是唯一源码补丁入口；后续版本从最新的较旧 stable Release 源码包派生。

## 当前功能

```text
patch-info-api
base-custom-names
base-storage-browser
player-notes
guild-detail-browser
base-worker-browser
base-feed-box-summary
insecure-endpoint-support
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


## HTTP/HTTPS 兼容性

`insecure-endpoint-support` 统一取消以下地址的“公网必须 HTTPS”限制：

- PalPanel 调用 AstrBot 插件的 `PALPANEL_ASTRBOT_PLUGIN_URL`；
- AstrBot 插件调用 PalPanel 的 `panel_url`；
- WebDAV 备份地址；
- OpenAI-compatible AI 翻译 Base URL；
- Steam API、社区服务器 API、SteamCMD 与 UE4SS 等可配置下载地址；
- 公共远程 Mod ZIP 和 Steam Workshop URL。

以上地址均接受 `http://` 或 `https://`。仍保留绝对 URL、协议类型、嵌入凭据、查询参数、WebDAV 远程路径、Mod 下载目标公网地址、重定向次数和文件大小等校验。HTTP 不提供传输加密，跨公网使用时由部署者自行承担明文传输风险。

`0012-restore-ai-translation-net-import.patch` 是编译修复补丁，只恢复 AI 翻译错误分类仍需使用的 Go `net` 导入，不改变 feature 或运行行为。

## 补丁结构

当前活动轨道：

```text
projects/uitok-palworld-panel/patches/candidate-v1.3.0/
├── track.json
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
│   ├── 0011-allow-http-service-endpoints.patch
│   ├── 0012-restore-ai-translation-net-import.patch
│   └── SHA256SUMS
├── build/
│   ├── build.sh
│   └── build-palpanel.sh
├── LICENSE
└── LICENSE-NOTICE.md
```

该目录是自包含的 v1.3.0 stable candidate。构建脚本按文件名顺序应用全部
`source/*.patch`，先校验 `source/SHA256SUMS`，再以官方 `v1.3.0` 源码执行
迁移、检查点编译和 clean-room 复验。

完整包不包含历史 dev 目录，所有 GitHub Actions workflow 只读取 `candidate-v1.3.0`。

## 稳定版自动发布

每天检查一次上游正式 Release，或通过 `workflow_dispatch` 指定正式版本。

```text
创建 candidate 工作区
→ 从最新更旧 stable Release 导入 source-chain
→ 逐补丁应用、编译检测和状态记录
→ 生成 active-source 与 merged patch
→ 在全新官方源码上只应用 merged patch
→ 全量测试、构建和运行时 smoke
→ 固化 stable 工作区
→ 发布五文件 immutable Release
```

失败时不创建 Release、PR 或 Issue；兼容报告与日志写入 `migration/vX.Y.Z` 分支。成功后 main 保留 `stable-vX.Y.Z` 审计工作区。

后续版本优先从上一个 stable 源码包内的 `.palpatch/source-track` 派生。只有首次 stable 或 legacy 迁移才使用 bootstrap/旧 merged patch。

Release 顶层严格限制为安装包、源码包、`manifest.json`、`compatibility-report.json` 和 `SHA256SUMS`。全部补丁与审计文件保留在包内。

## 验证

```bash
python3 -m pip install -r requirements-ci.txt
bash common/scripts/validate-repository.sh
```

完整 Go、前端和二进制冒烟测试在 GitHub Actions 的 Go 1.25.12 / Node 22 环境执行。


## v1.3.0 stable 校验修复

稳定版发布配置当前为：

```text
目标上游：v1.3.0
稳定补丁版本：0.8.1
预期 Release：uitok-stable-v1.3.0-p0.8.1
```

`manifest.files["bin/palpanel"].original_sha256` 现在直接取自上游正式 Release
`palpanel_v1.3.0_linux_amd64.tar.gz` 内的 `bin/palpanel`。构建过程仍会从源码重建
未打补丁二进制用于编译验证，但该重建值只记录在 `build-metadata.json` 的
`rebuilt_original_palpanel_sha256`，不再用于生产安装前置校验。

这样可以避免上游正式 Release 与二次源码构建因构建时间、前端产物或工具链差异而产生
不同 SHA-256，导致一键部署正确地拒绝安装并回滚。

## v0.12 稳定版更新链路

上游正式 Release 更新后，自动化按状态机迁移补丁：

```text
detected
→ workspace-created
→ patches-imported
→ testing
→ merged
→ releasable
→ released
```

核心规则：

- 为目标版本创建 `candidate-vX.Y.Z` 工作区；
- 从最新且更旧的 verified stable Release 导入补丁链，首次 stable 才使用 bootstrap；
- 按补丁顺序记录 `compatible`、`adapted`、`incompatible`、`blocked`、`superseded`；
- 任一必需功能失败即禁止 Release，并把 candidate 工作区写入 `migration/vX.Y.Z` 分支；
- 可用补丁生成一个 merged patch，再在全新的官方源码上只应用 merged patch 完整复验；
- 成功后固化 `stable-vX.Y.Z` 工作区并发布不可变 Release；
- Release 顶层固定为安装包、源码包、manifest、兼容报告和 SHA256SUMS 五个文件。

完整补丁链、merged patch、构建元数据、smoke 日志和派生信息保留在安装包及源码包内部。
