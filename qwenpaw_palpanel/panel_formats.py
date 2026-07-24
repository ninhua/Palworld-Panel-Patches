from __future__ import annotations

from typing import Any, Iterable, Sequence

from .operations import truncate_text, unwrap
from .table_format import render_key_values, render_table


def _dict(value: Any) -> dict[str, Any]:
    return value if isinstance(value, dict) else {}


def _list(value: Any) -> list[Any]:
    return value if isinstance(value, list) else []


def _num(value: Any, default: int | float = 0) -> int | float:
    try:
        return float(value) if isinstance(default, float) else int(value)
    except (TypeError, ValueError):
        return default


def _text(value: Any, default: str = "") -> str:
    text = str(value or "").strip()
    return text or default


def _bool_label(value: Any) -> str:
    return "是" if bool(value) else "否"


def _first(value: Any, keys: Sequence[str], default: str = "-") -> str:
    obj = _dict(value)
    for key in keys:
        text = _text(obj.get(key))
        if text:
            return text
    return default


def format_patch_info(payload: dict[str, Any], api_key_configured: bool) -> str:
    data = _dict(unwrap(payload))
    patch = _dict(data.get("patch"))
    upstream = _dict(data.get("upstream"))
    compatibility = _dict(data.get("compatibility"))
    build = _dict(data.get("build"))
    if not patch:
        return render_key_values(
            [
                ("补丁接口", "未检测到 /api/patch/info"),
                ("管理 API Key", "已配置" if api_key_configured else "未配置"),
            ],
            title="PalPanel 补丁信息",
        )
    features = [str(v) for v in _list(patch.get("features")) if str(v).strip()]
    rows = [
        ("补丁仓库", _text(patch.get("repository"), "未知")),
        ("补丁版本", _text(patch.get("version"), "未知")),
        ("目标版本", _text(compatibility.get("target_version"), "未知")),
        ("兼容验证", _bool_label(compatibility.get("verified"))),
        ("上游", f"{_text(upstream.get('repository'), '未知')}@{_text(upstream.get('ref'), '未知')}"),
        ("上游提交", _text(upstream.get("commit"), "未知")),
        ("构建版本", _text(build.get("version"), "未知")),
        ("管理 API Key", "已配置" if api_key_configured else "未配置"),
        ("功能", ", ".join(features) if features else "无"),
    ]
    return render_key_values(rows, title="PalPanel 补丁信息")


def format_generic_server_status(
    status_payload: dict[str, Any],
    players_payload: dict[str, Any] | None = None,
) -> str:
    data = _dict(unwrap(status_payload))
    container = _dict(data.get("container"))
    raw_state = _text(container.get("status") or data.get("status"), "unknown")
    running = raw_state.lower() in {"running", "healthy", "created", "restarting", "starting"}
    players = []
    if players_payload:
        player_data = _dict(unwrap(players_payload))
        players = [p for p in _list(player_data.get("players")) if isinstance(p, dict)]
    online = sum(1 for p in players if bool(p.get("is_online")))
    warnings = [str(v) for v in _list(data.get("warnings")) if str(v).strip()]
    rows = [
        ("状态", f"{'运行中' if running else '已停止'}（{raw_state}）"),
        ("在线人数", online if players_payload is not None else "未查询"),
        ("运行模式", _text(data.get("runtime_mode"), "未知")),
        ("游戏端口", _dict(data.get("ports")).get("game", data.get("port", "未知"))),
        ("版本", _text(data.get("version"), "未知")),
    ]
    if warnings:
        rows.append(("警告", "；".join(warnings[:3])))
    return render_key_values(rows, title="Palworld 服务器状态")


def format_version(payload: dict[str, Any]) -> str:
    data = _dict(unwrap(payload))
    warnings = [str(v) for v in _list(data.get("compatibility_warnings")) if str(v).strip()]
    rows = [
        ("游戏版本", _text(data.get("game_version"), "未知")),
        ("本地 Build ID", _text(data.get("current_build_id"), "未知")),
        ("最新 Build ID", _text(data.get("latest_build_id"), "未知")),
        ("需要更新", _bool_label(data.get("update_available"))),
        ("兼容目标", _text(data.get("compatibility_target"), "未知")),
    ]
    if isinstance(data.get("compatible"), bool):
        rows.append(("兼容", _bool_label(data.get("compatible"))))
    if warnings:
        rows.append(("警告", "；".join(warnings[:5])))
    if data.get("error"):
        rows.append(("错误", data["error"]))
    return render_key_values(rows, title="Palworld 版本")


