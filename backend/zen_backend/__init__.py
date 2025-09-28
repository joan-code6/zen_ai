from __future__ import annotations

from flask import Flask
from flask_cors import CORS

from .config import AppConfig, ConfigError, load_config
from .firebase import init_firebase
from .auth.routes import auth_bp
from .chats.routes import chats_bp


def create_app(config: AppConfig | None = None) -> Flask:
    """Application factory for the Zen backend."""
    if config is None:
        try:
            config = load_config()
        except ConfigError as exc:
            raise RuntimeError(f"Configuration error: {exc}") from exc

    app = Flask(__name__)

    app.config.update(
        PORT=config.port,
        FIREBASE_CREDENTIALS_PATH=str(config.firebase_credentials_path),
        FIREBASE_WEB_API_KEY=config.firebase_web_api_key,
        GEMINI_API_KEY=config.gemini_api_key,
        FIRESTORE_DATABASE_ID=config.firestore_database_id,
        UPLOADS_DIR=str(config.uploads_dir),
        MAX_UPLOAD_SIZE=10 * 1024 * 1024,
        MAX_INLINE_ATTACHMENT_BYTES=config.max_inline_attachment_bytes,
    )

    CORS(app)

    init_firebase(config.firebase_credentials_path, database_id=config.firestore_database_id)

    app.register_blueprint(auth_bp)
    app.register_blueprint(chats_bp)

    @app.get("/health")
    def health_check() -> dict[str, str]:
        return {"status": "ok"}

    return app
