from __future__ import annotations

from datetime import datetime, timezone
from http import HTTPStatus
from typing import Any

from flask import Blueprint, current_app, jsonify, request
from firebase_admin import firestore as firebase_firestore
from google.api_core import exceptions as google_exceptions
import re

from ..ai.gemini import GeminiAPIError, generate_reply
from ..firebase import get_firestore_client

chats_bp = Blueprint("chats", __name__, url_prefix="/chats")


def _parse_json_body() -> dict[str, Any]:
    if request.is_json:
        payload = request.get_json(silent=True) or {}
    else:
        payload = {}
    return payload


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _to_iso(value: Any) -> str | None:
    if isinstance(value, datetime):
        if value.tzinfo is None:
            value = value.replace(tzinfo=timezone.utc)
        return value.astimezone(timezone.utc).isoformat()
    return None


def _serialize_chat(doc_id: str, data: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": doc_id,
        "uid": data.get("uid"),
        "title": data.get("title"),
        "systemPrompt": data.get("systemPrompt"),
        "createdAt": _to_iso(data.get("createdAt")),
        "updatedAt": _to_iso(data.get("updatedAt")),
    }


def _serialize_message(doc_id: str, data: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": doc_id,
        "role": data.get("role"),
        "content": data.get("content"),
        "createdAt": _to_iso(data.get("createdAt")),
    }


def _get_chat_ref(chat_id: str):
    db = get_firestore_client()
    return db.collection("chats").document(chat_id)


def _firestore_error_response(exc: Exception) -> tuple[Any, int]:
    # Provide helpful client-facing messages for common Firestore issues.
    exc_text = str(exc) or ""
    lower = exc_text.lower()

    # If the project does not have a Firestore/Datastore database created yet
    if isinstance(exc, google_exceptions.NotFound) or "does not exist" in lower:
        # try to extract a project id from the error text
        m = re.search(r"project\s+([\w-]+)", exc_text)
        project = m.group(1) if m else None
        setup_url = (
            f"https://console.cloud.google.com/datastore/setup?project={project}"
            if project
            else "https://console.cloud.google.com/datastore/setup"
        )
        message = (
            "No Cloud Firestore / Cloud Datastore database exists for the configured Google Cloud project. "
            "Create a database in the Google Cloud Console and retry. "
            f"Setup: {setup_url}. "
            "If you've created a named Firestore database, set the FIRESTORE_DATABASE_ID environment variable "
            "to that database ID so the backend points to it."
        )
    else:
        # Default message when API is disabled or credentials lack permission
        message = (
            "Cloud Firestore API is disabled for the configured Google Cloud project "
            "or the service account does not have permission. Please enable the Firestore API "
            "and ensure credentials have the required permissions."
        )
    return (
        jsonify({"error": "firestore_service_unavailable", "message": message, "detail": str(exc)}),
        HTTPStatus.SERVICE_UNAVAILABLE,
    )


class FirestoreAccessError(Exception):
    """Internal sentinel to indicate a Firestore access issue occurred."""



def _get_chat_for_user(chat_id: str, uid: str):
    chat_ref = _get_chat_ref(chat_id)
    try:
        chat_snapshot = chat_ref.get()
    except google_exceptions.PermissionDenied as exc:
        raise FirestoreAccessError(exc)
    except google_exceptions.GoogleAPICallError as exc:
        raise FirestoreAccessError(exc)
    if not chat_snapshot.exists:
        return None, None

    data = chat_snapshot.to_dict() or {}
    if data.get("uid") != uid:
        return chat_ref, None

    return chat_ref, data


@chats_bp.post("")
def create_chat() -> tuple[Any, int]:
    payload = _parse_json_body()

    uid: str | None = payload.get("uid")
    title: str = (payload.get("title") or "New chat").strip()
    system_prompt: str | None = payload.get("systemPrompt")

    if not uid:
        return (
            jsonify({"error": "validation_error", "message": "uid is required."}),
            HTTPStatus.BAD_REQUEST,
        )

    now = _now()
    chat_data = {
        "uid": uid,
        "title": title,
        "systemPrompt": system_prompt,
        "createdAt": now,
        "updatedAt": now,
    }

    db = get_firestore_client()
    chats_collection = db.collection("chats")
    chat_ref = chats_collection.document()
    try:
        chat_ref.set(chat_data)
    except google_exceptions.PermissionDenied as exc:
        return _firestore_error_response(exc)
    except google_exceptions.GoogleAPICallError as exc:
        return _firestore_error_response(exc)

    return jsonify(_serialize_chat(chat_ref.id, chat_data)), HTTPStatus.CREATED


