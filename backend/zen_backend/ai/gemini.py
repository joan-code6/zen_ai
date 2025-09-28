from __future__ import annotations

from typing import Any, Dict, Iterable, Sequence
import logging

from google import genai
from google.genai import types

DEFAULT_MODEL = "gemini-2.0-flash"

_client_cache: Dict[str, genai.Client] = {}

log = logging.getLogger(__name__)


class GeminiAPIError(RuntimeError):
    """Raised when the Gemini API responds with an error."""


def _format_messages(
    messages: Sequence[dict[str, Any]],
    client: genai.Client,
) -> list[types.Content]:
    contents: list[types.Content] = []

    role_map = {
        "user": "user",
        "assistant": "model",
        "model": "model",
        "system": "user",
    }

    for message in messages:
        role = role_map.get(message.get("role", "user"), "user")
        parts: list[Any] = []

        raw_parts = message.get("parts")
        if isinstance(raw_parts, Sequence):
            for part in raw_parts:
                if isinstance(part, types.Part):
                    parts.append(part)
                    continue

                if isinstance(part, str):
                    text_value = part.strip()
                    if text_value:
                        parts.append(types.Part.from_text(text_value))
                    continue

                if not isinstance(part, dict):
                    continue

                kind = part.get("type")

                if kind == "text" or "text" in part:
                    text_value = str(part.get("text", part.get("content", ""))).strip()
                    if text_value:
                        parts.append(types.Part.from_text(text_value))
                elif kind == "bytes" or "data" in part:
                    data = part.get("data")
                    mime_type = part.get("mime_type")
                    if isinstance(data, (bytes, bytearray)) and mime_type:
                        try:
                            parts.append(types.Part.from_bytes(data=bytes(data), mime_type=str(mime_type)))
                        except Exception as exc:
                            log.warning("Failed to attach inline bytes (%s): %s", mime_type, exc)
                elif kind == "upload":
                    file_ref = part.get("file_ref")
                    if file_ref is None:
                        path = part.get("path")
                        mime_type = part.get("mime_type")
                        if not path or not mime_type:
                            continue
                        try:
                            with open(path, "rb") as fh:
                                file_ref = client.files.upload(file=fh, config={"mime_type": mime_type})
                            part["file_ref"] = file_ref
                        except FileNotFoundError:
                            log.warning("Attachment file not found: %s", path)
                            continue
                        except Exception as exc:
                            log.warning("Failed to upload attachment %s: %s", path, exc)
                            continue
                    parts.append(file_ref)
                elif kind == "inline_data" and "inline_data" in part:
                    inline_data = part.get("inline_data") or {}
                    data = inline_data.get("data")
                    mime_type = inline_data.get("mime_type")
                    if isinstance(data, (bytes, bytearray)) and mime_type:
                        try:
                            parts.append(types.Part.from_bytes(data=bytes(data), mime_type=str(mime_type)))
                        except Exception as exc:
                            log.warning("Failed to attach inline data (%s): %s", mime_type, exc)

        text = message.get("content", "")
        if isinstance(text, str):
            text = text.strip()
            if text and not parts:
                parts.append(types.Part.from_text(text))

        if not parts:
            continue

        contents.append(types.Content(role=role, parts=parts))

    return contents


def _get_client(api_key: str) -> genai.Client:
    client = _client_cache.get(api_key)
    if client is None:
        client = genai.Client(api_key=api_key)
        _client_cache[api_key] = client
    return client


def generate_reply(
    messages: Sequence[dict[str, Any]],
    api_key: str,
    model: str = DEFAULT_MODEL,
    safety_settings: Iterable[dict[str, object]] | None = None,
    timeout: int = 30,
) -> str:
    """Call the Gemini API with the provided conversation history."""

    client = _get_client(api_key)

    contents = _format_messages(messages, client)
    if not contents:
        raise GeminiAPIError("At least one message with content is required.")

    if safety_settings:
        # The installed genai SDK's Models.generate_content does not accept
        # a `safety_settings` kwarg in some versions. Ignore it but warn so
        # callers know their safety settings were not applied.
        log.warning(
            "safety_settings were provided to generate_reply but will be ignored by the SDK"
        )

    # Attempt the call in a few ways to support different genai SDK versions:
    # 1) Some versions accept `request_options={"timeout": ...}`.
    # 2) Some accept `timeout` as a top-level kwarg.
    # 3) Some accept neither; fall back to a call without timeout.
    last_exc: Exception | None = None

    try:
        response = client.models.generate_content(
            model=model,
            contents=contents,
            request_options={"timeout": timeout},
        )
    except TypeError as exc:
        last_exc = exc
        # If the SDK doesn't accept request_options, retry with timeout kwarg.
        err_text = str(exc)
        log.debug("generate_content TypeError (first attempt): %s", err_text)
        try:
            response = client.models.generate_content(
                model=model,
                contents=contents,
                timeout=timeout,
            )
        except TypeError as exc2:
            last_exc = exc2
            log.debug("generate_content TypeError (second attempt): %s", str(exc2))
            try:
                # Final attempt: call without any timeout/request options.
                response = client.models.generate_content(
                    model=model,
                    contents=contents,
                )
            except Exception as exc3:
                last_exc = exc3
                raise GeminiAPIError(str(exc3)) from exc3
        except Exception as exc2:
            last_exc = exc2
            raise GeminiAPIError(str(exc2)) from exc2
    except Exception as exc:
        last_exc = exc
        raise GeminiAPIError(str(exc)) from exc

    reply_text = (response.text or "").strip()
    if not reply_text:
        raise GeminiAPIError("Gemini API returned an empty response")

    return reply_text


def generate_chat_title(
    user_message: str,
    assistant_message: str,
    api_key: str,
    model: str = DEFAULT_MODEL,
    timeout: int = 20,
) -> str:
    """Produce a concise chat title based on the opening exchange."""

    instruction = (
        "Create a short, descriptive title for this conversation in six words or fewer. "
        "Always write the title in the same language as the user's message. "
        "Return only the title text without punctuation at the end."
        "Give me short, factual, and clear names for AI chat conversations. The names should act as bullet points and convey the essence of the content. No unnecessary words, no marketing, just a functional description."
    )

    conversation = (
        f"User: {user_message.strip()}\n"
        f"Assistant: {assistant_message.strip()}"
    )

    messages = [
        {"role": "system", "content": instruction},
        {"role": "user", "content": conversation},
    ]

    try:
        title = generate_reply(messages, api_key=api_key, model=model, timeout=timeout)
    except GeminiAPIError as exc:
        raise GeminiAPIError(f"Failed to generate chat title: {exc}") from exc

    clean_title = title.splitlines()[0].strip().strip('.;:')
    if len(clean_title) > 80:
        clean_title = clean_title[:80].rstrip()

    return clean_title or "New chat"
