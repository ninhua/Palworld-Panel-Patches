# PalPanel QwenPaw 插件

这是 `astrbot_plugin_palpanel` 的 QwenPaw 后端插件移植版。插件同时支持 QwenPaw 的 QQ 官方频道与 OneBot/NapCat，并在原有 HMAC 集成协议之外接入 PalPanel 管理 API 和 `ninhua/Palworld-Panel-Patches` 补丁接口。

## 0.2.4 接口架构

插件使用三类接口：

1. **AstrBot 兼容 HMAC 接口**：状态、在线、房间、开关服、绑定和快捷配种。
2. **PalPanel 管理 API**：版本、存档索引、玩家、公会、基地、仓库、帕鲁及服务器生命周期。
3. **补丁 API**：补丁能力探测、基地自定义名称、玩家备注、增强公会详情、工作帕鲁和饲料箱汇总。

状态、在线、房间和开关服默认先调用 HMAC 接口；HMAC 接口失败且已配置 `panel_api_key` 时，自动回退到 PalPanel 管理 API。

插件通过公开接口自动探测补丁能力：

```text
GET /api/patch/info
```

补丁功能不存在时会返回明确提示，不会把 404 当成通用故障。

## 命令

### 基础与诊断

```text
/palhelp
/palhelp 补丁    # 全部补丁 Feature、API 路径和对应命令
/palid
/面板信息
/接口诊断
/表格模式
/服状态
/在线
/房间 [关键词]
/游戏版本
/存档索引
```

### PalPanel 管理 API

```text
/玩家 [关键词]
/玩家详情 <昵称|PlayerUID|SteamID>
/背包 <昵称|PlayerUID|SteamID>

/公会 [关键词]
/公会详情 <名称|ID>

/基地 [关键词]
/基地详情 <名称|ID>
/仓库 <名称|ID>

/帕鲁 [关键词]
/帕鲁详情 <名称|实例ID>
```

### `ninhua/Palworld-Panel-Patches` 补丁命令

```text
/工作帕鲁 <基地名称|ID>
/饲料箱 <基地名称|ID>

/基地改名 <基地名称|ID> | <新名称>
/基地恢复名 <基地名称|ID>

/玩家备注 <玩家名称|ID> | <备注> | 标签1,标签2
/玩家清备注 <玩家名称|ID>
```

补丁写操作同时要求：

- 当前 QQ/OpenID 位于 `admin_qq_ids`；
- `panel_api_key` 有相应 PalPanel 权限；
- 补丁能力列表中包含对应 feature。

### 原有功能

```text
/开服
/关服 [5-300 秒]
/重启 [5-300 秒]
/强关

/bd <游戏昵称>
/bdqr <验证码>
/qd
/jf
/pz <目标帕鲁> [被动词条...]
/paladmin ...
```

## 安装

ZIP 根目录必须直接包含 `plugin.json` 和 `plugin.py`：

```text
设置 → 插件管理 → 上传 ZIP → 安装 → 完整重启 QwenPaw
```

首次启动生成：

```text
~/.qwenpaw/data/palpanel/config.json
```

## 配置

推荐配置：

```json
{
  "panel_url": "http://127.0.0.1:8080",
  "panel_public_url": "http://你的局域网或公网地址:8080",
  "panel_id": "palpanel",
  "shared_secret": "与 PalPanel AstrBot 集成完全相同的密钥",
  "panel_api_key": "ppk_开头的PalPanel开发密钥",
  "allowed_group_ids": ["QQ群号、群OpenID或频道ID"],
  "admin_qq_ids": ["管理员QQ号或用户OpenID"],
  "allowed_agent_ids": ["default"],
  "listen_host": "127.0.0.1",
  "listen_port": 8092,
  "table_mode": "markdown",
  "require_qq_channel": true
}
```

### `shared_secret`

用于以下 HMAC 签名接口：

```text
/api/integrations/astrbot/server-status
/api/integrations/astrbot/community-servers
/api/integrations/astrbot/server-control
/api/integrations/astrbot/binding-challenges
/api/integrations/astrbot/quick-solves
```

### `panel_api_key`

用于标准 PalPanel 管理 API。密钥格式通常为：

```text
ppk_...
```

在 PalPanel 管理员账户下创建开发密钥，完整 token 只在创建时返回一次。按用途授予权限：

| 用途 | PalPanel 权限 |
| --- | --- |
| 版本、索引、玩家、公会、基地、仓库、帕鲁、补丁只读接口 | `read` |
| 开关服、基地改名 | `server:control` |
| 玩家备注和标签 | `players:write` |

只读部署可仅授予 `read`。需要完整插件功能时，开发密钥至少需要 `read`、`server:control`、`players:write`。

所有配置项都可通过 `PALPANEL_QWENPAW_<大写字段名>` 覆盖，例如：

