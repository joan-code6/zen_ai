from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

from dotenv import load_dotenv


class ConfigError(Exception):
    """Raised when required configuration is missing or invalid."""


@dataclass(slots=True)
class AppConfig:
    port: int
    firebase_credentials_path: Path
    firebase_web_api_key: Optional[str]
    gemini_api_key: Optional[str]
    firestore_database_id: Optional[str] = None


def _resolve_path(path_str: str, base_dir: Path) -> Path:
    candidate = Path(path_str.strip()).expanduser()
    if candidate.is_absolute():
        return candidate

    for root in (base_dir, base_dir.parent):
        resolved = (root / candidate).resolve()
        if resolved.exists():
            return resolved

    # Fallback: return path relative to base dir even if it doesn't exist yet.
    return (base_dir / candidate).resolve()


def load_config() -> AppConfig:
    """Load configuration from environment variables/.env file."""
    backend_dir = Path(__file__).resolve().parent.parent
    dotenv_path = backend_dir / ".env"
    load_dotenv(dotenv_path)

    port_raw = os.getenv("PORT", "5000")
    try:
        port = int(port_raw)
    except ValueError as exc:
        raise ConfigError(f"PORT must be an integer, got '{port_raw}'") from exc

    credentials_path_raw = os.getenv("FIREBASE_CREDENTIALS_PATH")
    if not credentials_path_raw:
        raise ConfigError("FIREBASE_CREDENTIALS_PATH is required")

    credentials_path = _resolve_path(credentials_path_raw, backend_dir)
    if not credentials_path.exists():
        raise ConfigError(
            "Firebase credentials file not found at resolved path: "
            f"{credentials_path}"
        )

    firebase_web_api_key = os.getenv("FIREBASE_WEB_API_KEY")
    gemini_api_key = os.getenv("GEMINI_API_KEY")
    firestore_database_id = os.getenv("FIRESTORE_DATABASE_ID")

    return AppConfig(
        port=port,
        firebase_credentials_path=credentials_path,
        firebase_web_api_key=firebase_web_api_key,
        gemini_api_key=gemini_api_key,
        firestore_database_id=firestore_database_id,
    )
