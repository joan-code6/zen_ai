## Zen AI Backend — API Documentation

This document describes the HTTP API provided by the backend in `backend/` (Flask application).

Base URL
- When running locally via `backend/app.py` the default base URL is: http://localhost:5000
- The app reads `PORT` from configuration; the default is `5000`.

Configuration / environment variables
- `FIREBASE_CREDENTIALS_PATH` (required) — path to Firebase service account JSON used to initialize admin SDK.
- `FIREBASE_WEB_API_KEY` — Firebase Web API key used for email/password sign-in (used by `/auth/login`).
- `GEMINI_API_KEY` — API key for the Gemini (genai) model used by the AI endpoints.
- `FIRESTORE_DATABASE_ID` (optional) — if you use a named Firestore database, set this.

Common response shape for errors

```
{
  "error": "error_code",
  "message": "Human readable message",
  ... optional extra fields ...
}
```

HTTP status code highlights
- 200 OK — successful GET/POST/patch when returning data
- 201 Created — resource created (e.g., chat created, messages created)
- 204 No Content — successful deletion
- 400 Bad Request — validation errors / missing params
- 401 / 403 / 404 — auth/permission/not found
- 503 Service Unavailable — missing configuration or downstream service unavailable

-------------------------------------------------------------------------------

## Health

GET /health
- Description: Basic health check for the app.
- Request: none
- Response 200:

```json
{ "status": "ok" }
```

-------------------------------------------------------------------------------

## Authentication

All auth endpoints are mounted under the `/auth` prefix.

### POST /auth/signup
- Description: Create a new Firebase user (server-side using the admin SDK).
- Request JSON body:

```json
{
  "email": "user@example.com",
  "password": "s3cret",
  "displayName": "Optional Display Name"
}
```

- Required fields: `email`, `password`.
- Success 201 response body (example):

```json
{
  "uid": "firebase-uid",
  "email": "user@example.com",
  "displayName": "Optional Display Name",
  "emailVerified": false
}
```

- Error cases:
  - 400 validation_error — missing required fields
  - 409 email_in_use — email already registered
  - 500 firebase_error — other Firebase admin SDK error

### POST /auth/login
- Description: Sign in with an email and password using Firebase REST API. This endpoint proxies to
  Google Identity Toolkit and returns tokens (idToken, refreshToken).
- Requires `FIREBASE_WEB_API_KEY` to be set in environment/config.
- Request JSON body:

```json
{
  "email": "user@example.com",
  "password": "s3cret"
}
```

- Success 200 response body (example):

```json
{
  "idToken": "eyJ...",
  "refreshToken": "...",
  "expiresIn": "3600",
  "localId": "firebase-local-id",
  "email": "user@example.com"
}
```

- Error cases:
  - 400 validation_error — missing fields
  - 503 not_configured — FIREBASE_WEB_API_KEY missing
  - 502 network_error — network/requests issue
  - 401 firebase_auth_error — credential invalid / sign-in failed

### POST /auth/verify-token
- Description: Verify a Firebase ID token (server-side). Returns decoded token claims / uid / email.
- Request JSON body:

```json
{ "idToken": "eyJ..." }
```

- Success 200 response body (example):

```json
{
  "uid": "firebase-uid",
  "email": "user@example.com",
  "claims": {}
}
```

- Error cases:
  - 400 validation_error — token missing
  - 401 invalid_token / token_expired — token invalid or expired
  - 500 firebase_error — other Firebase errors

-------------------------------------------------------------------------------

## Chats & Messages API

All chat endpoints are mounted under the `/chats` prefix.

High-level data model (Firestore collections):
- `chats` collection: documents have fields: `uid`, `title`, `systemPrompt`, `createdAt`, `updatedAt`.
- Each chat document contains a subcollection `messages` with documents having fields `uid`, `role`, `content`, `createdAt`.

Notes about authentication/authorization:
- The backend uses Firebase Admin SDK to store and check `uid` values. The endpoints require callers to provide the `uid` of the acting user in the request (either as a query parameter for some GET endpoints or in the JSON body for mutating endpoints). The server checks the `uid` on stored documents and returns `403 Forbidden` if the provided `uid` does not own the resource.

### POST /chats
- Description: Create a new chat entry.
- Request JSON body:

```json
{
  "uid": "firebase-uid",
  "title": "Optional title",
  "systemPrompt": "Optional system prompt text"
}
```

- Required: `uid`.
- Response 201 (example):

```json
{
  "id": "chat-doc-id",
  "uid": "firebase-uid",
  "title": "My chat",
  "systemPrompt": null,
  "createdAt": "2025-09-27T12:34:56.000000+00:00",
  "updatedAt": "2025-09-27T12:34:56.000000+00:00"
}
```

- Errors: 400 validation_error if `uid` is missing; 503 if Firestore or credentials problem (service unavailable).

### GET /chats?uid=<uid>
- Description: List all chats for a user, ordered by most recently updated.
- Query parameters:
  - `uid` (required) — user id to filter chats by.
