from __future__ import annotations

import logging
from collections.abc import Awaitable, Callable, Iterable
from typing import Any

from qwenpaw.runtime.commands.control import parse_args
from qwenpaw.runtime.commands.control.base import (
    BaseControlCommandHandler,
    ControlContext,
)
from qwenpaw.runtime.slash_command_registry import CommandSpec

from .service import CommandIdentity, PalPanelService

logger = logging.getLogger(__name__)
CommandCallback = Callable[[CommandIdentity, str], Awaitable[str]]


def _mapping(value: Any) -> dict[str, Any]:
    """Convert dict/Pydantic/dataclass-like metadata to a plain mapping."""
    if isinstance(value, dict):
        return value
    if value is None:
        return {}
    for method_name in ("model_dump", "dict"):
        method = getattr(value, method_name, None)
        if callable(method):
            try:
                result = method()
                if isinstance(result, dict):
                    return result
            except Exception:
                pass
    raw = getattr(value, "__dict__", None)
    return raw if isinstance(raw, dict) else {}


def _value(source: Any, name: str, default: Any = "") -> Any:
    if source is None:
        return default
    if isinstance(source, dict):
        return source.get(name, default)
    return getattr(source, name, default)


def _normalize_channel(value: Any) -> str:
    text = str(value or "").strip().lower().replace("-", "_")
    if not text:
        return ""
    if text.startswith("onebot") or "napcat" in text:
        return "onebot"
    if text in {"qq", "qqbot", "qq_bot"}:
        return "qq"
    return text


def _onebot_session_values(session_id: str) -> tuple[str, str]:
    """Recover ``(group_id, user_id)`` from QwenPaw OneBot session IDs."""
    parts = str(session_id or "").split(":")
    if not parts or parts[0].lower() != "onebot":
        return "", ""
    # Shared group session: onebot:g:<group_id>
    if len(parts) >= 3 and parts[1].lower() == "g":
        return parts[2], ""
    # Private variants: onebot:p:<sender_id> / onebot:private:<sender_id>
    if len(parts) >= 3 and parts[1].lower() in {"p", "private"}:
        return "", parts[2]
    # Per-user group session: onebot:<group_id>:<sender_id>
    if len(parts) >= 3 and parts[1] and parts[2]:
        return parts[1], parts[2]
    return "", ""


def identity_from_context(context: ControlContext) -> CommandIdentity:
    request = context.payload
    meta = _mapping(
        _value(request, "channel_meta", None)
        or _value(request, "meta", None)
    )
    channel = context.channel
    session_id = str(context.session_id or "")
    session_group_id, session_user_id = _onebot_session_values(session_id)

    channel_candidates = (
        channel if isinstance(channel, str) else "",
        _value(channel, "channel", ""),
        _value(channel, "channel_id", ""),
        _value(request, "channel", ""),
        _value(request, "channel_id", ""),
        meta.get("channel_id", ""),
    )
    channel_id = ""
    explicit_onebot = False
    for candidate in channel_candidates:
        normalized = _normalize_channel(candidate)
        if not normalized:
            continue
        if not channel_id:
            channel_id = normalized
        if normalized == "onebot":
            explicit_onebot = True
            channel_id = "onebot"
            break

    user_id = str(
        context.user_id
        or meta.get("sender_id", "")
        or _value(request, "acl_sender_id", "")
        or _value(request, "user_id", "")
        or session_user_id
        or ""
    )
    message_type = str(meta.get("message_type", "") or "").lower()
    # OneBot uses numeric ``group_id``. QwenPaw's official QQ Bot channel
    # uses ``group_openid`` for QQ groups and ``channel_id``/``guild_id``
    # for guild channels. Normalize all of them into the plugin's group_id.
    if message_type == "group":
        group_id = str(
            meta.get("group_openid", "")
            or meta.get("group_id", "")
            or _value(request, "group_id", "")
            or session_group_id
            or ""
        )
    elif message_type == "guild":
        group_id = str(
            meta.get("channel_id", "")
            or meta.get("guild_id", "")
            or _value(request, "group_id", "")
            or ""
        )
    else:
        group_id = str(
            meta.get("group_id", "")
            or meta.get("group_openid", "")
            or _value(request, "group_id", "")
            or session_group_id
            or ""
        )
    is_group = bool(
        meta.get("is_group", False)
        or message_type in {"group", "guild"}
        or group_id
    )

    session_onebot = session_id.lower().startswith("onebot:")
    # Compatibility for builds that expose the generic ``qq`` key for a
    # NapCat/OneBot request. OneBot v11 IDs are numeric and its metadata uses
    # message_type/sender_id/group_id exactly as below.
    onebot_shaped_meta = bool(
        message_type in {"group", "private"}
        and user_id.isdigit()
        and (not is_group or (bool(group_id) and group_id.isdigit()))
    )
    is_onebot = explicit_onebot or session_onebot or (
        channel_id in {"", "qq"} and onebot_shaped_meta
    )
    if is_onebot:
        channel_id = "onebot"
    is_qq_channel = channel_id in {"qq", "onebot"}

    identity = CommandIdentity(
        user_id=user_id,
        group_id=group_id,
        agent_id=str(context.agent_id or ""),
        channel_id=channel_id,
        is_group=is_group,
        is_onebot=is_onebot,
        is_qq_channel=is_qq_channel,
    )
    logger.debug(
        "PalPanel identity channel=%s qq_channel=%s onebot=%s user=%s "
        "group=%s is_group=%s agent=%s session=%s message_type=%s",
        identity.channel_id or "<empty>",
        identity.is_qq_channel,
        identity.is_onebot,
        identity.user_id or "<empty>",
        identity.group_id or "<empty>",
        identity.is_group,
        identity.agent_id or "<empty>",
        session_id or "<empty>",
        message_type or "<empty>",
    )
    return identity



