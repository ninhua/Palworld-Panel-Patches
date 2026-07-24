from __future__ import annotations

import asyncio
import json
import logging
import os
import secrets
from dataclasses import dataclass
from datetime import datetime
from urllib.parse import quote, urlparse
from zoneinfo import ZoneInfo

from aiohttp import ClientSession, ClientTimeout

from .config import PalPanelConfig
from .management import ManagementCommandsMixin, PanelAPIError
from .panel_formats import format_binding_profile
from .table_format import (
    get_table_mode,
    normalize_table_mode,
    render_key_values,
    set_table_mode,
)
from .operations import (
    CooldownGuard,
    format_online_players,
    format_rooms,
    format_server_status,
    is_allowed,
    parse_wait_seconds,
)
from .security import body_bytes, signed_headers
from .storage import PalPanelStore

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class CommandIdentity:
    user_id: str
    group_id: str
    agent_id: str
    channel_id: str
    is_group: bool
    is_onebot: bool = False
    is_qq_channel: bool = False


class PalPanelService(ManagementCommandsMixin):
    def __init__(self, config: PalPanelConfig):
        self.config = config
        self.store = PalPanelStore(config.database_path)
        self.http: ClientSession | None = None
        self.cooldowns = CooldownGuard(
            query_seconds=config.query_cooldown_seconds,
            control_seconds=config.control_cooldown_seconds,
        )
        self._patch_cache_payload = None
        self._patch_cache_at = 0.0
        self._entity_selection_cache: dict[str, tuple[float, list[dict]]] = {}
        set_table_mode(config.table_mode)

    async def start(self) -> None:
        await self.store.initialize()
        if self.http is None or self.http.closed:
            self.http = ClientSession(timeout=ClientTimeout(total=30))
        if not self.config.shared_secret:
            logger.warning(
                "PalPanel shared_secret is empty; signed PalPanel integration requests will fail. "
                "Edit %s before production use.",
                self.config.config_path,
            )
        if not self.config.panel_api_key:
            logger.warning(
                "PalPanel panel_api_key is empty; management and patch API commands are disabled. "
                "Create a PalPanel development key and edit %s.",
                self.config.config_path,
            )
        logger.info(
            "PalPanel QwenPaw service initialized; database=%s panel=%s",
            self.config.database_path,
            self.config.panel_url,
        )

    async def stop(self) -> None:
        if self.http and not self.http.closed:
            await self.http.close()
        self.http = None

    def is_admin(self, user_id: str) -> bool:
        return str(user_id) in self.config.admin_qq_ids

    def _base_scope_error(self, identity: CommandIdentity) -> str | None:
        if self.config.allowed_agent_ids and not is_allowed(
            identity.agent_id, self.config.allowed_agent_ids
        ):
            return "当前智能体未获准使用 PalPanel 插件。"
        if self.config.require_qq_channel and not identity.is_qq_channel:
            detected = identity.channel_id or "未知"
            return (
                "该命令仅支持 QwenPaw 的 QQ 官方频道或 OneBot/NapCat 通道。"
                f"当前识别通道：{detected}。"
            )
        if not identity.user_id:
            return "无法识别当前 QQ 用户。"
        return None

    def _group_scope_error(self, identity: CommandIdentity) -> str | None:
        base_error = self._base_scope_error(identity)
        if base_error:
            return base_error
        if not identity.is_group or not identity.group_id:
            return "该命令只能在 QQ 群或 QQ 频道中使用。"
        if not is_allowed(identity.group_id, self.config.allowed_group_ids):
            return "当前 QQ 群未获准使用 PalPanel 插件。"
        return None

    def _retry_after(
        self,
        identity: CommandIdentity,
        action: str,
        *,
        control: bool = False,
    ) -> int:
        return self.cooldowns.retry_after(
            identity.group_id or "private",
            identity.user_id,
            action,
            control=control,
        )

    @staticmethod
    def _table_mode_label(mode: str) -> str:
        return "Markdown 管道表格" if mode == "markdown" else "ASCII 等宽代码块"

    def _write_config_value(self, key: str, value: object) -> None:
        """Persist one plugin setting without discarding unrelated fields."""
        path = self.config.config_path
        payload: dict[str, object] = {}
        if path.exists():
            loaded = json.loads(path.read_text(encoding="utf-8"))
            if not isinstance(loaded, dict):
                raise RuntimeError("配置文件根节点必须是 JSON 对象")
            payload = loaded
        payload[key] = value
        path.parent.mkdir(parents=True, exist_ok=True)
        temporary = path.with_suffix(path.suffix + ".tmp")
        temporary.write_text(
            json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        temporary.replace(path)

    async def table_mode_command(
        self,
        identity: CommandIdentity,
        args: str = "",
    ) -> str:
        """Show or update the process-wide table renderer mode."""
        error = self._base_scope_error(identity)
        if error:
            return error
        current = get_table_mode()
        requested = str(args or "").strip()
        if not requested:
            return (
                f"当前表格模式：{current}（{self._table_mode_label(current)}）\n"
                "管理员切换：/表格模式 markdown 或 /表格模式 ascii"
            )
        if not self.is_admin(identity.user_id):
            return "你没有修改表格模式的权限。"

        normalized = normalize_table_mode(requested, default="")
        accepted = {
            "markdown", "md", "pipe", "pipes", "管道", "markdown表格",
            "ascii", "text", "plain", "code", "codeblock", "代码块",
            "等宽", "字符", "ascii表格",
        }
        token = requested.casefold().replace("-", "_")
        if token not in accepted:
            return "未知表格模式。可选：markdown、ascii。"

        try:
            await asyncio.to_thread(
                self._write_config_value,
                "table_mode",
                normalized,
            )
        except (OSError, ValueError, RuntimeError, json.JSONDecodeError) as exc:
            logger.exception("failed to persist table mode")
            return f"表格模式保存失败：{exc}"

        set_table_mode(normalized)
        object.__setattr__(self.config, "table_mode", normalized)
        environment_override = os.getenv("PALPANEL_QWENPAW_TABLE_MODE")
        note = (
            "\n注意：PALPANEL_QWENPAW_TABLE_MODE 环境变量仍会在下次重启时覆盖配置文件。"
            if environment_override is not None
            else ""
        )
        return (
            f"表格模式已切换为 {normalized}（{self._table_mode_label(normalized)}）。"
            f"{note}"
        )

    async def identity_info(self, identity: CommandIdentity, _args: str = "") -> str:
        """Show identifiers needed to configure QQ and OneBot access lists."""
        error = self._base_scope_error(identity)
        if error:
            return error
        user_label = "QQ OpenID" if identity.channel_id == "qq" else "QQ号"
        group_label = "群 OpenID/频道 ID" if identity.channel_id == "qq" else "QQ群号"
        rows = [
            ("通道", identity.channel_id or "未知"),
            (user_label, identity.user_id or "无法识别"),
            ("会话类型", "群聊/频道" if identity.is_group else "私聊"),
            ("智能体", identity.agent_id or "default"),
        ]
        if identity.is_group:
            rows.insert(2, (group_label, identity.group_id or "无法识别"))
        return render_key_values(rows, title="QwenPaw 身份信息")

    async def server_status(self, identity: CommandIdentity, _args: str = "") -> str:
        error = self._group_scope_error(identity)
        if error:
            return error
        retry = self._retry_after(identity, "server_status")
        if retry:
            return f"查询太频繁，请 {retry} 秒后再试。"
        signed_error: Exception | None = None
        try:
            payload = await self._server_status_payload()
        except Exception as exc:
            signed_error = exc
            logger.warning("signed server status request failed, trying management API: %s", exc)
        else:
            try:
                return format_server_status(payload)
            except Exception as exc:
                # A formatter regression must not be reported as an API outage.
                logger.exception("signed server status formatting failed")
                signed_error = exc

        if not self.config.panel_api_key:
            return "暂时无法查询服务器状态；HMAC 集成失败且未配置 panel_api_key。请执行 /接口诊断。"
        try:
            return await self._generic_status_text()
        except PanelAPIError as exc:
            return exc.user_message()
        except Exception as exc:
            logger.exception("management server status failed")
            signed_name = type(signed_error).__name__ if signed_error else "未知错误"
            return (
                "暂时无法查询服务器状态。"
                f"HMAC：{signed_name}；管理 API：{type(exc).__name__}。"
                "请执行 /接口诊断。"
            )

    async def online(self, identity: CommandIdentity, _args: str = "") -> str:
        error = self._group_scope_error(identity)
        if error:
            return error
        retry = self._retry_after(identity, "online")
        if retry:
            return f"查询太频繁，请 {retry} 秒后再试。"
        try:
            return format_online_players(
                await self._server_status_payload(),
                self.config.output_max_chars,
            )
        except Exception as signed_exc:
            logger.warning("signed online query failed, trying management API: %s", signed_exc)
            if not self.config.panel_api_key:
                return "暂时无法查询在线玩家；HMAC 集成失败且未配置 panel_api_key。"
            try:
                return await self._generic_online_text()
            except PanelAPIError as exc:
                return exc.user_message()
            except Exception as exc:
                logger.warning("management online query failed: %s", exc)
                return "暂时无法查询在线玩家，请稍后重试。"

    async def rooms(self, identity: CommandIdentity, args: str = "") -> str:
        error = self._group_scope_error(identity)
        if error:
            return error
        retry = self._retry_after(identity, "rooms")
        if retry:
            return f"查询太频繁，请 {retry} 秒后再试。"
        try:
            payload = await self._panel_post(
                "/api/integrations/astrbot/community-servers",
                {
                    "query": args.strip(),
                    "limit": self.config.max_room_results,
                    "country": "CN",
                },
            )
            return format_rooms(
                payload,
                self.config.max_room_results,
                self.config.output_max_chars,
            )
        except Exception as signed_exc:
            logger.warning("signed community rooms failed, trying management API: %s", signed_exc)
            if not self.config.panel_api_key:
                return "社区服务器列表不可用；HMAC 集成失败且未配置 panel_api_key。"
            try:
                return await self._generic_rooms_text(args)
            except PanelAPIError as exc:
                return exc.user_message()
            except Exception as exc:
                logger.warning("management community rooms failed: %s", exc)
                return "社区服务器列表暂时不可用，请稍后重试。"

    async def start_server(self, identity: CommandIdentity, _args: str = "") -> str:
        return await self._run_control(identity, "start", "60")

    async def stop_server(self, identity: CommandIdentity, args: str = "") -> str:
        return await self._run_control(identity, "safe_stop", args or "60")

    async def restart_server(self, identity: CommandIdentity, args: str = "") -> str:
        return await self._run_control(identity, "safe_restart", args or "60")

    async def force_stop_server(self, identity: CommandIdentity, _args: str = "") -> str:
        return await self._run_control(identity, "force_stop", "60")

    async def _run_control(
        self,
        identity: CommandIdentity,
        action: str,
        wait: str,
    ) -> str:
        error = self._group_scope_error(identity)
        if error:
            return error
        if not self.is_admin(identity.user_id):
            return "你没有服务器控制权限。"
        try:
            waittime = parse_wait_seconds(wait, 60)
        except (TypeError, ValueError) as exc:
            return str(exc)
        retry = self._retry_after(identity, "server_control", control=True)
        if retry:
            return f"控制操作冷却中，请 {retry} 秒后再试。"
        try:
            try:
                payload = await self._panel_post(
                    "/api/integrations/astrbot/server-control",
                    {
                        "actor_qq_id": identity.user_id,
                        "group_id": identity.group_id,
                        "action": action,
                        "waittime": waittime,
                        "message": "服务器将在倒计时结束后进行维护，请尽快前往安全地点。",
                    },
                )
            except Exception as signed_exc:
                logger.warning("signed server control failed, trying management API: %s", signed_exc)
                if not self.config.panel_api_key:
                    raise
                payload = await self._generic_control(action, waittime)
            data = payload.get("data", payload)
            job = data if isinstance(data, dict) else {}
            nested_job = job.get("job", {}) if isinstance(job.get("job"), dict) else {}
            job_id = job.get("id") or nested_job.get("id")
            labels = {
                "start": "开服",
                "safe_stop": "安全关服",
                "safe_restart": "安全重启",
                "force_stop": "强制关服",
            }
            suffix = f"，任务 ID：{job_id}" if job_id else ""
            return f"{labels[action]}操作已接受{suffix}。"
        except PanelAPIError as exc:
            return exc.user_message()
        except Exception as exc:
            logger.warning("server control command %s failed: %s", action, exc)
            return "服务器控制操作失败，请检查 PalPanel 状态、HMAC 配置和管理 API Key。"

    async def bind(self, identity: CommandIdentity, args: str = "") -> str:
        error = self._group_scope_error(identity)
        if error:
            return error
        nickname = args.strip()
        if not nickname:
            return "用法：/bd 游戏昵称"
        players = await self.store.player_by_nickname(nickname)
        if len(players) != 1:
            return "没有找到唯一匹配的游戏昵称，请确认存档已同步且昵称完全一致。"
        player = players[0]
        if not player["online"]:
            return "该角色当前不在线，无法发送游戏内验证码。"
        code = f"{secrets.randbelow(1_000_000):06d}"
        await self.store.create_challenge(
            identity.user_id,
            player["player_uid"],
            player["nickname"],
            code,
        )
        try:
            await self._panel_post(
                "/api/integrations/astrbot/binding-challenges",
                {
                    "player_uid": player["player_uid"],
                    "nickname": player["nickname"],
                    "message": (
                        f"PalPanel QQ 绑定验证码：{code}"
                        f"（5 分钟内在群里发送 /bdqr {code}）"
                    ),
                },
            )
        except Exception as exc:
            logger.warning("failed to send binding challenge: %s", exc)
            return "PalDefender 暂时无法发送验证码，请稍后重试。"
        return "验证码已通过 PalDefender 私发到游戏内，请在 5 分钟内发送 /bdqr 验证码。"

    async def bind_confirm(self, identity: CommandIdentity, args: str = "") -> str:
        error = self._base_scope_error(identity)
        if error:
            return error
        code = args.strip()
        if not code:
            return "用法：/bdqr 验证码"
        result = await self.store.confirm_challenge(identity.user_id, code)
        if not result:
            return "验证码无效或已过期。"
        binding = await self.store.binding(identity.user_id) or result
        profile = await self._binding_profile(identity, binding)
        return "绑定成功。\n" + profile

    async def binding_info(self, identity: CommandIdentity, _args: str = "") -> str:
        error = self._base_scope_error(identity)
        if error:
            return error
        binding = await self.store.binding(identity.user_id)
        if not binding:
            return "尚未绑定游戏角色，请先使用 /bd 游戏昵称。"
        return await self._binding_profile(identity, binding)

    async def _binding_profile(
        self,
        identity: CommandIdentity,
        binding: dict,
    ) -> str:
        player_payload: dict | None = None
        bases_payload: dict | None = None
        api_error = ""
        if self.config.panel_api_key:
            player_uid = str(binding.get("player_uid") or "").strip()
            if player_uid:
                try:
                    player_payload = await self._api_request(
                        "GET",
                        f"/api/players/{quote(player_uid, safe='')}",
                    )
                    data = player_payload.get("data", player_payload)
                    player = data.get("player", {}) if isinstance(data, dict) else {}
                    guild_id = str(player.get("guild_id") or "").strip() if isinstance(player, dict) else ""
                    if guild_id:
                        try:
                            bases_payload = await self._api_request(
                                "GET",
                                "/api/bases",
                                params={"guild_id": guild_id, "limit": 100},
                            )
                        except Exception as exc:
                            logger.debug("bound player base lookup failed: %s", exc)
                except PanelAPIError as exc:
                    api_error = exc.user_message()
                except Exception as exc:
                    api_error = "玩家详情查询失败"
                    logger.warning("bound player profile lookup failed: %s", exc)
        else:
            api_error = "未配置 panel_api_key，仅显示本地绑定数据"
        return format_binding_profile(
            identity={
                "channel_id": identity.channel_id,
                "user_id": identity.user_id,
                "group_id": identity.group_id,
            },
            binding=binding,
            player_payload=player_payload,
            bases_payload=bases_payload,
            api_error=api_error,
            max_chars=self.config.output_max_chars,
        )

    async def checkin(self, identity: CommandIdentity, _args: str = "") -> str:
        error = self._group_scope_error(identity)
        if error:
            return error
        timezone = ZoneInfo(self.config.timezone)
        local_date = datetime.now(timezone).date().isoformat()
        awarded, balance = await self.store.checkin(
            identity.user_id,
            local_date,
            self.config.daily_points,
        )
        return render_key_values(
            [
                ("结果", "签到成功" if awarded else "今天已经签到过了"),
                ("日期", local_date),
                ("本次积分", self.config.daily_points if awarded else 0),
                ("当前积分", balance),
            ],
            title="每日签到",
        )

    async def points(self, identity: CommandIdentity, _args: str = "") -> str:
        error = self._base_scope_error(identity)
        if error:
            return error
        binding = await self.store.binding(identity.user_id)
        balance = await self.store.balance(identity.user_id)
        rows = [
            ("绑定状态", binding.get("status", "未知") if binding else "未绑定"),
            ("游戏昵称", binding.get("nickname", "-") if binding else "-"),
            ("PlayerUID", binding.get("player_uid", "-") if binding else "-"),
            ("当前积分", balance),
        ]
        return render_key_values(rows, title="账号与积分")

    async def breeding(self, identity: CommandIdentity, args: str = "") -> str:
        error = self._base_scope_error(identity)
        if error:
            return error
        binding = await self.store.binding(identity.user_id)
        if not binding or binding.get("status") != "active":
            return "请先使用 /bd 游戏昵称 完成绑定。"

        query = args.strip()
        summary = ""
        if query:
            parts = query.split()
            target, passives = parts[0], parts[1:5]
            try:
                submitted = await self._panel_post(
                    "/api/integrations/astrbot/quick-solves",
                    {
                        "qq_id": identity.user_id,
                        "player_uid": binding["player_uid"],
                        "target": target,
                        "passives": passives,
                    },
                )
                submitted_data = submitted.get("data", submitted)
                job = submitted_data.get("job", {}) if isinstance(submitted_data, dict) else {}
                job_id = str(job.get("id", ""))
                if not job_id:
                    raise RuntimeError("PalPanel did not return a job id")
                status_payload: dict = {}
                poll_count = max(1, self.config.quick_solve_timeout_seconds // 2)
                for _ in range(poll_count):
                    await asyncio.sleep(2)
                    status_payload = await self._panel_post(
                        "/api/integrations/astrbot/quick-solves",
                        {"qq_id": identity.user_id, "job_id": job_id},
                    )
                    current = status_payload.get("data", status_payload)
                    status_job = current.get("job", {}) if isinstance(current, dict) else {}
                    if str(status_job.get("status", "")) in {
                        "completed",
                        "failed",
                        "canceled",
                    }:
                        break
                current = status_payload.get("data", status_payload)
                current_job = current.get("job", {}) if isinstance(current, dict) else {}
                if str(current_job.get("status", "")) != "completed":
                    return str(
                        current_job.get("error")
                        or "计算失败或超时，已自动退还预留积分"
                    )
                result_payload = current.get("result", {}) if isinstance(current, dict) else {}
                results = result_payload.get("results", []) if isinstance(result_payload, dict) else []
                if results:
                    best = results[0]
                    minutes = max(1, round(float(best.get("effort_seconds", 0)) / 60))
                    summary = (
                        f"最优路线：{best.get('pal_name', target)}，"
                        f"{best.get('breeding_steps', 0)} 步，"
                        f"约 {best.get('eggs', 0)} 枚蛋 / {minutes} 分钟。\n"
                    )
                else:
                    summary = "计算完成，但当前帕鲁来源中没有可行路线。\n"
            except Exception as exc:
                logger.warning("quick breeding solve failed: %s", exc)
                return "快捷配种计算失败；若已预留积分，面板会自动退款。"

        token = await self.store.issue_ticket(
            identity.user_id,
            self.config.ticket_ttl_seconds,
        )
        base = self.config.panel_public_url or self.config.panel_url
        link = f"{base}/breeding?ticket={quote(token)}"
        if query:
            link += f"&quick={quote(query)}"
        return f"{summary}配种实验室：{link}\n链接仅可使用一次，并将在 5 分钟后失效。"

    async def admin(self, identity: CommandIdentity, args: str = "") -> str:
        error = self._base_scope_error(identity)
        if error:
            return error
        if not self.is_admin(identity.user_id):
            return "你没有 PalPanel 插件管理权限。"
        parts = args.strip().split()
        if not parts:
            return self._admin_usage()
        action, values = parts[0], parts[1:]
        actor = f"qq:{identity.user_id}"
        try:
            if action in {"解绑", "unbind"} and len(values) == 1:
                changed = await self.store.set_binding_status(actor, values[0], "unbound")
                return "解绑完成。" if changed else "未找到绑定。"
            if action in {"冻结", "freeze"} and len(values) == 1:
                changed = await self.store.set_binding_status(actor, values[0], "frozen")
                return "冻结完成。" if changed else "未找到绑定。"
            if action in {"绑定", "bind"} and len(values) >= 3:
                await self.store.admin_binding(
                    actor,
                    values[0],
                    values[1],
                    " ".join(values[2:]),
                )
                return "人工绑定完成，操作已写入审计。"
            if action in {"积分", "credits"} and len(values) >= 2:
                balance = await self.store.adjust_points(
                    actor,
                    values[0],
                    int(values[1]),
                    " ".join(values[2:]) or "admin_adjustment",
                )
                return f"积分调整完成，当前余额：{balance}。"
            if action in {"流水", "ledger"} and len(values) == 1:
                rows = await self.store.ledger(values[0])
                return "\n".join(
                    f"{item['delta']:+d} {item['reason']}" for item in rows
                ) or "暂无流水"
            return self._admin_usage()
        except Exception as exc:
            logger.warning("PalPanel admin command failed: %s", exc)
            return "管理操作失败，请检查参数和插件日志。"

    @staticmethod
    def _admin_usage() -> str:
        return (
            "用法：/paladmin 解绑 QQ；冻结 QQ；绑定 QQ PlayerUID 昵称；"
            "积分 QQ 增量 原因；流水 QQ"
        )

    async def _server_status_payload(self) -> dict:
        return await self._panel_post(
            "/api/integrations/astrbot/server-status",
            {},
        )

    async def _panel_post(self, path: str, payload: dict) -> dict:
        if not self.http or self.http.closed:
            raise RuntimeError("PalPanel plugin service is not initialized")
        if not self.config.shared_secret:
            raise RuntimeError("PalPanel shared_secret is empty")
        parsed = urlparse(self.config.panel_url)
        if parsed.scheme not in {"http", "https"}:
            raise RuntimeError("panel_url must use HTTP or HTTPS")
        if parsed.scheme == "http" and parsed.hostname not in {
            "127.0.0.1",
            "::1",
            "localhost",
        }:
            logger.warning(
                "PalPanel is using unencrypted HTTP for non-loopback panel_url: %s",
                self.config.panel_url,
            )
        raw = body_bytes(payload)
        headers = signed_headers(
            self.config.shared_secret,
            self.config.panel_id,
            "POST",
            path,
            raw,
        )
        async with self.http.post(
            self.config.panel_url + path,
            data=raw,
            headers=headers,
        ) as response:
            response.raise_for_status()
            result = await response.json()
            if not isinstance(result, dict):
                raise RuntimeError("PalPanel returned a non-object JSON response")
            return result
