# Changelog

## v0.11.0

### Added

- 新增每日一次的 `Auto release uitok stable patch` Workflow。
- 自动选择上游最高正式 `vMAJOR.MINOR[.PATCH]` Release。
- 自动应用当前完整功能补丁链，并把 PatchInfo、OpenAPI 和生成契约重定向到目标稳定版本。
- 自动执行 Go 测试、前端构建、嵌入式二进制构建和 `/api/patch/info` 冒烟测试。
- 构建通过后直接创建 `uitok-stable-vX.Y.Z-pA.B.C` 稳定 Release。
- 新增明确不兼容版本列表 `automation/incompatible-versions.json`。

### Behavior

- 不创建 PR。
- 不创建 Issue。
- 不自动提交稳定轨道目录到 `main`；GitHub Release 是生产脚本的唯一可安装发布信号。
- 补丁冲突、测试失败、构建失败或冒烟失败时，Workflow 直接失败，不创建 Release。
- 稳定兼容按 `target_version`、`verified=true`、SHA256SUMS、包结构和 feature 包含关系判断；上游 commit 仅用于追踪。

### Validation

- 新增稳定版本排序测试，支持 `v1.3` 与 `v1.3.0`。
- 新增 PatchInfo 稳定版重定向测试。
- 仓库校验确认自动化每天只调度一次、不得创建 PR/Issue，并必须直接创建 Release。

## v0.10.3

### Fixed

- 新增 `0012-restore-ai-translation-net-import.patch`。
- 修复 `0011-allow-http-service-endpoints.patch` 删除 `net` 导入后，`classifyProviderRequestError` 仍使用 `net.Error`，导致 Build/Release 编译失败。
- 功能补丁版本保持 `0.8.0-dev.1`，feature、Release tag、Artifact 命名和启动脚本接入规则均不变化。

### Validation

- 在真实 `0001–0011` 补丁链后的源码上复现 `undefined: net`。
- 应用 `0012` 后恢复 `net` 导入并通过 `gofmt`。
- 仓库校验增加 AI 翻译补丁链的 `net` 导入净变化检查，防止后续再次出现同类遗漏。

## v0.10.2

### Changed

- 新增 `0011-allow-http-service-endpoints.patch`。
- AstrBot 插件调用 PalPanel 与 PalPanel 调用 AstrBot 插件均接受 HTTP 或 HTTPS。
- WebDAV、公网 AI 翻译 Base URL、Steam/社区服务器/下载类可配置地址均接受 HTTP 或 HTTPS。
- 公共远程 Mod ZIP 与 Steam Workshop URL 接受 HTTP 或 HTTPS。
- 前端 WebDAV、AI 翻译和 Mod 导入说明同步更新，不再提示必须使用 HTTPS。
- 新增顶级 feature `insecure-endpoint-support`，功能补丁版本升级为 `0.8.0-dev.1`。

### Safety

- 仍拒绝非 HTTP(S) 协议、嵌入凭据和不合法 URL。
- WebDAV 仍拒绝查询参数、片段和不安全远程路径。
- Mod 下载仍执行公网地址、重定向、凭据和大小限制校验。
- 明确提示 HTTP 不提供传输加密。

### Validation

- Go `appconfig` 与 `astrbotclient` 单元测试通过。
- AstrBot URL、签名和操作 Python 测试通过。
- WebDAV、AI Base URL、远程 Mod URL 回归测试已更新或新增。
- OpenAPI、TypeScript/TSX 语法和补丁顺序应用检查通过。

## v0.10.1

### Fixed

- 修复 `0008-add-base-worker-browser.patch` 漏打新文件的问题。
- 正式加入 `backend/internal/api/base_workers.go` 与 `base_workers_test.go`，解决 Release 构建中的 `s.getSaveBaseWorkers undefined`。
- 新增补丁路由处理器静态契约校验：补丁新增路由引用的 `Server` 方法必须在补丁链中存在定义。
- 功能补丁版本保持 `0.7.0-dev.1`，features、Release tag、资产命名和启动脚本接入规则均不变化。

### Validation

- 在仅应用仓库实际 `0001–0009` 的干净源码上复现缺失处理器。
- 应用 `0010-fix-missing-base-worker-handler.patch` 后，路由和实现静态契约通过。

