from __future__ import annotations

from pathlib import Path
from typing import Optional
import json
import os
import logging

import firebase_admin
from firebase_admin import credentials, firestore
from google.cloud import firestore as gcloud_firestore

log = logging.getLogger(__name__)

firebase_app: Optional[firebase_admin.App] = None
_firestore_client: Optional[firestore.Client] = None
_firestore_database_id: Optional[str] = None
_firestore_project_id: Optional[str] = None


def init_firebase(credentials_path: Path, database_id: Optional[str] = None) -> firebase_admin.App:
    global firebase_app, _firestore_client, _firestore_database_id, _firestore_project_id

    if firebase_app is not None:
        # Update the cached database selection if provided after the initial call.
        if database_id:
            _firestore_database_id = database_id
            _firestore_client = None
        return firebase_app

    # Try to read the service account JSON to detect project_id. Allow an env override.
    project_id: Optional[str] = None
    try:
        with open(credentials_path, "r", encoding="utf-8") as fh:
            cred_json = json.load(fh)
            project_id = cred_json.get("project_id")
    except Exception:
        # If the credentials file can't be read or parsed, fall back to normal behavior
        project_id = None

    # Environment variable can override the project selection (useful for local testing)
    env_project = os.getenv("FIREBASE_PROJECT_ID")
    if env_project:
        project_id = env_project

    if not database_id:
        env_database = os.getenv("FIRESTORE_DATABASE_ID")
        if env_database:
            database_id = env_database.strip() or None

    if not firebase_admin._apps:
        cred = credentials.Certificate(str(credentials_path))
        init_options = {"projectId": project_id} if project_id else None
        firebase_app = firebase_admin.initialize_app(cred, options=init_options)
        if project_id:
            log.info("Initialized Firebase app for project '%s'", project_id)
        else:
            log.info("Initialized Firebase app (project_id not detected from credentials)")
    else:
        firebase_app = firebase_admin.get_app()

    _firestore_database_id = database_id
    _firestore_project_id = project_id or getattr(firebase_app, "project_id", None)
    if _firestore_database_id:
        log.info("Configured Firestore database '%s'", _firestore_database_id)
    else:
        log.info("Using default Firestore database")

    return firebase_app


def get_firestore_client() -> firestore.Client:
    global _firestore_client

    if firebase_app is None:
        raise RuntimeError("Firebase app has not been initialised. Call init_firebase() first.")

    if _firestore_client is None:
        if _firestore_database_id and _firestore_database_id not in {"(default)", "default", ""}:
            project_id = _firestore_project_id or getattr(firebase_app, "project_id", None)
            if not project_id:
                raise RuntimeError("Unable to determine Firebase project ID for Firestore client.")

            credentials_obj = firebase_app.credential.get_credential()
            _firestore_client = gcloud_firestore.Client(
                project=project_id,
                credentials=credentials_obj,
                database=_firestore_database_id,
            )
            log.debug(
                "Created Firestore client for project '%s' and database '%s'",
                project_id,
                _firestore_database_id,
            )
        else:
            _firestore_client = firestore.client(app=firebase_app)

    return _firestore_client
