from __future__ import annotations

import json
import os
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any

from .table_format import normalize_table_mode


def _csv(value: Any) -> tuple[str, ...]:
    if value is None:
        return ()
    if isinstance(value, (list, tuple, set)):
        items = value
    else:
        items = str(value).split(",")
    return tuple(dict.fromkeys(str(item).strip() for item in items if str(item).strip()))


def _integer(value: Any, default: int, minimum: int | None = None) -> int:
    try:
        result = int(value)
    except (TypeError, ValueError):
        result = default
    return max(minimum, result) if minimum is not None else result


def _floating(value: Any, default: float, minimum: float | None = None) -> float:
    try:
        result = float(value)
    except (TypeError, ValueError):
        result = default
    return max(minimum, result) if minimum is not None else result


@dataclass(frozen=True)
class PalPanelConfig:
    data_dir: Path
    config_path: Path
    panel_url: str = "http://127.0.0.1:8080"
    panel_public_url: str = "http://127.0.0.1:8080"
    panel_id: str = "palpanel"
    shared_secret: str = ""
    panel_api_key: str = ""
    allowed_group_ids: tuple[str, ...] = ()
    admin_qq_ids: tuple[str, ...] = ()
    allowed_agent_ids: tuple[str, ...] = ()
    listen_host: str = "127.0.0.1"
    listen_port: int = 8092
    daily_points: int = 10
    solve_cost: int = 1
    timezone: str = "Asia/Shanghai"
    ticket_ttl_seconds: int = 300
    quick_solve_timeout_seconds: int = 300
    query_cooldown_seconds: float = 5.0
    control_cooldown_seconds: float = 15.0
    max_room_results: int = 10
    output_max_chars: int = 1800
    selection_ttl_seconds: int = 300
    table_mode: str = "markdown"
    require_qq_channel: bool = True

    @property
    def require_onebot(self) -> bool:
        """Deprecated compatibility alias for pre-0.1.7 callers."""
        return self.require_qq_channel

    @property
    def database_path(self) -> Path:
        return self.data_dir / "palpanel.sqlite3"

    @classmethod
    def load(cls) -> "PalPanelConfig":
        default_data_dir = Path(
            os.getenv(
                "PALPANEL_QWENPAW_DATA_DIR",
                str(Path.home() / ".qwenpaw" / "data" / "palpanel"),
            )
        ).expanduser()
        config_path = Path(
            os.getenv(
                "PALPANEL_QWENPAW_CONFIG",
                str(default_data_dir / "config.json"),
            )
        ).expanduser()
        data_dir = Path(os.getenv("PALPANEL_QWENPAW_DATA_DIR", str(config_path.parent))).expanduser()
        data_dir.mkdir(parents=True, exist_ok=True)

        payload: dict[str, Any] = {}
        if config_path.exists():
            try:
                loaded = json.loads(config_path.read_text(encoding="utf-8"))
                if isinstance(loaded, dict):
                    payload = loaded
            except (OSError, json.JSONDecodeError) as exc:
                raise RuntimeError(f"无法读取 PalPanel 配置文件 {config_path}: {exc}") from exc
        else:
            config_path.parent.mkdir(parents=True, exist_ok=True)
            config_path.write_text(
                json.dumps(cls.default_file_payload(), ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8",
            )

        def env_or(key: str, default: Any, *aliases: str) -> Any:
            for name in (f"PALPANEL_QWENPAW_{key.upper()}", *aliases):
                if name in os.environ:
                    return os.environ[name]
            return payload.get(key, default)

        allowed_groups = env_or("allowed_group_ids", payload.get("allowed_group_id", ""))
        require_qq_channel_raw = str(
            env_or(
                "require_qq_channel",
                payload.get("require_onebot", True),
                "PALPANEL_QWENPAW_REQUIRE_ONEBOT",
            )
        ).strip().lower()

        return cls(
            data_dir=data_dir,
            config_path=config_path,
            panel_url=str(env_or("panel_url", "http://127.0.0.1:8080")).rstrip("/"),
            panel_public_url=str(
                env_or("panel_public_url", payload.get("panel_url", "http://127.0.0.1:8080"))
            ).rstrip("/"),
            panel_id=str(env_or("panel_id", "palpanel")),
            shared_secret=str(
                env_or(
                    "shared_secret",
                    "",
                    "PALPANEL_SHARED_SECRET",
                    "PALPANEL_ASTRBOT_SHARED_SECRET",
                )
            ),
            panel_api_key=str(
                env_or(
                    "panel_api_key",
                    "",
                    "PALPANEL_API_KEY",
                    "PALPANEL_DEVELOPMENT_KEY",
                )
            ).strip(),
            allowed_group_ids=_csv(allowed_groups),
            admin_qq_ids=_csv(env_or("admin_qq_ids", "")),
            allowed_agent_ids=_csv(env_or("allowed_agent_ids", "")),
            listen_host=str(env_or("listen_host", "127.0.0.1")),
            listen_port=_integer(env_or("listen_port", 8092), 8092, 1),
            daily_points=_integer(env_or("daily_points", 10), 10, 0),
            solve_cost=_integer(env_or("solve_cost", 1), 1, 0),
            timezone=str(env_or("timezone", "Asia/Shanghai")),
            ticket_ttl_seconds=_integer(env_or("ticket_ttl_seconds", 300), 300, 60),
            quick_solve_timeout_seconds=_integer(
                env_or("quick_solve_timeout_seconds", 300), 300, 2
            ),
            query_cooldown_seconds=_floating(
                env_or("query_cooldown_seconds", 5), 5.0, 0.0
            ),
            control_cooldown_seconds=_floating(
                env_or("control_cooldown_seconds", 15), 15.0, 0.0
            ),
            max_room_results=min(
                10, _integer(env_or("max_room_results", 10), 10, 1)
            ),
            output_max_chars=_integer(env_or("output_max_chars", 1800), 1800, 200),
            selection_ttl_seconds=_integer(env_or("selection_ttl_seconds", 300), 300, 30),
            table_mode=normalize_table_mode(env_or("table_mode", "markdown")),
            require_qq_channel=require_qq_channel_raw not in {"0", "false", "no", "off"},
        )

    @staticmethod
    def default_file_payload() -> dict[str, Any]:
        return {
            "panel_url": "http://127.0.0.1:8080",
            "panel_public_url": "http://127.0.0.1:8080",
            "panel_id": "palpanel",
            "shared_secret": "",
            "panel_api_key": "",
            "allowed_group_ids": [],
            "admin_qq_ids": [],
            "allowed_agent_ids": ["default"],
            "listen_host": "127.0.0.1",
            "listen_port": 8092,
            "daily_points": 10,
            "solve_cost": 1,
            "timezone": "Asia/Shanghai",
            "ticket_ttl_seconds": 300,
            "quick_solve_timeout_seconds": 300,
            "query_cooldown_seconds": 5,
            "control_cooldown_seconds": 15,
            "max_room_results": 10,
            "output_max_chars": 1800,
            "selection_ttl_seconds": 300,
            "table_mode": "markdown",
            "require_qq_channel": True,
        }

    def redacted(self) -> dict[str, Any]:
        result = asdict(self)
        result["data_dir"] = str(self.data_dir)
        result["config_path"] = str(self.config_path)
        result["shared_secret"] = "***" if self.shared_secret else ""
        result["panel_api_key"] = "***" if self.panel_api_key else ""
        return result
