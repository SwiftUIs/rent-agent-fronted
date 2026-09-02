#!/usr/bin/env bash
set -euo pipefail

# Elasticsearch 8.x
# 使用方式：ES_URL=http://localhost:9200 ES_USER=elastic ES_PASSWORD=xxx ./01_init.sh
ES_URL="${ES_URL:-http://localhost:9200}"
AUTH_ARGS=()
if [[ -n "${ES_USER:-}" ]]; then
  AUTH_ARGS=(-u "${ES_USER}:${ES_PASSWORD:?ES_PASSWORD is required when ES_USER is set}")
fi

curl "${AUTH_ARGS[@]}" -fsS -X PUT "$ES_URL/rentagent-meta-v1" \
  -H 'Content-Type: application/json' \
  -d @- <<'JSON'
{
  "settings": {
    "number_of_shards": 1,
    "number_of_replicas": 0,
    "analysis": {
      "normalizer": {
        "lowercase_normalizer": {
          "type": "custom",
          "filter": ["lowercase"]
        }
      }
    }
  },
  "mappings": {
    "dynamic": "strict",
    "properties": {
      "object_id": {"type": "keyword"},
      "object_type": {"type": "keyword"},
      "schema_name": {"type": "keyword"},
      "table_name": {"type": "keyword"},
      "column_name": {"type": "keyword", "normalizer": "lowercase_normalizer"},
      "metric_name": {"type": "keyword", "normalizer": "lowercase_normalizer"},
      "enum_value": {"type": "keyword", "normalizer": "lowercase_normalizer"},
      "display_name": {"type": "text"},
      "description": {"type": "text"},
      "aliases": {"type": "text"},
      "searchable_text": {"type": "text"},
      "data_type": {"type": "keyword"},
      "is_filterable": {"type": "boolean"},
      "is_selectable": {"type": "boolean"},
      "embedding_model": {"type": "keyword"},
      "embedding_version": {"type": "keyword"},
      "source_updated_at": {"type": "date"}
    }
  }
}
JSON

# 可选：如果希望直接在 ES 中按地址/房型做房源关键词过滤，可创建该索引。
curl "${AUTH_ARGS[@]}" -fsS -X PUT "$ES_URL/rentagent-properties-v1" \
  -H 'Content-Type: application/json' \
  -d @- <<'JSON'
{
  "settings": {
    "number_of_shards": 1,
    "number_of_replicas": 0
  },
  "mappings": {
    "dynamic": "strict",
    "properties": {
      "product_id": {"type": "keyword"},
      "product_name": {"type": "text", "fields": {"keyword": {"type": "keyword"}}},
      "property_type": {"type": "keyword"},
      "bedrooms": {"type": "integer"},
      "bathrooms": {"type": "integer"},
      "price": {"type": "scaled_float", "scaling_factor": 100},
      "is_pet_friendly": {"type": "boolean"},
      "region_id": {"type": "keyword"},
      "region_name": {"type": "keyword"},
      "availability_status": {"type": "keyword"},
      "updated_at": {"type": "date"}
    }
  }
}
JSON

echo "Elasticsearch indexes created: rentagent-meta-v1, rentagent-properties-v1"
