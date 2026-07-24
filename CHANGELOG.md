# Changelog

## v0.12.3

### Fixed

- 移除活动链路对 `dev-v1.2.2` 的依赖；`candidate-v1.3.0` 改为拥有 source、build、manifest 和许可文件的自包含稳定维护轨道。
- `validate-all.sh` 不再硬编码执行 `dev-v1.2.2/tests`，改为执行稳定自动化的 active-track 构建回归。
- 仓库 validator 不再从 `dev-v1.2.2/source` 读取补丁契约，并明确拒绝 active candidate 继续使用 `inherits`。
- 退役旧的 dev 构建和 dev Release workflows，避免稳定维护期间继续触发 dev 通道。

### Migration

- 升级脚本将现有历史补丁、构建脚本和许可文件一次性复制到 `candidate-v1.3.0`，随后所有构建和校验只读取该目录。
- `dev-v1.2.2` 目录可继续作为不可变历史归档存在，但不再是任何自动化入口。

## v0.12.2

### Fixed

- 修复逐补丁迁移器在 `0008-add-base-worker-browser.patch` 应用后立即编译，因后置纠正补丁 `0010-fix-missing-base-worker-handler.patch` 尚未到达而错误回滚整段累计上下文。
- `0008`、`0009` 现在保持累计应用状态并在 `0010` 后统一执行后端编译与前端 lint；`0011` 在 `0012` 恢复 Go `net` 导入后统一验证。
- 修复前置补丁被回滚后导致 `0009`、`0011` 出现连锁 `patch does not apply` 的误判；这些冲突不再被错误标记为独立的 v1.3.0 rebase 失败。
- 修复旧 stable Release 的 `SHA256SUMS` 使用 `*filename` 或 `./filename` 格式时，`prepare-source-track.sh` 误报“找不到 manifest.json”。
- 最终 Release 的 `SHA256SUMS` 改为在两个归档、manifest 和 compatibility report 全部定稿后统一生成，并立即按严格五文件集合复验。

### Changed

- `patch-catalog.json` 新增显式 `validation_checkpoint`；补丁仍逐个应用和记录，但允许一组源补丁在纠正补丁到达前处于临时不可编译状态。
- 无实际源码差异的补丁标记为 `superseded`，不写入 active source；整条链最终无差异时以 `no-release-needed` 成功结束，不创建空 Release。
- 失败汇总步骤直接输出 compatibility report 中的首个失败补丁和原因，不再只显示通用的 candidate 持久化错误。
- stable Release workflow 在版本检测和构建前运行与 Validate workflow 相同的统一 preflight。

### Validation

- 新增“先引用缺失 handler、后置补丁补齐 handler”的真实 Go 编译检查点回归。
- 新增 GNU SHA256SUMS 文本标记、二进制标记、`./` 前缀、缺失资产和哈希不匹配回归。
- 五文件布局测试会同时验证生成端校验表和消费端解析器。

## v0.12.1

### Fixed

- 修复 `test-relative-output-path.sh` 的 fake npm 仍只接受旧命令集，导致完整构建脚本执行 `npm run lint` 时错误失败。
- fake npm 现在接受并记录 `npm ci --no-audit --no-fund`、`npm run lint`、`npm run test` 和 `npm run build`，并校验顺序与参数。

### Changed

- 新增统一入口 `common/scripts/validate-all.sh`，集中执行仓库静态验证、相对输出路径回归和 stable 自动化测试。
- `.github/workflows/validate.yml` 与 stable Release workflow 改为调用同一校验入口；发布前置检查失败时不会进入版本检测、构建或发布阶段。

## v0.12.0

### Changed

- 将上游 stable 更新改为持久化工作区状态机：创建 candidate、导入旧 stable 补丁链、逐补丁检测、标记不兼容、生成 merged patch、clean-room 复验、固化 stable 并发布 Release。
- 后续版本不再把临时 `.work/source-track` 作为唯一迁移记录；失败候选写入 `migration/vX.Y.Z` 分支，成功工作区写入 main 的 `stable-vX.Y.Z`。
- Release 顶层改为严格五文件白名单，不再单独上传 `0001`、`0002` 等补丁及零散审计文件。
- 新版源码包内嵌 `.palpatch/source-track`，后续上游版本从最新更旧 stable Release 的源码包派生。

