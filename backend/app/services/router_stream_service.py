from __future__ import annotations

import asyncio
import logging
from collections import defaultdict
from typing import Any, DefaultDict, Set

from fastapi import WebSocket


logger = logging.getLogger(__name__)


class RouterStreamService:
    """管理 Router 执行流的 WebSocket 连接与事件分发。"""

    def __init__(self) -> None:
        self._connections: DefaultDict[str, Set[WebSocket]] = defaultdict(set)
        self._lock = asyncio.Lock()

    async def connect(self, stream_id: str, websocket: WebSocket) -> None:
        await websocket.accept()
        async with self._lock:
            self._connections[stream_id].add(websocket)

    async def disconnect(self, stream_id: str, websocket: WebSocket) -> None:
        async with self._lock:
            peers = self._connections.get(stream_id)
            if not peers:
                return
            peers.discard(websocket)
            if not peers:
                self._connections.pop(stream_id, None)

    async def emit(self, stream_id: str, payload: dict[str, Any]) -> None:
        async with self._lock:
            peers = list(self._connections.get(stream_id) or [])

        stale: list[WebSocket] = []
        for websocket in peers:
            try:
                await websocket.send_json(payload)
            except Exception:
                stale.append(websocket)

        if stale:
            async with self._lock:
                peers_set = self._connections.get(stream_id)
                if peers_set is None:
                    return
                for websocket in stale:
                    peers_set.discard(websocket)
                if not peers_set:
                    self._connections.pop(stream_id, None)

    async def has_stream(self, stream_id: str) -> bool:
        async with self._lock:
            return bool(self._connections.get(stream_id))


router_stream_service = RouterStreamService()
