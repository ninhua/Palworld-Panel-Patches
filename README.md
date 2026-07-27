# Palworld Panel Patches

仓库版本：`v0.12.34`

用于维护 `uitok/palworld-panel` 的可重复源码补丁、构建测试和 Release 资产。
一键部署脚本由独立流程维护，本仓库只提供明确的补丁接入契约。

源码补丁生成、累计迁移、覆盖包路径和 SHA-256 的硬性规则见根目录 [`PATCH-MAINTENANCE.md`](PATCH-MAINTENANCE.md)。

## 当前维护基线

```text
上游项目：uitok/palworld-panel
当前维护目标：v1.3.0
bootstrap 源轨道：patches/bootstrap-v1.3.0
当前已发布稳定补丁：0.8.16
下一稳定补丁候选：0.8.17 / 未发布前 verified=false
```

`bootstrap-v1.3.0` 是不可变的自包含发布源轨道，拥有自己的 `source/`、`build/`、manifest 和许可文件；所有补丁应用、测试和构建均以官方 `v1.3.0` tag 为基线。`candidate-v1.3.0` 仅用于保存迁移失败或无变更工作区，可以不存在、被覆盖或由 Draft PR 更新，不再作为下一次发布的输入。只有完整 stable Workflow 通过后，Release manifest 才会写入 `mode=exact`、`target_version=v1.3.0` 和 `verified=true`。

旧 `dev-v1.2.2` 仅作为历史归档保留，不再参与 validation、build 或 release。首个可用
`v1.3.0` stable Release 发布后，后续版本从最新的较旧 stable Release 源码包派生。

## 迁移失败跟踪

`Auto release uitok stable patch` 将补丁不兼容、编译失败或 clean-room 验证失败视为“blocked migration”，而不是 GitHub Actions 运行失败：

- 输出首个失败补丁、阶段和完整原因；
- 将 candidate 工作区写入 `migration/vX.Y.Z`；
- 创建或更新同版本 Issue；
- candidate 持久化成功时创建或更新 Draft PR；
- 跳过 Release 步骤并以成功状态正常结束，避免发送失败 workflow 通知；
- 后续迁移成功、无需发布或 Release 已存在时，自动关闭对应 Issue 和 Draft PR。

仓库配置、权限、依赖安装或 Release 上传等基础设施错误仍保持失败状态，避免静默掩盖发布系统故障。

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
panel-patch-hot-update
audit-log-response-display
player-presence-history（stable 必需功能，迁移或构建失败时禁止发布）
host-save-migrator（stable 必需功能）
global-inventory-browser（stable 必需功能，只读全服库存聚合）
new-player-starter-gift（stable 必需功能，新玩家初始物品与帕鲁模板分批发放）
unattended-inventory-delta（stable 必需功能，无人时段库存正向净变化）
player-summary（stable 必需功能，玩家存档概览与中文区域定位）
pal-inventory-advanced-filters（stable 必需功能，帕鲁仓库多项筛选与终端位置）
api-catalog（stable 必需功能，运行时 API 目录与中文使用说明）
```

## API 使用说明（补丁新增或增强的全部接口）

PalPanel 的标准响应使用统一 JSON envelope：成功为 `{"ok":true,"data":...}`，失败为 `{"ok":false,"error":{"code":"...","message":"..."}}`。除表中标记为 `public` 的接口外，请使用已登录浏览器会话 Cookie 或 PalPanel Development Key；Development Key 的具体传递方式以运行版本 `docs/openapi.yaml` 为准。

`GET /api/catalog` 会从当前 Gin 路由表实时枚举**所有** `/api` 接口，包括上游原生接口和本仓库补丁接口，并返回方法、路径、分类、用途、认证方式、权限、请求说明、返回说明、处理器名称以及 `patched` 标记。它是判断实际运行二进制支持哪些 API 的首选依据。

```bash
# 公共接口
curl -sS http://127.0.0.1:8080/api/patch/info

