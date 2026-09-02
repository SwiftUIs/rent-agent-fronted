from datetime import datetime
from decimal import Decimal
from typing import Any, Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class QueryRequest(BaseModel):
    query: str = Field(min_length=1, max_length=2000)


class PropertyOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    product_id: str
    product_name: str
    property_type: str
    bedrooms: int
    bathrooms: int
    price: Decimal
    is_pet_friendly: int
    region_name: str


class PropertyCreated(PropertyOut):
    region_id: str


class ProductsResponse(BaseModel):
    status: Literal["success"] = "success"
    data: list[PropertyOut]


class ProductResponse(BaseModel):
    status: Literal["success"] = "success"
    data: PropertyCreated


class ProgressEvent(BaseModel):
    type: Literal["progress"] = "progress"
    step: str
    status: Literal["running", "success", "error", "skipped"]
    info: str | None = None


class ResultEvent(BaseModel):
    type: Literal["result"] = "result"
    data: list[dict[str, Any]]


class ErrorEvent(BaseModel):
    type: Literal["error"] = "error"
    message: str


class TokenUsageOut(BaseModel):
    id: int
    user_id: str | None = None
    request_id: UUID
    node_name: str
    model_name: str
    prompt_tokens: int
    completion_tokens: int
    total_tokens: int
    cost_rmb: Decimal
    created_at: datetime
