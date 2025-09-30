from types import SimpleNamespace

import pytest

from zen_backend.ai import gemini


class _DummyStream:
    def __iter__(self):
        yield SimpleNamespace(text="chunk")


class _FakeFiles:
    def upload(self, *args, **kwargs):
        raise AssertionError("upload should not be called in this test")


def _simple_messages():
    return [{"role": "user", "content": "Hello"}]


def test_stream_reply_uses_generate_content_stream(monkeypatch):
    class FakeModels:
        def __init__(self):
            self.attempt = 0

        def generate_content_stream(self, *, model, contents, **kwargs):
            self.attempt += 1
            if "request_options" in kwargs and self.attempt == 1:
                raise TypeError("unexpected request_options")
            return _DummyStream()

    fake_client = SimpleNamespace(models=FakeModels(), files=_FakeFiles())

    gemini._client_cache["stream_key"] = fake_client
    try:
        stream = gemini.stream_reply(_simple_messages(), api_key="stream_key")
    finally:
        gemini._client_cache.pop("stream_key", None)

    assert isinstance(stream, _DummyStream)


def test_stream_reply_falls_back_to_generate_content_stream_flag(monkeypatch):
    class FakeModels:
        def generate_content(self, *, model, contents, stream=False, **kwargs):
            if not stream:
                pytest.fail("stream flag should be True")
            return _DummyStream()

    fake_client = SimpleNamespace(models=FakeModels(), files=_FakeFiles())

    gemini._client_cache["fallback_key"] = fake_client
    try:
        stream = gemini.stream_reply(_simple_messages(), api_key="fallback_key")
    finally:
        gemini._client_cache.pop("fallback_key", None)

    assert isinstance(stream, _DummyStream)