# 使用已登录会话 Cookie 查询完整 API 目录
curl -sS -b cookies.txt http://127.0.0.1:8080/api/catalog
```

### 系统与补丁

| 方法 | 路径 | 权限 | 用途与主要返回 |
|---|---|---|---|
| GET | `/api/patch/info` | public | 查询上游版本、目标版本、补丁版本、verified 状态、构建信息和功能列表。 |
| GET | `/api/catalog` | authenticated | 查询当前进程实际注册的全部 API 和中文说明。 |
| GET | `/api/patch/update/status` | authenticated | 查询当前补丁、可用稳定 Release 和最近更新状态。 |
| POST | `/api/patch/update/check` | `server:control` | 强制重新检查与当前 PalPanel 正式版本完全匹配的 verified stable Release。 |
| POST | `/api/patch/update` | `server:control` | 创建 `patch_hot_update` 任务，校验资产并原子替换面板二进制。 |

```bash
curl -sS -b cookies.txt -X POST http://127.0.0.1:8080/api/patch/update/check
curl -sS -b cookies.txt -X POST http://127.0.0.1:8080/api/patch/update
```

### 玩家、基地与存档索引

| 方法 | 路径 | 权限 | 请求与用途 |
|---|---|---|---|
| GET | `/api/players` | authenticated | 玩家列表；补丁版附加备注、标签和 WorldID 在线历史。支持现有 `limit`、`offset`、`q` 等列表参数。 |
| GET | `/api/players/{id}` | authenticated | 玩家详情；附加管理元数据、累计在线和最近会话。 |
| PUT | `/api/players/{id}/annotation` | `players:write` | JSON `{"note":"管理备注","tags":["标签"]}`；备注最多 500 字，标签最多 8 个。 |
| DELETE | `/api/players/{id}/annotation` | `players:write` | 删除该玩家在当前存档源下的备注和标签。 |
| GET | `/api/guilds/{id}` | authenticated | 公会会长、成员、成员注释和关联基地详情。 |
| PUT | `/api/bases/{id}/name` | `server:control` | JSON `{"name":"新的据点名称"}`；只写 PalPanel 元数据。 |
| DELETE | `/api/bases/{id}/name` | `server:control` | 删除据点别名并恢复原始名称。 |
| GET | `/api/bases/{id}/storage` | authenticated | 据点关联容器、槽位、本地化物品和数量。 |
| GET | `/api/bases/{id}/workers` | authenticated | 基地工作帕鲁及等级、性别、状态和被动词条。 |
| GET | `/api/bases/{id}/feed-boxes` | authenticated | 普通/低温饲料箱数量、占用格和物品聚合。 |
| GET | `/api/inventory` | authenticated | 全服库存；参数 `q`、`owner_type`、`category`、`sort`、`source_id`，返回位置明细与 `unattended` 无人时段状态。 |
| GET | `/api/pals` | authenticated | 帕鲁列表；补丁参数 `min_level`、`min_stars`、`min_iv_average`、`gender`、`location`、`passive`、`sort`。 |
| POST | `/api/save-sources/import/inspect` | `server:control` | 标准存档导入检查；补丁版同时支持合作房主档 UID 重映射检查。 |

```bash
curl -sS -b cookies.txt \
  'http://127.0.0.1:8080/api/pals?min_level=50&min_stars=4&min_iv_average=90&location=palbox&sort=iv_desc'

curl -sS -b cookies.txt -X PUT \
  -H 'Content-Type: application/json' \
  -d '{"note":"重点观察","tags":["管理","活跃"]}' \
  http://127.0.0.1:8080/api/players/PLAYER_UID/annotation
```

### 新玩家礼包与 PalDefender

| 方法 | 路径 | 权限 | 请求与用途 |
|---|---|---|---|
| GET | `/api/security/paldefender/starter-gift` | authenticated | 返回当前 WorldID、礼包配置、物品目录、模板与索引、任务摘要和发放记录。 |
| PUT | `/api/security/paldefender/starter-gift` | `security:write` | 保存 `enabled`、批大小、`items` 和 `pal_templates`；首次从禁用切换为启用时建立已有玩家基线。 |
| POST | `/api/security/paldefender/starter-gift/grants/{id}/retry` | `security:write` | 从持久化的未完成批次继续重试。 |
| DELETE | `/api/security/paldefender/starter-gift/grants/{id}` | `security:write` | 重置发放记录；玩家必须离线后重新进入才能再次触发。 |

```bash
curl -sS -b cookies.txt \
  http://127.0.0.1:8080/api/security/paldefender/starter-gift