### Fixed

- 修复 Run #5 中旧 Axios mock 适配器重复插入顶层 `status` 导致的 TS1117。新版适配器先解析对象字面量顶层属性，只为缺失 `status` 的 mock 补充字段。
- 可安全清理旧适配器紧邻 `data` 注入的 `status: 200`，同时保留上游已有状态码。
- 增加 `aiTranslation.test.ts`、`communityServers.test.ts`、`guilds.test.ts`、`mods.test.ts`、`monitor.test.ts` 和 `setup.test.ts` 回归夹具。

### Validation

- 新增逐补丁迁移器、candidate/stable 工作区持久化及前端 mock 去重回归测试。
- clean-room 阶段重新执行 merged patch 应用、gofmt、OpenAPI 生成、Go 全量测试、前端 lint/Vitest/build、Linux amd64 构建及 `/api/patch/info` smoke test。
- 任一阶段失败均不创建 Release。

## v0.11.5

### Fixed

- 修复 Run #5 中前端测试适配器无条件插入 `status: 200`，造成已有 `status` 的 mock 出现 TypeScript `TS1117` 重复属性错误。
- 适配器改为解析 `apiClient` mock 对象的顶层属性；仅当存在顶层 `data` 且缺少顶层 `status` 时才补充状态码。
- 已有 `status` 位于 `data` 前方或后方时均保持原样；`data` 内部的嵌套 `status` 不会被误判。

### Changed

- 当前补丁维护入口切换为 `projects/uitok-palworld-panel/patches/candidate-v1.3.0`。
- 配置新增 `maintenance_target_version=v1.3.0`；候选轨道显式继承旧 `dev-v1.2.2` 历史补丁链，但实际构建基线始终为官方 v1.3.0 tag。
- stable Release 顶层不再上传 `0001`、`0002` 等每个源补丁文件，也不再生成 `PATCH-SHA256SUMS`。
- 完整源补丁链继续保存在安装包的 `source/source-chain/` 和完整源码包内，审计能力不受影响。

### Validation

- 增加“已有 status 在 data 前/后”“嵌套 status”“缺失 status”“幂等执行”等回归场景。
- 候选轨道继承路径限制在本项目 `patches/` 目录内，并校验目标版本与维护配置一致。
- 仓库验证明确拒绝将每个源补丁作为独立 Release 顶层资产。

## v0.11.4

### Fixed

- 修复 Run #4 中 `frontend/src/api/bases.test.ts` 返回 `Unknown Base` 的失败。
- 根因不是基地自定义命名生产代码未应用，而是旧补丁测试模拟的 Axios 响应缺少 `status`；PalPanel v1.3.0 因而不再将其识别为 AxiosResponse，API envelope 没有被解包。
- 新增 `adapt-frontend-api-tests.py`，为补丁链中所有 `vi.spyOn(apiClient, ...).mockResolvedValue(...)` 的旧式响应夹具补充 `status: 200`。
- 同时覆盖基地命名、基地仓库以及其他补丁新增前端 API 测试，避免逐个修复后连续出现下一处同类失败。

### Safety

- 适配器只扫描 `frontend/src/**/*.test.ts(x)`，只修改 `apiClient` spy mock，不修改生产 API 实现。
- 只接受 `mockResolvedValue` 或 `mockResolvedValueOnce` 紧接 `data` 属性的已知旧结构；已适配文件保持幂等。
- 前端 lint、Vitest、build 仍完整执行；适配后若存在真实功能问题，Workflow 仍失败且不创建 Release。

### Validation

- 新增三种旧式 Axios mock、已适配输入、幂等执行、非 apiClient mock 不修改和缺失目录拒绝测试。
- `validate-repository.sh` 现在执行补丁重定位、官方二进制解析和前端测试夹具适配三套回归测试。
- stable 补丁版本保持 `0.8.1`；Run #4 在 Release 创建前失败，因此不会与已发布资产冲突。

