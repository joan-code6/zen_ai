from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Iterable
import re

TRIGGER_TOKEN_RE = re.compile(
    r"[0-9A-Za-zÀ-ÖØ-öø-ÿ]+(?:['-][0-9A-Za-zÀ-ÖØ-öø-ÿ]+)*",
    re.UNICODE,
)
DEFAULT_CONTEXT_CONTENT_LIMIT = 1200

__all__ = [
    "DEFAULT_CONTEXT_CONTENT_LIMIT",
    "extract_trigger_candidates",
    "format_note_for_context",
    "normalize_string_list",
]


def normalize_string_list(
    values: Iterable[Any] | None,
    *,
    lowercase: bool = False,
    max_items: int | None = None,
) -> list[str]:
    """Return a cleaned list of unique strings.

    - Trims whitespace and ignores empty entries.
    - Casts non-string values to strings when possible.
    - Deduplicates values case-insensitively while preserving order.
    - Optionally lowercases all results.
    - Optionally truncates to ``max_items`` entries.
    """

    if values is None:
        return []

    if isinstance(values, str):
        iterator: Iterable[Any] = [values]
    else:
        iterator = values

    result: list[str] = []
    seen: set[str] = set()

    for raw in iterator:
        if raw is None:
            continue
        if not isinstance(raw, str):
            try:
                raw = str(raw)
            except Exception:
                continue
        text = raw.strip()
        if not text:
            continue

        key = text.lower()
        if key in seen:
            continue

        seen.add(key)
        normalized = key if lowercase else text
        result.append(normalized)

        if max_items is not None and len(result) >= max_items:
            break

    return result


def extract_trigger_candidates(
    text: str | None,
    *,
    max_terms: int = 10,
    min_length: int = 2,
) -> list[str]:
    """Extract candidate trigger words from free-form text.

    The function lowercases the text, tokenizes using ``TRIGGER_TOKEN_RE``,
    filters out short tokens, and returns up to ``max_terms`` unique items
    preserving the order in which they appeared.
    """

    if not text:
        return []

    tokens = TRIGGER_TOKEN_RE.findall(text.lower())
    results: list[str] = []
    seen: set[str] = set()

    for token in tokens:
        if len(token) < min_length:
            continue
        if token in seen:
            continue
        seen.add(token)
        results.append(token)
        if len(results) >= max_terms:
            break

    return results


def _format_timestamp(value: Any) -> str | None:
    if isinstance(value, str):
        return value
    if isinstance(value, datetime):
        if value.tzinfo is None:
            value = value.replace(tzinfo=timezone.utc)
        return value.astimezone(timezone.utc).isoformat()
    return None


def format_note_for_context(
    note: dict[str, Any],
    *,
    content_limit: int = DEFAULT_CONTEXT_CONTENT_LIMIT,
    include_metadata: bool = True,
) -> str:
    """Format a note dictionary into a compact context block for the LLM."""

    title = (note.get("title") or "New note").strip()
    content = (note.get("content") or note.get("excerpt") or "").strip()

    if content_limit and len(content) > content_limit:
        content = f"{content[:content_limit].rstrip()}…"

    keywords = note.get("keywords") or []
    trigger_words = note.get("triggerWords") or note.get("triggerwords") or []

    timestamp = _format_timestamp(note.get("updatedAt") or note.get("updated_at"))

    lines: list[str] = [f"Stored note: {title}"]
    if include_metadata and timestamp:
        lines.append(f"Last updated: {timestamp}")
    if content:
        lines.append(f"Body: {content}")
    if include_metadata and keywords:
        lines.append(f"Keywords: {', '.join(str(k) for k in keywords)}")
    if include_metadata and trigger_words:
        lines.append(f"Trigger words: {', '.join(str(t) for t in trigger_words)}")

    return "\n".join(lines).strip()
