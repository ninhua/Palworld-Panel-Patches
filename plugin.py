# -*- coding: utf-8 -*-
"""PalPanel QwenPaw plugin entry point."""

from __future__ import annotations

import asyncio
import logging
from collections.abc import Mapping
from typing import Any

from qwenpaw.plugins.api import PluginApi
from qwenpaw.runtime.slash_command_registry import CommandSpec

from .qwenpaw_palpanel.commands import build_command_specs, build_handlers
from .qwenpaw_palpanel.config import PalPanelConfig
from .qwenpaw_palpanel.internal_api import PalPanelInternalApi
from .qwenpaw_palpanel.service import PalPanelService

logger = logging.getLogger(__name__)


class PalPanelQwenPawPlugin:
    def __init__(self) -> None:
        self.config: PalPanelConfig | None = None
        self.service: PalPanelService | None = None
        self.internal_api: PalPanelInternalApi | None = None
        self.command_specs: list[CommandSpec] = []

    def register(self, api: PluginApi) -> None:
        self.config = PalPanelConfig.load()
        self.service = PalPanelService(self.config)
        self.internal_api = PalPanelInternalApi(self.config, self.service)

        handlers = build_handlers(self.service)
        self.command_specs = build_command_specs(handlers)

        api.register_startup_hook(
            hook_name="palpanel_qwenpaw_start",
            callback=self.on_startup,
            priority=50,
        )
        api.register_shutdown_hook(
            hook_name="palpanel_qwenpaw_stop",
            callback=self.on_shutdown,
            priority=50,
        )
        api.register_workspace_created_hook(
            hook_name="palpanel_qwenpaw_workspace_commands",
            callback=self.on_workspace_created,
            priority=100,
        )

        # Keep the official control-command registration for priority routing,
        # discovery and compatibility. QwenPaw 2.x creates workspaces before
        # general plugins load, so on_startup additionally injects CommandSpec
        # objects into each already-running workspace's SlashCommandRegistry.
        for handler in handlers:
            api.register_control_command(handler=handler, priority_level=5)

        logger.info(
            "PalPanel QwenPaw plugin registered; config=%s commands=%d",
            self.config.config_path,
            len(self.command_specs),
        )

    @staticmethod
    def _workspace_mapping(manager: Any) -> Mapping[str, Any]:
        for attr in ("agents", "workspaces", "_workspaces"):
            value = getattr(manager, attr, None)
            if isinstance(value, Mapping):
                return value
        return {}

    def _install_runtime_slash_commands(
        self,
        *,
        agent_id: str | None = None,
    ) -> tuple[int, int, int]:
        """Inject specs into running workspaces and future bootstrap config.

        Returns ``(matched_workspaces, installed_specs, bootstrap_specs_added)``.
        """

        from qwenpaw.plugins.registry import PluginRegistry

        manager = PluginRegistry().get_workspace_manager()
        if manager is None:
            return 0, 0, 0

        bootstrap_added = 0
        bootstrap_kwargs = getattr(manager, "_bootstrap_kwargs", None)
        if isinstance(bootstrap_kwargs, dict):
            bootstrap_specs = bootstrap_kwargs.setdefault(
                "builtin_command_specs",
                [],
            )
            existing_bootstrap = {
                str(getattr(spec, "name", "")).lower()
                for spec in bootstrap_specs
            }
            for spec in self.command_specs:
                key = spec.name.lower()
                if key not in existing_bootstrap:
                    bootstrap_specs.append(spec)
                    existing_bootstrap.add(key)
                    bootstrap_added += 1

        workspaces = self._workspace_mapping(manager)
        matched = 0
        installed = 0
        for current_agent_id, workspace in list(workspaces.items()):
            if agent_id and str(current_agent_id) != agent_id:
                continue
            matched += 1
            plugins = getattr(workspace, "plugins", None)
            slash_registry = getattr(plugins, "slash_command_registry", None)
            if slash_registry is None:
                logger.warning(
                    "Workspace %s has no SlashCommandRegistry",
                    current_agent_id,
                )
                continue
            existing = set(slash_registry.names())
            for spec in self.command_specs:
                key = spec.name.lower()
                if key in existing:
                    continue
                slash_registry.register(spec)
                existing.add(key)
                installed += 1

        return matched, installed, bootstrap_added

    async def on_workspace_created(self, workspace_info: dict[str, Any]) -> None:
        agent_id = str(workspace_info.get("agent_id", "") or "")
        if not agent_id:
            return
        # The creation hook may run just before the manager publishes the new
        # workspace. Retry briefly so command injection remains deterministic.
        for _ in range(10):
            matched, installed, bootstrap_added = (
                self._install_runtime_slash_commands(agent_id=agent_id)
            )
            if matched:
                logger.info(
                    "PalPanel slash commands ready for workspace=%s "
                    "installed=%d bootstrap_added=%d",
                    agent_id,
                    installed,
                    bootstrap_added,
                )
                return
            await asyncio.sleep(0.05)
        logger.warning(
            "PalPanel could not find newly created workspace %s for command injection",
            agent_id,
        )

    async def on_startup(self) -> None:
        if not self.service or not self.internal_api:
            raise RuntimeError("PalPanel plugin was not registered")
        await self.service.start()
        try:
            await self.internal_api.start()
            matched, installed, bootstrap_added = (
                self._install_runtime_slash_commands()
            )
            logger.info(
                "PalPanel runtime slash command injection complete: "
                "workspaces=%d installed=%d bootstrap_added=%d",
                matched,
                installed,
                bootstrap_added,
            )
            if matched == 0:
                logger.warning(
                    "No running QwenPaw workspace was found; commands will be "
                    "added through the future-workspace bootstrap path",
                )
        except Exception:
            await self.internal_api.stop()
            await self.service.stop()
            raise

    async def on_shutdown(self) -> None:
        if self.internal_api:
            await self.internal_api.stop()
        if self.service:
            await self.service.stop()


plugin = PalPanelQwenPawPlugin()