```

发放目标解析规则：当前在线身份以官方 Palworld REST `/players` 为准；PalDefender `/v1/pdapi/players` 仅用于把该在线身份映射到可写入的 `UserId` / `PlayerUID`。PalDefender 返回的 `Status` 是账户状态字段，不再作为在线过滤条件。已有 `pending` 或旧 `PLAYER_NOT_FOUND` 记录会在下一次 15 秒采样后自动续发。

已经被旧版本写入“已见玩家”但从未生成发放记录的测试账号，无法与真正老玩家安全区分。此类账号应使用一个从未进入过该 WorldID 的账号复测，或先在“发放记录”中重置已有记录并完成一次离线→上线。

### 上游原生 API

补丁版继续支持 PalPanel v1.3.0 的全部原生 API，包括认证、Development Key、异步任务、审计、服务器生命周期、监控、备份/WebDAV、配置、模组、AI 翻译、PalDefender GM、存档源、玩家、公会、基地、帕鲁、地图和配种等接口。由于上游接口数量较多且会随正式 PalPanel 版本变化，README 不复制一份可能失真的静态清单；请使用：

- `GET /api/catalog`：当前运行二进制的精确路由和说明；
- `docs/openapi.yaml`：精确请求/响应 schema 和 `x-palpanel-permission`；
- `GET /api/patch/info`：确认当前补丁和目标 PalPanel 版本。

`new-player-starter-gift` 提供：

- 在现有 15 秒在线玩家采样后识别新身份，不增加独立高频轮询；
- 启用时将玩家在线历史和当前服务器 save index 中的已有玩家写入基线，避免老玩家补发；如果现有存档无法安全索引则拒绝启用；
- 每个存档世界独立保存礼包配置、已见玩家、冻结计划和批次进度；新世界继承最新配置模板，但不会改写已有世界配置；
- 左侧“玩家与世界”菜单提供“新玩家礼包”入口；礼包页面以物品、帕鲁模板和发放记录三个 Tab 组织操作；
- 物品目录显示本地化图标，按帕鲁球、工具、近战、枪械、弹药、防具、食物、药品、基础/高级材料、关键物品和图纸分类；支持搜索、多选、只看已选、当前筛选全选/取消与行内数量调整；
- PalDefender 模板身份和头像始终读取模板 JSON 内的 `PalID`；Templates 目录中的可选索引 JSON 可按文件名补充分类、中文名和英文名，并作为“常用毕业帕鲁清单”等独立筛选条件；未命中索引时保持显示模板文件名；支持搜索、多选、只看已选和当前筛选批量操作；物品与模板按可配置批大小通过每世界串行 worker 发送；
- 每位玩家冻结一份领取计划并持久化批次进度；发放前以 PlayerUID/SteamID 对照 PalDefender 在线玩家解析实际目标，PalDefender 尚未登记玩家时保持等待并在后续采样自动重试；旧版 `PLAYER_NOT_FOUND` 失败记录会自动恢复；其他失败仍可由管理员从未完成位置重试；
- 页面顶部显示当前 WorldID、启用状态、礼包内容和任务摘要；底部固定操作栏汇总未保存修改并提供撤销/保存；失败任务可重试或重置，重置后必须先离线再进入；
- 依赖 PalDefender REST 与已有模板目录，不修改 Palworld 存档。

`unattended-inventory-delta` 提供：

- 库存管理入口位于左侧“存档管理工具”，页面路径为 `/inventory`；

- 复用现有 15 秒玩家在线采样，不增加新的高频轮询；
- 当当前服务器世界无人在线时，从只读 save index 建立全服库存基线，并持续计算物品正向净变化；
- 无人时段至少持续 5 分钟才保留，短暂断线或重连不会生成误导记录；
- REST 在线状态、面板采样或存档索引中断超过 60 秒时重建基线，避免把停机时间计入时长或库存差值；
- 状态、基线和最近一次完整结果按 WorldID 独立保存在 PalPanel SQLite KV 中；导入存档不参与实时统计；
- 库存页面显示当前/最近一次无人时段、持续时间、有效门槛、索引状态和净增加最多的物品；
- 结果只表示全服库存正向净变化，不等同于据点生产量，不修改 Palworld 存档。


`pal-inventory-advanced-filters` 提供：

- 扩展现有 `/pal-inventory` 帕鲁仓库，不新增存档解析器或写入能力；
- 支持最低等级、最低星级、最低平均 IV、性别、位置和多个被动词条联合筛选；
- 支持按等级、平均 IV、星级或名称排序；
- 展示 HP/攻击/防御 IV、平均 IV 和 0–4 星浓缩等级；
- 根据 save index 的 `LocationType` 与 `SlotIndex` 显示队伍位置、据点工作位、远征状态或帕鲁终端页/行/列；
- 帕鲁终端按每页 30 格、每行 6 格换算，所有结果保持只读。


`player-summary` 提供：

- 在“世界档案”顶部标签中增加“玩家概览”，页面路径为 `/player-summary`；
- 复用现有玩家档案、帕鲁索引和 WorldID 在线历史，不增加新的后端轮询或存档解析器；
- 按 PlayerUID / SteamID 关联玩家持有帕鲁，展示数量、种类、平均等级和最高等级；
- 展示玩家等级、公会、在线状态、本次/上次在线、累计在线和最近上线时间；
- 复用实时地图已验证的坐标投影，将玩家坐标匹配为世界树外缘、雪山、樱花岛、沙丘、中央群岛、火山岛、天坠之地或起始群岛等宽泛中文区域；
- 中文区域明确标记为估算，不冒充精确游戏地标；坐标无效时显示“位置未记录”；
- 当前 sav-cli 未输出科技、配方、图鉴和首领进度时明确省略，不使用猜测值填充；
- 全程只读，不修改 Palworld 存档。

`player-presence-history` 提供：

- 后台复用现有 15 秒监控采样，不依赖玩家页面打开；
- 从官方 Palworld REST `/players` 读取在线玩家，并按 PlayerUID/SteamID 合并身份；
- 按当前 `DedicatedServerName` 对应的 WorldID 独立记录本次在线、累计在线、最近上线、最近下线和最近 20 次完整会话；
- 玩家列表显示本次/上次在线和累计时长，玩家详情显示时间点与最近会话；
- REST 暂时不可用时保持上一状态，不把所有玩家误记为下线；
- 下一次成功采样最多补记 60 秒，避免面板停机或网络中断形成虚假在线时长；
- 只对当前服务器存档源展示实时历史，导入存档不复用服务器在线记录；
- 数据保存在 PalPanel SQLite KV 中，不修改 Palworld 存档。


`global-inventory-browser` 提供：

- 聚合当前激活存档中的玩家背包、据点关联仓储与未识别归属容器；
- 按物品 ID 合并总量，同时保留每个容器槽位的位置、数量、归属和容器名称；
- 支持物品、玩家、据点、公会、容器名称或内部 ID 搜索；
- 支持玩家、据点、未知容器范围筛选，以及分类和总量/名称排序；
- 据点位置使用 `base-custom-names` 的自定义显示名称，容器和物品复用现有本地化与图标目录；
- 只读取现有 save index，不扩展 `sav-cli`，不修改 Palworld 存档，也不提供物品写入操作。

`audit-log-response-display` 提供：

- 操作审计桌面表格增加“响应”列，移动端操作卡片显示响应摘要；
- 点击桌面表格行或移动端卡片打开响应详情弹窗；
- 详情展示记录 ID、时间、操作者、角色、动作、对象、状态、来源 IP 和结构化审计响应，JSON 自动格式化；
- 写操作统一记录实际 `data` / `error` 响应，而不是只保存 `ok` 等泛化摘要；未使用标准响应助手的 JSON 处理器通过限长响应捕获补齐；
- 响应在写入现有审计 `message` 字段前递归脱敏密码、令牌、Cookie、Authorization、凭据和密钥字段，并限制深度、数组长度、字符串长度及 32 KiB 总大小；
- 支持 Enter/空格打开、Esc/遮罩关闭，并支持复制响应；HTTP 页面使用兼容复制回退；
- 详情弹窗通过 `document.body` Portal 渲染，避免 `#app-main` 的滚动、隔离和页面动画上下文裁剪弹窗内容；
- 失败响应使用醒目样式，无响应详情时显示明确占位；不修改审计数据库结构。

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

