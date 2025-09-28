from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Iterable, Sequence
import logging

from firebase_admin import firestore as firebase_firestore
from google.api_core import exceptions as google_exceptions

from ..firebase import get_firestore_client
from .utils import extract_trigger_candidates, format_note_for_context, normalize_string_list

log = logging.getLogger(__name__)

__all__ = [
    "NoteNotFoundError",
    "NotePermissionError",
    "NoteStoreError",
    "create_note",
    "delete_note",
    "find_notes_for_text",
    "format_note_for_context",
    "get_note",
    "list_notes",
    "search_notes",
    "serialize_note",
    "update_note",
]


class NoteStoreError(Exception):
    """Base exception for note storage errors."""


class NoteNotFoundError(NoteStoreError):
    """Raised when a note document does not exist."""


class NotePermissionError(NoteStoreError):
    """Raised when a caller attempts to act on a note they do not own."""


_NOTES_COLLECTION = "notes"
_MAX_SEARCH_SCAN = 500


def _notes_collection():
    return get_firestore_client().collection(_NOTES_COLLECTION)


def _to_datetime(value: Any) -> datetime | None:
    if value is None:
        return None
    if isinstance(value, datetime):
        return value
    to_datetime = getattr(value, "to_datetime", None)
    if callable(to_datetime):
        return to_datetime(tz=timezone.utc)
    return None


def _to_iso(value: Any) -> str | None:
    dt = _to_datetime(value)
    if dt is None:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc).isoformat()


def serialize_note(document_id: str, data: dict[str, Any]) -> dict[str, Any]:
    content = data.get("content")
    if content is None:
        content = ""

    trigger_words = data.get("triggerWords") or []

    serialized = {
        "id": document_id,
        "uid": data.get("uid"),
        "title": data.get("title"),
        "content": content,
        "excerpt": content,
        "keywords": data.get("keywords") or [],
        "triggerWords": trigger_words,
        "triggerwords": trigger_words,
        "createdAt": _to_iso(data.get("createdAt")),
        "updatedAt": _to_iso(data.get("updatedAt")),
    }
    return serialized


def _ensure_ownership(data: dict[str, Any], uid: str, note_id: str) -> None:
    if data.get("uid") != uid:
        raise NotePermissionError(f"Note '{note_id}' does not belong to uid '{uid}'.")


def _prepare_keywords(values: Iterable[Any] | None) -> tuple[list[str], list[str]]:
    original = normalize_string_list(values)
    lowered = normalize_string_list(values, lowercase=True)
    return original, lowered


def _prepare_trigger_words(values: Iterable[Any] | None) -> tuple[list[str], list[str]]:
    original = normalize_string_list(values)
    lowered = normalize_string_list(values, lowercase=True)
    return original, lowered


def _clean_title(value: str | None) -> str:
    title = (value or "").strip()
    return title or "New note"


def _clean_content(value: str | None) -> str:
    if value is None:
        return ""
    return str(value).strip()


def create_note(
    uid: str,
    *,
    title: str | None = None,
    content: str | None = None,
    keywords: Iterable[Any] | None = None,
    trigger_words: Iterable[Any] | None = None,
) -> dict[str, Any]:
    if not uid:
        raise NoteStoreError("uid is required to create a note")

    title_clean = _clean_title(title)
    content_clean = _clean_content(content)
    keywords_clean, keywords_lower = _prepare_keywords(keywords)
    trigger_clean, trigger_lower = _prepare_trigger_words(trigger_words)

    data = {
        "uid": uid,
        "title": title_clean,
        "content": content_clean,
        "keywords": keywords_clean,
        "keywordsLower": keywords_lower,
        "triggerWords": trigger_clean,
        "triggerWordsLower": trigger_lower,
        "createdAt": firebase_firestore.SERVER_TIMESTAMP,
        "updatedAt": firebase_firestore.SERVER_TIMESTAMP,
    }

    notes_col = _notes_collection()
    doc_ref = notes_col.document()

    try:
        doc_ref.set(data)
        snapshot = doc_ref.get()
    except (google_exceptions.PermissionDenied, google_exceptions.GoogleAPICallError) as exc:
        raise NoteStoreError(str(exc)) from exc

    stored = snapshot.to_dict() or {}
    stored["id"] = doc_ref.id
    return stored


def list_notes(uid: str, *, limit: int | None = None) -> list[dict[str, Any]]:
    if not uid:
        raise NoteStoreError("uid is required to list notes")

    notes_col = _notes_collection()
    query = notes_col.where("uid", "==", uid).order_by(
        "updatedAt",
        direction=firebase_firestore.Query.DESCENDING,
    )
    if limit:
        query = query.limit(limit)

    try:
        documents = list(query.stream())
    except (google_exceptions.PermissionDenied, google_exceptions.GoogleAPICallError) as exc:
        raise NoteStoreError(str(exc)) from exc

    results: list[dict[str, Any]] = []
    for doc in documents:
        payload = doc.to_dict() or {}
        payload["id"] = doc.id
        results.append(payload)

    return results


def get_note(note_id: str, uid: str) -> dict[str, Any]:
    notes_col = _notes_collection()
    doc_ref = notes_col.document(note_id)

    try:
        snapshot = doc_ref.get()
    except (google_exceptions.PermissionDenied, google_exceptions.GoogleAPICallError) as exc:
        raise NoteStoreError(str(exc)) from exc

    if not snapshot.exists:
        raise NoteNotFoundError(f"Note '{note_id}' was not found")

    data = snapshot.to_dict() or {}
    _ensure_ownership(data, uid, note_id)
    data["id"] = snapshot.id
    return data


