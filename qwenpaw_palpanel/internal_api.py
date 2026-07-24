from __future__ import annotations

import asyncio
import json
import logging

from aiohttp import web

from . import __version__
from .config import PalPanelConfig
from .security import verify_headers
from .service import PalPanelService

logger = logging.getLogger(__name__)


class PalPanelInternalApi:
    def __init__(self, config: PalPanelConfig, service: PalPanelService):
        self.config = config
        self.service = service
        self.runner: web.AppRunner | None = None
        self.site: web.TCPSite | None = None
        self.nonces: dict[str, float] = {}

    async def start(self) -> None:
        if self.runner is not None:
            return
        app = web.Application(client_max_size=4 * 1024 * 1024)
        app.middlewares.append(self._auth_middleware)
        app.router.add_get("/v1/health", self._health)
        app.router.add_post("/v1/catalog/sync", self._catalog_sync)
        app.router.add_post("/v1/tickets/exchange", self._ticket_exchange)
        app.router.add_post("/v1/credits/reserve", self._credit_reserve)
        app.router.add_post("/v1/credits/commit", self._credit_commit)
        app.router.add_post("/v1/credits/release", self._credit_release)

        self.runner = web.AppRunner(app)
        await self.runner.setup()
        self.site = web.TCPSite(
            self.runner,
            self.config.listen_host,
            self.config.listen_port,
        )
        try:
            await self.site.start()
        except Exception:
            await self.runner.cleanup()
            self.runner = None
            self.site = None
            raise
        logger.info(
            "PalPanel QwenPaw internal API listening on %s:%s",
            self.config.listen_host,
            self.config.listen_port,
        )

    async def stop(self) -> None:
        if self.runner:
            await self.runner.cleanup()
        self.runner = None
        self.site = None
        self.nonces.clear()

    @web.middleware
    async def _auth_middleware(self, request: web.Request, handler):
        if request.path == "/v1/health":
            return await handler(request)
        body = await request.read()
        request["raw_body"] = body
        expected_panel = self.config.panel_id
        ok, nonce = verify_headers(
            self.config.shared_secret,
            request.method,
            request.path,
            request.headers,
            body,
        )
        ok = ok and request.headers.get("X-PalPanel-Id", "") == expected_panel
        if not ok or nonce in self.nonces:
            raise web.HTTPUnauthorized(text="invalid signature")
        now = asyncio.get_running_loop().time()
        self.nonces[nonce] = now
        cutoff = now - 120
        self.nonces = {key: value for key, value in self.nonces.items() if value >= cutoff}
        return await handler(request)

    @staticmethod
    async def _json(request: web.Request) -> dict:
        try:
            value = json.loads((request.get("raw_body") or b"{}").decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise web.HTTPBadRequest(text="invalid json") from exc
        if not isinstance(value, dict):
            raise web.HTTPBadRequest(text="json body must be an object")
        return value

    async def _health(self, _request: web.Request):
        return web.json_response(
            {
                "status": "ok",
                "plugin": "palpanel-qwenpaw",
                "version": __version__,
                "protocol": "astrbot-compatible-v1",
            }
        )

    async def _catalog_sync(self, request: web.Request):
        data = await self._json(request)
        players = data.get("players", [])
        if not isinstance(players, list):
            raise web.HTTPBadRequest(text="players must be a list")
        await self.service.store.sync_catalog(
            players,
            str(data.get("fingerprint", "")),
        )
        return web.json_response({"ok": True, "count": len(players)})

    async def _ticket_exchange(self, request: web.Request):
        data = await self._json(request)
        result = await self.service.store.exchange_ticket(str(data.get("ticket", "")))
        if not result:
            raise web.HTTPUnauthorized(text="invalid ticket")
        return web.json_response(result)

    async def _credit_reserve(self, request: web.Request):
        data = await self._json(request)
        try:
            qq_id = str(data["qq_id"])
            reference_id = str(data["reference_id"])
            amount = int(data.get("amount", self.config.solve_cost))
        except (KeyError, TypeError, ValueError) as exc:
            raise web.HTTPBadRequest(text="invalid credit reservation") from exc
        if amount < 0:
            raise web.HTTPBadRequest(text="amount must be non-negative")
        if self.service.is_admin(qq_id):
            return web.json_response(
                {
                    "ok": True,
                    "reservation_id": f"admin:{reference_id}",
                    "balance": await self.service.store.balance(qq_id),
                }
            )
        ok, reservation, balance = await self.service.store.reserve(
            qq_id,
            reference_id,
            amount,
        )
        return web.json_response(
            {"ok": ok, "reservation_id": reservation, "balance": balance},
            status=200 if ok else 409,
        )

    async def _credit_commit(self, request: web.Request):
        return await self._settle_credit(request, commit=True)

    async def _credit_release(self, request: web.Request):
        return await self._settle_credit(request, commit=False)

    async def _settle_credit(self, request: web.Request, commit: bool):
        data = await self._json(request)
        reservation_id = str(data.get("reservation_id", ""))
        if not reservation_id:
            raise web.HTTPBadRequest(text="missing reservation_id")
        if reservation_id.startswith("admin:"):
            return web.json_response({"ok": True})
        return web.json_response(
            {"ok": await self.service.store.settle(reservation_id, commit)}
        )
