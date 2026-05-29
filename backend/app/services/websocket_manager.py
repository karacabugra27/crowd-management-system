"""In-process WebSocket connection manager.

Tracks connected clients and broadcasts occupancy updates. Each client
may either subscribe to a specific `area_id` or receive updates for all
areas (when `area_id` is None).
"""
from __future__ import annotations

import asyncio
import logging
from dataclasses import dataclass, field
from typing import Any, Dict, Optional, Set

from fastapi import WebSocket

logger = logging.getLogger(__name__)


@dataclass(eq=False)
class _Client:
    """A single WebSocket subscription.

    `eq=False` so the dataclass keeps the default identity-based hash —
    required to store instances in a `set`.
    """

    ws: WebSocket
    area_id: Optional[int] = None  # None = wildcard


class WebSocketManager:
    """Manages WS clients and fans out broadcast messages."""

    def __init__(self) -> None:
        self._clients: Set[_Client] = set()
        self._lock = asyncio.Lock()

    async def connect(self, ws: WebSocket, area_id: Optional[int] = None) -> _Client:
        """Accept the WebSocket and register the client."""
        await ws.accept()
        client = _Client(ws=ws, area_id=area_id)
        async with self._lock:
            self._clients.add(client)
        logger.info("WS connected (area_id=%s, total=%d)", area_id, len(self._clients))
        return client

    async def disconnect(self, client: _Client) -> None:
        """Remove a client from the active set."""
        async with self._lock:
            self._clients.discard(client)
        logger.info("WS disconnected (total=%d)", len(self._clients))

    async def broadcast(self, message: Dict[str, Any]) -> None:
        """Send `message` to every relevant client.

        Clients with no `area_id` receive every update. Clients with a
        specific `area_id` receive only messages where the payload's
        `area_id` matches.
        """
        target_area = message.get("area_id")
        async with self._lock:
            clients = list(self._clients)

        dead: list[_Client] = []
        for client in clients:
            if client.area_id is not None and client.area_id != target_area:
                continue
            try:
                await client.ws.send_json(message)
            except Exception:  # noqa: BLE001
                dead.append(client)

        if dead:
            async with self._lock:
                for c in dead:
                    self._clients.discard(c)
            logger.info("Pruned %d dead WS clients", len(dead))

    def active_count(self) -> int:
        return len(self._clients)


# Module-level singleton — shared by routers and services.
manager = WebSocketManager()
