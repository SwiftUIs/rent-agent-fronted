# RentAgent.AI

访问地址: [https://rent-agent-fronted.vercel.app/](https://rent-agent-fronted.vercel.app/)

RentAgent.AI 是一个面向澳洲租房场景的 **AI Agent 房源智能检索与分析系统**。用户可以使用自然语言描述租房需求，系统由后端 Agent 将需求转换为结构化查询并检索房源，前端则实时展示匹配结果、Agent 执行过程、统计指标和 Token 消耗情况。

> 这是一个以前端展示和交互为核心的项目。自然语言理解、RAG 检索、SQL 生成与执行等智能能力由远程后端服务提供，并不包含在本仓库中。

简单来说，这是一个用于展示 **RAG、Text-to-SQL 和 LangGraph Agent 工作流** 的澳洲房源查询 Demo/产品原型，而不是一个完整的房东或租客交易平台。


![](src/assets/20260526194449_270_179.png)

![](src/assets/20260526194535_271_179.png)


## 工作流程
1. **输入**：用户输入自然语言选房需求（例如：“帮我找一下价格在 500 到 600 的房子，且能养宠物的”）。
2. **理解与规划**：AI Agent (由 LangGraph 驱动的后端) 接收需求，通过 10 个完整的智能处理节点进行链路推理与决策决策：
   * 抽取关键字 ➔ 召回字段 ➔ 召回指标 ➔ 召回值 ➔ 合并召回信息 ➔ 过滤指标 ➔ 过滤表格 ➔ 添加额外上下文信息 ➔ 生成SQL ➔ 验证SQL ➔ 校正SQL(验证不通过时执行) ➔ 执行SQL
3. **输出**：前端实时展现工作流执行日志（Developer Console Logs）与查询到的澳洲房源卡片/列表，直观呈现数据指标（KPI卡片）以及 Token 消耗审计。

## 技术栈
| 分类 | 选型 | 说明 |
| :--- | :--- | :--- |
| **前端框架** | React 19 + Vite 8 | 负责页面组件、交互逻辑和前端工程构建 |
| **样式** | Tailwind CSS v4 | 现代 Web3 风格，深色渐变与玻璃态微光质感 |
| **AI 代理后端** | LangGraph + FastAPI | 远程实现 RAG、查询规划、SQL 生成、校验和执行 |
| **图标** | Lucide React | 提供一致性高的高品质图标集 |
| **数据监控** | Vercel Web Analytics | 统计网页访问和转化数据 |

## 核心技术要点
- **实时执行状态追溯 (Developer Console Logs)**：前端内建仿真开发控制台，记录并滚动显示 LangGraph 后端各个节点的执行轨迹与状态反馈，方便分析流程。
- **全平台自适应响应式设计 (Responsive Layout)**：
  - **桌面端**：沉浸式多栏 Dashboard，房源列表与 AI 助手左右分屏，保持工作流饱满。
  - **移动端**：布局自动流式向下堆叠，智能隐藏次要表格列，并配备一键开启控制台的悬浮按钮 (FAB)，结合物理阻尼滑入与淡入遮罩动效，完美适配小屏阅读。
- **多维度统计与 Token 消耗审计**：自动统计当前符合筛选条件的房源数据（包括平均租金、平均租约、总营收流水等 KPI），并集成明细弹窗，详尽展示每个智能节点所使用的 LLM 模型、输入/输出 Token 数量、预计折算费用等。
- **配置一致的接口路由代理**：配置 Vite Proxy（本地开发）与 vercel.json rewrite（生产部署），将所有 API 路由收归为相对路径 /api，确保前后端分离模式下无 CORS 跨域困扰。

---

## 功能概览

| 功能 | 说明 |
| :--- | :--- |
| 自然语言检索 | 使用自然语言描述预算、宠物、区域、房型等租房条件 |
| 实时 Agent 日志 | 展示后端工作流节点的运行中、成功、跳过或失败状态 |
| 房源结果展示 | 展示地址、房屋类型、卧室数、卫生间数、租金、宠物友好和地区等字段 |
| 聚合分析 | 支持展示平均租金、平均租约期限、总租金等 KPI 指标 |
| 房源数据加载 | 从后端获取全部房源，并支持在页面中进行本地筛选/搜索 |
| 随机新增房源 | 调用后端接口生成并插入一条随机房源数据 |
| Token 消耗审计 | 查看各个 Agent 节点的模型、Token 用量、估算成本和请求时间 |
| 响应式布局 | 桌面端采用多栏 Dashboard，移动端自动堆叠并适配小屏操作 |

## 前后端边界

本仓库主要是 **前端项目**，核心代码集中在 `src/App.jsx`、`src/App.css` 和 `src/index.css`。以下能力依赖远程后端服务：自然语言需求理解与 Agent 工作流编排、RAG 字段/指标/值召回、SQL 生成/验证/校正、MySQL 房源数据查询、Elasticsearch/Qdrant 等检索索引同步，以及 Token 消耗记录和成本审计数据生成。

因此，仅启动前端并不会自动提供完整的 AI 查询能力；必须确保前端配置的后端 API 服务可访问。

## 后端架构

根据作者对项目后端的介绍，RentAgent.AI 的后端不是普通的房源 CRUD 服务，而是一个面向结构化数据查询的 **Text-to-SQL Agent**。整体链路可以概括为：

```text
浏览器前端
    │ HTTPS + REST / SSE
    ▼
FastAPI API 服务
    │
    ├── QueryService
    │       └── LangGraph Agent 状态图
    │              ├── 关键词抽取
    │              ├── 元数据召回
    │              ├── 指标/字段/值过滤
    │              ├── SQL 生成
    │              ├── SQL 验证
    │              ├── SQL 校正与重试
    │              └── 只读 SQL 执行
    │
    ├── 元知识检索服务
    │       ├── Elasticsearch：关键词检索
    │       └── Qdrant：向量语义检索
    │
    ├── LLM / Embedding 服务
    │       ├── DeepSeek / GPT / Claude
    │       └── TEI + bge-large-zh-v1.5
    │
    └── MySQL 数据层
            ├── dw：房源业务数据
            └── meta_db：表结构、字段和指标定义
```

作者文章明确提到的后端技术包括 **Python 3.12+、FastAPI、LangGraph、MySQL 8.0、Elasticsearch、Qdrant、bge-large-zh-v1.5、HuggingFace TEI 和 `uv`**。其中，FastAPI 负责 API 接入，LangGraph 负责有状态的 Agent 节点编排，TEI 提供私有化 Embedding 接口，Elasticsearch 和 Qdrant 共同完成元数据混合检索。[作者文章](https://juejin.cn/post/7644135664519741449)

`/api/query` 使用 SSE 流式返回 Agent 节点进度、最终结果或错误事件，因此后端需要保持查询期间的长连接，并在每个节点完成时推送 `progress` 事件。SQL 验证失败时，LangGraph 可以将状态转交给 SQL 校正节点，再重新执行查询；这也是该项目区别于普通问答接口的关键能力。

## 数据库架构

后端采用“**MySQL 双逻辑库 + Elasticsearch/Qdrant 派生索引**”的思路。`dw` 是房源业务数据仓库，保存房源事实数据；`meta_db` 保存 Agent 用来理解数据库的元知识，例如表结构、字段描述、业务指标、枚举值和允许的关联关系。

| 数据组件 | 主要职责 | 数据性质 |
| :--- | :--- | :--- |
| MySQL `dw` | 房源主数据、地区、租金和可租状态 | 权威事实数据 |
| MySQL `meta_db` | 表、列、指标、枚举值、JOIN 关系和 Prompt 元数据 | Agent 元知识 |
| Elasticsearch | 城市、房型、字段名、别名和值的关键词匹配 | 可重建的倒排索引 |
| Qdrant | 字段描述、指标定义和自然语言表达的语义匹配 | 可重建的向量索引 |
| Token 审计表 | 请求 ID、节点、模型、输入/输出 Token、估算成本和时间 | 查询审计数据 |

房源核心数据至少包括 `product_id`、`product_name`、`property_type`、`bedrooms`、`bathrooms`、`price`、`is_pet_friendly` 和 `region_name`。推荐将房源主表、地区表、查询请求表和 LLM Token 使用表放在 `dw` 中；将 `meta_table`、`meta_column`、`meta_metric`、`meta_enum_value` 和 `meta_relation` 等元数据表放在 `meta_db` 中。

Elasticsearch 和 Qdrant 不应作为唯一事实源。新增房源时，建议先通过 MySQL 事务写入 `dw`，再发布索引同步事件，后台任务负责更新 Elasticsearch、生成 Embedding 并写入 Qdrant。这样可以让 MySQL 作为权威源，让检索索引采用最终一致性，并通过重试或定时对账修复同步失败。

## Text-to-SQL 安全要求

由于后端会执行大模型生成的 SQL，生产环境不能只依赖 Prompt 约束。建议同时使用只读数据库账号、SQL AST 解析、表字段白名单、强制 `LIMIT`、查询超时、最大返回行数、JOIN 白名单和完整审计日志。SQL 校正也应设置最大重试次数，避免异常情况下无限循环。

当前 Vercel 配置将 `/api/*` 转发到 `http://175.178.18.199:8000`，这适合 Demo 联调，但正式环境建议替换成 HTTPS 域名或 API Gateway，并补充鉴权、限流、来源校验和密钥管理。数据库凭据与 LLM API Key 不应出现在前端代码或浏览器请求中。

## 后端实现方案选择

| 方案 | 架构 | 优点 | 适用场景 |
| :--- | :--- | :--- | :--- |
| 保持当前设计 | MySQL `dw` + MySQL `meta_db` + Elasticsearch + Qdrant | 与作者文章和现有 API 最一致，适合展示混合检索原理 | 复现项目、学习 Agent/RAG 架构 |
| 生产简化版 | PostgreSQL + pgvector + Redis | 组件更少，结构化数据与向量检索更容易统一 | 中小规模生产 MVP |
| 扩展分析版 | MySQL + ClickHouse + Elasticsearch/Qdrant | 适合大量历史房源和复杂统计分析 | 数据规模明显增长后 |

如果目标是复现作者项目，建议继续采用第一种方案；如果目标是重新建设一个更易运维的生产 MVP，可以评估 PostgreSQL + pgvector。当前项目规模下，不建议一开始就同时引入过多基础设施。

## API 接口概览

完整接口定义请参阅 [`api_documentation.md`](api_documentation.md)。当前前端使用的主要接口如下：

| 接口 | 方法 | 用途 |
| :--- | :--- | :--- |
| `/api/query` | `POST` | 提交自然语言查询，通过 SSE 流式返回进度、结果或错误事件 |
| `/api/products` | `GET` | 获取全部房源列表 |
| `/api/product/random` | `POST` | 生成并插入一条随机房源数据 |
| `/api/token-consumption?ip=...` | `GET` | 查询指定客户端 IP 相关的 Token 消耗记录 |

`/api/query` 的流式事件主要包括 `progress`（Agent 节点进度）、`result`（房源或聚合分析结果）和 `error`（执行错误）。

## 目录结构

```text
.
├── design-system/              # 设计系统相关资源
├── public/                     # 公共静态资源
├── src/
│   ├── assets/                 # 页面图片、图标等资源
│   ├── App.jsx                 # 主页面、查询交互、SSE 解析和结果展示
│   ├── App.css                 # 页面组件样式
│   ├── index.css               # 全局样式
│   └── main.jsx                # React 应用入口
├── api_documentation.md        # 后端 API 规范
├── index.html                  # HTML 入口
├── package.json                # 依赖和脚本配置
├── vercel.json                 # Vercel 部署及 API rewrite 配置
└── vite.config.js              # Vite 开发配置
```

## 本地运行

```bash
npm install
npm run dev
```

其他常用命令：

```bash
npm run build    # 构建生产版本
npm run lint     # 运行代码检查
```

启动后端 API 并配置好 Vite Proxy 或 Vercel rewrite 后，前端才能正常完成房源查询、随机新增和 Token 审计等操作。

## 项目状态

当前仓库是一个轻量级前端 Demo，重点用于验证和展示“自然语言租房查询 + Agent 工作流可视化”的产品形态。它暂不包含完整的后端服务、数据库初始化脚本、认证系统、房源交易流程或生产级数据采集系统。

## 相关链接

- 在线演示：[rent-agent-fronted.vercel.app](https://rent-agent-fronted.vercel.app/)
- API 文档：[`api_documentation.md`](api_documentation.md)
- GitHub 仓库：[SwiftUIs/rent-agent-fronted](https://github.com/SwiftUIs/rent-agent-fronted)
- 作者后端架构文章：[从零开始：前端转型 AI agent 直到就业第十八天-第五十六天](https://juejin.cn/post/7644135664519741449)

> 注：仓库名称中的 `fronted` 看起来是 `frontend` 的拼写变体；本文沿用仓库当前名称，以保持与 GitHub 地址一致。

---
**快速开始**：`npm install && npm run dev`
