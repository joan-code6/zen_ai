"""Gemini client stub.

Replace the implementation with real API calls to Google Gemini when ready.
"""

import os


def send_prompt(prompt: str) -> str:
    """Send a prompt to Gemini (stub) and return a reply.

    For now this returns a canned response. Configure GEMINI_API_KEY in the
    environment and implement a real client when ready.
    """
    if not prompt:
        return 'No prompt provided.'
    # TODO: implement real Gemini API call here
    return f'[gemini-stub] Echo: {prompt}'