def format_save_index(payload: dict[str, Any]) -> str:
    data = _dict(unwrap(payload))
    counts = _dict(data.get("counts"))
    warnings = [str(v) for v in _list(data.get("warnings")) if str(v).strip()]
    rows = [
        ("状态", _text(data.get("state"), "未知") + ("（过期）" if data.get("stale") else "")),
        ("已启用", _bool_label(data.get("enabled"))),
        ("解析器", _text(data.get("parser"), "未知")),
        ("玩家", _num(counts.get("players"))),
        ("公会", _num(counts.get("guilds"))),
        ("基地", _num(counts.get("bases"))),
        ("帕鲁", _num(counts.get("pals"))),
        ("容器", _num(counts.get("containers"))),
        ("更新时间", _text(data.get("updated_at"), "未知")),
    ]
    if warnings:
        rows.append(("警告", "；".join(warnings[:5])))
    if data.get("error"):
        rows.append(("错误", data["error"]))
    return render_key_values(rows, title="存档索引")


def format_players(payload: dict[str, Any], max_chars: int) -> str:
    data = _dict(unwrap(payload))
    players = [p for p in _list(data.get("players")) if isinstance(p, dict)]
    if not players:
        return "没有找到玩家。"
    summary = _dict(data.get("summary"))
    rows = []
    for idx, player in enumerate(players, 1):
        tags = "/".join(str(v) for v in _list(player.get("tags")) if str(v).strip())
        rows.append(
            (
                idx,
                _text(player.get("nickname"), "未命名"),
                _num(player.get("level")),
                "在线" if player.get("is_online") else "离线",
                _text(player.get("player_uid"), "-"),
                _text(player.get("steam_id"), "-"),
                tags or "-",
            )
        )
    text = (
        f"玩家列表：返回 {len(players)} / 总计 {_num(summary.get('total'), len(players))}\n"
        "序号可直接用于：/玩家详情、/背包、/玩家备注、/玩家清备注\n"
        + render_table(
        ("#", "昵称", "Lv", "状态", "PlayerUID", "SteamID", "标签"),
        rows,
        max_column_widths=(3, 14, 4, 4, 20, 18, 12),
        minimum_column_widths=(1, 4, 2, 4, 8, 8, 4),
    )
    )
    return truncate_text(text, max_chars)


def format_player_detail(payload: dict[str, Any], max_chars: int) -> str:
    data = _dict(unwrap(payload))
    player = _dict(data.get("player"))
    if not player:
        return "未找到玩家详情。"
    view = _dict(data.get("view"))
    tags = [str(v) for v in _list(player.get("tags")) if str(v).strip()]
    rows = [
        ("昵称", _text(player.get("nickname"), "未命名")),
        ("等级", _num(player.get("level"))),
        ("状态", "在线" if player.get("is_online") else "离线"),
        ("PalPanel ID", _text(player.get("id"), "-")),
        ("PlayerUID", _text(player.get("player_uid"), "-")),
        ("SteamID", _text(player.get("steam_id"), "-")),
        ("GM User ID", _text(player.get("gm_user_id"), "-")),
        ("公会名称", _text(player.get("guild_name"), "-")),
        ("公会 ID", _text(player.get("guild_id"), "-")),
        ("存档源 ID", _text(view.get("source_id") or data.get("source_id"), "-")),
        ("存档源类型", _text(view.get("source_kind"), "-")),
        ("最后在线", _text(player.get("last_online_time"), "未知")),
        ("坐标", f"{player.get('location_x', player.get('x', 0))}, {player.get('location_y', player.get('y', 0))}, {player.get('location_z', player.get('z', 0))}"),
        ("标签", "、".join(tags) if tags else "无"),
        ("备注", _text(player.get("note"), "无")),
    ]
    return truncate_text(render_key_values(rows, title="玩家详情"), max_chars)


