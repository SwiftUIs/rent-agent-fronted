from __future__ import annotations

from collections.abc import AsyncIterator
from uuid import UUID

from fastapi import APIRouter, Depends, Query, Request
from fastapi.responses import StreamingResponse
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.repositories.property import PropertyRepository
from app.schemas import (
    ProductResponse,
    ProductsResponse,
    PropertyCreated,
    PropertyOut,
    QueryRequest,
    TokenUsageOut,
)
from app.services.query import QueryService


router = APIRouter()


@router.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}


@router.post("/query")
async def query_agent(
    body: QueryRequest,
    request: Request,
) -> StreamingResponse:
    service: QueryService = request.app.state.query_service
    return StreamingResponse(
        service.stream(body.query),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )


@router.get("/products", response_model=ProductsResponse)
async def list_products(session: AsyncSession = Depends(get_db)) -> ProductsResponse:
    rows = await PropertyRepository(session).list_all()
    return ProductsResponse(data=[PropertyOut.model_validate(row) for row in rows])


@router.post("/product/random", response_model=ProductResponse)
async def create_random_product(session: AsyncSession = Depends(get_db)) -> ProductResponse:
    record = await PropertyRepository(session).create_random()
    return ProductResponse(data=PropertyCreated.model_validate(record.__dict__))


@router.get("/token-consumption", response_model=list[TokenUsageOut])
async def token_consumption(
    ip: str = Query(..., min_length=1, max_length=128),
    session: AsyncSession = Depends(get_db),
) -> list[TokenUsageOut]:
    result = await session.execute(text("""
        SELECT id, user_id, request_id, node_name, model_name,
               prompt_tokens, completion_tokens, total_tokens, cost_rmb, created_at
        FROM llm_token_usage
        WHERE user_id = :ip
        ORDER BY created_at DESC
        LIMIT 500
    """), {"ip": ip})
    return [TokenUsageOut.model_validate(row) for row in result.mappings().all()]
