from __future__ import annotations

import asyncio
import json
import logging
import time
from typing import Any, Iterable
from urllib.parse import quote, urlparse

from .operations import format_online_players, format_rooms, truncate_text, unwrap
from .table_format import render_table
from .panel_formats import (
    format_base_detail,
    format_bases,
    format_diagnostics,
    format_entity_choices,
    format_feed_boxes,
    format_generic_server_status,
    format_guild_detail,
    format_guilds,
    format_inventory,
    format_pal_detail,
    format_pals,
    format_patch_info,
    format_player_detail,
    format_players,
    format_save_index,
    format_storage,
    format_version,
    format_workers,
)

logger = logging.getLogger(__name__)


PATCH_API_HELP_ROWS: tuple[tuple[str, str, str], ...] = (
    ("patch-info-api", "GET /api/patch/info", "/面板信息"),
    ("base-custom-names", "GET /api/bases", "/基地"),
    ("base-custom-names", "GET /api/bases/{id}", "/基地详情"),
    ("base-custom-names", "PUT /api/bases/{id}/name", "/基地改名"),
    ("base-custom-names", "DELETE /api/bases/{id}/name", "/基地恢复名"),
    ("base-storage-browser", "GET /api/bases/{id}/storage", "/仓库"),
    ("player-notes", "GET /api/players", "/玩家"),
    ("player-notes", "GET /api/players/{id}", "/玩家详情"),
    ("player-notes", "PUT /api/players/{id}/annotation", "/玩家备注"),
    ("player-notes", "DELETE /api/players/{id}/annotation", "/玩家清备注"),
    ("guild-detail-browser", "GET /api/guilds/{id}", "/公会详情"),
    ("base-worker-browser", "GET /api/bases/{id}/workers", "/工作帕鲁"),
    ("base-feed-box-summary", "GET /api/bases/{id}/feed-boxes", "/饲料箱"),
)


class PanelAPIError(RuntimeError):
    def __init__(self, status: int, message: str, *, code: str = "", path: str = ""):
        super().__init__(message)
        self.status = int(status)
        self.code = str(code or "")
        self.path = str(path or "")

    def user_message(self) -> str:
        if self.status == 401:
            return "PalPanel 管理 API Key 无效或已撤销。"
        if self.status == 403:
            return "PalPanel API Key 权限不足。"
        if self.status == 404:
            return "当前 PalPanel 版本不提供该接口。"
        if self.status == 409:
            return "PalPanel 拒绝操作：当前状态冲突。"
        if self.status >= 500:
            return "PalPanel 服务暂时不可用。"
        return str(self) or f"PalPanel 请求失败（HTTP {self.status}）。"


def _mapping(value: Any) -> dict[str, Any]:
    return value if isinstance(value, dict) else {}


def _items(payload: dict[str, Any], key: str) -> list[dict[str, Any]]:
    data = unwrap(payload)
    if isinstance(data, list):
        return [v for v in data if isinstance(v, dict)]
    if isinstance(data, dict):
        return [v for v in data.get(key, []) if isinstance(v, dict)]
    return []


def _norm(value: Any) -> str:
    return str(value or "").strip().casefold()


def _first(value: Any, *keys: str) -> str:
    obj = _mapping(value)
    for key in keys:
        text = str(obj.get(key) or "").strip()
        if text:
            return text
    return ""


