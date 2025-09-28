from __future__ import annotations

from datetime import datetime, timezone
from http import HTTPStatus
from pathlib import Path
from typing import Any, Iterable
from uuid import uuid4

from flask import Blueprint, current_app, jsonify, request, send_file, url_for
from firebase_admin import firestore as firebase_firestore
from google.api_core import exceptions as google_exceptions
from werkzeug.utils import secure_filename
import logging
import re
import mimetypes

from ..ai.gemini import GeminiAPIError, generate_reply, generate_chat_title
from ..firebase import get_firestore_client

chats_bp = Blueprint("chats", __name__, url_prefix="/chats")
log = logging.getLogger(__name__)


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
        "fileIds": data.get("fileIds", []),
    }


def _serialize_file(chat_id: str, doc_id: str, data: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": doc_id,
        "fileName": data.get("fileName"),
        "mimeType": data.get("mimeType"),
        "size": data.get("size"),
        "createdAt": _to_iso(data.get("createdAt")),
        "downloadPath": url_for("chats.download_file", chat_id=chat_id, file_id=doc_id, _external=False),
        "textPreview": data.get("textPreview"),
    }


def _get_upload_root() -> Path:
    upload_dir = current_app.config.get("UPLOADS_DIR")
    if not upload_dir:
        raise RuntimeError("UPLOADS_DIR is not configured for the application.")
    root = Path(upload_dir).resolve()
    root.mkdir(parents=True, exist_ok=True)
    return root


def _resolve_storage_path(relative_path: str) -> Path:
    root = _get_upload_root()
    candidate = (root / relative_path).resolve()
    if not str(candidate).startswith(str(root)):
        raise RuntimeError("Resolved file path is outside the uploads directory.")
    return candidate


def _extract_text_snippet(file_path: Path, mime_type: str | None, limit: int = 4000) -> str | None:
    mime = mime_type or mimetypes.guess_type(file_path.name)[0]
    if mime is None:
        return None

    textual_mimes = {
        "text/plain",
        "text/markdown",
        "text/csv",
        "text/html",
        "text/xml",
        "application/json",
        "application/xml",
        "application/yaml",
        "application/x-yaml",
    }

    if not (mime.startswith("text/") or mime in textual_mimes):
        return None

    try:
        with file_path.open("r", encoding="utf-8", errors="ignore") as fp:
            snippet = fp.read(limit + 1)
    except OSError:
        return None

    if len(snippet) > limit:
        snippet = snippet[:limit]

    return snippet.strip() or None


def _get_files_metadata(chat_ref, file_ids: Iterable[str]) -> dict[str, dict[str, Any]]:
    files_data: dict[str, dict[str, Any]] = {}
    files_collection = chat_ref.collection("files")
    for file_id in file_ids:
        if not file_id or file_id in files_data:
            continue
        try:
            snapshot = files_collection.document(file_id).get()
        except google_exceptions.PermissionDenied as exc:
            raise FirestoreAccessError(exc)
        except google_exceptions.GoogleAPICallError as exc:
            raise FirestoreAccessError(exc)
        if snapshot.exists:
            files_data[file_id] = snapshot.to_dict() or {}
    return files_data