`panel-patch-hot-update` 提供：

- 优先读取仓库中 `stable-vX.Y.Z/workspace.json` 的 released/verified 发布状态，不再把 GitHub REST API 作为唯一发现路径；
- 由已验证的 Release tag 构造确定性的补丁包、manifest 和 SHA256SUMS 下载地址；
- GitHub REST API 仅作为兼容回退，避免共享出口 IP 的匿名 API 限额导致热更新不可用；
- 同时识别 `PALWORLD_LINUX_PANEL_PATCH_GITHUB_TOKEN`、`PALPANEL_PANEL_PATCH_GITHUB_TOKEN`、`PALPANEL_PATCH_GITHUB_TOKEN`、`GITHUB_TOKEN` 和 `GH_TOKEN`；
- 在任务队列和开服向导的服务端更新区域提供统一“补丁热更新”按钮；
- 只选择与当前 PalPanel 正式版本完全一致的 stable patch Release；
- 校验 Release `SHA256SUMS`、exact/verified manifest、平台、功能声明和补丁二进制 SHA-256；
- 备份当前 PalPanel 二进制后进行同目录原子替换；
- Linux 上通过 `exec` 保持原进程 PID 重启，避免启动脚本退出导致容器停止；
- 新进程初始化时复验已激活二进制，失败时恢复备份并重新执行旧二进制；
- 更新过程进入现有任务队列，任务类型为 `patch_hot_update`。

