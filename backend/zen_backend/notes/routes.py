from __future__ import annotations

from http import HTTPStatus
from typing import Any

from flask import Blueprint, jsonify, request

from .service import (
    NoteNotFoundError,
    NotePermissionError,
    NoteStoreError,
    create_note,
    delete_note,
    get_note,
    list_notes,
    search_notes,
    serialize_note,
    update_note,
)

notes_bp = Blueprint("notes", __name__, url_prefix="/notes")


def _parse_json_body() -> dict[str, Any]:
    if request.is_json:
        return request.get_json(silent=True) or {}
    return {}


def _store_error_response(detail: str, *, status: HTTPStatus = HTTPStatus.SERVICE_UNAVAILABLE):
    return (
        jsonify({
            "error": "notes_store_error",
            "message": "Unable to access notes storage.",
            "detail": detail,
        }),
        status,
    )


def _validation_error(message: str):
    return (
        jsonify({"error": "validation_error", "message": message}),
        HTTPStatus.BAD_REQUEST,
    )


def _serialize_many(notes: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [serialize_note(note.get("id"), note) for note in notes]


@notes_bp.get("")
def list_user_notes() -> tuple[Any, int]:
    uid = request.args.get("uid")
    if not uid:
        return _validation_error("uid query parameter is required.")

    limit_param = request.args.get("limit")
    limit: int | None = None
    if limit_param:
        try:
            limit_value = int(limit_param)
        except ValueError:
            return _validation_error("limit must be an integer.")
        if limit_value <= 0:
            return _validation_error("limit must be a positive integer.")
        limit = min(limit_value, 200)

    try:
        notes = list_notes(uid, limit=limit)
    except NoteStoreError as exc:
        return _store_error_response(str(exc))

    return jsonify({"items": _serialize_many(notes)}), HTTPStatus.OK


@notes_bp.post("")
def create_user_note() -> tuple[Any, int]:
    payload = _parse_json_body()
    uid = payload.get("uid")
    if not uid:
        return _validation_error("uid is required.")

    title = payload.get("title")
    content = payload.get("content", payload.get("excerpt"))
    keywords = payload.get("keywords")
    trigger_words = payload.get("triggerWords", payload.get("triggerwords"))

    try:
        note = create_note(
            uid,
            title=title,
            content=content,
            keywords=keywords,
            trigger_words=trigger_words,
        )
    except NoteStoreError as exc:
        return _store_error_response(str(exc))

    return jsonify(serialize_note(note.get("id"), note)), HTTPStatus.CREATED


@notes_bp.get("/<note_id>")
def get_user_note(note_id: str) -> tuple[Any, int]:
    uid = request.args.get("uid")
    if not uid:
        return _validation_error("uid query parameter is required.")

    try:
        note = get_note(note_id, uid)
    except NotePermissionError as exc:
        return (
            jsonify({"error": "forbidden", "message": str(exc)}),
            HTTPStatus.FORBIDDEN,
        )
    except NoteNotFoundError as exc:
        return (
            jsonify({"error": "not_found", "message": str(exc)}),
            HTTPStatus.NOT_FOUND,
        )
    except NoteStoreError as exc:
        return _store_error_response(str(exc))

    return jsonify(serialize_note(note.get("id"), note)), HTTPStatus.OK


@notes_bp.patch("/<note_id>")
def update_user_note(note_id: str) -> tuple[Any, int]:
    payload = _parse_json_body()
    uid = payload.get("uid")
    if not uid:
        return _validation_error("uid is required.")

    update_fields: dict[str, Any] = {}
    for field in ("title", "content", "excerpt", "keywords", "triggerWords", "triggerwords"):
        if field in payload:
            update_fields[field] = payload.get(field)

    if not update_fields:
        return _validation_error(
            "Provide at least one updatable field: title, content/excerpt, keywords, triggerWords."
        )

    try:
        note = update_note(note_id, uid, update_fields)
    except NotePermissionError as exc:
        return (
            jsonify({"error": "forbidden", "message": str(exc)}),
            HTTPStatus.FORBIDDEN,
        )
    except NoteNotFoundError as exc:
        return (
            jsonify({"error": "not_found", "message": str(exc)}),
            HTTPStatus.NOT_FOUND,
        )
    except NoteStoreError as exc:
        return _store_error_response(str(exc))

    return jsonify(serialize_note(note.get("id"), note)), HTTPStatus.OK


@notes_bp.delete("/<note_id>")
def delete_user_note(note_id: str) -> tuple[Any, int]:
    payload = _parse_json_body()
    uid = payload.get("uid") or request.args.get("uid")
    if not uid:
        return _validation_error("uid is required.")

    try:
        delete_note(note_id, uid)
    except NotePermissionError as exc:
        return (
            jsonify({"error": "forbidden", "message": str(exc)}),
            HTTPStatus.FORBIDDEN,
        )
    except NoteNotFoundError as exc:
        return (
            jsonify({"error": "not_found", "message": str(exc)}),
            HTTPStatus.NOT_FOUND,
        )
    except NoteStoreError as exc:
        return _store_error_response(str(exc))

    return ("", HTTPStatus.NO_CONTENT)


@notes_bp.get("/search")
def search_user_notes() -> tuple[Any, int]:
    uid = request.args.get("uid")
    if not uid:
        return _validation_error("uid query parameter is required.")

    limit_param = request.args.get("limit")
    limit = 50
    if limit_param:
        try:
            limit_value = int(limit_param)
        except ValueError:
            return _validation_error("limit must be an integer.")
        if limit_value <= 0:
            return _validation_error("limit must be a positive integer.")
        limit = min(limit_value, 200)

    query_text = request.args.get("q")
    trigger_terms = request.args.getlist("trigger") or request.args.getlist("triggerWords")
    keyword_terms = request.args.getlist("keyword") or request.args.getlist("keywords")

    try:
        notes = search_notes(
            uid,
            query=query_text,
            trigger_terms=trigger_terms,
            keyword_terms=keyword_terms,
            limit=limit,
        )
    except NoteStoreError as exc:
        return _store_error_response(str(exc))

    return jsonify({"items": _serialize_many(notes)}), HTTPStatus.OK
