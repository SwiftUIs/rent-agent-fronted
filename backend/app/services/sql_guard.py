from __future__ import annotations

import re


class UnsafeSQL(ValueError):
    pass


_FORBIDDEN = re.compile(
    r"\b(insert|update|delete|drop|alter|truncate|create|grant|revoke|call|execute|outfile|load_file)\b",
    re.IGNORECASE,
)
_MULTIPLE_STATEMENTS = re.compile(r";\s*\S", re.IGNORECASE)


def validate_readonly_sql(sql: str, max_rows: int = 200) -> str:
    """校验并规范化 LLM 输出；不能替代数据库只读账号。"""
    normalized = sql.strip().rstrip(";").strip()
    if not normalized:
        raise UnsafeSQL("SQL is empty")
    if not re.match(r"^(select|with)\b", normalized, re.IGNORECASE):
        raise UnsafeSQL("Only SELECT/WITH queries are allowed")
    if _FORBIDDEN.search(normalized):
        raise UnsafeSQL("Forbidden SQL keyword detected")
    if _MULTIPLE_STATEMENTS.search(normalized):
        raise UnsafeSQL("Multiple SQL statements are not allowed")
    if re.search(r"\blimit\b", normalized, re.IGNORECASE):
        return normalized
    return f"{normalized} LIMIT {max_rows}"