def _compose_message_content(base_content: str, file_ids: Iterable[str], files_data: dict[str, dict[str, Any]]) -> str:
    content = base_content or ""
    attachment_blocks: list[str] = []
    for file_id in file_ids or []:
        file_info = files_data.get(file_id)
        if not file_info:
            continue
        file_name = file_info.get("fileName") or "Unnamed file"
        mime_type = file_info.get("mimeType") or "unknown type"
        size = file_info.get("size")
        size_text = f"{size} bytes" if isinstance(size, int) else "unknown size"
        header = f"[Attached file: {file_name} ({mime_type}, {size_text})]"
        preview = file_info.get("textPreview")
        if preview:
            block = f"{header}\n{preview}"
        else:
            block = header
        attachment_blocks.append(block)

    if attachment_blocks:
        attachments_text = "\n\n".join(attachment_blocks)
        if content:
            content = f"{content}\n\n{attachments_text}"
        else:
            content = attachments_text

    return content


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

    file_ids: set[str] = set()
    raw_messages: list[dict[str, Any]] = []
    for doc in message_docs:
        data = doc.to_dict() or {}
        raw_messages.append({"id": doc.id, "data": data})
        for fid in data.get("fileIds", []) or []:
            if isinstance(fid, str) and fid:
                file_ids.add(fid)

    files_data: dict[str, dict[str, Any]] = {}
    if file_ids:
        try:
            files_data = _get_files_metadata(chat_ref, file_ids)
        except FirestoreAccessError as exc:
            return _firestore_error_response(exc)

    messages = []
    for item in raw_messages:
        data = item["data"]
        enriched_content = _compose_message_content(data.get("content", ""), data.get("fileIds", []), files_data)
        enriched = dict(data)
        enriched["content"] = enriched_content
        messages.append(_serialize_message(item["id"], enriched))

    files_ref = chat_ref.collection("files").order_by("createdAt")
    try:
        file_docs = list(files_ref.stream())
    except google_exceptions.PermissionDenied as exc:
        return _firestore_error_response(exc)
    except google_exceptions.GoogleAPICallError as exc:
        return _firestore_error_response(exc)

    files = [
        _serialize_file(chat_ref.id, doc.id, doc.to_dict() or {})
        for doc in file_docs
    ]

    return (
        jsonify(
            {
                "chat": _serialize_chat(chat_ref.id, chat_data),
                "messages": messages,
                "files": files,
            }
        ),
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


@chats_bp.post("/<chat_id>/files")
def upload_file(chat_id: str) -> tuple[Any, int]:
    if request.content_type and "multipart/form-data" not in request.content_type:
        return (
            jsonify({"error": "validation_error", "message": "Request must be multipart/form-data."}),
            HTTPStatus.BAD_REQUEST,
        )

    uid = request.form.get("uid", type=str, default="").strip()
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

    file = request.files.get("file")
    if file is None or not file.filename:
        return (
            jsonify({"error": "validation_error", "message": "file is required."}),
            HTTPStatus.BAD_REQUEST,
        )

    max_size = int(current_app.config.get("MAX_UPLOAD_SIZE", 10 * 1024 * 1024))
    content_length = request.content_length
    if content_length and content_length > max_size:
        return (
            jsonify({"error": "validation_error", "message": "File exceeds maximum allowed size."}),
            HTTPStatus.BAD_REQUEST,
        )

    filename = secure_filename(file.filename)
    if not filename:
        filename = "upload"

    upload_root = _get_upload_root()
    chat_dir = upload_root / chat_ref.id
    chat_dir.mkdir(parents=True, exist_ok=True)

    file_id = uuid4().hex
    stored_filename = f"{file_id}_{filename}"
    destination = chat_dir / stored_filename

    try:
        file.save(destination)
    except Exception as exc:
        if destination.exists():
            destination.unlink(missing_ok=True)
        return (
            jsonify({"error": "upload_failed", "message": "Unable to store file.", "detail": str(exc)}),
            HTTPStatus.INTERNAL_SERVER_ERROR,
        )

    try:
        size = destination.stat().st_size
    except OSError:
        size = 0

    if size == 0:
        destination.unlink(missing_ok=True)
        return (
            jsonify({"error": "validation_error", "message": "Uploaded file is empty."}),
            HTTPStatus.BAD_REQUEST,
        )

    if size > max_size:
        destination.unlink(missing_ok=True)
        return (
            jsonify({"error": "validation_error", "message": "File exceeds maximum allowed size."}),
            HTTPStatus.BAD_REQUEST,
        )

    mime_type = file.mimetype or mimetypes.guess_type(filename)[0] or "application/octet-stream"

    storage_path = str(destination.relative_to(upload_root))
    text_preview = _extract_text_snippet(destination, mime_type)
    now = _now()

    file_data = {
        "uid": uid,
        "fileName": filename,
        "mimeType": mime_type,
        "size": size,
        "storagePath": storage_path,
        "createdAt": now,
        "textPreview": text_preview,
    }

    file_ref = chat_ref.collection("files").document(file_id)
    try:
        file_ref.set(file_data)
        chat_ref.update({"updatedAt": now})
    except google_exceptions.PermissionDenied as exc:
        destination.unlink(missing_ok=True)
        return _firestore_error_response(exc)
    except google_exceptions.GoogleAPICallError as exc:
        destination.unlink(missing_ok=True)
        return _firestore_error_response(exc)

    serialized = _serialize_file(chat_ref.id, file_ref.id, file_data)
    return jsonify({"file": serialized}), HTTPStatus.CREATED


@chats_bp.get("/<chat_id>/files")
def list_files(chat_id: str) -> tuple[Any, int]:
    uid = request.args.get("uid", type=str)
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

    files_ref = chat_ref.collection("files").order_by("createdAt")
    try:
        file_docs = list(files_ref.stream())
    except google_exceptions.PermissionDenied as exc:
        return _firestore_error_response(exc)
    except google_exceptions.GoogleAPICallError as exc:
        return _firestore_error_response(exc)

    files = [
        _serialize_file(chat_ref.id, doc.id, doc.to_dict() or {})
        for doc in file_docs
    ]

    return jsonify({"items": files}), HTTPStatus.OK


@chats_bp.get("/<chat_id>/files/<file_id>/download")
def download_file(chat_id: str, file_id: str):
    uid = request.args.get("uid", type=str)
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

    files_collection = chat_ref.collection("files")
    try:
        snapshot = files_collection.document(file_id).get()
    except google_exceptions.PermissionDenied as exc:
        return _firestore_error_response(exc)
    except google_exceptions.GoogleAPICallError as exc:
        return _firestore_error_response(exc)

    if not snapshot.exists:
        return (
            jsonify({"error": "not_found", "message": "File not found."}),
            HTTPStatus.NOT_FOUND,
        )

    data = snapshot.to_dict() or {}
    storage_path = data.get("storagePath")
    if not storage_path:
        return (
            jsonify({"error": "not_found", "message": "File metadata incomplete."}),
            HTTPStatus.NOT_FOUND,
        )

    try:
        absolute_path = _resolve_storage_path(storage_path)
    except RuntimeError:
        return (
            jsonify({"error": "not_found", "message": "File not available."}),
            HTTPStatus.NOT_FOUND,
        )

    if not absolute_path.exists():
        return (
            jsonify({"error": "not_found", "message": "File not available."}),
            HTTPStatus.NOT_FOUND,
        )

    download_name = data.get("fileName") or absolute_path.name
    return send_file(
        absolute_path,
        mimetype=data.get("mimeType") or mimetypes.guess_type(download_name)[0],
        as_attachment=True,
        download_name=download_name,
        conditional=True,
    )


@chats_bp.post("/<chat_id>/messages")
def add_message(chat_id: str) -> tuple[Any, int]:
    payload = _parse_json_body()

    uid: str | None = payload.get("uid")
    content: str = (payload.get("content") or "").strip()
    role: str = (payload.get("role") or "user").lower()
    raw_file_ids = payload.get("fileIds") or []

    if isinstance(raw_file_ids, list):
        file_ids = []
        for fid in raw_file_ids:
            if not isinstance(fid, str):
                return (
                    jsonify({"error": "validation_error", "message": "fileIds must be a list of strings."}),
                    HTTPStatus.BAD_REQUEST,
                )
            fid_clean = fid.strip()
            if not fid_clean:
                continue
            if fid_clean not in file_ids:
                file_ids.append(fid_clean)
    elif raw_file_ids:
        return (
            jsonify({"error": "validation_error", "message": "fileIds must be a list."}),
            HTTPStatus.BAD_REQUEST,
        )
    else:
        file_ids = []

    if not uid:
        return (
            jsonify({"error": "validation_error", "message": "uid is required."}),
            HTTPStatus.BAD_REQUEST,
        )
    if not content and not file_ids:
        return (
            jsonify(
                {
                    "error": "validation_error",
                    "message": "content is required when no files are attached.",
                }
            ),
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

    attachments_data: dict[str, dict[str, Any]] = {}
    if file_ids:
        try:
            attachments_data = _get_files_metadata(chat_ref, file_ids)
        except FirestoreAccessError as exc:
            return _firestore_error_response(exc)

        missing = [fid for fid in file_ids if fid not in attachments_data]
        if missing:
            return (
                jsonify(
                    {
                        "error": "validation_error",
                        "message": "One or more files could not be found for this chat.",
                        "missingFileIds": missing,
                    }
                ),
                HTTPStatus.BAD_REQUEST,
            )

        unauthorised = [fid for fid, meta in attachments_data.items() if meta.get("uid") != uid]
        if unauthorised:
            return (
                jsonify(
                    {
                        "error": "forbidden",
                        "message": "You do not have access to one or more attached files.",
                        "fileIds": unauthorised,
                    }
                ),
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
    if file_ids:
        user_message_data["fileIds"] = file_ids

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

    files_cache = dict(attachments_data)

    history_records: list[tuple[str, dict[str, Any]]] = []
    for doc in history_docs:
        data = doc.to_dict() or {}
        history_records.append((doc.id, data))

    additional_file_ids: set[str] = set()
    for _, data in history_records:
        for fid in data.get("fileIds", []) or []:
            if isinstance(fid, str) and fid and fid not in files_cache:
                additional_file_ids.add(fid)

    if additional_file_ids:
        try:
            extra_files = _get_files_metadata(chat_ref, additional_file_ids)
        except FirestoreAccessError as exc:
            return _firestore_error_response(exc)
        files_cache.update(extra_files)

    for _, data in history_records:
        message_content = _compose_message_content(data.get("content", ""), data.get("fileIds", []), files_cache)
        history_messages.append(
            {
                "role": data.get("role", "user"),
                "content": message_content,
            }
        )

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

    chat_title = (chat_data.get("title") or "").strip()
    default_titles = {"", "new chat"}
    should_update_title = chat_title.lower() in default_titles or chat_title == content
    updated_title: str | None = None

    if should_update_title:
        user_prompt_for_title = user_message_data.get("content", "") or history_messages[-1].get("content", "")
        try:
            updated_title = generate_chat_title(
                user_message=user_prompt_for_title,
                assistant_message=ai_reply,
                api_key=gemini_api_key,
            )
        except GeminiAPIError as exc:
            log.warning("Unable to generate chat title: %s", exc)

    if updated_title:
        try:
            chat_ref.update({
                "title": updated_title,
                "updatedAt": ai_message_data["createdAt"],
            })
            chat_data["title"] = updated_title
        except google_exceptions.PermissionDenied as exc:
            log.warning("Failed to persist chat title: %s", exc)
        except google_exceptions.GoogleAPICallError as exc:
            log.warning("Failed to persist chat title: %s", exc)

    return (
        jsonify(
            {
                "userMessage": _serialize_message(user_message_ref.id, user_message_data),
                "assistantMessage": _serialize_message(ai_message_ref.id, ai_message_data),
            }
        ),
        HTTPStatus.CREATED,
    )
