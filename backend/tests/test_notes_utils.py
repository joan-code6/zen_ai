import sys
import unittest
from datetime import datetime, timezone

sys.path.insert(0, r"c:\Users\benne\Documents\projects\zen_ai\backend")

from zen_backend.notes.utils import (  # noqa: E402
    DEFAULT_CONTEXT_CONTENT_LIMIT,
    extract_trigger_candidates,
    format_note_for_context,
    normalize_string_list,
)


class NormalizeStringListTests(unittest.TestCase):
    def test_deduplicates_and_trims_values(self):
        values = ["  Foo  ", "foo", "BAR", None, 42]
        self.assertEqual(normalize_string_list(values), ["Foo", "BAR", "42"])

    def test_lowercase_mode_preserves_order(self):
        values = ["Alpha", "alpha", "Beta", "gamma"]
        self.assertEqual(normalize_string_list(values, lowercase=True), ["alpha", "beta", "gamma"])


class ExtractTriggerCandidatesTests(unittest.TestCase):
    def test_extracts_unique_tokens(self):
        text = "Project X update! Remember focus-mode -- go go go!"
        self.assertEqual(
            extract_trigger_candidates(text, max_terms=6, min_length=1),
            ["project", "x", "update", "remember", "focus-mode", "go"],
        )

    def test_respects_min_length(self):
        text = "a b cd ef"
        self.assertEqual(
            extract_trigger_candidates(text, min_length=2),
            ["cd", "ef"],
        )


class FormatNoteForContextTests(unittest.TestCase):
    def test_formats_note_with_metadata(self):
        timestamp = datetime(2025, 9, 28, 12, 30, tzinfo=timezone.utc)
        note = {
            "title": "Weekly plan",
            "content": "Remember to prepare slides for Monday meeting.",
            "keywords": ["planning"],
            "triggerWords": ["project alpha"],
            "updatedAt": timestamp,
        }
        block = format_note_for_context(note)
        self.assertIn("Stored note: Weekly plan", block)
        self.assertIn("Body: Remember to prepare slides for Monday meeting.", block)
        self.assertIn("Keywords: planning", block)
        self.assertIn("Trigger words: project alpha", block)
        self.assertIn("2025-09-28T12:30:00+00:00", block)

    def test_truncates_long_content(self):
        note = {
            "title": "Long note",
            "content": "x" * (DEFAULT_CONTEXT_CONTENT_LIMIT + 50),
            "keywords": [],
            "triggerWords": [],
        }
        block = format_note_for_context(note, content_limit=40)
        self.assertTrue(block.count("x") <= 41)
        self.assertIn("…", block)


if __name__ == "__main__":
    unittest.main()
