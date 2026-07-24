from __future__ import annotations

import time
from dataclasses import dataclass
from typing import Any

from .table_format import render_key_values, render_table


def unwrap(payload: dict[str, Any]) -> Any:
    return payload.get("data", payload)


def parse_wait_seconds(value: str | int | None, default: int = 60) -> int:
    if value is None or str(value).strip() == "":
        return default
    wait = int(str(value).strip())
    if wait < 5 or wait > 300:
        raise ValueError("倒计时必须在 5 到 300 秒之间")
    return wait


def is_allowed(value: str, allowed_values: tuple[str, ...]) -> bool:
    return not allowed_values or str(value).strip() in allowed_values


@dataclass
class CooldownGuard:
    query_seconds: float = 5
    control_seconds: float = 15

    def __post_init__(self) -> None:
        self._seen: dict[tuple[str, str, str], float] = {}

    def retry_after(
        self,
        group_id: str,
        user_id: str,
        action: str,
        *,
        control: bool = False,
        now: float | None = None,
    ) -> int:
        current = time.monotonic() if now is None else now
        window = self.control_seconds if control else self.query_seconds
        key = (str(group_id), str(user_id), action)
        group_key = (str(group_id), "*", action)
        last = max(self._seen.get(key, -1e12), self._seen.get(group_key, -1e12))
        remaining = window - (current - last)
        if remaining > 0:
            return max(1, int(remaining + 0.999))
        self._seen[key] = current
        self._seen[group_key] = current - max(0.0, window - min(2.0, window))
        cutoff = current - max(self.query_seconds, self.control_seconds, 1.0) * 2
        self._seen = {item: seen for item, seen in self._seen.items() if seen >= cutoff}
        return 0


def _mapping(value: Any) -> dict[str, Any]:
    return value if isinstance(value, dict) else {}


def _list_of_mappings(value: Any) -> list[dict[str, Any]]:
    if not isinstance(value, list):
        return []
    return [item for item in value if isinstance(item, dict)]


def _safe_int(value: Any, default: int = 0) -> int:
    try:
        if isinstance(value, bool):
            return int(value)
        return int(float(str(value).strip()))
    except (TypeError, ValueError):
        return default


def _first_value(*values: Any, default: Any = "") -> Any:
    for value in values:
        if value is None:
            continue
        if isinstance(value, str) and not value.strip():
            continue
        return value
    return default


def format_server_status(payload: dict[str, Any]) -> str:
    """Format both upstream and patched AstrBot status payload variants.

    Formatting must never turn a successful HTTP response into an apparent
    API failure. PalPanel releases have used slightly different nesting and
    scalar types, so every field is read defensively.
    """
    data = _mapping(unwrap(payload))
    server = _mapping(data.get("server"))
    container = _mapping(server.get("container") or data.get("container"))
    info = _mapping(data.get("info") or server.get("info") or data.get("server_info"))
    status_obj = _mapping(data.get("status_detail"))

    state = str(
        _first_value(
            container.get("status"),
            server.get("status"),
            data.get("status"),
            status_obj.get("status"),
            data.get("state"),
            default="unknown",
        )
    ).strip() or "unknown"
    explicit_running = _first_value(
        server.get("running"),
        server.get("is_running"),
        data.get("running"),
        data.get("is_running"),
        data.get("server_running"),
        default=None,
    )
    if isinstance(explicit_running, bool):
        running = explicit_running
    else:
        running = state.lower() in {
            "running",
            "healthy",
            "restarting",
            "created",
            "starting",
            "online",
        }

    online_players = _list_of_mappings(
        data.get("online_players") or data.get("players") or info.get("online_players")
    )
    online_value = _first_value(
        data.get("online_count"),
        data.get("current_players"),
        info.get("online_count"),
        info.get("current_players"),
        info.get("players"),
        default=len(online_players),
    )
    online = _safe_int(online_value, len(online_players))

    name = str(
        _first_value(
            info.get("server_name"),
            info.get("servername"),
            info.get("serverName"),
            server.get("name"),
            data.get("server_name"),
            default="Palworld 服务器",
        )
    )
    version = str(
        _first_value(
            info.get("version"),
            server.get("version"),
            data.get("version"),
            data.get("game_version"),
            default="未知",
        )
    )
    return render_key_values(
        [
            ("服务器", name),
            ("状态", f"{'运行中' if running else '已停止'}（{state}）"),
            ("在线人数", online),
            ("版本", version),
        ],
        title="Palworld 服务器状态",
    )


def format_online_players(payload: dict[str, Any], max_chars: int = 1800) -> str:
    data = _mapping(unwrap(payload))
    players = _list_of_mappings(data.get("online_players") or data.get("players"))
    players = [
        player
        for player in players
        if data.get("online_players") is not None or player.get("is_online", True)
    ]
    if not players:
        available = bool(data.get("players_available", True))
        return "当前没有在线玩家。" if available else "暂时无法查询在线玩家，请稍后重试。"
    rows = []
    for index, player in enumerate(players, 1):
        name = str(
            _first_value(
                player.get("name"),
                player.get("nickname"),
                player.get("player_id"),
                player.get("player_uid"),
                default="未知玩家",
            )
        )
        level = player.get("level")
        player_id = _first_value(
            player.get("player_id"),
            player.get("player_uid"),
            player.get("steam_id"),
            default="-",
        )
        rows.append((index, name, "-" if level in (None, "") else level, player_id))
    text = f"当前在线 {len(players)} 人\n" + render_table(
        ("#", "玩家", "等级", "PlayerUID"),
        rows,
        max_column_widths=(3, 20, 6, 32),
        minimum_column_widths=(1, 6, 4, 8),
    )
    return truncate_text(text, max_chars)


def format_rooms(payload: dict[str, Any], limit: int = 10, max_chars: int = 1800) -> str:
    data = unwrap(payload)
    if isinstance(data, dict):
        rooms = _list_of_mappings(data.get("servers") or data.get("items"))
        stale = bool(data.get("stale"))
    else:
        rooms = _list_of_mappings(data)
        stale = False
    if not rooms:
        return "没有找到匹配的可发现社区服务器。"
    rows = []
    for index, room in enumerate(rooms[: max(1, limit)], 1):
        name = str(room.get("name") or "未命名服务器")
        host = room.get("address") or room.get("ip") or ""
        port = room.get("port") or room.get("query_port") or ""
        address = f"{host}:{port}" if host and port else str(host)
        players = room.get("players", room.get("current_players", 0))
        capacity = room.get("max_players", room.get("capacity", "?"))
        country = room.get("country") or room.get("country_code") or "--"
        rows.append((index, name, address or "-", f"{players}/{capacity}", country))
    title = "可发现社区服务器" + ("（缓存数据）" if stale else "")
    text = title + "\n" + render_table(
        ("#", "名称", "连接地址", "人数", "地区"),
        rows,
        max_column_widths=(3, 22, 24, 9, 6),
        minimum_column_widths=(1, 6, 8, 4, 4),
    )
    if len(rooms) > limit:
        text += f"\n仅显示前 {limit} 条，请增加关键词缩小范围。"
    return truncate_text(text, max_chars)

def truncate_text(value: str, max_chars: int) -> str:
    if max_chars < 32:
        max_chars = 32
    if len(value) <= max_chars:
        return value
    suffix = "\n…内容已截断"
    room = max_chars - len(suffix)
    prefix = value[: max(1, room)].rstrip()
    if prefix.count("```") % 2 == 1:
        closing = "\n```"
        room = max_chars - len(suffix) - len(closing)
        prefix = value[: max(1, room)].rstrip() + closing
    return prefix + suffix