def update_note(note_id: str, uid: str, updates: dict[str, Any]) -> dict[str, Any]:
    notes_col = _notes_collection()
    doc_ref = notes_col.document(note_id)

    try:
        snapshot = doc_ref.get()
    except (google_exceptions.PermissionDenied, google_exceptions.GoogleAPICallError) as exc:
        raise NoteStoreError(str(exc)) from exc

    if not snapshot.exists:
        raise NoteNotFoundError(f"Note '{note_id}' was not found")

    stored = snapshot.to_dict() or {}
    _ensure_ownership(stored, uid, note_id)

    update_payload: dict[str, Any] = {}

    if "title" in updates:
        update_payload["title"] = _clean_title(updates.get("title"))
    if "content" in updates or "excerpt" in updates:
        content_source = updates.get("content", updates.get("excerpt"))
        update_payload["content"] = _clean_content(content_source)
    if "keywords" in updates:
        keywords_clean, keywords_lower = _prepare_keywords(updates.get("keywords"))
        update_payload["keywords"] = keywords_clean
        update_payload["keywordsLower"] = keywords_lower
    if "triggerWords" in updates or "triggerwords" in updates:
        trigger_source = updates.get("triggerWords", updates.get("triggerwords"))
        trigger_clean, trigger_lower = _prepare_trigger_words(trigger_source)
        update_payload["triggerWords"] = trigger_clean
        update_payload["triggerWordsLower"] = trigger_lower

    if not update_payload:
        raise NoteStoreError("No supported fields provided for update")

    update_payload["updatedAt"] = firebase_firestore.SERVER_TIMESTAMP

    try:
        doc_ref.update(update_payload)
        final_snapshot = doc_ref.get()
    except (google_exceptions.PermissionDenied, google_exceptions.GoogleAPICallError) as exc:
        raise NoteStoreError(str(exc)) from exc

    final_data = final_snapshot.to_dict() or {}
    final_data["id"] = note_id
    return final_data


def delete_note(note_id: str, uid: str) -> None:
    notes_col = _notes_collection()
    doc_ref = notes_col.document(note_id)

    try:
        snapshot = doc_ref.get()
    except (google_exceptions.PermissionDenied, google_exceptions.GoogleAPICallError) as exc:
        raise NoteStoreError(str(exc)) from exc

    if not snapshot.exists:
        raise NoteNotFoundError(f"Note '{note_id}' was not found")

    data = snapshot.to_dict() or {}
    _ensure_ownership(data, uid, note_id)

    try:
        doc_ref.delete()
    except (google_exceptions.PermissionDenied, google_exceptions.GoogleAPICallError) as exc:
        raise NoteStoreError(str(exc)) from exc


def search_notes(
    uid: str,
    *,
    query: str | None = None,
    trigger_terms: Sequence[str] | None = None,
    keyword_terms: Sequence[str] | None = None,
    limit: int = 50,
) -> list[dict[str, Any]]:
    if not uid:
        raise NoteStoreError("uid is required to search notes")

    trigger_terms = normalize_string_list(trigger_terms, lowercase=True, max_items=10)
    keyword_terms = normalize_string_list(keyword_terms, lowercase=True)
    query_text = (query or "").strip().lower()

    # Always scan a bounded set of notes for the user to avoid repeated round-trips.
    scan_limit = min(max(limit * 3, limit), _MAX_SEARCH_SCAN)

    notes_col = _notes_collection()
    base_query = notes_col.where("uid", "==", uid).order_by(
        "updatedAt",
        direction=firebase_firestore.Query.DESCENDING,
    ).limit(scan_limit)

    try:
        documents = list(base_query.stream())
    except google_exceptions.FailedPrecondition:
        # If the order_by requires an index that does not exist yet, fall back to an
        # unordered scan. Firestore will raise FAILED_PRECONDITION with the index URL.
        log.warning("Firestore index missing for notes search; falling back to unordered scan for uid %s", uid)
        try:
            documents = list(notes_col.where("uid", "==", uid).limit(scan_limit).stream())
        except (google_exceptions.PermissionDenied, google_exceptions.GoogleAPICallError) as exc:
            raise NoteStoreError(str(exc)) from exc
    except (google_exceptions.PermissionDenied, google_exceptions.GoogleAPICallError) as exc:
        raise NoteStoreError(str(exc)) from exc

    results: list[dict[str, Any]] = []

    trigger_set = set(trigger_terms)
    keyword_set = set(keyword_terms)

    for doc in documents:
        data = doc.to_dict() or {}
        trigger_lower = set(data.get("triggerWordsLower") or [])
        keywords_lower = set(data.get("keywordsLower") or [])

        if trigger_set and not trigger_set.intersection(trigger_lower):
            continue
        if keyword_set and not keyword_set.intersection(keywords_lower):
            continue
        if query_text:
            haystack = " ".join(
                str(part or "")
                for part in (
                    data.get("title"),
                    data.get("content"),
                    " ".join(data.get("keywords") or []),
                    " ".join(data.get("triggerWords") or []),
                )
            ).lower()
            if query_text not in haystack:
                continue

        data["id"] = doc.id
        results.append(data)
        if len(results) >= limit:
            break

    return results


def find_notes_for_text(uid: str, text: str | None, *, limit: int = 5) -> list[dict[str, Any]]:
    triggers = extract_trigger_candidates(text, max_terms=10)
    if not triggers:
        return []

    try:
        candidates = search_notes(uid, trigger_terms=triggers, limit=limit)
    except NoteStoreError as exc:
        log.warning("Failed to search notes for triggers: %s", exc)
        return []

    return candidates
