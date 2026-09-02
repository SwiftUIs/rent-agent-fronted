#!/usr/bin/env bash
set -euo pipefail

# Qdrant 1.x
# bge-large-zh-v1.5 默认使用 1024 维向量；如更换 Embedding 模型，请同步修改 VECTOR_SIZE。
QDRANT_URL="${QDRANT_URL:-http://localhost:6333}"
QDRANT_API_KEY_ARG=()
if [[ -n "${QDRANT_API_KEY:-}" ]]; then
  QDRANT_API_KEY_ARG=(-H "api-key: ${QDRANT_API_KEY}")
fi

curl "${QDRANT_API_KEY_ARG[@]}" -fsS -X PUT "$QDRANT_URL/collections/rentagent-meta" \
  -H 'Content-Type: application/json' \
  -d @- <<'JSON'
{
  "vectors": {
    "size": 1024,
    "distance": "Cosine",
    "on_disk": true
  },
  "optimizers_config": {
    "default_segment_number": 2
  },
  "hnsw_config": {
    "m": 16,
    "ef_construct": 100,
    "on_disk": true
  }
}
JSON

# 建议的 payload 索引，便于按对象类型、表、列和可过滤性做混合过滤。
for field in object_type table_name column_name metric_name enum_value is_filterable is_selectable embedding_version; do
  case "$field" in
    is_filterable|is_selectable) schema='{"type":"bool"}' ;;
    *) schema='{"type":"keyword"}' ;;
  esac
  curl "${QDRANT_API_KEY_ARG[@]}" -fsS -X PUT "$QDRANT_URL/collections/rentagent-meta/index" \
    -H 'Content-Type: application/json' \
    -d "{\"field_name\":\"$field\",\"field_schema\":$schema}" >/dev/null
done

echo "Qdrant collection created: rentagent-meta"