class PalPanelCommandHandler(BaseControlCommandHandler):
    def __init__(
        self,
        command_name: str,
        description: str,
        callback: CommandCallback,
    ) -> None:
        # QwenPaw plugin handlers use the bare command token. The leading '/'
        # belongs to the incoming message, not to ``command_name``.
        self.command_name = command_name.lstrip("/")
        self.description = description
        self.help_text = description
        self._callback = callback

    async def handle(self, context: ControlContext) -> str:
        raw_args = str(context.args.get("_raw_args", "") or "")
        try:
            return await self._callback(identity_from_context(context), raw_args)
        except Exception as exc:
            logger.exception("PalPanel command %s failed: %s", self.command_name, exc)
            return "PalPanel 命令执行失败，请检查 QwenPaw 与 PalPanel 日志。"


def _aliases(
    names: tuple[str, ...],
    description: str,
    callback: CommandCallback,
) -> list[PalPanelCommandHandler]:
    return [
        PalPanelCommandHandler(
            command_name=name,
            description=description,
            callback=callback,
        )
        for name in names
    ]


def build_handlers(service: PalPanelService) -> list[BaseControlCommandHandler]:
    handlers: list[BaseControlCommandHandler] = []
    definitions: list[tuple[tuple[str, ...], str, CommandCallback]] = [
        (("服状态", "serverstatus", "服务器状态"), "查询 Palworld 服务器状态", service.server_status),
        (("在线", "online", "在线玩家"), "查询当前在线玩家", service.online),
        (("房间", "rooms", "社区服"), "查询社区服务器：/房间 [关键词]", service.rooms),
        (("开服", "serverstart"), "管理员启动服务器", service.start_server),
        (("关服", "serverstop"), "管理员安全关服：/关服 [5-300 秒]", service.stop_server),
        (("重启", "serverrestart"), "管理员安全重启：/重启 [5-300 秒]", service.restart_server),
        (("强关", "serverforcestop"), "管理员强制停止服务器", service.force_stop_server),
        (("bd", "绑定"), "绑定游戏角色：/bd 游戏昵称", service.bind),
        (("bdqr", "绑定确认"), "确认绑定验证码：/bdqr 验证码", service.bind_confirm),
        (("qd", "签到"), "每日签到领取积分", service.checkin),
        (("jf", "积分"), "查看角色绑定和积分", service.points),
        (("我的角色", "绑定信息", "角色信息", "myplayer"), "显示已绑定角色及关联 ID", service.binding_info),
        (("pz", "配种"), "配种计算：/pz [目标帕鲁] [被动词条...]", service.breeding),
        (("paladmin", "帕鲁管理"), "PalPanel 管理操作", service.admin),
        (("palid", "身份"), "显示当前 QQ/OneBot 用户与群标识", service.identity_info),
        (("palhelp", "帕鲁帮助", "面板帮助"), "显示命令帮助；/palhelp 补丁列出全部补丁 API", service.panel_help),
        (("表格模式", "tablemode", "显示模式"), "查看或切换表格格式：/表格模式 markdown|ascii", service.table_mode_command),
        (("面板信息", "补丁信息", "patchinfo"), "显示 PalPanel 补丁版本和能力", service.panel_info),
        (("接口诊断", "paldiag"), "诊断 PalPanel 健康、补丁和 API Key", service.diagnostics),
        (("游戏版本", "gameversion"), "查询 Palworld 游戏和 Build 版本", service.game_version),
        (("存档索引", "saveindex"), "查询 PalPanel 存档索引状态", service.save_index),
        (("玩家", "players"), "查询玩家：/玩家 [关键词]", service.players),
        (("玩家详情", "playerdetail"), "查询玩家详情：/玩家详情 <昵称或ID>", service.player_detail),
        (("背包", "inventory"), "查询玩家背包：/背包 <昵称或ID>", service.inventory),
        (("公会", "guilds"), "查询公会：/公会 [关键词]", service.guilds),
        (("公会详情", "guilddetail"), "查询补丁增强公会详情", service.guild_detail),
        (("基地", "bases"), "查询基地：/基地 [关键词]", service.bases),
        (("基地详情", "basedetail"), "查询基地详情：/基地详情 <名称或ID>", service.base_detail),
        (("仓库", "storage"), "查询基地仓库：/仓库 <基地>", service.storage),
        (("帕鲁", "pals"), "查询帕鲁：/帕鲁 [关键词]", service.pals),
        (("帕鲁详情", "paldetail"), "查询帕鲁详情：/帕鲁详情 <名称或ID>", service.pal_detail),
        (("工作帕鲁", "baseworkers"), "查询补丁基地工作帕鲁", service.workers),
        (("饲料箱", "feedboxes"), "查询补丁基地饲料箱汇总", service.feed_boxes),
        (("基地改名", "baserename"), "管理员设置基地自定义名称", service.rename_base),
        (("基地恢复名", "baseclearname"), "管理员恢复基地原名", service.clear_base_name),
        (("玩家备注", "playernote"), "管理员保存玩家备注和标签", service.annotate_player),
        (("玩家清备注", "playerclearnote"), "管理员清除玩家备注和标签", service.clear_player_annotation),
    ]
    for names, description, callback in definitions:
        handlers.extend(_aliases(names, description, callback))
    return handlers


