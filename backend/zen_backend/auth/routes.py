from __future__ import annotations

from http import HTTPStatus
from typing import Any

import requests
from flask import Blueprint, current_app, jsonify, request
from firebase_admin import auth as firebase_auth
from firebase_admin import exceptions as firebase_exceptions

auth_bp = Blueprint("auth", __name__, url_prefix="/auth")


def _parse_json_body() -> dict[str, Any]:
    if request.is_json:
        payload = request.get_json(silent=True) or {}
    else:
        payload = {}
    return payload


@auth_bp.post("/signup")
def signup() -> tuple[Any, int]:
    payload = _parse_json_body()

    email: str | None = payload.get("email")
    password: str | None = payload.get("password")
    display_name: str | None = payload.get("displayName")

    missing_fields = [field for field in ("email", "password") if not payload.get(field)]
    if missing_fields:
        return (
            jsonify({
                "error": "validation_error",
                "message": f"Missing required fields: {', '.join(missing_fields)}",
            }),
            HTTPStatus.BAD_REQUEST,
        )

    try:
        user_record = firebase_auth.create_user(
            email=email,
            password=password,
            display_name=display_name,
        )
    except firebase_exceptions.AlreadyExistsError:
        return (
            jsonify({"error": "email_in_use", "message": "Email already registered."}),
            HTTPStatus.CONFLICT,
        )
    except firebase_exceptions.FirebaseError as exc:
        return (
            jsonify({"error": "firebase_error", "message": str(exc)}),
            HTTPStatus.INTERNAL_SERVER_ERROR,
        )

    return (
        jsonify(
            {
                "uid": user_record.uid,
                "email": user_record.email,
                "displayName": user_record.display_name,
                "emailVerified": user_record.email_verified,
            }
        ),
        HTTPStatus.CREATED,
    )


@auth_bp.post("/login")
def login() -> tuple[Any, int]:
    payload = _parse_json_body()

    email: str | None = payload.get("email")
    password: str | None = payload.get("password")

    missing_fields = [field for field in ("email", "password") if not payload.get(field)]
    if missing_fields:
        return (
            jsonify({
                "error": "validation_error",
                "message": f"Missing required fields: {', '.join(missing_fields)}",
            }),
            HTTPStatus.BAD_REQUEST,
        )

    api_key = current_app.config.get("FIREBASE_WEB_API_KEY")
    if not api_key:
        return (
            jsonify({
                "error": "not_configured",
                "message": "FIREBASE_WEB_API_KEY is not set. Add it to backend/.env.",
            }),
            HTTPStatus.SERVICE_UNAVAILABLE,
        )

    try:
        response = requests.post(
            "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword",
            params={"key": api_key},
            json={
                "email": email,
                "password": password,
                "returnSecureToken": True,
            },
            timeout=10,
        )
    except requests.RequestException as exc:
        return (
            jsonify({"error": "network_error", "message": str(exc)}),
            HTTPStatus.BAD_GATEWAY,
        )

    if not response.ok:
        error_message = response.json().get("error", {}).get("message", "Login failed.")
        return (
            jsonify({"error": "firebase_auth_error", "message": error_message}),
            HTTPStatus.UNAUTHORIZED,
        )

    data = response.json()
    return (
        jsonify(
            {
                "idToken": data.get("idToken"),
                "refreshToken": data.get("refreshToken"),
                "expiresIn": data.get("expiresIn"),
                "localId": data.get("localId"),
                "email": data.get("email"),
            }
        ),
        HTTPStatus.OK,
    )


@auth_bp.post("/verify-token")
def verify_token() -> tuple[Any, int]:
    payload = _parse_json_body()
    id_token: str | None = payload.get("idToken")

    if not id_token:
        return (
            jsonify({"error": "validation_error", "message": "idToken is required."}),
            HTTPStatus.BAD_REQUEST,
        )

    try:
        decoded_token = firebase_auth.verify_id_token(id_token)
    except firebase_exceptions.InvalidArgumentError:
        return (
            jsonify({"error": "invalid_token", "message": "Token format is invalid."}),
            HTTPStatus.UNAUTHORIZED,
        )
    except firebase_exceptions.ExpiredIdTokenError:
        return (
            jsonify({"error": "token_expired", "message": "Token has expired."}),
            HTTPStatus.UNAUTHORIZED,
        )
    except firebase_exceptions.FirebaseError as exc:
        return (
            jsonify({"error": "firebase_error", "message": str(exc)}),
            HTTPStatus.INTERNAL_SERVER_ERROR,
        )

    return (
        jsonify(
            {
                "uid": decoded_token.get("uid"),
                "email": decoded_token.get("email"),
                "claims": decoded_token.get("claims", {}),
            }
        ),
        HTTPStatus.OK,
    )