```bash
PALPANEL_QWENPAW_PANEL_URL=http://127.0.0.1:8080
PALPANEL_QWENPAW_PANEL_API_KEY='ppk_...'
PALPANEL_QWENPAW_SHARED_SECRET='replace-me'
PALPANEL_QWENPAW_ALLOWED_GROUP_IDS=123456789
PALPANEL_QWENPAW_ADMIN_QQ_IDS=987654321
```

兼容环境变量：

```text
PALPANEL_SHARED_SECRET
PALPANEL_ASTRBOT_SHARED_SECRET
PALPANEL_API_KEY
PALPANEL_DEVELOPMENT_KEY
```

## QQ 官方频道与 OneBot

支持：

- `qq`：QwenPaw 内置 QQ 官方机器人频道；
- `onebot`：NapCat、Lagrange、go-cqhttp 等 OneBot v11 通道。

发送：

```text
/palid
```

将返回值填入访问名单：

| 通道 | `admin_qq_ids` | `allowed_group_ids` |
| --- | --- | --- |
| OneBot/NapCat | 实际 QQ 号 | 实际 QQ 群号 |
| QQ 官方群机器人 | 用户 OpenID | `group_openid` |
| QQ 官方频道机器人 | 用户 OpenID | `channel_id` |

## 补丁接口覆盖

0.2.4 已适配以下 feature：

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

对应的新接口和增强接口：

```text
GET    /api/patch/info
GET    /api/bases
GET    /api/bases/{id}
PUT    /api/bases/{id}/name
DELETE /api/bases/{id}/name
GET    /api/bases/{id}/storage
GET    /api/players
GET    /api/players/{id}
PUT    /api/players/{id}/annotation
DELETE /api/players/{id}/annotation
GET    /api/guilds/{id}
GET    /api/bases/{id}/workers
GET    /api/bases/{id}/feed-boxes
```

在 QQ 中发送 `/palhelp 补丁` 或 `/palhelp api`，可查看同一份完整列表及每个接口对应的插件命令。`insecure-endpoint-support` 是地址校验行为补丁，没有独立 HTTP API。

`/仓库` 与 `/公会详情` 在未安装补丁时仍调用上游接口；安装补丁后会自动展示增强字段。

## 内部回调 API

继续兼容原 AstrBot 插件协议：

```text
GET  /v1/health
POST /v1/catalog/sync
POST /v1/tickets/exchange
POST /v1/credits/reserve
POST /v1/credits/commit
POST /v1/credits/release
```

PalPanel 回调地址默认：

```text
http://127.0.0.1:8092
```

跨主机时将 `listen_host` 改为 `0.0.0.0`，并通过防火墙只允许 PalPanel 主机访问。

## 测试顺序

```text
/palid
/接口诊断
/面板信息
/服状态
/玩家
/基地
/工作帕鲁 <基地ID>
/饲料箱 <基地ID>
```

日志中应出现：

```text
PalPanel runtime slash command injection complete: workspaces=1 installed=75
```

## 数据迁移

数据库表结构保持兼容。停止 AstrBot 和 QwenPaw 后，可复制旧数据库：

```bash
cp data/plugin_data/astrbot_plugin_palpanel/palpanel.sqlite3 \
  ~/.qwenpaw/data/palpanel/palpanel.sqlite3
```

不要让 AstrBot 插件和 QwenPaw 插件同时写同一个 SQLite 文件。

## 安全

- `panel_api_key` 等同于其拥有的 PalPanel 权限，应只保存在 QwenPaw 配置文件或受保护环境变量中。
- `shared_secret` 与 `panel_api_key` 会在日志配置输出中自动脱敏。
- HTTP 可用但不加密；跨公网部署应使用 HTTPS 或受控专网。
- `/强关` 可能造成未保存进度丢失。
- QQ 官方接口可能过滤普通文本 URL，`/pz` 链接场景优先启用 Markdown 或使用 OneBot。

## 验证

```bash
python -m compileall plugin.py qwenpaw_palpanel
```

```bash
curl http://127.0.0.1:8092/v1/health
```

## 许可证

本移植版基于 GPL-3.0 项目代码，按 GPL-3.0-or-later 分发。


## 双表格模式

0.2.4 起可在两种格式间切换：

- `markdown`：标准 Markdown 管道表格，适合已启用 Markdown 的 QQ 官方频道。
- `ascii`：带边框的等宽字符表格，并放在 `text` 代码块中，适合 OneBot 或不渲染 Markdown 的客户端。

配置文件：

```json
{
  "table_mode": "markdown"
}
```

管理员也可在 QQ 中即时切换并写回配置文件：

```text
/表格模式
/表格模式 markdown
/表格模式 ascii
```

环境变量 `PALPANEL_QWENPAW_TABLE_MODE` 可覆盖配置文件。
