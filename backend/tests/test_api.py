import json

import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app, settings
from app.services.agent import create_agent
from app.services.query import QueryService
from app.services.sql_guard import UnsafeSQL, validate_readonly_sql


@pytest.mark.asyncio
async def test_health() -> None:
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        response = await client.get("/api/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


@pytest.mark.asyncio
async def test_query_sse_stub() -> None:
    # ASGITransport 默认不触发 lifespan，因此测试中显式注入应用依赖。
    app.state.query_service = QueryService(create_agent(settings), settings)
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        response = await client.post("/api/query", json={"query": "找 500-600 允许养宠物的房子"})
    assert response.status_code == 200
    assert response.headers["content-type"].startswith("text/event-stream")
    events = [json.loads(line[6:]) for line in response.text.splitlines() if line.startswith("data: ")]
    assert events[0]["type"] == "progress"
    assert events[-1]["type"] == "result"


def test_sql_guard() -> None:
    assert validate_readonly_sql("SELECT * FROM property_listing") == "SELECT * FROM property_listing LIMIT 200"
    assert validate_readonly_sql("WITH x AS (SELECT 1) SELECT * FROM x LIMIT 10").endswith("LIMIT 10")
    with pytest.raises(UnsafeSQL):
        validate_readonly_sql("DELETE FROM property_listing")
