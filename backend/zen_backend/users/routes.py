from __future__ import annotations

from http import HTTPStatus
from typing import Any
import logging

from flask import Blueprint, jsonify, request
from firebase_admin import auth as firebase_auth
from firebase_admin import exceptions as firebase_exceptions

from .service import (
    UserProfileStoreError,
    get_user_profile,
    serialize_user_profile,
    upsert_user_profile,
)

users_bp = Blueprint("users", __name__, url_prefix="/users")
log = logging.getLogger(__name__)


def _parse_json_body() -> dict[str, Any]:
    if request.is_json:
        return request.get_json(silent=True) or {}
    return {}


def _profile_error_response(detail: str, *, status: HTTPStatus = HTTPStatus.SERVICE_UNAVAILABLE):
    return (
        jsonify({
            "error": "profile_store_error",
            "message": "Unable to persist user profile information.",
            "detail": detail,
        }),
        status,
    )


@users_bp.get("/<uid>")
def get_profile(uid: str) -> tuple[Any, int]:
    try:
        profile = get_user_profile(uid)
    except UserProfileStoreError as exc:
        log.exception("Failed to fetch profile for %s", uid)
        return _profile_error_response(str(exc))

    if profile is None:
        return (
            jsonify({"error": "not_found", "message": "User profile not found."}),
            HTTPStatus.NOT_FOUND,
        )

    return jsonify(serialize_user_profile(profile)), HTTPStatus.OK


@users_bp.patch("/<uid>")
def update_profile(uid: str) -> tuple[Any, int]:
    payload = _parse_json_body()
    display_name = payload.get("displayName")
    photo_url = payload.get("photoUrl")

    if display_name is None and photo_url is None:
        return (
            jsonify({
                "error": "validation_error",
                "message": "Provide at least one field to update (displayName or photoUrl).",
            }),
            HTTPStatus.BAD_REQUEST,
        )

    update_kwargs: dict[str, Any] = {}
    if display_name is not None:
        update_kwargs["display_name"] = display_name
    if photo_url is not None:
        update_kwargs["photo_url"] = photo_url

    try:
        firebase_auth.update_user(uid, **update_kwargs)
    except firebase_exceptions.FirebaseError as exc:
        log.exception("Failed to update Firebase auth profile for %s", uid)
        return (
            jsonify({"error": "firebase_error", "message": str(exc)}),
            HTTPStatus.BAD_GATEWAY,
        )

    try:
        profile = upsert_user_profile(
            uid,
            display_name=display_name,
            photo_url=photo_url,
        )
    except UserProfileStoreError as exc:
        log.exception("Failed to update stored profile for %s", uid)
        return _profile_error_response(str(exc))

    return jsonify(serialize_user_profile(profile)), HTTPStatus.OK