## v0.10.0

### Added

- 新增独立实现的 `base-feed-box-summary` 顶级功能。
- 新增只读接口 `GET /api/bases/{id}/feed-boxes`。
- 基地页面增加桌面端苹果图标与移动端“饲料箱”入口。
- 只识别普通饲料箱和低温保鲜饲料箱，不把普通仓库或冰箱误算为饲料箱。
- 汇总相同物品在多个饲料箱中的总数量与分布箱数，并保留按箱查看。
- 新增饲料箱数、空箱数、占用格、物品种类和物品总量统计。
- 支持按物品名称、内部 ID、饲料箱名称、类型或容器 ID 搜索。
- 补丁版本升级为 `0.7.0-dev.1`，预发布标签为 `uitok-dev-v1.2.2-p0.7.0-dev.1`。

### Safety

- 只读取锁定存档索引中的容器与槽位数据，不修改容器或 Palworld 存档。
- 不推断食物保质期、腐败时间、营养值或其他当前索引未提供的数据。
- 顶级 features 现在为 `patch-info-api`、`base-custom-names`、`base-storage-browser`、`player-notes`、`guild-detail-browser`、`base-worker-browser`、`base-feed-box-summary`。

### Validation

- 新增饲料箱类型过滤、跨箱聚合、空箱保留和普通仓库排除回归测试。
- OpenAPI、生成的 TypeScript 契约和前端 API 映射测试同步更新。

## v0.9.0

### Added

- 新增独立实现的 `base-worker-browser` 顶级功能。
- 新增只读接口 `GET /api/bases/{id}/workers`。
- 基地页面增加桌面端图标与移动端“工作帕鲁”入口。
- 工作帕鲁详情按实例 ID 合并存档索引中的种类、昵称、等级、性别、Rank、状态、远征状态和被动词条。
- 新增总数、平均等级、最高等级、命名数量和种类数量统计。
- 支持按昵称、种类、内部 ID、实例 ID 和被动词条搜索。
- 补丁版本升级为 `0.6.0-dev.1`，预发布标签为 `uitok-dev-v1.2.2-p0.6.0-dev.1`。

### Safety

- 只展示锁定存档索引真实提供的数据；不虚构饱食度、SAN、工作适性等缺失字段。
- 不修改 `Level.sav`、玩家 `.sav`、帕鲁数据或基地数据。
- 顶级 features 现在为 `patch-info-api`、`base-custom-names`、`base-storage-browser`、`player-notes`、`guild-detail-browser`、`base-worker-browser`。

### Validation

- 新增工作帕鲁详情合并与统计回归测试。
- OpenAPI、生成的 TypeScript 契约和前端 API 映射测试同步更新。

## v0.8.0

### Added

- 新增独立实现的 `guild-detail-browser` 顶级功能。
- `GET /api/guilds/{id}` 返回丰富的成员详情、玩家备注/标签及关联基地详情。
- 公会页面增加桌面端和移动端详情入口与响应式侧边抽屉。
- 成员详情展示会长标识、在线状态、等级、最后在线时间、备注和标签。
- 基地详情展示面板自定义名称、坐标、建筑数和工作帕鲁数。
- 补丁版本升级为 `0.5.0-dev.1`，预发布标签为 `uitok-dev-v1.2.2-p0.5.0-dev.1`。

### Safety

- 本功能只读取存档索引与 PalPanel SQLite 元数据，不修改 `Level.sav`、玩家 `.sav` 或基地数据。
- 顶级 features 现在为 `patch-info-api`、`base-custom-names`、`base-storage-browser`、`player-notes`、`guild-detail-browser`。

### Validation

- 新增公会成员注释、会长识别、显式/隐式基地关联和自定义基地名称回归测试。
- OpenAPI 与生成的 TypeScript 契约同步更新。

## v0.7.0

### Added

