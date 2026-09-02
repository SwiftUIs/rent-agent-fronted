# RentAgent.AI 后端数据库结构设计

这套脚本根据 RentAgent.AI 的 API 文档、作者公开的后端架构说明和在线示例设计，目标是提供一套可以直接作为后端项目起点的数据库初始化方案。

## 文件说明

| 文件 | 用途 |
| :--- | :--- |
| `mysql/01_init.sql` | 初始化 MySQL 8.0 的 `dw` 和 `meta_db` 两个逻辑数据库，并创建业务、元数据、审计和 outbox 表 |
| `elasticsearch/01_init.sh` | 创建 Agent 元知识关键词索引，并额外创建可选的房源关键词索引 |
| `qdrant/01_init.sh` | 创建 1024 维 Cosine 向量集合及常用 payload 索引 |

## 架构职责

```text
MySQL dw
  ├── property_listing       房源权威事实数据
  ├── region                 地区维表
  ├── property_snapshot      租金/状态历史
  ├── query_request          查询请求和生成 SQL 审计
  ├── llm_token_usage        LLM Token 与成本审计
  └── outbox_event            数据变更事件

MySQL meta_db
  ├── meta_table              可查询表定义
  ├── meta_column             字段、别名和权限属性
  ├── meta_metric             指标定义与 SQL 口径
  ├── meta_enum_value         房型、地区等枚举值
  ├── meta_relation           允许的 JOIN 关系
  └── prompt_version          Agent Prompt 版本

Elasticsearch rentagent-meta-v1
  └── 元知识的倒排索引，用于关键词、别名和值召回

Qdrant rentagent-meta
  └── 元知识 Embedding，用于语义相似度召回
```

MySQL 是唯一事实源。Elasticsearch 和 Qdrant 都属于可重建的派生索引，不建议把它们作为房源数据的唯一存储。

## 初始化方式

### MySQL

```bash
mysql -uroot -p < mysql/01_init.sql
```

脚本会创建 `dw` 与 `meta_db`，并插入少量与前端 API 文档一致的示例房源和地区数据。生产环境应修改字符集、时区、账号权限和密码策略，并为 Agent 使用独立的只读账号。

### Elasticsearch

```bash
chmod +x elasticsearch/01_init.sh
ES_URL=http://localhost:9200 \
ES_USER=elastic \
ES_PASSWORD='change-me' \
./elasticsearch/01_init.sh
```

脚本会创建：

- `rentagent-meta-v1`：用于字段、指标、枚举值和表描述的关键词检索；
- `rentagent-properties-v1`：可选，用于房源地址、房型和地区的关键词过滤。

正式环境建议使用别名，例如 `rentagent-meta-read` 和 `rentagent-meta-write`，通过新建版本索引后切换 alias 实现无停机重建。

### Qdrant

```bash
chmod +x qdrant/01_init.sh
QDRANT_URL=http://localhost:6333 \
QDRANT_API_KEY='change-me-if-enabled' \
./qdrant/01_init.sh
```

集合 `rentagent-meta` 使用 1024 维 Cosine 向量，适配作者文章中提到的 `bge-large-zh-v1.5`。如果更换 Embedding 模型，必须同时调整向量维度，并通过 `embedding_version` 区分新旧索引。

## Qdrant Payload 约定

写入 Qdrant 的每个 point 建议使用以下 payload。向量本身来自 `embedding_text`，payload 保存可过滤和回填到 Prompt 的结构化元数据。

```json
{
  "object_id": "column:dw.property_listing.price",
  "object_type": "column",
  "schema_name": "dw",
  "table_name": "property_listing",
  "column_name": "price",
  "metric_name": null,
  "enum_value": null,
  "display_name": "周租金",
  "description": "澳元周租金",
  "aliases": ["租金", "预算", "价格", "周租"],
  "is_filterable": true,
  "is_selectable": true,
  "embedding_model": "bge-large-zh-v1.5",
  "embedding_version": "2026-01"
}
```

同一条元数据可以分别对字段名、中文描述、别名和指标定义生成多个向量 point，但应共享同一个 `object_id`，方便召回后去重。

## 写入和索引同步

`POST /api/product/random` 的推荐执行顺序是：

```text
校验房源数据
  → MySQL 事务写入 dw.property_listing
  → 同一事务写入 dw.outbox_event
  → Worker 消费 PROPERTY_CREATED
  → 更新 Elasticsearch 房源索引（如启用）
  → 生成 Embedding
  → 更新 Qdrant
  → 标记索引同步成功；失败则重试
```

不要尝试让 MySQL、Elasticsearch 和 Qdrant 参与一个分布式强一致事务。MySQL 写入成功后，检索索引采用最终一致性，并通过 outbox、重试队列和定时对账修复失败记录。

## Text-to-SQL 使用约束

生成 SQL 的 Agent 应连接专用只读账号，只允许访问 `meta_db` 允许的表和列，并在程序层执行 SQL AST 校验。至少需要阻止写入、更新、删除、DDL、危险函数和未定义 JOIN，同时强制设置 `LIMIT`、执行超时、最大扫描量和最大返回数据量。

Prompt 中的安全要求不能替代数据库权限。即使大模型生成了错误 SQL，数据库权限和 SQL 校验层也应保证语句无法修改数据。

## 参考来源

- [RentAgent.AI API 文档](https://github.com/SwiftUIs/rent-agent-fronted/blob/main/api_documentation.md)
- [作者掘金文章](https://juejin.cn/post/7644135664519741449)
- [在线示例页面](https://rent-agent-fronted.vercel.app/)