def format_inventory(payload: dict[str, Any], max_chars: int) -> str:
    data = _dict(unwrap(payload))
    containers = [c for c in _list(data.get("containers")) if isinstance(c, dict)]
    if not containers:
        return "该玩家没有可读取的背包容器。"
    rows = []
    for cidx, container in enumerate(containers, 1):
        slots = [s for s in _list(container.get("slots")) if isinstance(s, dict) and _num(s.get("count")) > 0]
        for slot in slots[:30]:
            rows.append(
                (
                    cidx,
                    _text(container.get("container_id"), "-"),
                    _num(slot.get("slot")),
                    _text(slot.get("item_name") or slot.get("item_id"), "未知物品"),
                    _num(slot.get("count")),
                )
            )
    if not rows:
        return "玩家背包容器存在，但没有非空槽位。"
    text = f"玩家背包：{len(containers)} 个容器\n" + render_table(
        ("箱", "容器 ID", "槽", "物品", "数量"),
        rows,
        max_column_widths=(3, 20, 4, 24, 8),
        minimum_column_widths=(2, 8, 2, 6, 4),
    )
    return truncate_text(text, max_chars)


def format_guilds(payload: dict[str, Any], max_chars: int) -> str:
    data = _dict(unwrap(payload))
    guilds = [g for g in _list(data.get("guilds")) if isinstance(g, dict)]
    if not guilds:
        return "没有找到公会。"
    rows = [
        (
            idx,
            _text(guild.get("name"), "未命名公会"),
            _num(guild.get("member_count"), len(_list(guild.get("members")))),
            _num(guild.get("online_count")),
            _text(guild.get("id"), "-"),
            _text(guild.get("owner_player_uid"), "-"),
        )
        for idx, guild in enumerate(guilds, 1)
    ]
    text = f"公会列表（{len(guilds)}）\n序号可直接用于：/公会详情\n" + render_table(
        ("#", "名称", "成员", "在线", "公会 ID", "会长 UID"),
        rows,
        max_column_widths=(3, 18, 5, 5, 22, 20),
        minimum_column_widths=(1, 6, 4, 4, 8, 8),
    )
    return truncate_text(text, max_chars)


def format_guild_detail(payload: dict[str, Any], max_chars: int) -> str:
    data = _dict(unwrap(payload))
    guild = _dict(data.get("guild"))
    if not guild:
        return "未找到公会详情。"
    members = [m for m in _list(data.get("members") or guild.get("members")) if isinstance(m, dict)]
    bases = [b for b in _list(data.get("bases")) if isinstance(b, dict)]
    sections = [
        render_key_values(
            [
                ("公会名称", _text(guild.get("name"), "未命名公会")),
                ("公会 ID", _text(guild.get("id"), "-")),
                ("会长 UID", _text(guild.get("owner_player_uid"), "-")),
                ("成员数量", len(members) if members else _num(guild.get("member_count"))),
                ("关联基地", len(bases)),
                ("存档源 ID", _text(data.get("source_id"), "-")),
            ],
            title="公会详情",
        )
    ]
    if members:
        member_rows = []
        for idx, member in enumerate(members[:30], 1):
            member_rows.append(
                (
                    idx,
                    ("[会长]" if member.get("is_owner") else "") + _text(member.get("nickname"), member.get("player_uid", "未知")),
                    _num(member.get("level")),
                    "在线" if member.get("is_online") else "离线",
                    _text(member.get("player_uid"), "-"),
                    "/".join(str(v) for v in _list(member.get("tags"))) or "-",
                )
            )
        sections.append("成员\n" + render_table(
            ("#", "昵称", "Lv", "状态", "PlayerUID", "标签"),
            member_rows,
            max_column_widths=(3, 16, 4, 4, 22, 12),
            minimum_column_widths=(1, 6, 2, 4, 8, 4),
        ))
    if bases:
        sections.append("关联基地\n" + render_table(
            ("#", "基地名称", "基地 ID", "工作帕鲁", "建筑"),
            [
                (
                    idx,
                    _text(base.get("name"), base.get("id", "未知")),
                    _text(base.get("id"), "-"),
                    _num(base.get("workers_count"), base.get("pals_count", 0)),
                    _num(base.get("structures_count")),
                )
                for idx, base in enumerate(bases[:20], 1)
            ],
            max_column_widths=(3, 18, 24, 8, 6),
            minimum_column_widths=(1, 6, 8, 4, 4),
        ))
    return truncate_text("\n".join(sections), max_chars)


