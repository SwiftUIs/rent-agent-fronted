from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "RentAgent.AI Backend"
    environment: str = "development"
    api_prefix: str = "/api"
    database_url: str = "mysql+asyncmy://rentagent_readonly:change-me@127.0.0.1:3306/dw"
    meta_database_url: str = "mysql+asyncmy://rentagent_readonly:change-me@127.0.0.1:3306/meta_db"
    cors_origins: str = "http://localhost:5173,https://rent-agent-fronted.vercel.app"
    es_url: str = "http://127.0.0.1:9200"
    es_index: str = "rentagent-properties-v1"
    qdrant_url: str = "http://127.0.0.1:6333"
    qdrant_collection: str = "rentagent-meta"
    embedding_model: str = "bge-large-zh-v1.5"
    embedding_dimension: int = 1024
    llm_provider: str = "stub"
    llm_model: str = "stub"
    query_timeout_seconds: int = 20
    max_result_rows: int = 200
    sql_max_retries: int = 2

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    @property
    def cors_origin_list(self) -> list[str]:
        return [item.strip() for item in self.cors_origins.split(",") if item.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()
