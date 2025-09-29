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
- `UPLOADS_DIR` (optional) — directory where uploaded chat files will be stored. Defaults to `backend/uploads`.
- `MAX_INLINE_ATTACHMENT_BYTES` (optional) — maximum size (bytes) of an attachment that will be sent inline to Gemini (defaults to 350000 bytes).

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
- Each chat document contains a subcollection `messages` with documents having fields `uid`, `role`, `content`, `fileIds`, `createdAt`.
- Each chat document may also contain a subcollection `files` with documents describing uploaded files (`uid`, `fileName`, `mimeType`, `size`, `storagePath`, `textPreview`, `createdAt`).

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
  "messages": [ { "id": "msg-id", "role": "user|assistant|system", "content": "...", "fileIds": ["file-id"], "createdAt": "..." }, ... ],
  "files": [ { "id": "file-id", "fileName": "notes.txt", "mimeType": "text/plain", "size": 1234, "downloadPath": "/chats/chat-id/files/file-id/download", "textPreview": "First lines...", "createdAt": "..." } ]
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
  "uid": "firebase-uid",            // required
  "content": "Hello, how are you?", // optional if files attached
  "role": "user",                   // optional, defaults to "user"; allowed: "user", "system"
  "fileIds": ["file-id-1", "file-id-2"] // optional list of uploaded file ids
}
```

- Behavior:
  1. Validates the `uid`, `content` (unless files are attached), and optional `fileIds`.
  2. Stores the user message in the chat's `messages` subcollection and updates chat.updatedAt.
  3. If `GEMINI_API_KEY` is not configured, returns 503 not_configured and includes the stored `userMessage` in the response.
  4. If `GEMINI_API_KEY` is configured, the backend reads the full message history (including text previews of any referenced files and the optional systemPrompt), attaches supported files inline (currently image formats up to the size limit), calls the Gemini model via the `genai` client, stores an assistant message with the model reply, and returns both `userMessage` and `assistantMessage`.
  5. Replies are generated in the same language as the most recent user message; if the language is ambiguous, the model is instructed to request clarification instead of defaulting to English.
  6. When the first assistant reply is successfully generated, the backend asks Gemini to produce a concise chat title (≤6 words) in the same language as the user's opening message and updates the chat record if the existing title is still the default or matches the user's opening question.

- Success 201 response body (when Gemini is configured):

```json
{
  "userMessage": { "id": "user-msg-id", "role": "user", "content": "...", "fileIds": ["file-id-1"], "createdAt": "..." },
  "assistantMessage": { "id": "assistant-msg-id", "role": "assistant", "content": "...", "createdAt": "..." }
}
```

- If Gemini call fails: 502 ai_error with `userMessage` included.

### File attachments for chats

File handling endpoints let clients upload supporting documents that can be referenced in subsequent chat messages. Uploaded files are stored on disk under `UPLOADS_DIR` and described in a `files` subcollection for each chat. When a message references uploaded files via `fileIds`, the backend includes any stored text preview into the message content and, for supported binary formats (images within the configured size limit), streams the raw data inline to Gemini so the model can interpret the actual file rather than relying on the filename alone.

#### POST /chats/<chat_id>/files
- Description: Upload a file for a chat (multipart/form-data).
- Form fields:
  - `uid` (required) — the owner of the chat.
  - `file` (required) — the file to upload.
- Validation: maximum file size defaults to 10 MB (`MAX_UPLOAD_SIZE` config). Only the chat owner can upload files.
- Success 201 response example:

```json
{
  "file": {
    "id": "file-id",
    "fileName": "notes.txt",
    "mimeType": "text/plain",
    "size": 1234,
    "downloadPath": "/chats/chat-id/files/file-id/download",
    "textPreview": "First lines...",
    "createdAt": "2025-09-27T12:34:56.000000+00:00"
  }
}
```

- Errors: 400 validation_error for missing fields or size limit, 403 forbidden if the user does not own the chat, 404 not_found if the chat does not exist.

#### GET /chats/<chat_id>/files?uid=<uid>
- Description: List all files uploaded for a chat. Response shape matches the `files` array returned by `GET /chats/<chat_id>`.

#### GET /chats/<chat_id>/files/<file_id>/download?uid=<uid>
- Description: Download a previously uploaded file. Returns binary content using the stored filename and MIME type. Only the chat owner can download files.

-------------------------------------------------------------------------------

## Notes API

Notes provide a lightweight memory store per user. All endpoints are mounted under the `/notes` prefix.

High-level data model (Firestore collection):
- `notes` collection: documents include `uid`, `title`, `content`, `keywords`, `triggerWords`, lowercase variants for search, and Firestore timestamps `createdAt`/`updatedAt`.
- Document IDs serve as the stable `id` returned to clients.

All endpoints return note objects in the following shape:

```json
{
  "id": "note-doc-id",
  "uid": "firebase-uid",
  "title": "Project preferences",
  "content": "Full body text",
  "excerpt": "Full body text",
  "keywords": ["project", "preferences"],
  "triggerWords": ["project x"],
  "triggerwords": ["project x"],
  "createdAt": "2025-09-27T12:34:56.000000+00:00",
  "updatedAt": "2025-09-28T08:15:30.000000+00:00"
}
```

### GET /notes?uid=<uid>&limit=<optional>
- Description: List notes for a user ordered by `updatedAt` (newest first).
- Query parameters:
  - `uid` (required) — Firebase UID.
  - `limit` (optional) — positive integer cap (max 200).
- Success 200 response body: `{ "items": [ ...note objects... ] }`.
- Errors: 400 validation_error if `uid` missing; 503 notes_store_error on Firestore issues.

### POST /notes
- Description: Create a new note. Missing titles default to `"New note"`; missing content defaults to an empty string.
- Request JSON body:

```json
{
  "uid": "firebase-uid",
  "title": "Optional title",
  "content": "Optional body",
  "keywords": ["tag"],
  "triggerWords": ["trigger word"]
}
```

- Success: 201 Created with the stored note object.
- Errors: 400 validation_error for missing `uid`; 503 notes_store_error for Firestore issues.

### GET /notes/<note_id>?uid=<uid>
- Description: Fetch a single note owned by the user.
- Errors:
  - 400 validation_error if `uid` missing.
  - 403 forbidden if the note belongs to another user.
  - 404 not_found if no note exists with that id.

### PATCH /notes/<note_id>
- Description: Update note fields. Supported keys: `title`, `content` (or `excerpt`), `keywords`, `triggerWords`.
- Request JSON body:

```json
{
  "uid": "firebase-uid",
  "title": "Updated title",
  "content": "Updated body",
  "keywords": [],
  "triggerWords": ["new trigger"]
}
```

- Success: 200 OK with updated note object.
- Errors: same as GET plus 400 validation_error when no updatable fields supplied.

### DELETE /notes/<note_id>
- Description: Delete a note owned by the user.
- Request: provide `uid` in the JSON body or as a query parameter.
- Success: 204 No Content.
- Errors: 400 validation_error, 403 forbidden, 404 not_found, 503 notes_store_error.

### GET /notes/search
- Description: Search a user's notes using free text, trigger words, and/or keywords.
- Query parameters:
  - `uid` (required).
  - `q` (optional) — substring search across title, content, keywords, trigger words.
  - `trigger` / `triggerWords` (optional, repeatable) — match trigger words case-insensitively.
  - `keyword` / `keywords` (optional, repeatable) — match keywords case-insensitively.
  - `limit` (optional, max 200) — number of items to return (default 50).
- Success: 200 OK with `{ "items": [ ... ] }` sorted by most recently updated.
- Errors: 400 validation_error for missing `uid` or malformed `limit`; 503 notes_store_error on Firestore failure.

The chat pipeline automatically pulls notes whose trigger words appear in the latest user message and injects them into the Gemini prompt, allowing the assistant to answer with personal context when appropriate.

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