API：

```http
GET /api/patch/update/status
POST /api/patch/update/check
POST /api/patch/update
```

写操作要求 `server:control` 权限。

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

`0016-fix-panel-patch-update-openapi-contract.patch` 修复 `0014` 遗漏的 OpenAPI 路由声明：

- 为补丁热更新的查询、检查和执行接口补齐 OpenAPI operation；
- 在路由契约测试中显式断言三个接口存在；
- 修复 clean-room `go test -p=1 ./...` 报出的 `API route is missing from OpenAPI`；
- stable patch version 保持 `0.8.4`，因为失败运行没有创建 immutable Release。

`0017-add-audit-log-response-detail-dialog.patch` 增强 `audit-log-response-display`：

- 审计列表行和移动端卡片都可打开详情弹窗；
- 完整展示后端已脱敏的 `message`，并列出审计上下文；
- 增加键盘操作、滚动锁定、遮罩关闭和复制响应；
- 不新增后端响应体采集或数据库字段。

`0018-add-player-presence-history.patch` 增加 `player-presence-history`：

- 补丁已按 PalPanel v1.3.0 累计源码上下文重新生成，可由标准 `git apply --check` 直接验证和应用，不依赖 0018 专用语义适配器；
- 使用现有监控采样器周期读取官方 REST 玩家列表；
- 按玩家身份持久累计在线时长并保存最近完成会话；
- 将统计附加到玩家列表和玩家详情，不新增写操作或权限；
- 数据源失败时不推进状态，恢复后限制最大补记间隔；
- 仅当前服务器存档源显示该统计。

`0019-avoid-github-api-rate-limit.patch` 修复补丁热更新的 Release 发现：

- 优先读取已发布 stable 工作区元数据，绕过匿名 GitHub REST API 共享 IP 限额；
- 仅接受 `state=released`、`verified=true` 且目标版本与 Release tag 精确匹配的工作区；
- 继续对 manifest、SHA256SUMS 和补丁二进制执行原有完整校验；
- REST API 保留为回退路径，并兼容一键部署脚本使用的补丁 GitHub Token 变量。

`0020-fix-audit-response-dialog-portal.patch` 修复操作审计响应详情弹窗：

- 使用 React Portal 将弹窗挂载到 `document.body`；
- 避免 `#app-main` 的滚动容器、`isolation` 与页面进入动画 `transform` 改变 fixed 弹窗的包含块和堆叠上下文；
- 复用 PalPanel 现有弹窗样式并提升层级；
- 保留记录元数据、完整响应、JSON 格式化、复制和键盘关闭行为。