@chats_bp.get("")
def list_chats() -> tuple[Any, int]:
    uid = request.args.get("uid")
    if not uid:
        return (
            jsonify({"error": "validation_error", "message": "uid query parameter is required."}),
            HTTPStatus.BAD_REQUEST,
        )

    db = get_firestore_client()
    query = (
        db.collection("chats")
        .where("uid", "==", uid)
        .order_by("updatedAt", direction=firebase_firestore.Query.DESCENDING)
    )

    try:
        chat_docs = list(query.stream())
    except google_exceptions.PermissionDenied as exc:
        return _firestore_error_response(exc)
    except google_exceptions.GoogleAPICallError as exc:
        return _firestore_error_response(exc)

    chats = [
        _serialize_chat(doc.id, doc.to_dict() or {})
        for doc in chat_docs
    ]

    return jsonify({"items": chats}), HTTPStatus.OK


@chats_bp.get("/<chat_id>")
def get_chat(chat_id: str) -> tuple[Any, int]:
    uid = request.args.get("uid")
    if not uid:
        return (
            jsonify({"error": "validation_error", "message": "uid query parameter is required."}),
            HTTPStatus.BAD_REQUEST,
        )

    try:
        chat_ref, chat_data = _get_chat_for_user(chat_id, uid)
    except FirestoreAccessError as exc:
        return _firestore_error_response(exc)
    if chat_ref is None:
        return (
            jsonify({"error": "not_found", "message": "Chat not found."}),
            HTTPStatus.NOT_FOUND,
        )
    if chat_data is None:
        return (
            jsonify({"error": "forbidden", "message": "You do not have access to this chat."}),
            HTTPStatus.FORBIDDEN,
        )

    messages_ref = chat_ref.collection("messages").order_by("createdAt")
    try:
        message_docs = list(messages_ref.stream())
    except google_exceptions.PermissionDenied as exc:
        return _firestore_error_response(exc)
    except google_exceptions.GoogleAPICallError as exc:
        return _firestore_error_response(exc)

    messages = [
        _serialize_message(doc.id, doc.to_dict() or {})
        for doc in message_docs
    ]

    return (
        jsonify({"chat": _serialize_chat(chat_ref.id, chat_data), "messages": messages}),
        HTTPStatus.OK,
    )


@chats_bp.patch("/<chat_id>")
def update_chat(chat_id: str) -> tuple[Any, int]:
    payload = _parse_json_body()

    uid: str | None = payload.get("uid")
    if not uid:
        return (
            jsonify({"error": "validation_error", "message": "uid is required."}),
            HTTPStatus.BAD_REQUEST,
        )

    try:
        chat_ref, chat_data = _get_chat_for_user(chat_id, uid)
    except FirestoreAccessError as exc:
        return _firestore_error_response(exc)
    if chat_ref is None:
        return (
            jsonify({"error": "not_found", "message": "Chat not found."}),
            HTTPStatus.NOT_FOUND,
        )
    if chat_data is None:
        return (
            jsonify({"error": "forbidden", "message": "You do not have access to this chat."}),
            HTTPStatus.FORBIDDEN,
        )

    updates: dict[str, Any] = {}
    if "title" in payload:
        updates["title"] = (payload.get("title") or "").strip()
    if "systemPrompt" in payload:
        updates["systemPrompt"] = payload.get("systemPrompt")

    if not updates:
        return (
            jsonify({"error": "validation_error", "message": "Nothing to update."}),
            HTTPStatus.BAD_REQUEST,
        )

    updates["updatedAt"] = _now()

    try:
        chat_ref.update(updates)
    except google_exceptions.PermissionDenied as exc:
        return _firestore_error_response(exc)
    except google_exceptions.GoogleAPICallError as exc:
        return _firestore_error_response(exc)

    chat_data.update(updates)

    return jsonify(_serialize_chat(chat_ref.id, chat_data)), HTTPStatus.OK


@chats_bp.delete("/<chat_id>")
def delete_chat(chat_id: str) -> tuple[Any, int]:
    payload = _parse_json_body()
    uid: str | None = payload.get("uid")
    if not uid:
        return (
            jsonify({"error": "validation_error", "message": "uid is required."}),
            HTTPStatus.BAD_REQUEST,
        )

    try:
        chat_ref, chat_data = _get_chat_for_user(chat_id, uid)
    except FirestoreAccessError as exc:
        return _firestore_error_response(exc)
    if chat_ref is None:
        return (
            jsonify({"error": "not_found", "message": "Chat not found."}),
            HTTPStatus.NOT_FOUND,
        )
    if chat_data is None:
        return (
            jsonify({"error": "forbidden", "message": "You do not have access to this chat."}),
            HTTPStatus.FORBIDDEN,
        )

    batch = get_firestore_client().batch()
    messages_ref = chat_ref.collection("messages")
    try:
        for message_doc in messages_ref.stream():
            batch.delete(message_doc.reference)
        batch.delete(chat_ref)
        batch.commit()
    except google_exceptions.PermissionDenied as exc:
        return _firestore_error_response(exc)
    except google_exceptions.GoogleAPICallError as exc:
        return _firestore_error_response(exc)

    return ("", HTTPStatus.NO_CONTENT)


