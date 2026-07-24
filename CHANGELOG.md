# Changelog

## 0.2.4

- 新增 `table_mode` 配置，可选 `markdown` 与 `ascii`。
- 新增 `/表格模式`、`/tablemode`、`/显示模式` 命令；管理员可即时切换并持久化到 `config.json`。
- Markdown 模式保留标准管道表格；ASCII 模式恢复等宽边框及 `text` 代码块。
- 支持 `PALPANEL_QWENPAW_TABLE_MODE` 环境变量覆盖。
- 所有列表、详情、诊断、绑定信息和补丁帮助共用同一全局渲染模式。

## 0.2.3

- 全局表格渲染改为标准 Markdown 管道表格。
- 移除 ASCII `+---+` 边框和三反引号代码块。
- 自动转义单元格中的竖线与反斜杠，避免破坏 Markdown 列结构。
- 保留原有宽度裁剪、中文宽度计算和旧 `fenced` 参数兼容性。

## 0.2.2

- `/palhelp 补丁` 与 `/palhelp api` 现在列出插件已适配的全部补丁 Feature、HTTP 方法、API 路径和对应 QQ 命令。
- 帮助中明确说明 `{id}` 可通过实体列表返回的数字序号代替。
- 将 `insecure-endpoint-support` 标注为行为补丁，无独立 HTTP API。
- 修复 0.2.1 状态表格格式化异常会被错误当成 PalPanel API 故障的问题。
- 服务器状态解析兼容更多上游/补丁响应字段和字符串数值，不再因单个字段类型变化导致整个查询失败。
- 查询失败时返回 HMAC 与管理 API 的异常类型，并引导执行 `/接口诊断`。

## 0.2.1

- 玩家、公会、基地和帕鲁列表增加数字序号选择缓存。
- 绑定成功后可查询 PlayerUID、SteamID、公会、存档源等关联 ID。
- 查询结果改为等宽表格或键值表输出。

## 0.2.0

- 新增 PalPanel Bearer 开发密钥配置 `panel_api_key`。
- 新增标准管理 API：版本、存档索引、玩家、背包、公会、基地、仓库、帕鲁。
- 新增 `GET /api/patch/info` 能力探测与 feature 缓存。
- 适配 `ninhua/Palworld-Panel-Patches`：基地改名、玩家备注、增强公会详情、工作帕鲁、饲料箱汇总。
- `/服状态`、`/在线`、`/房间` 和服务器控制增加 HMAC → 管理 API 自动回退。
- 新增 `/palhelp`、`/面板信息`、`/接口诊断` 等命令，共注册 75 个命令别名。
- 所有管理 API 错误按 401/403/404/409/5xx 返回明确提示。

## 0.1.7

- Support QwenPaw's official `qq` channel in addition to OneBot/NapCat.
- Normalize official QQ `group_openid`, guild `channel_id`, and sender OpenID into command identity fields.
- Keep legacy `require_onebot` configuration as an alias while changing its semantics to require a QQ-family channel.
- Add `/palid` and `/身份` diagnostics for discovering the IDs required by access lists.
- Document that official QQ uses OpenIDs rather than real QQ numbers and may suppress plain-text URLs.

## 0.1.6

- Fix OneBot/NapCat requests being rejected after direct slash dispatch.
- Read channel metadata from QwenPaw objects, dictionaries, request fields and OneBot session IDs.
- Recognize QwenPaw builds that expose NapCat traffic through the generic `qq` channel key.
- Recover numeric QQ sender/group IDs from OneBot session and metadata variants.
- Include the detected channel in scope errors and add debug identity diagnostics.

## 0.1.4

- Fix slash commands being forwarded to the AI instead of executing directly.
- Use bare control-command names, matching QwenPaw's plugin contract.
- Inject PalPanel `CommandSpec` objects into already-running workspace `SlashCommandRegistry` instances.
- Extend workspace bootstrap specs so newly created or reloaded agents also receive the commands.

## 0.1.3

- Removed the hard requirement that non-loopback `panel_url` values use HTTPS.
- Remote HTTP PalPanel endpoints are now accepted.
- Keep a runtime warning when a non-loopback HTTP endpoint is configured.

## 0.1.2

- Removed the `aiosqlite` installation requirement.
- Reimplemented persistence with the Python standard-library `sqlite3` module.
- Database calls run through `asyncio.to_thread` and remain asynchronous to QwenPaw.
- Plugin installation no longer needs pip, uv, or outbound network access.

## 0.1.1

- Fix QwenPaw dynamic-loader compatibility by importing bundled modules through the plugin package namespace.
- Add `requirements.txt` so QwenPaw installs `aiohttp` and `aiosqlite` before loading the plugin.

## 0.1.0

- Port AstrBot PalPanel command handlers to QwenPaw control commands.
- Preserve the existing AstrBot-compatible PalPanel integration endpoints.
- Preserve SQLite binding, check-in, credits, tickets and audit data model.
- Add OneBot/NapCat, group, QQ administrator and agent scope checks.
- Add startup/shutdown lifecycle management and HMAC-protected callback API.
- Add configuration file generation, environment overrides and migration notes.