`0021-capture-audit-response-details.patch` 修复审计响应只有 `ok` 等摘要的问题：

- 将标准成功/失败响应中的实际 `data` / `error` 结构写入现有审计 `message`；
- 对直接输出 JSON 的写操作使用最多 64 KiB 的临时响应捕获作为兼容回退；
- 写入前递归脱敏敏感键和 Bearer Token，并将最终记录限制在 32 KiB；
- 保持现有数据库列、权限、详情弹窗和复制行为不变。

## 补丁结构

当前活动轨道：

```text
projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/
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
│   ├── 0013-fix-player-annotation-online-resolution.patch
│   ├── 0014-add-panel-patch-hot-update.patch
│   ├── 0015-add-audit-log-response-display.patch
│   ├── 0016-fix-panel-patch-update-openapi-contract.patch
│   ├── 0017-add-audit-log-response-detail-dialog.patch
│   ├── 0018-add-player-presence-history.patch
│   ├── 0019-avoid-github-api-rate-limit.patch
│   ├── 0020-fix-audit-response-dialog-portal.patch
│   ├── 0021-capture-audit-response-details.patch
│   └── SHA256SUMS
├── build/
│   ├── build.sh
│   └── build-palpanel.sh
├── LICENSE
└── LICENSE-NOTICE.md
```

该目录是自包含且不可变的 v1.3.0 stable bootstrap。构建脚本按文件名顺序应用全部
`source/*.patch`，先校验 `source/SHA256SUMS`，再以官方 `v1.3.0` 源码执行
迁移、检查点编译和 clean-room 复验。

历史 `dev-v1.2.2` 目录不再是配置入口，也不再由任何 GitHub Actions workflow 调用。

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

补丁不兼容、编译失败或 clean-room 验证失败时不创建 Release；兼容报告与日志写入
`migration/vX.Y.Z` 分支，并创建或更新同版本 Issue 和 Draft PR。workflow 以成功状态正常结束。
迁移成功、无需发布或 Release 已存在时自动关闭对应跟踪项；成功后 main 保留
`stable-vX.Y.Z` 审计工作区。

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
当前已发布稳定补丁：0.8.12
下一稳定补丁候选：0.8.13
预期 Release：uitok-stable-v1.3.0-p0.8.13
```

`host-save-migrator` 使用随 Release 分发的 `palworld-uid-remap`。helper 现在以 `oodle` feature 构建，可解析 Palworld v1.0+ 的 `PlM`/Oodle `Level.sav`。执行迁移时保留受管导入源，若服务器正在运行则先停止，然后将迁移结果复制到 `Pal/Saved/SaveGames/0/<DedicatedServerName>`，原子更新 `Pal/Saved/Config/WindowsServer/GameUserSettings.ini`，并仅在迁移前处于运行状态时重新启动。helper 作为 overlay 附加文件分发，但不列为安装前必须已存在的 manifest 目标，以兼容旧安装器；旧部署或热更新只替换主二进制时，面板会从同版本 Release 包自举 helper 并按构建时 SHA-256 校验。离线环境可设置 `PALPANEL_UID_REMAPPER_BIN`。

主机迁移 OpenAPI 同时声明 `SaveSource` component，确保 `HostMigrationResult.source` 经内置 `openapi-types` 生成后不会产生悬空的 `components['schemas']['SaveSource']` TypeScript 引用。

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
- 当 bootstrap 目标高于上一个 verified stable Release 时使用 bootstrap；否则从最新且更旧的 stable Release 导入补丁链；
- 按补丁顺序记录 `compatible`、`adapted`、`incompatible`、`blocked`、`superseded`；
- 任一必需功能失败即禁止 Release，并把 candidate 工作区写入 `migration/vX.Y.Z` 分支；
- 可用补丁生成一个 merged patch，再在全新的官方源码上只应用 merged patch 完整复验；
- 成功后固化 `stable-vX.Y.Z` 工作区并发布不可变 Release；
- Release 顶层固定为安装包、源码包、manifest、兼容报告和 SHA256SUMS 五个文件。

完整补丁链、merged patch、构建元数据、smoke 日志和派生信息保留在安装包及源码包内部。
