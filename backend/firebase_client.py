"""Minimal Firebase initializer stub.

This will attempt to initialize the Firebase Admin SDK if a service account
JSON file is pointed to by FIREBASE_CREDENTIALS_PATH in the environment.
If not present, initialization is skipped which is convenient for local
development without credentials.
"""
import os


def initialize_firebase():
    creds = os.environ.get('FIREBASE_CREDENTIALS_PATH')
    if not creds:
        # No credentials provided; skip initialization.
        return None
    # Lazy import to avoid requiring firebase-admin for users who don't need it yet
    try:
        import firebase_admin
        from firebase_admin import credentials, firestore
    except Exception:
        print('firebase-admin not installed; skipping Firebase initialization')
        return None

    try:
        cred = credentials.Certificate(creds)
        firebase_admin.initialize_app(cred)
        db = firestore.client()
        return db
    except Exception as e:
        print(f'Failed to initialize Firebase: {e}')
        return None
