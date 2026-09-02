from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import get_settings
from app.routers.routes import router
from app.services.agent import create_agent
from app.services.query import QueryService


settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.query_service = QueryService(create_agent(settings), settings)
    yield


app = FastAPI(
    title=settings.app_name,
    version="0.1.0",
    description="RentAgent.AI Text-to-SQL Agent backend scaffold",
    lifespan=lifespan,
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=False,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["Content-Type", "Authorization"],
)
app.include_router(router, prefix=settings.api_prefix)