def _make_slash_handler(
    control_handler: BaseControlCommandHandler,
    command_name: str,
):
    """Adapt a control handler to QwenPaw's per-workspace slash runtime."""

    async def _dispatch(ctx: Any, args: str):
        from agentscope.message import Msg, TextBlock

        workspace = getattr(ctx, "workspace", None)
        request = getattr(ctx, "request", None)
        if workspace is None:
            return Msg(
                name="assistant",
                role="assistant",
                content=[
                    TextBlock(
                        type="text",
                        text="PalPanel 命令不可用：QwenPaw workspace 尚未初始化。",
                    ),
                ],
            )

        channel = None
        channel_mgr = getattr(workspace, "channel_manager", None)
        if channel_mgr is not None:
            channel_id = getattr(request, "channel", None) or "console"
            try:
                channel = await channel_mgr.get_channel(channel_id)
            except Exception:
                logger.debug(
                    "Unable to resolve channel %s for /%s",
                    channel_id,
                    command_name,
                    exc_info=True,
                )

        full_query = (
            f"/{command_name} {args}".strip() if args else f"/{command_name}"
        )
        parsed_args = parse_args(full_query, f"/{command_name}")
        ctrl_ctx = ControlContext(
            workspace=workspace,
            payload=request,
            channel=channel,
            session_id=getattr(ctx, "session_id", "") or "",
            user_id=(getattr(request, "user_id", "") if request else "") or "",
            agent_id=getattr(ctx, "agent_id", "") or "",
            args=parsed_args,
        )

        result = await control_handler.handle(ctrl_ctx)
        if isinstance(result, Msg):
            return result
        return Msg(
            name="assistant",
            role="assistant",
            content=[TextBlock(type="text", text=str(result))],
        )

    return _dispatch


def build_command_specs(
    handlers: Iterable[BaseControlCommandHandler],
) -> list[CommandSpec]:
    """Build runtime slash specs for direct, model-free command dispatch."""

    specs: list[CommandSpec] = []
    for handler in handlers:
        command_name = str(handler.command_name).lstrip("/")
        description = str(
            getattr(handler, "description", "")
            or getattr(handler, "help_text", "")
            or ""
        )
        specs.append(
            CommandSpec(
                name=command_name,
                handler=_make_slash_handler(handler, command_name),
                category="control",
                help_text=description,
                metadata={"plugin_id": "palpanel-qwenpaw"},
            ),
        )
    return specs
