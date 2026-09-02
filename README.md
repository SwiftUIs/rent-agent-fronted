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

> 注：仓库名称中的 `fronted` 看起来是 `frontend` 的拼写变体；本文沿用仓库当前名称，以保持与 GitHub 地址一致。

---
**快速开始**：`npm install && npm run dev`
