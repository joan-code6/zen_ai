import json
from types import SimpleNamespace

from zen_backend.chats.routes import _extract_text_from_event, _sse_message


def test_sse_message_format():
    payload = {"type": "token", "text": "hello"}
    result = _sse_message(payload, event="token")
    assert result.endswith("\n\n")
    lines = result.strip().splitlines()
    assert lines[0] == "event: token"
    assert lines[1].startswith("data: ")
    encoded = lines[1][6:]
    assert json.loads(encoded) == payload


def test_extract_text_prefers_text_attribute():
    event = SimpleNamespace(text="chunk")
    assert _extract_text_from_event(event) == "chunk"


def test_extract_text_falls_back_to_delta():
    event = SimpleNamespace(text=None, delta={"text": "delta"}, candidates=None)
    assert _extract_text_from_event(event) == "delta"


def test_extract_text_handles_candidate_parts():
    part = SimpleNamespace(text="piece")
    content = SimpleNamespace(parts=[part])
    candidate = SimpleNamespace(content=content)
    event = SimpleNamespace(text=None, delta=None, candidates=[candidate])
    assert _extract_text_from_event(event) == "piece"