class ManagementCommandsMixin:
    """Management API and ninhua patch endpoint support for PalPanelService."""

    _patch_cache_payload: dict[str, Any] | None = None
    _patch_cache_at: float = 0.0
    _patch_cache_ttl: float = 60.0
    _selection_ttl: float = 300.0

    def _selection_key(self, identity: Any, entity_type: str) -> str:
        return "|".join(
            [
                str(getattr(identity, "agent_id", "") or "default"),
                str(getattr(identity, "channel_id", "") or "unknown"),
                str(getattr(identity, "group_id", "") or "private"),
                str(getattr(identity, "user_id", "") or "anonymous"),
                entity_type,
            ]
        )

    def _remember_selection(
        self,
        identity: Any,
        entity_type: str,
        items: list[dict[str, Any]],
    ) -> None:
        cache = getattr(self, "_entity_selection_cache", None)
        if cache is None:
            cache = {}
            self._entity_selection_cache = cache
        cache[self._selection_key(identity, entity_type)] = (
            time.monotonic() + float(getattr(self.config, "selection_ttl_seconds", self._selection_ttl)),
            [dict(item) for item in items[:50]],
        )

    def _selection_item(
        self,
        identity: Any,
        entity_type: str,
        raw_index: str,
    ) -> tuple[dict[str, Any] | None, str | None]:
        value = raw_index.strip()
        if not value.isdigit() or len(value) > 3:
            return None, None
        cache = getattr(self, "_entity_selection_cache", {})
        entry = cache.get(self._selection_key(identity, entity_type))
        if not entry:
            return None, "没有可用的选择列表，请先执行对应列表命令。"
        expires_at, items = entry
        if time.monotonic() > expires_at:
            cache.pop(self._selection_key(identity, entity_type), None)
            return None, "选择列表已过期，请重新执行对应列表命令。"
        index = int(value)
        if index < 1 or index > len(items):
            return None, f"序号必须在 1 到 {len(items)} 之间。"
        return dict(items[index - 1]), None

    def _api_key_error(self) -> str | None:
        if not self.config.panel_api_key:
            return (
                "该命令需要 PalPanel 管理 API Key。请在 PalPanel 创建开发密钥，"
                "再填写 config.json 的 panel_api_key。"
            )
        return None

    def _validate_panel_url(self) -> None:
        parsed = urlparse(self.config.panel_url)
        if parsed.scheme not in {"http", "https"}:
            raise RuntimeError("panel_url must use HTTP or HTTPS")
        if parsed.scheme == "http" and parsed.hostname not in {"127.0.0.1", "::1", "localhost"}:
            logger.warning(
                "PalPanel management API is using unencrypted HTTP: %s",
                self.config.panel_url,
            )

    async def _api_request(
        self,
        method: str,
        path: str,
        *,
        params: dict[str, Any] | None = None,
        payload: dict[str, Any] | None = None,
        require_key: bool = True,
    ) -> dict[str, Any]:
        if not self.http or self.http.closed:
            raise RuntimeError("PalPanel plugin service is not initialized")
        if require_key and not self.config.panel_api_key:
            raise RuntimeError("PalPanel panel_api_key is empty")
        self._validate_panel_url()
        headers = {"Accept": "application/json"}
        if require_key:
            headers["Authorization"] = f"Bearer {self.config.panel_api_key}"
        kwargs: dict[str, Any] = {"headers": headers}
        if params:
            kwargs["params"] = params
        if payload is not None:
            kwargs["json"] = payload
        async with self.http.request(method.upper(), self.config.panel_url + path, **kwargs) as response:
            raw = await response.read()
            result: Any = {}
            if raw.strip():
                try:
                    result = json.loads(raw.decode("utf-8"))
                except (UnicodeDecodeError, json.JSONDecodeError):
                    result = {"message": raw.decode("utf-8", errors="replace")[:500]}
            if response.status >= 400:
                error_obj = _mapping(result.get("error")) if isinstance(result, dict) else {}
                data_obj = _mapping(result.get("data")) if isinstance(result, dict) else {}
                message = (
                    error_obj.get("message")
                    or data_obj.get("message")
                    or (result.get("message") if isinstance(result, dict) else "")
                    or response.reason
                    or f"HTTP {response.status}"
                )
                code = error_obj.get("code") or data_obj.get("code") or ""
                raise PanelAPIError(response.status, str(message), code=str(code), path=path)
            if not isinstance(result, dict):
                raise RuntimeError("PalPanel returned a non-object JSON response")
            return result

    async def _get_patch_info(self, *, refresh: bool = False) -> dict[str, Any]:
        now = time.monotonic()
        if (
            not refresh
            and self._patch_cache_payload is not None
            and now - self._patch_cache_at < self._patch_cache_ttl
        ):
            return self._patch_cache_payload
        try:
            payload = await self._api_request("GET", "/api/patch/info", require_key=False)
        except PanelAPIError as exc:
            if exc.status == 404:
                payload = {}
            else:
                raise
        self._patch_cache_payload = payload
        self._patch_cache_at = now
        return payload

    async def _patch_features(self) -> set[str]:
        payload = await self._get_patch_info()
        data = _mapping(unwrap(payload))
        patch = _mapping(data.get("patch"))
        return {str(v) for v in patch.get("features", []) if str(v).strip()}

    async def _patch_feature_error(self, feature: str) -> str | None:
        try:
            features = await self._patch_features()
        except Exception as exc:
            logger.warning("patch feature detection failed: %s", exc)
            return "无法探测 PalPanel 补丁能力，请检查 /api/patch/info。"
        if not features:
            return "当前 PalPanel 未检测到 ninhua/Palworld-Panel-Patches 补丁。"
        if feature not in features:
            return f"当前补丁版本未提供 {feature} 功能。"
        return None

    async def _query_scope(
        self,
        identity: Any,
        action: str,
        *,
        selection_entity: str = "",
        selection_query: str = "",
    ) -> str | None:
        error = self._group_scope_error(identity)
        if error:
            return error
        if selection_entity and selection_query.strip().isdigit() and len(selection_query.strip()) <= 3:
            selected, _ = self._selection_item(identity, selection_entity, selection_query)
            if selected is not None:
                return None
        retry = self._retry_after(identity, action)
        if retry:
            return f"查询太频繁，请 {retry} 秒后再试。"
        return None

    async def panel_help(self, identity: Any, _args: str = "") -> str:
        error = self._base_scope_error(identity)
        if error:
            return error
        table = render_table(
            ("Feature", "HTTP API", "对应命令"),
            PATCH_API_HELP_ROWS,
            max_total_width=88,
            max_column_widths=(24, 39, 15),
            minimum_column_widths=(12, 18, 8),
        )
        patch_help = (
            "补丁 API（{id} 可用列表返回的数字序号代替）\n"
            + table
            + "\ninsecure-endpoint-support：无独立 API；用于允许受控的 HTTP 服务地址。"
        )
        topic = _norm(_args)
        if topic in {"补丁", "补丁api", "api", "接口", "patch", "patchapi", "2"}:
            return truncate_text(
                "PalPanel 补丁 API 帮助\n" + patch_help,
                self.config.output_max_chars,
            )
        overview = (
            "PalPanel 命令帮助\n"
            "基础：/服状态 /在线 /房间 /游戏版本 /存档索引 /面板信息 /接口诊断 /表格模式\n"
            "实体：/玩家 /玩家详情 /背包 /公会 /公会详情 /基地 /基地详情 /仓库 "
            "/帕鲁 /帕鲁详情 /工作帕鲁 /饲料箱\n"
            "写操作：/基地改名 /基地恢复名 /玩家备注 /玩家清备注\n"
            "运维：/开服 /关服 /重启 /强关；账号：/bd /bdqr /我的角色 /qd /jf /pz /paladmin /palid\n"
        )
        return truncate_text(
            overview + patch_help,
            self.config.output_max_chars,
        )

    async def panel_info(self, identity: Any, _args: str = "") -> str:
        error = await self._query_scope(identity, "panel_info")
        if error:
            return error
        try:
            payload = await self._get_patch_info(refresh=True)
            return format_patch_info(payload, bool(self.config.panel_api_key))
        except Exception as exc:
            logger.warning("panel info failed: %s", exc)
            return "无法读取 PalPanel 补丁信息。"

    async def diagnostics(self, identity: Any, _args: str = "") -> str:
        error = await self._query_scope(identity, "diagnostics")
        if error:
            return error
        rows: list[tuple[str, str]] = []
        try:
            health = await self._api_request("GET", "/api/health", require_key=False)
            rows.append(("健康接口", "正常" if health else "返回空对象"))
        except Exception as exc:
            rows.append(("健康接口", f"失败：{exc}"))
        try:
            patch = await self._get_patch_info(refresh=True)
            data = _mapping(unwrap(patch))
            patch_obj = _mapping(data.get("patch"))
            if patch_obj:
                rows.append(("补丁", f"{patch_obj.get('version', '未知')} / {len(patch_obj.get('features', []))} 项功能"))
            else:
                rows.append(("补丁", "未安装或无 /api/patch/info"))
        except Exception as exc:
            rows.append(("补丁", f"探测失败：{exc}"))
        if not self.config.panel_api_key:
            rows.append(("管理 API Key", "未配置"))
        else:
            try:
                me = await self._api_request("GET", "/api/auth/me")
                principal = _mapping(unwrap(me))
                rows.append(("管理 API Key", f"有效（{_first(principal, 'name', 'username', 'role') or '已认证'}）"))
            except PanelAPIError as exc:
                rows.append(("管理 API Key", exc.user_message()))
            except Exception as exc:
                rows.append(("管理 API Key", f"验证失败：{exc}"))
        rows.append(("HMAC 密钥", "已配置" if self.config.shared_secret else "未配置"))
        return truncate_text(format_diagnostics(rows), self.config.output_max_chars)

    async def game_version(self, identity: Any, _args: str = "") -> str:
        error = await self._query_scope(identity, "game_version") or self._api_key_error()
        if error:
            return error
        try:
            return format_version(await self._api_request("GET", "/api/server/version"))
        except PanelAPIError as exc:
            return exc.user_message()
        except Exception as exc:
            logger.warning("game version failed: %s", exc)
            return "无法查询游戏版本。"

    async def save_index(self, identity: Any, _args: str = "") -> str:
        error = await self._query_scope(identity, "save_index") or self._api_key_error()
        if error:
            return error
        try:
            return format_save_index(await self._api_request("GET", "/api/save/index/status"))
        except PanelAPIError as exc:
            return exc.user_message()
        except Exception as exc:
            logger.warning("save index failed: %s", exc)
            return "无法查询存档索引。"

    async def _entity_list(
        self,
        path: str,
        key: str,
        query: str,
        *,
        limit: int = 30,
        extra: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        params: dict[str, Any] = {"limit": min(max(1, limit), 100)}
        if query.strip():
            params["q"] = query.strip()
        if extra:
            params.update(extra)
        return await self._api_request("GET", path, params=params)

    async def _resolve_entity(
        self,
        *,
        identity: Any,
        entity_type: str,
        path: str,
        key: str,
        query: str,
        id_fields: tuple[str, ...],
        name_fields: tuple[str, ...],
        label: str,
        usage: str,
    ) -> tuple[dict[str, Any] | None, str | None]:
        query = query.strip()
        selected, selection_error = self._selection_item(identity, entity_type, query)
        if selected is not None:
            return selected, None
        if selection_error and query.isdigit() and len(query) <= 3:
            return None, selection_error

        if not query:
            payload = await self._entity_list(path, key, "", limit=20)
            candidates = _items(payload, key)
            if not candidates:
                return None, f"没有找到可选择的{label}。"
            self._remember_selection(identity, entity_type, candidates)
            return None, format_entity_choices(
                label,
                candidates,
                id_fields=id_fields,
                name_fields=name_fields,
                usage=usage,
                max_chars=self.config.output_max_chars,
            )

        payload = await self._entity_list(path, key, query, limit=50)
        candidates = _items(payload, key)
        needle = _norm(query)
        exact = [
            item
            for item in candidates
            if any(_norm(item.get(field)) == needle for field in (*id_fields, *name_fields))
        ]
        selected_items = exact if exact else candidates
        if len(selected_items) == 1:
            return selected_items[0], None
        if not selected_items:
            return None, f"没有找到匹配的{label}。"
        self._remember_selection(identity, entity_type, selected_items)
        return None, format_entity_choices(
            label,
            selected_items[:20],
            id_fields=id_fields,
            name_fields=name_fields,
            usage=usage,
            max_chars=self.config.output_max_chars,
        )

    async def players(self, identity: Any, args: str = "") -> str:
        error = await self._query_scope(identity, "players") or self._api_key_error()
        if error:
            return error
        try:
            payload = await self._entity_list("/api/players", "players", args, limit=30)
            self._remember_selection(identity, "player", _items(payload, "players"))
            return format_players(payload, self.config.output_max_chars)
        except PanelAPIError as exc:
            return exc.user_message()
        except Exception as exc:
            logger.warning("players command failed: %s", exc)
            return "无法查询玩家列表。"

    async def player_detail(self, identity: Any, args: str = "") -> str:
        error = await self._query_scope(identity, "player_detail", selection_entity="player", selection_query=args) or self._api_key_error()
        if error:
            return error
        try:
            player, resolve_error = await self._resolve_entity(
                identity=identity, entity_type="player",
                path="/api/players", key="players", query=args,
                id_fields=("player_uid", "steam_id", "id"),
                name_fields=("nickname",), label="玩家", usage="/玩家详情 <序号>",
            )
            if resolve_error:
                return resolve_error
            player_id = _first(player, "player_uid", "steam_id", "id")
            return format_player_detail(
                await self._api_request("GET", f"/api/players/{quote(player_id, safe='')}"),
                self.config.output_max_chars,
            )
        except PanelAPIError as exc:
            return exc.user_message()
        except Exception as exc:
            logger.warning("player detail failed: %s", exc)
            return "无法查询玩家详情。"

    async def inventory(self, identity: Any, args: str = "") -> str:
        error = await self._query_scope(identity, "inventory", selection_entity="player", selection_query=args) or self._api_key_error()
        if error:
            return error
        try:
            player, resolve_error = await self._resolve_entity(
                identity=identity, entity_type="player",
                path="/api/players", key="players", query=args,
                id_fields=("player_uid", "steam_id", "id"),
                name_fields=("nickname",), label="玩家", usage="/背包 <序号>",
            )
            if resolve_error:
                return resolve_error
            player_id = _first(player, "player_uid", "steam_id", "id")
            return format_inventory(
                await self._api_request("GET", f"/api/players/{quote(player_id, safe='')}/inventory"),
                self.config.output_max_chars,
            )
        except PanelAPIError as exc:
            return exc.user_message()
        except Exception as exc:
            logger.warning("inventory failed: %s", exc)
            return "无法查询玩家背包。"

    async def guilds(self, identity: Any, args: str = "") -> str:
        error = await self._query_scope(identity, "guilds") or self._api_key_error()
        if error:
            return error
        try:
            payload = await self._entity_list("/api/guilds", "guilds", args, limit=30)
            self._remember_selection(identity, "guild", _items(payload, "guilds"))
            return format_guilds(payload, self.config.output_max_chars)
        except PanelAPIError as exc:
            return exc.user_message()
        except Exception as exc:
            logger.warning("guilds failed: %s", exc)
            return "无法查询公会列表。"

    async def guild_detail(self, identity: Any, args: str = "") -> str:
        error = await self._query_scope(identity, "guild_detail", selection_entity="guild", selection_query=args) or self._api_key_error()
        if error:
            return error
        try:
            guild, resolve_error = await self._resolve_entity(
                identity=identity, entity_type="guild",
                path="/api/guilds", key="guilds", query=args,
                id_fields=("id",), name_fields=("name", "owner_player_uid"), label="公会", usage="/公会详情 <序号>",
            )
            if resolve_error:
                return resolve_error
            guild_id = _first(guild, "id")
            return format_guild_detail(
                await self._api_request("GET", f"/api/guilds/{quote(guild_id, safe='')}"),
                self.config.output_max_chars,
            )
        except PanelAPIError as exc:
            return exc.user_message()
        except Exception as exc:
            logger.warning("guild detail failed: %s", exc)
            return "无法查询公会详情。"

    async def bases(self, identity: Any, args: str = "") -> str:
        error = await self._query_scope(identity, "bases") or self._api_key_error()
        if error:
            return error
        try:
            payload = await self._entity_list("/api/bases", "bases", args, limit=30)
            self._remember_selection(identity, "base", _items(payload, "bases"))
            return format_bases(payload, self.config.output_max_chars)
        except PanelAPIError as exc:
            return exc.user_message()
        except Exception as exc:
            logger.warning("bases failed: %s", exc)
            return "无法查询基地列表。"

    async def _resolve_base(self, identity: Any, query: str, usage: str) -> tuple[dict[str, Any] | None, str | None]:
        return await self._resolve_entity(
            identity=identity,
            entity_type="base",
            path="/api/bases",
            key="bases",
            query=query,
            id_fields=("id",),
            name_fields=("name", "raw_name", "custom_name"),
            label="基地",
            usage=usage,
        )

    async def base_detail(self, identity: Any, args: str = "") -> str:
        error = await self._query_scope(identity, "base_detail", selection_entity="base", selection_query=args) or self._api_key_error()
        if error:
            return error
        try:
            base, resolve_error = await self._resolve_base(identity, args, "/基地详情 <序号>")
            if resolve_error:
                return resolve_error
            base_id = _first(base, "id")
            return format_base_detail(
                await self._api_request("GET", f"/api/bases/{quote(base_id, safe='')}"),
                self.config.output_max_chars,
            )
        except PanelAPIError as exc:
            return exc.user_message()
        except Exception as exc:
            logger.warning("base detail failed: %s", exc)
            return "无法查询基地详情。"

    async def storage(self, identity: Any, args: str = "") -> str:
        error = await self._query_scope(identity, "storage", selection_entity="base", selection_query=args) or self._api_key_error()
        if error:
            return error
        try:
            base, resolve_error = await self._resolve_base(identity, args, "/仓库 <序号>")
            if resolve_error:
                return resolve_error
            base_id = _first(base, "id")
            return format_storage(
                await self._api_request("GET", f"/api/bases/{quote(base_id, safe='')}/storage"),
                self.config.output_max_chars,
            )
        except PanelAPIError as exc:
            return exc.user_message()
        except Exception as exc:
            logger.warning("storage failed: %s", exc)
            return "无法查询基地仓库。"

    async def pals(self, identity: Any, args: str = "") -> str:
        error = await self._query_scope(identity, "pals") or self._api_key_error()
        if error:
            return error
        try:
            payload = await self._entity_list("/api/pals", "pals", args, limit=30)
            self._remember_selection(identity, "pal", _items(payload, "pals"))
            return format_pals(payload, self.config.output_max_chars)
        except PanelAPIError as exc:
            return exc.user_message()
        except Exception as exc:
            logger.warning("pals failed: %s", exc)
            return "无法查询帕鲁列表。"

    async def pal_detail(self, identity: Any, args: str = "") -> str:
        error = await self._query_scope(identity, "pal_detail", selection_entity="pal", selection_query=args) or self._api_key_error()
        if error:
            return error
        try:
            pal, resolve_error = await self._resolve_entity(
                identity=identity, entity_type="pal",
                path="/api/pals", key="pals", query=args,
                id_fields=("instance_id", "id"),
                name_fields=("name", "nickname", "species_name", "character_id"), label="帕鲁", usage="/帕鲁详情 <序号>",
            )
            if resolve_error:
                return resolve_error
            pal_id = _first(pal, "instance_id", "id")
            return format_pal_detail(
                await self._api_request("GET", f"/api/pals/{quote(pal_id, safe='')}"),
                self.config.output_max_chars,
            )
        except PanelAPIError as exc:
            return exc.user_message()
        except Exception as exc:
            logger.warning("pal detail failed: %s", exc)
            return "无法查询帕鲁详情。"

    async def workers(self, identity: Any, args: str = "") -> str:
        error = await self._query_scope(identity, "workers", selection_entity="base", selection_query=args) or self._api_key_error()
        if error:
            return error
        feature_error = await self._patch_feature_error("base-worker-browser")
        if feature_error:
            return feature_error
        try:
            base, resolve_error = await self._resolve_base(identity, args, "/工作帕鲁 <序号>")
            if resolve_error:
                return resolve_error
            base_id = _first(base, "id")
            return format_workers(
                await self._api_request("GET", f"/api/bases/{quote(base_id, safe='')}/workers"),
                self.config.output_max_chars,
            )
        except PanelAPIError as exc:
            return exc.user_message()
        except Exception as exc:
            logger.warning("workers failed: %s", exc)
            return "无法查询基地工作帕鲁。"

    async def feed_boxes(self, identity: Any, args: str = "") -> str:
        error = await self._query_scope(identity, "feed_boxes", selection_entity="base", selection_query=args) or self._api_key_error()
        if error:
            return error
        feature_error = await self._patch_feature_error("base-feed-box-summary")
        if feature_error:
            return feature_error
        try:
            base, resolve_error = await self._resolve_base(identity, args, "/饲料箱 <序号>")
            if resolve_error:
                return resolve_error
            base_id = _first(base, "id")
            return format_feed_boxes(
                await self._api_request("GET", f"/api/bases/{quote(base_id, safe='')}/feed-boxes"),
                self.config.output_max_chars,
            )
        except PanelAPIError as exc:
            return exc.user_message()
        except Exception as exc:
            logger.warning("feed boxes failed: %s", exc)
            return "无法查询基地饲料箱。"

    def _admin_write_error(self, identity: Any) -> str | None:
        error = self._group_scope_error(identity)
        if error:
            return error
        if not self.is_admin(identity.user_id):
            return "你没有 PalPanel 管理 API 写入权限。"
        return self._api_key_error()

    async def rename_base(self, identity: Any, args: str = "") -> str:
        error = self._admin_write_error(identity)
        if error:
            return error
        feature_error = await self._patch_feature_error("base-custom-names")
        if feature_error:
            return feature_error
        if not args.strip():
            try:
                _, resolve_error = await self._resolve_base(
                    identity,
                    "",
                    "/基地改名 <序号> | <新名称>",
                )
                return resolve_error or "请选择基地。"
            except PanelAPIError as exc:
                return exc.user_message()
        parts = [v.strip() for v in args.split("|", 1)]
        if len(parts) != 2 or not all(parts):
            return "用法：/基地改名 基地名称或ID或序号 | 新名称"
        try:
            base, resolve_error = await self._resolve_base(identity, parts[0], "/基地改名 <序号> | <新名称>")
            if resolve_error:
                return resolve_error
            base_id = _first(base, "id")
            result = await self._api_request(
                "PUT", f"/api/bases/{quote(base_id, safe='')}/name", payload={"name": parts[1]}
            )
            updated = _mapping(_mapping(unwrap(result)).get("base"))
            return f"基地名称已更新：{_first(updated, 'name', 'custom_name') or parts[1]}（{base_id}）"
        except PanelAPIError as exc:
            return exc.user_message()
        except Exception as exc:
            logger.warning("rename base failed: %s", exc)
            return "基地改名失败。"

    async def clear_base_name(self, identity: Any, args: str = "") -> str:
        error = self._admin_write_error(identity)
        if error:
            return error
        feature_error = await self._patch_feature_error("base-custom-names")
        if feature_error:
            return feature_error
        try:
            base, resolve_error = await self._resolve_base(identity, args, "/基地恢复名 <序号>")
            if resolve_error:
                return resolve_error
            base_id = _first(base, "id")
            await self._api_request("DELETE", f"/api/bases/{quote(base_id, safe='')}/name")
            return f"基地已恢复原名（{base_id}）。"
        except PanelAPIError as exc:
            return exc.user_message()
        except Exception as exc:
            logger.warning("clear base name failed: %s", exc)
            return "恢复基地名称失败。"

    async def annotate_player(self, identity: Any, args: str = "") -> str:
        error = self._admin_write_error(identity)
        if error:
            return error
        feature_error = await self._patch_feature_error("player-notes")
        if feature_error:
            return feature_error
        if not args.strip():
            try:
                _, resolve_error = await self._resolve_entity(
                    identity=identity,
                    entity_type="player",
                    path="/api/players",
                    key="players",
                    query="",
                    id_fields=("player_uid", "steam_id", "id"),
                    name_fields=("nickname",),
                    label="玩家",
                    usage="/玩家备注 <序号> | <备注> | 标签",
                )
                return resolve_error or "请选择玩家。"
            except PanelAPIError as exc:
                return exc.user_message()
        parts = [v.strip() for v in args.split("|")]
        if len(parts) < 2 or not parts[0]:
            return "用法：/玩家备注 玩家名称或ID或序号 | 备注 | 标签1,标签2"
        query = parts[0]
        note = parts[1] if len(parts) >= 2 else ""
        tags = [v.strip() for v in (parts[2].replace("，", ",").split(",") if len(parts) >= 3 else []) if v.strip()]
        try:
            player, resolve_error = await self._resolve_entity(
                identity=identity, entity_type="player",
                path="/api/players", key="players", query=query,
                id_fields=("player_uid", "steam_id", "id"), name_fields=("nickname",), label="玩家", usage="/玩家备注 <序号> | <备注> | 标签",
            )
            if resolve_error:
                return resolve_error
            player_id = _first(player, "player_uid", "steam_id", "id")
            result = await self._api_request(
                "PUT", f"/api/players/{quote(player_id, safe='')}/annotation",
                payload={"note": note, "tags": tags},
            )
            updated = _mapping(_mapping(unwrap(result)).get("player"))
            return f"玩家备注已保存：{_first(updated, 'nickname') or _first(player, 'nickname') or player_id}｜标签 {len(tags)} 个。"
        except PanelAPIError as exc:
            return exc.user_message()
        except Exception as exc:
            logger.warning("annotate player failed: %s", exc)
            return "保存玩家备注失败。"

    async def clear_player_annotation(self, identity: Any, args: str = "") -> str:
        error = self._admin_write_error(identity)
        if error:
            return error
        feature_error = await self._patch_feature_error("player-notes")
        if feature_error:
            return feature_error
        try:
            player, resolve_error = await self._resolve_entity(
                identity=identity, entity_type="player",
                path="/api/players", key="players", query=args,
                id_fields=("player_uid", "steam_id", "id"), name_fields=("nickname",), label="玩家", usage="/玩家清备注 <序号>",
            )
            if resolve_error:
                return resolve_error
            player_id = _first(player, "player_uid", "steam_id", "id")
            await self._api_request("DELETE", f"/api/players/{quote(player_id, safe='')}/annotation")
            return f"玩家备注与标签已清除：{_first(player, 'nickname') or player_id}。"
        except PanelAPIError as exc:
            return exc.user_message()
        except Exception as exc:
            logger.warning("clear player annotation failed: %s", exc)
            return "清除玩家备注失败。"

    async def _generic_status_text(self) -> str:
        status_task = self._api_request("GET", "/api/server/status")
        players_task = self._api_request(
            "GET", "/api/players", params={"online": "true", "limit": 100}
        )
        status, players = await asyncio.gather(status_task, players_task, return_exceptions=True)
        if isinstance(status, BaseException):
            raise status
        return format_generic_server_status(status, None if isinstance(players, BaseException) else players)

    async def _generic_online_text(self) -> str:
        payload = await self._api_request(
            "GET", "/api/players", params={"online": "true", "limit": 100}
        )
        data = _mapping(unwrap(payload))
        players = [p for p in data.get("players", []) if isinstance(p, dict) and p.get("is_online")]
        compatible = {
            "data": {
                "online_players": [
                    {
                        "name": p.get("nickname") or p.get("steam_id") or p.get("player_uid"),
                        "player_id": p.get("player_uid") or p.get("steam_id"),
                        "level": p.get("level"),
                    }
                    for p in players
                ],
                "players_available": True,
            }
        }
        return format_online_players(compatible, self.config.output_max_chars)

    async def _generic_rooms_text(self, query: str) -> str:
        params: dict[str, Any] = {
            "region": "cn",
            "status": "online",
            "page": 1,
            "page_size": self.config.max_room_results,
        }
        if query.strip():
            params["search"] = query.strip()
        payload = await self._api_request("GET", "/api/community-servers", params=params)
        return format_rooms(payload, self.config.max_room_results, self.config.output_max_chars)

    async def _generic_control(self, action: str, waittime: int) -> dict[str, Any]:
        message = "服务器将在倒计时结束后进行维护，请尽快前往安全地点。"
        mapping = {
            "start": ("/api/server/start", None),
            "safe_stop": ("/api/server/safe-stop", {"waittime": waittime, "message": message}),
            "safe_restart": ("/api/server/safe-restart", {"waittime": waittime, "message": message}),
            "force_stop": ("/api/server/force-stop", None),
        }
        path, payload = mapping[action]
        return await self._api_request("POST", path, payload=payload)