@chats_bp.post("/<chat_id>/messages")
def add_message(chat_id: str) -> tuple[Any, int]:
    payload = _parse_json_body()

    uid: str | None = payload.get("uid")
    content: str = (payload.get("content") or "").strip()
    role: str = (payload.get("role") or "user").lower()

    if not uid:
        return (
            jsonify({"error": "validation_error", "message": "uid is required."}),
            HTTPStatus.BAD_REQUEST,
        )
    if not content:
        return (
            jsonify({"error": "validation_error", "message": "content is required."}),
            HTTPStatus.BAD_REQUEST,
        )
    if role not in {"user", "system"}:
        return (
            jsonify({"error": "validation_error", "message": "role must be 'user' or 'system'."}),
            HTTPStatus.BAD_REQUEST,
        )

    try:
        chat_ref, chat_data = _get_chat_for_user(chat_id, uid)
    except FirestoreAccessError as exc:
        return _firestore_error_response(exc)
    if chat_ref is None:
        return (
            jsonify({"error": "not_found", "message": "Chat not found."}),
            HTTPStatus.NOT_FOUND,
        )
    if chat_data is None:
        return (
            jsonify({"error": "forbidden", "message": "You do not have access to this chat."}),
            HTTPStatus.FORBIDDEN,
        )

    db = get_firestore_client()
    messages_ref = chat_ref.collection("messages")
    now = _now()

    user_message_data = {
        "uid": uid,
        "role": role,
        "content": content,
        "createdAt": now,
    }

    try:
        user_message_ref = messages_ref.document()
        user_message_ref.set(user_message_data)

        chat_ref.update({"updatedAt": now})
    except google_exceptions.PermissionDenied as exc:
        return _firestore_error_response(exc)
    except google_exceptions.GoogleAPICallError as exc:
        return _firestore_error_response(exc)

    gemini_api_key: str | None = current_app.config.get("GEMINI_API_KEY")
    if not gemini_api_key:
        return (
            jsonify(
                {
                    "error": "not_configured",
                    "message": "GEMINI_API_KEY is not configured.",
                    "userMessage": _serialize_message(user_message_ref.id, user_message_data),
                }
            ),
            HTTPStatus.SERVICE_UNAVAILABLE,
        )

    history_query = messages_ref.order_by("createdAt")
    try:
        history_docs = list(history_query.stream())
    except google_exceptions.PermissionDenied as exc:
        return _firestore_error_response(exc)
    except google_exceptions.GoogleAPICallError as exc:
        return _firestore_error_response(exc)

    history_messages = []
    if chat_data.get("systemPrompt"):
        history_messages.append({"role": "system", "content": chat_data["systemPrompt"]})

    for doc in history_docs:
        data = doc.to_dict() or {}
        history_messages.append({
            "role": data.get("role", "user"),
            "content": data.get("content", ""),
        })

    try:
        ai_reply = generate_reply(history_messages, api_key=gemini_api_key)
    except GeminiAPIError as exc:
        return (
            jsonify(
                {
                    "error": "ai_error",
                    "message": str(exc),
                    "userMessage": _serialize_message(user_message_ref.id, user_message_data),
                }
            ),
            HTTPStatus.BAD_GATEWAY,
        )

    ai_message_data = {
        "uid": uid,
        "role": "assistant",
        "content": ai_reply,
        "createdAt": _now(),
    }

    try:
        ai_message_ref = messages_ref.document()
        ai_message_ref.set(ai_message_data)
        chat_ref.update({"updatedAt": ai_message_data["createdAt"]})
    except google_exceptions.PermissionDenied as exc:
        return _firestore_error_response(exc)
    except google_exceptions.GoogleAPICallError as exc:
        return _firestore_error_response(exc)

    return (
        jsonify(
            {
                "userMessage": _serialize_message(user_message_ref.id, user_message_data),
                "assistantMessage": _serialize_message(ai_message_ref.id, ai_message_data),
            }
        ),
        HTTPStatus.CREATED,
    )