## v0.11.3

### Fixed

- 修复 `uitok-stable-v1.3.0-p0.8.0` manifest 使用“源码重建官方二进制”SHA-256，导致一键部署下载官方 v1.3.0 后校验失败并回滚的问题。
- 稳定 manifest 的 `original_sha256` 改为从上游正式 GitHub Release 的 Linux 包中安全提取并验证 `bin/palpanel` 后生成。
- 新稳定补丁版本设为 `0.8.1`，重新发布 `uitok-stable-v1.3.0-p0.8.1`，不会被已有错误的 `p0.8.0` Release 跳过。
- `build-metadata.json` 同时记录官方 Release 包信息和源码重建二进制 SHA-256，明确区分安装基线与构建验证产物。

### Safety

- 下载上游 `SHA256SUMS` 并校验完整 Linux 归档。
- 拒绝归档绝对路径、`..` 路径、符号链接、硬链接和特殊文件。
- 校验归档内部 `checksums.txt` 的 `bin/palpanel` SHA-256，并执行 `--version` 确认目标版本。
- 校验上一个 stable Release 的 `manifest.json`、`build-metadata.json` 和合并补丁均出现在 `SHA256SUMS` 且哈希一致。
- 上一个 stable Release 必须包含配置要求的全部 feature。
- pallocalize 测试重定位改为精确结构校验，发现额外新增、删除或额外 hunk 时拒绝自动排除。

### Validation

- 新增官方 Release 包安全提取、归档内哈希、版本匹配、链接拒绝和损坏校验回归测试。
- 新增补丁正常应用、已知测试上下文漂移、核心文件冲突、额外测试及删除行拒绝回归测试。
- 稳定构建增加前端 lint 和 Vitest 测试。
- 稳定版本格式收紧为 `vMAJOR.MINOR.PATCH`。

## v0.11.2

### Fixed

- 修复首次稳定版迁移时 `0005-enhance-base-storage-display.patch` 因上游调整 `backend/internal/pallocalize/localize_test.go` 而无法应用。
- 新增受控补丁应用器：普通补丁仍要求完整 `git apply --check`；只有确认冲突仅来自已知 pallocalize 测试路径时，才排除旧测试 hunk。
- 被排除的测试覆盖迁移到独立 `patch_storage_localize_test.go`，继续验证 ItemIcon、ContainerName 与未知值回退行为。

### Safety

- 不使用 `git apply --reject`，不允许半应用补丁。
- 排除已知测试路径后，只要其他任意文件仍有冲突，Workflow 立即失败且不创建 Release。
- 已知测试 hunk 内容与预期标记不一致时拒绝自动重定位。

### Validation

- 增加已知测试上下文漂移回归测试。
- 验证重定位后核心补丁完整应用，独立 Go 测试文件格式正确并保留原测试语义。

## v0.11.1

### Changed

- 稳定版自动发布改为优先从目标版本之前、版本最高的已发布稳定补丁 Release 派生。
- 同一上游版本存在多个稳定补丁时，选择补丁版本最高者。
- 只有第一次没有更早 stable Release 时，才回退到 `bootstrap_source_track`。
- 新增 `select-previous-stable-release.py` 与 `prepare-source-track.sh`。
- 自动下载并校验上一个稳定 Release 的 manifest、build metadata、SHA256SUMS 和合并补丁。
- 稳定 Release 新增 `derivation.json`，构建元数据同步记录派生来源。

### Safety

- 上一个稳定 Release 必须为 `exact`、`verified=true`，且 tag、目标版本、补丁版本和合并补丁 SHA-256 完全一致。
- 派生、补丁应用、测试、构建或冒烟失败时不创建 Release。
- 不创建 PR，不创建 Issue，不修改生产环境。

### Validation

- 新增上一个稳定 Release 选择、同版本最高补丁选择、首次迁移回退和派生轨道构建测试。
- 仓库校验要求 Workflow 必须包含稳定 Release 选择与派生源准备步骤。

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
