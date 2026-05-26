"""/ws/occupancy — real-time occupancy push.

Query string:
  - `area_id` (optional): subscribe to a single area; without it, all
    updates are delivered.
"""
from typing import Optional

from fastapi import APIRouter, Query, WebSocket, WebSocketDisconnect

from app.services.websocket_manager import manager

router = APIRouter()


@router.websocket("/ws/occupancy")
async def occupancy_socket(
    websocket: WebSocket, area_id: Optional[int] = Query(default=None)
) -> None:
    """Accept a client and stream occupancy updates until disconnect."""
    client = await manager.connect(websocket, area_id=area_id)
    try:
        while True:
            # We don't expect messages from the client; just keep alive.
            await websocket.receive_text()
    except WebSocketDisconnect:
        await manager.disconnect(client)
    except Exception:  # noqa: BLE001
        await manager.disconnect(client)
