-- RentAgent.AI MySQL schema
-- MySQL 8.0+
-- 说明：dw 保存业务事实与审计数据；meta_db 保存 Text-to-SQL 所需的元知识。

SET NAMES utf8mb4;
SET time_zone = '+00:00';

CREATE DATABASE IF NOT EXISTS dw
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;

CREATE DATABASE IF NOT EXISTS meta_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;

USE dw;

CREATE TABLE IF NOT EXISTS region (
  region_id      VARCHAR(30)  NOT NULL,
  region_name    VARCHAR(100) NOT NULL,
  city           VARCHAR(100) NOT NULL,
  state_code     VARCHAR(20)  NULL,
  country_code   CHAR(2)      NOT NULL DEFAULT 'AU',
  latitude       DECIMAL(9,6) NULL,
  longitude      DECIMAL(9,6) NULL,
  created_at     DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at     DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
                              ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (region_id),
  UNIQUE KEY uk_region_name_city (region_name, city),
  KEY idx_region_city (city)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS property_listing (
  product_id          VARCHAR(30)    NOT NULL,
  product_name        VARCHAR(255)   NOT NULL COMMENT '地址或房源名称',
  property_type       VARCHAR(50)    NOT NULL,
  bedrooms            TINYINT UNSIGNED NOT NULL DEFAULT 0,
  bathrooms           TINYINT UNSIGNED NOT NULL DEFAULT 0,
  price               DECIMAL(10,2)  NOT NULL COMMENT 'AUD weekly rent',
  is_pet_friendly     TINYINT(1)     NOT NULL DEFAULT 0,
  region_id           VARCHAR(30)    NOT NULL,
  availability_status ENUM('available','leased','inactive')
                                    NOT NULL DEFAULT 'available',
  source_url          VARCHAR(1000) NULL,
  description         TEXT          NULL,
  listed_at           DATETIME(6)    NULL,
  created_at          DATETIME(6)    NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at          DATETIME(6)    NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
                                      ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (product_id),
  CONSTRAINT fk_property_region
    FOREIGN KEY (region_id) REFERENCES region (region_id),
  CONSTRAINT chk_property_price CHECK (price >= 0),
  CONSTRAINT chk_property_bedrooms CHECK (bedrooms <= 50),
  CONSTRAINT chk_property_bathrooms CHECK (bathrooms <= 50),
  KEY idx_property_region_status (region_id, availability_status),
  KEY idx_property_type_price (property_type, price),
  KEY idx_property_pet_price (is_pet_friendly, price),
  KEY idx_property_bedrooms_bathrooms (bedrooms, bathrooms),
  FULLTEXT KEY ftx_property_text (product_name, description)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS property_snapshot (
  snapshot_id        BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  product_id         VARCHAR(30)     NOT NULL,
  captured_at        DATETIME(6)     NOT NULL,
  price              DECIMAL(10,2)   NOT NULL,
  availability_status ENUM('available','leased','inactive') NOT NULL,
  source_url         VARCHAR(1000)   NULL,
  PRIMARY KEY (snapshot_id),
  UNIQUE KEY uk_property_snapshot_time (product_id, captured_at),
  CONSTRAINT fk_snapshot_property
    FOREIGN KEY (product_id) REFERENCES property_listing (product_id),
  KEY idx_snapshot_product_time (product_id, captured_at),
  KEY idx_snapshot_captured_at (captured_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS property_attribute (
  attribute_id       BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  product_id         VARCHAR(30)     NOT NULL,
  attribute_name     VARCHAR(100)    NOT NULL,
  attribute_value    VARCHAR(500)    NOT NULL,
  normalized_value   VARCHAR(500)    NULL,
  created_at         DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (attribute_id),
  UNIQUE KEY uk_property_attribute (product_id, attribute_name),
  CONSTRAINT fk_attribute_property
    FOREIGN KEY (product_id) REFERENCES property_listing (product_id),
  KEY idx_attribute_name_value (attribute_name, normalized_value)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS query_request (
  request_id         CHAR(36)       NOT NULL,
  user_id            VARCHAR(128)   NULL COMMENT 'Demo 中可使用客户端 IP；生产环境建议使用匿名用户 ID',
  client_ip_hash     CHAR(64)       NULL,
  raw_query          TEXT           NOT NULL,
  status             ENUM('running','success','error','timeout') NOT NULL DEFAULT 'running',
  generated_sql      MEDIUMTEXT     NULL,
  final_sql          MEDIUMTEXT     NULL,
  result_count       INT UNSIGNED   NULL,
  error_message      TEXT           NULL,
  started_at         DATETIME(6)    NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  finished_at        DATETIME(6)    NULL,
  created_at         DATETIME(6)    NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (request_id),
  KEY idx_query_user_time (user_id, created_at),
  KEY idx_query_status_time (status, created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS llm_token_usage (
  id                 BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  request_id         CHAR(36)       NOT NULL,
  user_id            VARCHAR(128)   NULL,
  node_name          VARCHAR(100)   NOT NULL,
  model_name         VARCHAR(150)   NOT NULL,
  prompt_tokens      INT UNSIGNED   NOT NULL DEFAULT 0,
  completion_tokens  INT UNSIGNED   NOT NULL DEFAULT 0,
  total_tokens       INT UNSIGNED   NOT NULL DEFAULT 0,
  cost_rmb           DECIMAL(12,6)  NOT NULL DEFAULT 0,
  latency_ms         INT UNSIGNED   NULL,
  created_at         DATETIME(6)    NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (id),
  CONSTRAINT fk_token_request
    FOREIGN KEY (request_id) REFERENCES query_request (request_id),
  KEY idx_token_user_time (user_id, created_at),
  KEY idx_token_request_node (request_id, node_name),
  KEY idx_token_created_at (created_at)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS outbox_event (
  event_id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  aggregate_type     VARCHAR(50)    NOT NULL,
  aggregate_id       VARCHAR(100)   NOT NULL,
  event_type         VARCHAR(100)   NOT NULL,
  payload            JSON           NOT NULL,
  status             ENUM('pending','processing','published','failed')
                                    NOT NULL DEFAULT 'pending',
  attempts           SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  next_attempt_at    DATETIME(6)    NULL,
  last_error         TEXT           NULL,
  created_at         DATETIME(6)    NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  published_at       DATETIME(6)    NULL,
  PRIMARY KEY (event_id),
  KEY idx_outbox_status_next (status, next_attempt_at),
  KEY idx_outbox_aggregate (aggregate_type, aggregate_id)
) ENGINE=InnoDB;

USE meta_db;

CREATE TABLE IF NOT EXISTS meta_table (
  table_id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  schema_name        VARCHAR(64)    NOT NULL,
  table_name         VARCHAR(128)   NOT NULL,
  display_name       VARCHAR(255)   NULL,
  description        TEXT          NOT NULL,
  allowed_for_query  TINYINT(1)     NOT NULL DEFAULT 1,
  row_level_filter   TEXT          NULL,
  version            INT UNSIGNED   NOT NULL DEFAULT 1,
  is_active          TINYINT(1)     NOT NULL DEFAULT 1,
  updated_at         DATETIME(6)    NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
                                      ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (table_id),
  UNIQUE KEY uk_meta_table (schema_name, table_name),
  KEY idx_meta_table_active (is_active, allowed_for_query)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS meta_column (
  column_id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  table_id            BIGINT UNSIGNED NOT NULL,
  column_name        VARCHAR(128)   NOT NULL,
  display_name       VARCHAR(255)   NULL,
  data_type          VARCHAR(64)    NOT NULL,
  description        TEXT           NOT NULL,
  aliases            JSON           NULL,
  is_selectable      TINYINT(1)     NOT NULL DEFAULT 1,
  is_filterable      TINYINT(1)     NOT NULL DEFAULT 1,
  is_groupable       TINYINT(1)     NOT NULL DEFAULT 0,
  is_sensitive       TINYINT(1)     NOT NULL DEFAULT 0,
  embedding_version  VARCHAR(64)    NULL,
  updated_at         DATETIME(6)    NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
                                      ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (column_id),
  UNIQUE KEY uk_meta_column (table_id, column_name),
  CONSTRAINT fk_meta_column_table
    FOREIGN KEY (table_id) REFERENCES meta_table (table_id),
  KEY idx_meta_column_filterable (is_filterable, is_selectable)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS meta_metric (
  metric_id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  metric_name        VARCHAR(128)   NOT NULL,
  display_name       VARCHAR(255)   NOT NULL,
  description        TEXT          NOT NULL,
  sql_expression     TEXT           NOT NULL,
  filter_rule        TEXT           NULL,
  default_table_id   BIGINT UNSIGNED NULL,
  data_type          VARCHAR(64)    NOT NULL DEFAULT 'DECIMAL',
  is_active          TINYINT(1)     NOT NULL DEFAULT 1,
  version            INT UNSIGNED   NOT NULL DEFAULT 1,
  updated_at         DATETIME(6)    NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
                                      ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (metric_id),
  UNIQUE KEY uk_metric_name_version (metric_name, version),
  CONSTRAINT fk_metric_table
    FOREIGN KEY (default_table_id) REFERENCES meta_table (table_id),
  KEY idx_metric_active (is_active, metric_name)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS meta_enum_value (
  enum_id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  column_id          BIGINT UNSIGNED NOT NULL,
  value              VARCHAR(255)   NOT NULL,
  display_name       VARCHAR(255)   NULL,
  aliases            JSON           NULL,
  description        TEXT           NULL,
  is_active          TINYINT(1)     NOT NULL DEFAULT 1,
  PRIMARY KEY (enum_id),
  UNIQUE KEY uk_enum_column_value (column_id, value),
  CONSTRAINT fk_enum_column
    FOREIGN KEY (column_id) REFERENCES meta_column (column_id),
  KEY idx_enum_value (value),
  KEY idx_enum_active (is_active)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS meta_relation (
  relation_id        BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  left_table_id      BIGINT UNSIGNED NOT NULL,
  right_table_id     BIGINT UNSIGNED NOT NULL,
  join_type          ENUM('INNER','LEFT') NOT NULL DEFAULT 'INNER',
  join_condition     TEXT          NOT NULL,
  is_allowed         TINYINT(1)    NOT NULL DEFAULT 1,
  PRIMARY KEY (relation_id),
  UNIQUE KEY uk_meta_relation (left_table_id, right_table_id),
  CONSTRAINT fk_relation_left_table
    FOREIGN KEY (left_table_id) REFERENCES meta_table (table_id),
  CONSTRAINT fk_relation_right_table
    FOREIGN KEY (right_table_id) REFERENCES meta_table (table_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS prompt_version (
  prompt_id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  node_name           VARCHAR(100)   NOT NULL,
  version             INT UNSIGNED   NOT NULL,
  template_body       MEDIUMTEXT     NOT NULL,
  input_schema        JSON           NULL,
  output_schema       JSON           NULL,
  is_active           TINYINT(1)     NOT NULL DEFAULT 0,
  created_at          DATETIME(6)    NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (prompt_id),
  UNIQUE KEY uk_prompt_node_version (node_name, version),
  KEY idx_prompt_active (node_name, is_active)
) ENGINE=InnoDB;

-- 预置地区。
USE dw;
INSERT INTO region (region_id, region_name, city, state_code) VALUES
  ('R001', 'Sydney CBD', 'Sydney', 'NSW'),
  ('R002', 'Chatswood', 'Sydney', 'NSW'),
  ('R003', 'Hurstville', 'Sydney', 'NSW'),
  ('R004', 'Melbourne CBD', 'Melbourne', 'VIC'),
  ('R005', 'Richmond', 'Melbourne', 'VIC'),
  ('R006', 'South Yarra', 'Melbourne', 'VIC')
ON DUPLICATE KEY UPDATE
  region_name = VALUES(region_name), city = VALUES(city), state_code = VALUES(state_code);

-- 预置少量示例房源，与前端 API 文档中的字段保持一致。
INSERT INTO property_listing
  (product_id, product_name, property_type, bedrooms, bathrooms, price,
   is_pet_friendly, region_id, availability_status)
VALUES
  ('P001', '101/50 George St, Sydney CBD', 'Apartment', 2, 1, 850.00, 1, 'R001', 'available'),
  ('P002', '302/8 Albert Ave, Chatswood', 'Apartment', 1, 1, 650.00, 0, 'R002', 'available'),
  ('P003', '14 Forest Rd, Hurstville', 'House', 4, 2, 1100.00, 1, 'R003', 'available'),
  ('P004', '12 Flinders St, Melbourne CBD', 'Studio', 0, 1, 450.00, 0, 'R004', 'available'),
  ('P005', '45 Bridge Rd, Richmond', 'Townhouse', 3, 2, 900.00, 1, 'R005', 'available'),
  ('P006', '88 Chapel St, South Yarra', 'Apartment', 2, 2, 800.00, 1, 'R006', 'available')
ON DUPLICATE KEY UPDATE
  product_name = VALUES(product_name), property_type = VALUES(property_type),
  bedrooms = VALUES(bedrooms), bathrooms = VALUES(bathrooms), price = VALUES(price),
  is_pet_friendly = VALUES(is_pet_friendly), region_id = VALUES(region_id),
  availability_status = VALUES(availability_status);

-- 预置 Agent 可查询的核心房源表元数据。
USE meta_db;
INSERT INTO meta_table
  (schema_name, table_name, display_name, description, allowed_for_query)
VALUES
  ('dw', 'property_listing', '房源表',
   '澳洲租赁房源的核心事实表，包含地址、房型、卧室、卫生间、周租金、宠物政策和地区。', 1),
  ('dw', 'region', '地区表',
   '澳洲房源地区维度表，保存地区名称、城市和州信息。', 1)
ON DUPLICATE KEY UPDATE
  display_name = VALUES(display_name), description = VALUES(description),
  allowed_for_query = VALUES(allowed_for_query);

INSERT INTO meta_column
  (table_id, column_name, display_name, data_type, description, aliases,
   is_selectable, is_filterable, is_groupable)
SELECT table_id, 'product_id', '房源 ID', 'VARCHAR', '房源唯一标识。', JSON_ARRAY('房源编号','编号'), 1, 1, 0
FROM meta_table WHERE schema_name = 'dw' AND table_name = 'property_listing'
ON DUPLICATE KEY UPDATE description = VALUES(description), aliases = VALUES(aliases);

INSERT INTO meta_column
  (table_id, column_name, display_name, data_type, description, aliases,
   is_selectable, is_filterable, is_groupable)
SELECT table_id, 'product_name', '房源地址', 'VARCHAR', '房源物理地址或展示名称。', JSON_ARRAY('地址','位置'), 1, 1, 0
FROM meta_table WHERE schema_name = 'dw' AND table_name = 'property_listing'
ON DUPLICATE KEY UPDATE description = VALUES(description), aliases = VALUES(aliases);

INSERT INTO meta_column
  (table_id, column_name, display_name, data_type, description, aliases,
   is_selectable, is_filterable, is_groupable)
SELECT table_id, 'property_type', '房屋类型', 'VARCHAR', 'Apartment、House、Townhouse 或 Studio。', JSON_ARRAY('房型','公寓','房子'), 1, 1, 1
FROM meta_table WHERE schema_name = 'dw' AND table_name = 'property_listing'
ON DUPLICATE KEY UPDATE description = VALUES(description), aliases = VALUES(aliases);

INSERT INTO meta_column
  (table_id, column_name, display_name, data_type, description, aliases,
   is_selectable, is_filterable, is_groupable)
SELECT table_id, 'bedrooms', '卧室数', 'TINYINT', '卧室数量；Studio 的值为 0。', JSON_ARRAY('卧室','几居室','房间数'), 1, 1, 1
FROM meta_table WHERE schema_name = 'dw' AND table_name = 'property_listing'
ON DUPLICATE KEY UPDATE description = VALUES(description), aliases = VALUES(aliases);

INSERT INTO meta_column
  (table_id, column_name, display_name, data_type, description, aliases,
   is_selectable, is_filterable, is_groupable)
SELECT table_id, 'bathrooms', '卫生间数', 'TINYINT', '卫生间数量。', JSON_ARRAY('卫生间','浴室'), 1, 1, 1
FROM meta_table WHERE schema_name = 'dw' AND table_name = 'property_listing'
ON DUPLICATE KEY UPDATE description = VALUES(description), aliases = VALUES(aliases);

INSERT INTO meta_column
  (table_id, column_name, display_name, data_type, description, aliases,
   is_selectable, is_filterable, is_groupable)
SELECT table_id, 'price', '周租金', 'DECIMAL', '澳元周租金。', JSON_ARRAY('租金','价格','预算','周租'), 1, 1, 0
FROM meta_table WHERE schema_name = 'dw' AND table_name = 'property_listing'
ON DUPLICATE KEY UPDATE description = VALUES(description), aliases = VALUES(aliases);

INSERT INTO meta_column
  (table_id, column_name, display_name, data_type, description, aliases,
   is_selectable, is_filterable, is_groupable)
SELECT table_id, 'is_pet_friendly', '允许宠物', 'TINYINT', '1 表示允许宠物，0 表示不允许。', JSON_ARRAY('宠物','养宠物','宠物友好'), 1, 1, 1
FROM meta_table WHERE schema_name = 'dw' AND table_name = 'property_listing'
ON DUPLICATE KEY UPDATE description = VALUES(description), aliases = VALUES(aliases);

INSERT INTO meta_column
  (table_id, column_name, display_name, data_type, description, aliases,
   is_selectable, is_filterable, is_groupable)
SELECT table_id, 'region_id', '地区 ID', 'VARCHAR', '关联 dw.region.region_id。', JSON_ARRAY('地区编号'), 1, 1, 1
FROM meta_table WHERE schema_name = 'dw' AND table_name = 'property_listing'
ON DUPLICATE KEY UPDATE description = VALUES(description), aliases = VALUES(aliases);

INSERT INTO meta_column
  (table_id, column_name, display_name, data_type, description, aliases,
   is_selectable, is_filterable, is_groupable)
SELECT table_id, 'region_name', '地区名称', 'VARCHAR', '房源所属地区。', JSON_ARRAY('地区','区域','城区'), 1, 1, 1
FROM meta_table WHERE schema_name = 'dw' AND table_name = 'region'
ON DUPLICATE KEY UPDATE description = VALUES(description), aliases = VALUES(aliases);

INSERT INTO meta_metric
  (metric_name, display_name, description, sql_expression, default_table_id, data_type)
SELECT 'avg_weekly_rent', '平均周租金', '满足条件房源的平均澳元周租金。', 'AVG(p.price)', table_id, 'DECIMAL'
FROM meta_table WHERE schema_name = 'dw' AND table_name = 'property_listing'
ON DUPLICATE KEY UPDATE description = VALUES(description), sql_expression = VALUES(sql_expression);

INSERT INTO meta_metric
  (metric_name, display_name, description, sql_expression, default_table_id, data_type)
SELECT 'property_count', '房源数量', '满足条件的房源数量。', 'COUNT(*)', table_id, 'BIGINT'
FROM meta_table WHERE schema_name = 'dw' AND table_name = 'property_listing'
ON DUPLICATE KEY UPDATE description = VALUES(description), sql_expression = VALUES(sql_expression);

-- 说明：生产环境应使用独立的只读 Agent 数据库账号，并仅授予 dw 的 SELECT 权限。
-- CREATE USER 'rentagent_readonly'@'%' IDENTIFIED BY 'CHANGE_ME';
-- GRANT SELECT ON dw.* TO 'rentagent_readonly'@'%';
-- REVOKE INSERT, UPDATE, DELETE, DROP, ALTER, CREATE ON dw.* FROM 'rentagent_readonly'@'%';