- 新增独立实现的 `player-notes` 顶级功能。
- 新增 `PUT /api/players/{id}/annotation` 与 `DELETE /api/players/{id}/annotation`。
- 玩家详情增加管理备注编辑、标签编辑和清除操作。
- 玩家列表显示标签，移动端卡片显示备注摘要。
- 玩家搜索支持匹配备注和标签。
- 备注最多 500 个 Unicode 字符；标签最多 8 个，每个最多 24 个字符。
- 注释数据按存档源隔离并持久化在 PalPanel SQLite KV 中。
- 写操作要求 `players:write` 权限。
- 补丁版本升级为 `0.4.0-dev.1`，预发布标签为 `uitok-dev-v1.2.2-p0.4.0-dev.1`。

### Safety

- 不修改 `Level.sav`、玩家 `.sav` 或任何游戏世界数据。
- 顶级 features 现在为 `patch-info-api`、`base-custom-names`、`base-storage-browser`、`player-notes`。

### Validation

- 新增备注标准化、长度限制、标签去重、存档源隔离、搜索和权限回归测试。
- OpenAPI 与生成的 TypeScript 契约同步更新。

## v0.6.3

### Enhanced

- 完善现有 `base-storage-browser`，不新增顶级 feature。
- 基地仓库接口通过 `container.owner_id` 关联存档索引中的地图对象，返回 `container_type` 和本地化 `container_name`。
- 仓库槽位返回现有物品目录中的 `item_icon`，前端使用内置 `/assets/items/*.webp` 图标并提供 SVG 缺图回退。
- 仓库搜索同时支持容器中文名、容器类型、物品中文名和内部 ID。
- OpenAPI、生成的 TypeScript 契约、后端测试和前端 API 映射测试同步更新。
- 功能补丁版本升级为 `0.3.2-dev.1`，预发布标签为 `uitok-dev-v1.2.2-p0.3.2-dev.1`。

### Safety

- 仍为只读展示，不修改容器或 Palworld 存档。
- 顶级 features 仍为 `patch-info-api`、`base-custom-names`、`base-storage-browser`。

## v0.6.2

- 修复基地仓库接口只接受 `owner_type=base`，导致实际由地图对象承载的基地箱子无法返回。
- `GET /api/bases/{id}/storage` 现在同时解析基地记录中的 `containers` 关联，并保留旧的直接 owner 匹配。
- 新增回归测试，覆盖 `map_object` 容器、直接基地容器和无关容器过滤。
- 功能补丁版本升级为 `0.3.1-dev.1`，预发布标签为 `uitok-dev-v1.2.2-p0.3.1-dev.1`。

## v0.6.1

### Fixed

- 修复 `tests/smoke.sh` 仍精确要求旧功能数组，导致 `base-storage-browser` 已构建成功后冒烟测试误判失败。
- 冒烟测试改为检查所需功能集合是否包含 `patch-info-api`、`base-custom-names` 和 `base-storage-browser`，不依赖数组顺序，也不限制未来增加额外功能。
- 功能补丁版本保持 `0.3.0-dev.1`，预发布标签保持 `uitok-dev-v1.2.2-p0.3.0-dev.1`。

## v0.6.0

### Added

- 新增独立实现的 `base-storage-browser` 功能。
- 基地桌面列表和移动卡片增加“查看仓库”入口。
- 复用既有 `GET /api/bases/{id}/storage` 只读接口。
- 新增容器数、占用格、物品总量汇总。
- 新增按本地化物品名和内部物品 ID 搜索。
- 按容器显示槽位、数量及可用耐久信息。
- 新增存档索引过期提示、错误展示和重试。
- 新增前端 API 映射测试。
- 补丁版本升级为 `0.3.0-dev.1`，功能列表增加 `base-storage-browser`。

### Changed

- PatchInfo OpenAPI 契约和生成的 TypeScript 类型同步到 `0.3.0-dev.1`。
- 新预发布标签为 `uitok-dev-v1.2.2-p0.3.0-dev.1`。

### Safety

- 本功能不修改容器、不修改 Palworld 存档，只读取现有存档索引。
- 兼容状态仍为 `source-alias`、`verified=false`。

## v0.5.1

### Fixed

- 修复 `base_custom_names_test.go` 调用不存在的 `newQueryContext`，导致 `palpanel/internal/api` 测试无法编译。
- 改为使用上游实际 Gin 测试方式：`gin.CreateTestContext`、`httptest.NewRecorder` 和 GET 请求查询参数。
- 更新 `0002-add-base-custom-names.patch` 及 `source/SHA256SUMS`。

