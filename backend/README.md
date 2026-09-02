# RentAgent.AI FastAPI Backend Scaffold

这是 RentAgent.AI 后端服务的分层代码骨架，当前提供与前端兼容的 API 路由、MySQL Repository、SSE 响应和可替换的 Agent Engine。

## 目录

```text
backend/
├── app/
│   ├── core/config.py       # 环境配置
│   ├── db/session.py        # MySQL 异步连接池
│   ├── repositories/        # 数据访问层
│   ├── routers/routes.py    # FastAPI 路由
│   ├── services/agent.py    # Stub/LangGraph Agent 抽象
│   ├── services/query.py    # SSE 查询服务
│   ├── schemas.py           # Pydantic 请求和响应模型
│   └── main.py              # FastAPI 入口
├── requirements.txt
└── .env.example
```

## 启动

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
uvicorn app.main:app --reload --port 8000
```

默认 `LLM_PROVIDER=stub`，这样不连接真实数据库和大模型也可以启动服务并测试 `/api/query` 的 SSE 协议。接入真实 LangGraph 前，需要实现 `LangGraphAgent.run()`，将真实 StateGraph 的事件转换成 `AgentEvent`。

## 路由

| 路由 | 方法 | 说明 |
| :--- | :--- | :--- |
| `/api/health` | `GET` | 健康检查 |
| `/api/query` | `POST` | 自然语言查询，返回 SSE |
| `/api/products` | `GET` | 从 `dw.property_listing` 查询房源 |
| `/api/product/random` | `POST` | 写入随机房源，并写入 outbox 事件 |
| `/api/token-consumption?ip=...` | `GET` | 查询 Token 审计记录 |

## 生产接入清单

当前版本是“核心业务代码框架”，不是完整生产后端。上线前仍应补充真实 LangGraph 节点、ES/Qdrant Repository、outbox Worker、SQL AST 安全校验、鉴权、Redis 限流、请求超时、结构化日志、数据库迁移和完整测试。