def format_bases(payload: dict[str, Any], max_chars: int) -> str:
    data = _dict(unwrap(payload))
    bases = [b for b in _list(data.get("bases")) if isinstance(b, dict)]
    if not bases:
        return "没有找到基地。"
    rows = [
        (
            idx,
            _text(base.get("name"), "未命名基地"),
            _num(base.get("pals_count"), len(_list(base.get("workers")))),
            _num(base.get("structures_count")),
            _text(base.get("guild_name"), "-"),
            _text(base.get("id"), "-"),
        )
        for idx, base in enumerate(bases, 1)
    ]
    text = f"基地列表（{len(bases)}）\n序号可直接用于：/基地详情、/仓库、/工作帕鲁、/饲料箱、/基地改名\n" + render_table(
        ("#", "基地名称", "帕鲁", "建筑", "公会", "基地 ID"),
        rows,
        max_column_widths=(3, 18, 5, 5, 14, 26),
        minimum_column_widths=(1, 6, 4, 4, 4, 8),
    )
    return truncate_text(text, max_chars)


def format_base_detail(payload: dict[str, Any], max_chars: int) -> str:
    data = _dict(unwrap(payload))
    base = _dict(data.get("base"))
    if not base:
        return "未找到基地详情。"
    rows = [
        ("基地名称", _text(base.get("name"), "未命名基地")),
        ("基地 ID", _text(base.get("id"), "-")),
        ("原始名称", _text(base.get("raw_name"), "-")),
        ("自定义名称", _text(base.get("custom_name"), "未设置")),
        ("公会名称", _text(base.get("guild_name"), "-")),
        ("公会 ID", _text(base.get("guild_id"), "-")),
        ("存档源 ID", _text(data.get("source_id"), "-")),
        ("坐标", f"{base.get('x', 0)}, {base.get('y', 0)}, {base.get('z', 0)}"),
        ("建筑数量", _num(base.get("structures_count"))),
        ("工作帕鲁", _num(base.get("pals_count"), len(_list(base.get("workers"))))),
        ("状态", _text(base.get("status"), "未知")),
    ]
    return truncate_text(render_key_values(rows, title="基地详情"), max_chars)


def format_storage(payload: dict[str, Any], max_chars: int) -> str:
    data = _dict(unwrap(payload))
    containers = [c for c in _list(data.get("containers")) if isinstance(c, dict)]
    if not containers:
        return "该基地没有可读取的仓库容器。"
    rows = []
    occupied = 0
    total_items = 0
    for idx, container in enumerate(containers, 1):
        slots = [s for s in _list(container.get("slots")) if isinstance(s, dict) and _num(s.get("count")) > 0]
        occupied += len(slots)
        total_items += sum(int(_num(s.get("count"))) for s in slots)
        for slot in slots[:30]:
            rows.append(
                (
                    idx,
                    _text(container.get("container_name"), container.get("container_type", "存储容器")),
                    _num(slot.get("slot")),
                    _text(slot.get("item_name") or slot.get("item_id"), "未知物品"),
                    _num(slot.get("count")),
                )
            )
    summary = render_key_values(
        [("容器数量", len(containers)), ("占用槽位", occupied), ("物品总量", total_items)],
        title="基地仓库汇总",
    )
    if not rows:
        return summary + "\n所有容器均为空。"
    table = render_table(
        ("箱", "容器", "槽", "物品", "数量"),
        rows,
        max_column_widths=(3, 18, 4, 24, 8),
        minimum_column_widths=(2, 6, 2, 6, 4),
    )
    return truncate_text(summary + "\n仓库明细\n" + table, max_chars)