### Validation

- `git diff --check` 通过。
- 两个补丁可按顺序应用到锁定上游源码。
- 仓库结构、YAML、Shell 和补丁 SHA 校验通过。
- 完整 Go 1.25.12 测试仍由 GitHub Actions 执行。

## v0.5.0

### Added

- 新增独立实现的 `base-custom-names` 功能。
- 新增 `PUT /api/bases/{id}/name` 与 `DELETE /api/bases/{id}/name`。
- 自定义名称持久化到 PalPanel SQLite KV，并按活动存档源隔离。
- 基地列表、详情和搜索支持自定义名称，同时保留原始名称字段。
- 基地前端页面增加编辑名称与恢复原名操作。
- 新增后端持久化、隔离、校验和权限测试，以及前端 API 测试。
- 补丁版本升级为 `0.2.0-dev.1`，功能列表增加 `base-custom-names`。
- 构建脚本支持按顺序应用多个补丁并验证补丁 SHA-256。

### Changed

- 新预发布标签为 `uitok-dev-v1.2.2-p0.2.0-dev.1`。
- Release 工作流不再覆盖已存在的同名标签。
- 脚本集成代码不属于本次功能补丁交付范围。

### Limitations

- 仍基于固定 dev commit，兼容状态保持 `source-alias`、`verified=false`。
- 本地环境缺少 Go 1.25.12 和完整依赖缓存，完整编译测试需由 GitHub Actions 执行。

## v0.4.2

### Added

- 新增 `Release uitok dev patch` 手动发布工作流。
- 构建通过后自动创建或更新固定 GitHub 预发布。
- Release 同时发布二进制包、完整对应源码、manifest、补丁、许可证、冒烟日志和 `SHA256SUMS`。
- 新增 Host Wine AIO `v1.0.40` 完整脚本。
- 新增固定补丁通道元数据 `patch-channel.json`。
- AIO 支持远程 Release 下载以及本地补丁包测试。
- AIO 对补丁包执行外层、内层、manifest 和二进制四层校验。
- AIO 支持原子替换、原版备份、状态记录和失败放行。
- AIO 记录功能补丁后二进制 SHA 与 PalDefender URL 运行时补丁后的最终 SHA。

### Compatibility

- 当前允许面板版本：`v1.2.1,v1.2.2`。
- 补丁源码：`uitok/palworld-panel:dev@5e3c0bce9d33091b3261f82b3e4da062fc35a8a1`。
- 兼容目标仍为未精确验证的 `v1.2.2`。

## v0.4.1

### Fixed

- 修复 `build-palpanel.sh` 在 `backend/` 中执行 `go build` 时错误解析相对输出路径。
- 将目标二进制路径转换为绝对路径后再传给 `go build -o`。
- 将总构建输出目录转换为绝对路径，避免后续打包步骤受当前工作目录影响。
- 在 `go build` 后强制检查目标文件是否存在、非空且可执行。
- 构建失败时输出明确的目标路径和源码目录。
- 增加相对输出路径回归测试，并纳入 `Validate repository`。

## v0.4.0

### Added

- 基于 `uitok/palworld-panel:dev` commit `5e3c0bce9d33091b3261f82b3e4da062fc35a8a1` 建立第一个真实补丁。
- 新增公开接口 `GET /api/patch/info`。
- 新增 PatchInfo OpenAPI 契约和生成的 TypeScript 类型。
- 新增 API 单元测试和路由契约测试。
- 新增确定性 Linux amd64 `palpanel` 构建脚本。
- 新增原版与补丁版 SHA-256 生成。
- 新增运行时 API 冒烟测试。
- 新增补丁构建 GitHub Actions。
- 新增补丁后完整源码归档和 GPL-3.0 许可证材料。

### Limitations

- 兼容目标 `v1.2.2` 仍标记为 `verified=false`。
- CI 生成的原版 SHA-256 是该 dev commit 的可重复构建结果，不保证等于已删除的官方 v1.2.2 Release 二进制。
- 在接入 AIO 前仍需获取用户本地 v1.2.2 `palpanel` 的 SHA-256。

## v0.3.0

- 新增 dev 源码探测工作流并锁定真实源码结构。

## v0.2.4

- 修复版本元数据同步。