- Response 200 (example):

```json
{
  "items": [
    { "id": "chat-id-1", "uid": "...", "title": "...", "systemPrompt": "...", "createdAt": "...", "updatedAt": "..." },
    ...
  ]
}
```

- Errors: 400 validation_error if `uid` missing.

### GET /chats/<chat_id>?uid=<uid>
- Description: Get chat metadata and all messages for a specific chat.
- Path parameter: `chat_id` — chat document id.
- Query parameter: `uid` (required) — the requesting user's uid; used to validate ownership.
- Success 200 response body (example):

```json
{
  "chat": { "id": "chat-id", "uid": "...", "title": "...", "systemPrompt": "...", "createdAt": "...", "updatedAt": "..." },
  "messages": [ { "id": "msg-id", "role": "user|assistant|system", "content": "...", "createdAt": "..." }, ... ]
}
```

- Errors:
  - 400 validation_error if `uid` missing
  - 404 not_found if chat id doesn't exist
  - 403 forbidden if chat exists but `uid` does not match owner

### PATCH /chats/<chat_id>
- Description: Update chat metadata (`title` and/or `systemPrompt`).
- Path parameter: `chat_id` — chat document id.
- Request JSON body:

```json
{
  "uid": "firebase-uid",            // required, used for ownership check
  "title": "New title",            // optional
  "systemPrompt": "New prompt"     // optional
}
```

- If no updatable fields are present the server returns 400 Nothing to update.
- Success 200 returns the updated chat object (same shape as create/list entries).
- Errors: 400 validation_error, 403 forbidden, 404 not_found, 503 firestore_service_unavailable (on Firestore errors).

### DELETE /chats/<chat_id>
- Description: Delete a chat and its messages.
- Path parameter: `chat_id`.
- Request JSON body:

```json
{ "uid": "firebase-uid" }
```

- Success: 204 No Content.
- Errors: 400 validation_error if `uid` missing, 403 forbidden if not owner, 404 not_found if no chat, 503 on Firestore errors.

### POST /chats/<chat_id>/messages
- Description: Add a message to a chat. If a GEMINI_API_KEY is configured, the backend will send the message history (including optional system prompt) to Gemini and store an assistant reply.
- Path parameter: `chat_id`.
- Request JSON body:

```json
{
  "uid": "firebase-uid",          // required
  "content": "Hello, how are you?", // required
  "role": "user"                  // optional, defaults to "user"; allowed: "user", "system"
}
```

- Behavior:
  1. Validates the `uid` and `content`.
  2. Stores the user message in the chat's `messages` subcollection and updates chat.updatedAt.
  3. If `GEMINI_API_KEY` is not configured, returns 503 not_configured and includes the stored `userMessage` in the response.
  4. If `GEMINI_API_KEY` is configured, the backend reads the full message history (and optional systemPrompt), calls the Gemini model via the `genai` client, stores an assistant message with the model reply, and returns both `userMessage` and `assistantMessage`.

- Success 201 response body (when Gemini is configured):

```json
{
  "userMessage": { "id": "user-msg-id", "role": "user", "content": "...", "createdAt": "..." },
  "assistantMessage": { "id": "assistant-msg-id", "role": "assistant", "content": "...", "createdAt": "..." }
}
```

- If Gemini call fails: 502 ai_error with `userMessage` included.

-------------------------------------------------------------------------------

Developer examples (PowerShell / curl)

Create a chat (POST /chats):

```powershell
$body = @{
  uid = "USER_UID"
  title = "My first chat"
} | ConvertTo-Json

curl -Method Post -Uri http://localhost:5000/chats -ContentType 'application/json' -Body $body
```

Add a message (POST /chats/<chat_id>/messages):

```powershell
$body = @{
  uid = "USER_UID"
  content = "Hello"
  role = "user"
} | ConvertTo-Json

curl -Method Post -Uri http://localhost:5000/chats/CHAT_ID/messages -ContentType 'application/json' -Body $body
```

Notes & Troubleshooting
- If you see `firestore_service_unavailable` errors, check that the service account in `FIREBASE_CREDENTIALS_PATH` has the correct permissions and that the Firestore API is enabled for the project. If you have a named Firestore database, set `FIRESTORE_DATABASE_ID`.
- If `/chats/*/messages` returns `not_configured`, set `GEMINI_API_KEY` to enable AI replies.
- To diagnose Firebase sign-in errors for `/auth/login`, ensure `FIREBASE_WEB_API_KEY` matches your Firebase project's Web API key.

-------------------------------------------------------------------------------

Contact / next steps
- This file is intentionally concise. If you'd like we can:
  - Add full example requests/responses for each endpoint (curl, HTTPie, JavaScript/fetch),
  - Add an OpenAPI / Swagger spec generated from these endpoints,
  - Add automated smoke tests that exercise each endpoint (unit/integration tests).

---

Generated from the backend source: `backend/app.py`, `backend/zen_backend/*` on branch `main`.