def format_pals(payload: dict[str, Any], max_chars: int) -> str:
    data = _dict(unwrap(payload))
    pals = [p for p in _list(data.get("pals")) if isinstance(p, dict)]
    if not pals:
        return "没有找到帕鲁。"
    rows = []
    for idx, pal in enumerate(pals, 1):
        rows.append(
            (
                idx,
                _text(pal.get("name"), pal.get("species_name", "未知帕鲁")),
                _text(pal.get("species_name"), pal.get("character_id", "未知")),
                _num(pal.get("level")),
                _text(pal.get("owner_nickname"), "-"),
                _text(pal.get("instance_id") or pal.get("id"), "-"),
            )
        )
    text = f"帕鲁列表（{len(pals)}）\n序号可直接用于：/帕鲁详情\n" + render_table(
        ("#", "名称", "种类", "Lv", "主人", "实例 ID"),
        rows,
        max_column_widths=(3, 15, 15, 4, 12, 26),
        minimum_column_widths=(1, 4, 4, 2, 4, 8),
    )
    return truncate_text(text, max_chars)


def format_pal_detail(payload: dict[str, Any], max_chars: int) -> str:
    data = _dict(unwrap(payload))
    pal = _dict(data.get("pal"))
    if not pal:
        return "未找到帕鲁详情。"
    passives = [str(v) for v in _list(pal.get("passives"))]
    rows = [
        ("名称", _text(pal.get("name"), pal.get("species_name", "未知帕鲁"))),
        ("种类", _text(pal.get("species_name"), pal.get("character_id", "未知"))),
        ("实例 ID", _text(pal.get("instance_id") or pal.get("id"), "-")),
        ("Character ID", _text(pal.get("character_id"), "-")),
        ("等级", _num(pal.get("level"))),
        ("状态", _text(pal.get("status"), "未知")),
        ("主人", _text(pal.get("owner_nickname"), "-")),
        ("主人 UID", _text(pal.get("owner_player_uid"), "-")),
        ("公会 ID", _text(pal.get("guild_id"), "-")),
        ("容器 ID", _text(pal.get("container_id"), "-")),
        ("坐标", f"{pal.get('x', 0)}, {pal.get('y', 0)}, {pal.get('z', 0)}"),
        ("被动", "、".join(passives) if passives else "无"),
    ]
    return truncate_text(render_key_values(rows, title="帕鲁详情"), max_chars)


def format_workers(payload: dict[str, Any], max_chars: int) -> str:
    data = _dict(unwrap(payload))
    base = _dict(data.get("base"))
    workers = [w for w in _list(data.get("workers")) if isinstance(w, dict)]
    summary = _dict(data.get("summary"))
    sections = [
        render_key_values(
            [
                ("基地", _text(base.get("name"), base.get("id", "未知基地"))),
                ("基地 ID", _text(base.get("id"), "-")),
                ("总数", _num(summary.get("total"), len(workers))),
                ("平均等级", f"{float(_num(summary.get('average_level'), 0.0)):.1f}"),
                ("最高等级", _num(summary.get("max_level"))),
                ("种类数量", _num(summary.get("species_count"))),
            ],
            title="工作帕鲁汇总",
        )
    ]
    if workers:
        sections.append(render_table(
            ("#", "名称", "种类", "Lv", "Rank", "状态", "实例 ID"),
            [
                (
                    idx,
                    _text(worker.get("name"), worker.get("species_name", "未知帕鲁")),
                    _text(worker.get("species_name"), worker.get("character_id", "未知")),
                    _num(worker.get("level")),
                    _num(worker.get("rank")),
                    _text(worker.get("status"), "未知"),
                    _text(worker.get("instance_id"), "-"),
                )
                for idx, worker in enumerate(workers, 1)
            ],
            max_column_widths=(3, 14, 14, 4, 5, 10, 24),
            minimum_column_widths=(1, 4, 4, 2, 4, 4, 8),
        ))
    else:
        sections.append("当前没有工作帕鲁。")
    return truncate_text("\n".join(sections), max_chars)


