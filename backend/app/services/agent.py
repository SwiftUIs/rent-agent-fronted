from __future__ import annotations

import re
from collections.abc import AsyncIterator
from dataclasses import dataclass
from typing import Any, Protocol

from app.core.config import Settings


NODE_STEPS = [
    "抽取关键字", "召回字段", "召回指标", "召回值", "合并召回信息",
    "过滤指标", "过滤表格", "添加额外上下文信息", "生成SQL", "验证SQL",
    "校正SQL", "执行SQL",
]


@dataclass(frozen=True)
class AgentEvent:
    type: str
    step: str | None = None
    status: str | None = None
    info: str | None = None
    data: list[dict[str, Any]] | None = None
    message: str | None = None


class AgentEngine(Protocol):
    async def run(self, query: str, request_id: str) -> AsyncIterator[AgentEvent]: ...


class StubAgentEngine:
    """开发期可运行的 Agent；生产环境替换为 LangGraphAgent。"""

    def __init__(self, settings: Settings) -> None:
        self.settings = settings

    async def run(self, query: str, request_id: str) -> AsyncIterator[AgentEvent]:
        for step in NODE_STEPS[:-1]:
            if step == "校正SQL":
                yield AgentEvent("progress", step, "skipped", "SQL 验证通过，跳过校正")
                continue
            yield AgentEvent("progress", step, "running", f"{step}处理中")
            if step == "生成SQL":
                yield AgentEvent("progress", step, "success", "开发 Stub 未生成真实 SQL")
            else:
                yield AgentEvent("progress", step, "success", f"{step}完成")

        yield AgentEvent("progress", "执行SQL", "running", "执行只读查询")
        filters = _parse_simple_filters(query)
        yield AgentEvent("progress", "执行SQL", "success", f"Stub 查询条件: {filters}")
        yield AgentEvent("result", data=[])


class LangGraphAgent:
    """真实实现的接入点。

    这里保留依赖注入边界，具体项目可在本类中构造 StateGraph、LLM、ES/Qdrant
    Repository，并以同样的 AgentEvent 协议向 QueryService 输出事件。
    """

    def __init__(self, settings: Settings) -> None:
        self.settings = settings

    async def run(self, query: str, request_id: str) -> AsyncIterator[AgentEvent]:
        try:
            from langgraph.graph import END, START, StateGraph  # noqa: F401
        except ImportError as exc:
            raise RuntimeError("LangGraph is not installed") from exc
        raise NotImplementedError(
            "请在 LangGraphAgent.run 中接入真实 StateGraph；开发环境可使用 AGENT_PROVIDER=stub。"
        )


def create_agent(settings: Settings) -> AgentEngine:
    if settings.llm_provider.lower() == "stub":
        return StubAgentEngine(settings)
    return LangGraphAgent(settings)


def _parse_simple_filters(query: str) -> dict[str, Any]:
    filters: dict[str, Any] = {}
    price_range = re.search(r"(\d{3,5})\s*[-到至~]\s*(\d{3,5})", query)
    if price_range:
        filters["price_min"] = float(price_range.group(1))
        filters["price_max"] = float(price_range.group(2))
    if any(word in query for word in ("宠物", "养猫", "养狗")):
        filters["is_pet_friendly"] = 1
    return filters
