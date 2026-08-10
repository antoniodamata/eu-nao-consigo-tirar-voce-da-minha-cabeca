import asyncio
from typing import Set

from fastapi import WebSocket


class WebHub:
    """Mantém os navegadores conectados e transmite o estado para todos."""

    def __init__(self) -> None:
        self.clients: Set[WebSocket] = set()
        self._lock = asyncio.Lock()

    async def connect(self, websocket: WebSocket) -> None:
        await websocket.accept()

        async with self._lock:
            self.clients.add(websocket)

        print(f"Navegador conectado. Total: {len(self.clients)}")

    async def disconnect(self, websocket: WebSocket) -> None:
        async with self._lock:
            self.clients.discard(websocket)

        print(f"Navegador desconectado. Total: {len(self.clients)}")

    async def broadcast(self, payload: dict) -> None:
        """Envia para todos, descartando as conexões que morreram."""

        async with self._lock:
            alvos = list(self.clients)

        mortos = []

        for client in alvos:
            try:
                await client.send_json(payload)
            except Exception:
                mortos.append(client)

        if mortos:
            async with self._lock:
                for client in mortos:
                    self.clients.discard(client)


hub = WebHub()
