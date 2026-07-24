from __future__ import annotations

import asyncio
import hashlib
import secrets
import sqlite3
import time
from contextlib import contextmanager
from pathlib import Path
from typing import Callable, Iterator, TypeVar

_T = TypeVar("_T")


class PalPanelStore:
    """SQLite-backed state store using only Python's standard library.

    QwenPaw plugin installation may run in environments without pip/uv or
    outbound network access. Database work therefore uses ``sqlite3`` and is
    dispatched through ``asyncio.to_thread`` so command handling does not block
    the event loop.
    """

    def __init__(self, path: Path):
        self.path = path
        self._lock = asyncio.Lock()

    @contextmanager
    def _connect(self) -> Iterator[sqlite3.Connection]:
        db = sqlite3.connect(self.path, timeout=30.0)
        db.row_factory = sqlite3.Row
        try:
            yield db
        finally:
            db.close()

    async def _run(self, operation: Callable[[], _T]) -> _T:
        # Serialising store operations avoids lock storms under group-message
        # bursts while each operation still executes outside the event loop.
        async with self._lock:
            return await asyncio.to_thread(operation)

    async def initialize(self) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)

        def operation() -> None:
            with self._connect() as db:
                db.executescript(
                    """
                    PRAGMA journal_mode=WAL;
                    PRAGMA foreign_keys=ON;
                    CREATE TABLE IF NOT EXISTS accounts (
                      qq_id TEXT PRIMARY KEY, balance INTEGER NOT NULL DEFAULT 0,
                      created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL
                    );
                    CREATE TABLE IF NOT EXISTS bindings (
                      qq_id TEXT PRIMARY KEY, player_uid TEXT NOT NULL UNIQUE, nickname TEXT NOT NULL,
                      source_fingerprint TEXT NOT NULL DEFAULT '', status TEXT NOT NULL DEFAULT 'active',
                      verified_at INTEGER NOT NULL, updated_at INTEGER NOT NULL
                    );
                    CREATE TABLE IF NOT EXISTS binding_challenges (
                      id TEXT PRIMARY KEY, qq_id TEXT NOT NULL, player_uid TEXT NOT NULL, nickname TEXT NOT NULL,
                      code_hash TEXT NOT NULL, expires_at INTEGER NOT NULL, status TEXT NOT NULL DEFAULT 'pending',
                      created_at INTEGER NOT NULL
                    );
                    CREATE TABLE IF NOT EXISTS player_catalog (
                      player_uid TEXT PRIMARY KEY, nickname TEXT NOT NULL, online INTEGER NOT NULL DEFAULT 0,
                      source_fingerprint TEXT NOT NULL, updated_at INTEGER NOT NULL
                    );
                    CREATE TABLE IF NOT EXISTS checkins (
                      qq_id TEXT NOT NULL, local_date TEXT NOT NULL, points INTEGER NOT NULL, created_at INTEGER NOT NULL,
                      PRIMARY KEY(qq_id,local_date)
                    );
                    CREATE TABLE IF NOT EXISTS credit_ledger (
                      id TEXT PRIMARY KEY, qq_id TEXT NOT NULL, delta INTEGER NOT NULL, reason TEXT NOT NULL,
                      reference_id TEXT NOT NULL DEFAULT '', created_at INTEGER NOT NULL
                    );
                    CREATE TABLE IF NOT EXISTS credit_reservations (
                      id TEXT PRIMARY KEY, qq_id TEXT NOT NULL, amount INTEGER NOT NULL, reference_id TEXT NOT NULL UNIQUE,
                      status TEXT NOT NULL, expires_at INTEGER NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL
                    );
                    CREATE TABLE IF NOT EXISTS login_tickets (
                      token_hash TEXT PRIMARY KEY, qq_id TEXT NOT NULL, expires_at INTEGER NOT NULL,
                      used_at INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL
                    );
                    CREATE TABLE IF NOT EXISTS audit_logs (
                      id TEXT PRIMARY KEY, actor TEXT NOT NULL, action TEXT NOT NULL, target TEXT NOT NULL,
                      detail TEXT NOT NULL DEFAULT '', created_at INTEGER NOT NULL
                    );
                    """
                )
                db.commit()

        await self._run(operation)
        await self.release_expired_reservations()

    async def release_expired_reservations(self) -> int:
        now = int(time.time())

        def operation() -> int:
            with self._connect() as db:
                db.execute("BEGIN IMMEDIATE")
                try:
                    rows = db.execute(
                        "SELECT id,qq_id,amount FROM credit_reservations "
                        "WHERE status='reserved' AND expires_at<?",
                        (now,),
                    ).fetchall()
                    for row in rows:
                        db.execute(
                            "UPDATE accounts SET balance=balance+?,updated_at=? WHERE qq_id=?",
                            (int(row["amount"]), now, row["qq_id"]),
                        )
                        db.execute(
                            "UPDATE credit_reservations SET status='expired',updated_at=? WHERE id=?",
                            (now, row["id"]),
                        )
                    db.commit()
                    return len(rows)
                except Exception:
                    db.rollback()
                    raise

        return await self._run(operation)

    async def sync_catalog(self, players: list[dict], fingerprint: str) -> None:
        now = int(time.time())
        normalized = [
            (
                str(player["player_uid"]),
                str(player["nickname"]),
                1 if player.get("online") else 0,
                fingerprint,
                now,
            )
            for player in players
            if player.get("player_uid") and player.get("nickname")
        ]

        def operation() -> None:
            with self._connect() as db:
                db.execute("BEGIN IMMEDIATE")
                try:
                    db.execute("DELETE FROM player_catalog")
                    db.executemany(
                        "INSERT INTO player_catalog(player_uid,nickname,online,source_fingerprint,updated_at) "
                        "VALUES(?,?,?,?,?)",
                        normalized,
                    )
                    db.execute(
                        "UPDATE bindings SET status='frozen',updated_at=? "
                        "WHERE player_uid NOT IN (SELECT player_uid FROM player_catalog)",
                        (now,),
                    )
                    db.execute(
                        "UPDATE bindings SET status='active',"
                        "source_fingerprint=(SELECT source_fingerprint FROM player_catalog "
                        "WHERE player_uid=bindings.player_uid),updated_at=? "
                        "WHERE player_uid IN (SELECT player_uid FROM player_catalog)",
                        (now,),
                    )
                    db.commit()
                except Exception:
                    db.rollback()
                    raise

        await self._run(operation)

    async def player_by_nickname(self, nickname: str) -> list[dict]:
        def operation() -> list[dict]:
            with self._connect() as db:
                rows = db.execute(
                    "SELECT * FROM player_catalog WHERE nickname=? COLLATE NOCASE",
                    (nickname.strip(),),
                ).fetchall()
                return [dict(row) for row in rows]

        return await self._run(operation)

    async def create_challenge(
        self,
        qq_id: str,
        player_uid: str,
        nickname: str,
        code: str,
        ttl: int = 300,
    ) -> str:
        challenge_id = secrets.token_hex(12)
        now = int(time.time())
        code_hash = hashlib.sha256(code.encode()).hexdigest()

        def operation() -> str:
            with self._connect() as db:
                try:
                    db.execute(
                        "UPDATE binding_challenges SET status='expired' "
                        "WHERE qq_id=? AND status='pending'",
                        (qq_id,),
                    )
                    db.execute(
                        "INSERT INTO binding_challenges VALUES(?,?,?,?,?,?,?,?)",
                        (
                            challenge_id,
                            qq_id,
                            player_uid,
                            nickname,
                            code_hash,
                            now + ttl,
                            "pending",
                            now,
                        ),
                    )
                    db.commit()
                    return challenge_id
                except Exception:
                    db.rollback()
                    raise

        return await self._run(operation)

    async def confirm_challenge(self, qq_id: str, code: str) -> dict | None:
        now = int(time.time())
        code_hash = hashlib.sha256(code.encode()).hexdigest()

        def operation() -> dict | None:
            with self._connect() as db:
                db.execute("BEGIN IMMEDIATE")
                try:
                    row = db.execute(
                        "SELECT * FROM binding_challenges WHERE qq_id=? AND code_hash=? "
                        "AND status='pending' AND expires_at>=? ORDER BY created_at DESC LIMIT 1",
                        (qq_id, code_hash, now),
                    ).fetchone()
                    if row is None:
                        db.rollback()
                        return None
                    item = dict(row)
                    db.execute(
                        "UPDATE binding_challenges SET status='used' WHERE id=?",
                        (item["id"],),
                    )
                    db.execute(
                        "DELETE FROM bindings WHERE player_uid=? AND qq_id<>?",
                        (item["player_uid"], qq_id),
                    )
                    db.execute(
                        "INSERT INTO bindings(qq_id,player_uid,nickname,source_fingerprint,status,verified_at,updated_at) "
                        "VALUES(?,?,?,'','active',?,?) ON CONFLICT(qq_id) DO UPDATE SET "
                        "player_uid=excluded.player_uid,nickname=excluded.nickname,status='active',"
                        "verified_at=excluded.verified_at,updated_at=excluded.updated_at",
                        (qq_id, item["player_uid"], item["nickname"], now, now),
                    )
                    db.execute(
                        "INSERT OR IGNORE INTO accounts VALUES(?,0,?,?)",
                        (qq_id, now, now),
                    )
                    db.commit()
                    return item
                except Exception:
                    db.rollback()
                    raise

        return await self._run(operation)

    async def binding(self, qq_id: str) -> dict | None:
        def operation() -> dict | None:
            with self._connect() as db:
                row = db.execute(
                    "SELECT * FROM bindings WHERE qq_id=?",
                    (qq_id,),
                ).fetchone()
                return dict(row) if row else None

        return await self._run(operation)

    async def checkin(self, qq_id: str, local_date: str, points: int) -> tuple[bool, int]:
        now = int(time.time())

        def operation() -> tuple[bool, int]:
            with self._connect() as db:
                db.execute("BEGIN IMMEDIATE")
                try:
                    db.execute(
                        "INSERT OR IGNORE INTO accounts VALUES(?,0,?,?)",
                        (qq_id, now, now),
                    )
                    cursor = db.execute(
                        "INSERT OR IGNORE INTO checkins VALUES(?,?,?,?)",
                        (qq_id, local_date, points, now),
                    )
                    awarded = cursor.rowcount == 1
                    if awarded:
                        db.execute(
                            "UPDATE accounts SET balance=balance+?,updated_at=? WHERE qq_id=?",
                            (points, now, qq_id),
                        )
                        db.execute(
                            "INSERT INTO credit_ledger VALUES(?,?,?,?,?,?)",
                            (
                                secrets.token_hex(12),
                                qq_id,
                                points,
                                "daily_checkin",
                                local_date,
                                now,
                            ),
                        )
                    row = db.execute(
                        "SELECT balance FROM accounts WHERE qq_id=?",
                        (qq_id,),
                    ).fetchone()
                    db.commit()
                    return awarded, int(row["balance"])
                except Exception:
                    db.rollback()
                    raise

        return await self._run(operation)

    async def balance(self, qq_id: str) -> int:
        def operation() -> int:
            with self._connect() as db:
                row = db.execute(
                    "SELECT balance FROM accounts WHERE qq_id=?",
                    (qq_id,),
                ).fetchone()
                return int(row["balance"]) if row else 0

        return await self._run(operation)

    async def reserve(
        self,
        qq_id: str,
        reference_id: str,
        amount: int,
        ttl: int = 900,
    ) -> tuple[bool, str, int]:
        await self.release_expired_reservations()
        now = int(time.time())
        reservation_id = secrets.token_hex(12)

        def operation() -> tuple[bool, str, int]:
            with self._connect() as db:
                db.execute("BEGIN IMMEDIATE")
                try:
                    existing = db.execute(
                        "SELECT id,status FROM credit_reservations WHERE reference_id=?",
                        (reference_id,),
                    ).fetchone()
                    if existing:
                        balance_row = db.execute(
                            "SELECT balance FROM accounts WHERE qq_id=?",
                            (qq_id,),
                        ).fetchone()
                        balance = int(balance_row["balance"]) if balance_row else 0
                        db.rollback()
                        return True, str(existing["id"]), balance
                    row = db.execute(
                        "SELECT balance FROM accounts WHERE qq_id=?",
                        (qq_id,),
                    ).fetchone()
                    balance = int(row["balance"]) if row else 0
                    if balance < amount:
                        db.rollback()
                        return False, "", balance
                    db.execute(
                        "UPDATE accounts SET balance=balance-?,updated_at=? WHERE qq_id=?",
                        (amount, now, qq_id),
                    )
                    db.execute(
                        "INSERT INTO credit_reservations VALUES(?,?,?,?,?,?,?,?)",
                        (
                            reservation_id,
                            qq_id,
                            amount,
                            reference_id,
                            "reserved",
                            now + ttl,
                            now,
                            now,
                        ),
                    )
                    db.commit()
                    return True, reservation_id, balance - amount
                except Exception:
                    db.rollback()
                    raise

        return await self._run(operation)

    async def admin_binding(
        self,
        actor: str,
        qq_id: str,
        player_uid: str,
        nickname: str,
    ) -> None:
        now = int(time.time())

        def operation() -> None:
            with self._connect() as db:
                db.execute("BEGIN IMMEDIATE")
                try:
                    db.execute(
                        "INSERT OR IGNORE INTO accounts VALUES(?,0,?,?)",
                        (qq_id, now, now),
                    )
                    db.execute(
                        "DELETE FROM bindings WHERE player_uid=? AND qq_id<>?",
                        (player_uid, qq_id),
                    )
                    db.execute(
                        "INSERT INTO bindings(qq_id,player_uid,nickname,source_fingerprint,status,verified_at,updated_at) "
                        "VALUES(?,?,?,'','active',?,?) ON CONFLICT(qq_id) DO UPDATE SET "
                        "player_uid=excluded.player_uid,nickname=excluded.nickname,status='active',"
                        "verified_at=excluded.verified_at,updated_at=excluded.updated_at",
                        (qq_id, player_uid, nickname, now, now),
                    )
                    db.execute(
                        "INSERT INTO audit_logs VALUES(?,?,?,?,?,?)",
                        (
                            secrets.token_hex(12),
                            actor,
                            "binding.manual",
                            qq_id,
                            player_uid,
                            now,
                        ),
                    )
                    db.commit()
                except Exception:
                    db.rollback()
                    raise

        await self._run(operation)

    async def set_binding_status(self, actor: str, qq_id: str, status: str) -> bool:
        now = int(time.time())

        def operation() -> bool:
            with self._connect() as db:
                try:
                    cursor = db.execute(
                        "UPDATE bindings SET status=?,updated_at=? WHERE qq_id=?",
                        (status, now, qq_id),
                    )
                    changed = cursor.rowcount == 1
                    if changed:
                        db.execute(
                            "INSERT INTO audit_logs VALUES(?,?,?,?,?,?)",
                            (
                                secrets.token_hex(12),
                                actor,
                                f"binding.{status}",
                                qq_id,
                                "",
                                now,
                            ),
                        )
                    db.commit()
                    return changed
                except Exception:
                    db.rollback()
                    raise

        return await self._run(operation)

    async def adjust_points(self, actor: str, qq_id: str, delta: int, reason: str) -> int:
        now = int(time.time())

        def operation() -> int:
            with self._connect() as db:
                db.execute("BEGIN IMMEDIATE")
                try:
                    db.execute(
                        "INSERT OR IGNORE INTO accounts VALUES(?,0,?,?)",
                        (qq_id, now, now),
                    )
                    row = db.execute(
                        "SELECT balance FROM accounts WHERE qq_id=?",
                        (qq_id,),
                    ).fetchone()
                    current = int(row["balance"])
                    next_balance = max(0, current + delta)
                    applied = next_balance - current
                    db.execute(
                        "UPDATE accounts SET balance=?,updated_at=? WHERE qq_id=?",
                        (next_balance, now, qq_id),
                    )
                    db.execute(
                        "INSERT INTO credit_ledger VALUES(?,?,?,?,?,?)",
                        (secrets.token_hex(12), qq_id, applied, reason, actor, now),
                    )
                    db.execute(
                        "INSERT INTO audit_logs VALUES(?,?,?,?,?,?)",
                        (
                            secrets.token_hex(12),
                            actor,
                            "credits.adjust",
                            qq_id,
                            f"{applied}:{reason}",
                            now,
                        ),
                    )
                    db.commit()
                    return next_balance
                except Exception:
                    db.rollback()
                    raise

        return await self._run(operation)

    async def ledger(self, qq_id: str, limit: int = 10) -> list[dict]:
        limit = max(1, min(limit, 50))

        def operation() -> list[dict]:
            with self._connect() as db:
                rows = db.execute(
                    "SELECT delta,reason,reference_id,created_at FROM credit_ledger "
                    "WHERE qq_id=? ORDER BY created_at DESC LIMIT ?",
                    (qq_id, limit),
                ).fetchall()
                return [dict(row) for row in rows]

        return await self._run(operation)

    async def settle(self, reservation_id: str, commit: bool) -> bool:
        now = int(time.time())

        def operation() -> bool:
            with self._connect() as db:
                db.execute("BEGIN IMMEDIATE")
                try:
                    row = db.execute(
                        "SELECT qq_id,amount,reference_id,status FROM credit_reservations WHERE id=?",
                        (reservation_id,),
                    ).fetchone()
                    if not row or row["status"] != "reserved":
                        db.rollback()
                        return False
                    status = "committed" if commit else "released"
                    if commit:
                        db.execute(
                            "INSERT INTO credit_ledger VALUES(?,?,?,?,?,?)",
                            (
                                secrets.token_hex(12),
                                row["qq_id"],
                                -int(row["amount"]),
                                "breeding_solve",
                                row["reference_id"],
                                now,
                            ),
                        )
                    else:
                        db.execute(
                            "UPDATE accounts SET balance=balance+?,updated_at=? WHERE qq_id=?",
                            (int(row["amount"]), now, row["qq_id"]),
                        )
                    db.execute(
                        "UPDATE credit_reservations SET status=?,updated_at=? WHERE id=?",
                        (status, now, reservation_id),
                    )
                    db.commit()
                    return True
                except Exception:
                    db.rollback()
                    raise

        return await self._run(operation)

    async def issue_ticket(self, qq_id: str, ttl: int) -> str:
        token = secrets.token_urlsafe(32)
        token_hash = hashlib.sha256(token.encode()).hexdigest()
        now = int(time.time())

        def operation() -> str:
            with self._connect() as db:
                try:
                    db.execute(
                        "INSERT INTO login_tickets VALUES(?,?,?,?,?)",
                        (token_hash, qq_id, now + ttl, 0, now),
                    )
                    db.commit()
                    return token
                except Exception:
                    db.rollback()
                    raise

        return await self._run(operation)

    async def exchange_ticket(self, token: str) -> dict | None:
        token_hash = hashlib.sha256(token.encode()).hexdigest()
        now = int(time.time())

        def operation() -> dict | None:
            with self._connect() as db:
                db.execute("BEGIN IMMEDIATE")
                try:
                    row = db.execute(
                        "SELECT qq_id FROM login_tickets "
                        "WHERE token_hash=? AND used_at=0 AND expires_at>=?",
                        (token_hash, now),
                    ).fetchone()
                    if not row:
                        db.rollback()
                        return None
                    qq_id = str(row["qq_id"])
                    db.execute(
                        "UPDATE login_tickets SET used_at=? WHERE token_hash=?",
                        (now, token_hash),
                    )
                    binding = db.execute(
                        "SELECT * FROM bindings WHERE qq_id=? AND status='active'",
                        (qq_id,),
                    ).fetchone()
                    balance = db.execute(
                        "SELECT balance FROM accounts WHERE qq_id=?",
                        (qq_id,),
                    ).fetchone()
                    db.commit()
                    if not binding:
                        return None
                    result = dict(binding)
                    result["qq_id"] = qq_id
                    result["balance"] = int(balance["balance"]) if balance else 0
                    return result
                except Exception:
                    db.rollback()
                    raise

        return await self._run(operation)
