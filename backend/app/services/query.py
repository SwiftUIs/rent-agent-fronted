from __future__ import annotations

import json
from collections.abc import AsyncIterator
from uuid import uuid4

from app.core.config import Settings
from app.services.agent import AgentEngine, AgentEvent


class QueryService:
    def __init__(self, agent: AgentEngine, settings: Settings) -> None:
        self.agent = agent
        self.settings = settings

    async def stream(self, query: str) -> AsyncIterator[str]:
        request_id = str(uuid4())
        try:
            async for event in self.agent.run(query, request_id):
                yield _sse(event)
        except Exception as exc:
            yield _sse(AgentEvent(type="error", message=str(exc)))


def _sse(event: AgentEvent) -> str:
    payload = {"type": event.type}
    if event.step is not None:
        payload["step"] = event.step
    if event.status is not None:
        payload["status"] = event.status
    if event.info is not None:
        payload["info"] = event.info
    if event.data is not None:
        payload["data"] = event.data
    if event.message is not None:
        payload["message"] = event.message
    return f"data: {json.dumps(payload, ensure_ascii=False, default=str)}\n\n"