def format_feed_boxes(payload: dict[str, Any], max_chars: int) -> str:
    data = _dict(unwrap(payload))
    base = _dict(data.get("base"))
    items = [i for i in _list(data.get("items")) if isinstance(i, dict)]
    boxes = [b for b in _list(data.get("feed_boxes")) if isinstance(b, dict)]
    summary = _dict(data.get("summary"))
    sections = [
        render_key_values(
            [
                ("基地", _text(base.get("name"), base.get("id", "未知基地"))),
                ("基地 ID", _text(base.get("id"), "-")),
                ("箱子数量", _num(summary.get("box_count"), len(boxes))),
                ("空箱", _num(summary.get("empty_box_count"))),
                ("占用槽位", _num(summary.get("occupied_slots"))),
                ("物品总量", _num(summary.get("total_items"))),
                ("食物种类", _num(summary.get("item_types"), len(items))),
            ],
            title="饲料箱汇总",
        )
    ]
    if items:
        sections.append(render_table(
            ("#", "食物", "Item ID", "数量", "分布箱数"),
            [
                (
                    idx,
                    _text(item.get("item_name"), item.get("item_id", "未知物品")),
                    _text(item.get("item_id"), "-"),
                    _num(item.get("count")),
                    _num(item.get("box_count")),
                )
                for idx, item in enumerate(items, 1)
            ],
            max_column_widths=(3, 20, 22, 8, 8),
            minimum_column_widths=(1, 6, 8, 4, 4),
        ))
    else:
        sections.append("没有食物。")
    return truncate_text("\n".join(sections), max_chars)


def format_diagnostics(rows: Iterable[tuple[str, str]]) -> str:
    return render_table(
        ("检查项", "结果"),
        list(rows),
        max_column_widths=(20, 52),
        minimum_column_widths=(6, 8),
    )


def format_entity_choices(
    label: str,
    items: Sequence[dict[str, Any]],
    *,
    id_fields: Sequence[str],
    name_fields: Sequence[str],
    usage: str,
    max_chars: int,
) -> str:
    rows = []
    for index, item in enumerate(items, 1):
        rows.append(
            (
                index,
                _first(item, name_fields, "未知"),
                _first(item, id_fields, "-"),
            )
        )
    text = f"请选择{label}\n选择有效期内可直接使用序号：{usage}\n" + render_table(
        ("序号", label, "ID"),
        rows,
        max_column_widths=(4, 24, 38),
        minimum_column_widths=(4, 6, 8),
    )
    return truncate_text(text, max_chars)


def format_binding_profile(
    *,
    identity: dict[str, Any],
    binding: dict[str, Any],
    player_payload: dict[str, Any] | None,
    bases_payload: dict[str, Any] | None,
    api_error: str = "",
    max_chars: int,
) -> str:
    player_data = _dict(unwrap(player_payload or {}))
    player = _dict(player_data.get("player"))
    view = _dict(player_data.get("view"))
    rows = [
        ("通道", _text(identity.get("channel_id"), "未知")),
        ("QQ/OpenID", _text(identity.get("user_id"), "-")),
        ("群/频道 ID", _text(identity.get("group_id"), "私聊")),
        ("绑定状态", _text(binding.get("status"), "未知")),
        ("游戏昵称", _text(player.get("nickname") or binding.get("nickname"), "未知")),
        ("PalPanel ID", _text(player.get("id"), "-")),
        ("PlayerUID", _text(player.get("player_uid") or binding.get("player_uid"), "-")),
        ("SteamID", _text(player.get("steam_id"), "-")),
        ("GM User ID", _text(player.get("gm_user_id"), "-")),
        ("公会名称", _text(player.get("guild_name"), "-")),
        ("公会 ID", _text(player.get("guild_id"), "-")),
        ("存档源 ID", _text(view.get("source_id") or player_data.get("source_id"), "-")),
        ("存档源类型", _text(view.get("source_kind"), "-")),
        ("等级", _num(player.get("level")) if player else "-"),
        ("在线状态", ("在线" if player.get("is_online") else "离线") if player else "未查询"),
    ]
    if api_error:
        rows.append(("管理 API", api_error))
    sections = [render_key_values(rows, title="我的绑定角色与关联 ID")]
    bases_data = _dict(unwrap(bases_payload or {}))
    bases = [b for b in _list(bases_data.get("bases")) if isinstance(b, dict)]
    if bases:
        sections.append("所属公会关联基地\n" + render_table(
            ("#", "基地名称", "基地 ID", "坐标"),
            [
                (
                    idx,
                    _text(base.get("name"), "未命名基地"),
                    _text(base.get("id"), "-"),
                    f"{base.get('x', 0)}, {base.get('y', 0)}",
                )
                for idx, base in enumerate(bases[:20], 1)
            ],
            max_column_widths=(3, 20, 30, 16),
            minimum_column_widths=(1, 6, 8, 6),
        ))
    return truncate_text("\n".join(sections), max_chars)
