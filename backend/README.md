# Zen Backend

This folder hosts the Flask API for the Zen assistant. The current milestone covers Firebase-backed authentication and AI chat orchestration. Future milestones will add scheduling, integrations, and richer memory features.

## Features

- Environment-driven configuration via `.env`
- Firebase Admin SDK bootstrapped with a service-account key
- REST endpoints for sign-up, email/password login, Google Sign-In exchange, and ID-token verification
- Firestore-backed chat storage (create, list, update, delete)
- Firestore-backed user profile storage (email, display name, photo)
- Gemini-powered conversation replies with history-aware prompts (default model: `gemini-2.0-flash`)
- Health check endpoint for monitoring (`/health`)

## Prerequisites

1. Python 3.11 or newer
2. A Firebase project with:
   - Email/password authentication enabled in **Authentication → Sign-in method**
   - A Web API key (see **Project settings → General → Web API key**)
   - A service-account key JSON downloaded and stored at the path referenced by `FIREBASE_CREDENTIALS_PATH`
   - Firestore database created (any region) with access rules suitable for your environment
   - Optional: Generative Language API enabled in Google AI Studio for Gemini access (ensure the `gemini-2.0-flash` family is available)

## Setup

1. Create a Python virtual environment and install dependencies:

   ```powershell
   cd backend
   python -m venv .venv
   .\.venv\Scripts\Activate.ps1
   pip install -r requirements.txt
   ```

2. Copy `.env.example` to `.env` if you prefer not to edit secrets in place (optional). Ensure the following variables are present:

   ```dotenv
   PORT=5000
   FIREBASE_CREDENTIALS_PATH=../.config/zen-ai6-firebase-adminsdk-fbsvc-957386bfc8.json
   FIREBASE_WEB_API_KEY=<your-firebase-web-api-key>
   GEMINI_API_KEY=<google-gemini-api-key>
   # Optional: only needed if you use a named Firestore database (e.g. "main")
    FIRESTORE_DATABASE_ID=main
   ```

   > **Note:** Paths can be absolute or relative to the `backend/` folder. The sample above assumes the key file lives in the repository-level `.config` directory.

3. Run the development server:

   ```powershell
   python app.py
   ```

   The API listens on `http://127.0.0.1:5000` by default.

## API Reference

### `POST /auth/signup`
Create a new Firebase Authentication user.

- **Body:** `{ "email": "user@example.com", "password": "secret", "displayName": "User" }`
- **Responses:**
   - `201 Created` — Returns `{ uid, email, displayName, emailVerified, profile }`
  - `409 Conflict` — Email already registered

### `POST /auth/login`
Authenticate an email/password user via Firebase's Identity Toolkit. Requires `FIREBASE_WEB_API_KEY`.

- **Body:** `{ "email": "user@example.com", "password": "secret" }`
- **Responses:**
   - `200 OK` — Returns `{ idToken, refreshToken, expiresIn, localId, email, displayName, profile, profileSynced }`
  - `503 Service Unavailable` — API key not configured

### `POST /auth/google-signin`
Exchange a Google ID token or access token for Firebase credentials. Requires `FIREBASE_WEB_API_KEY` and Google Sign-In enabled in Firebase.

- **Body:** `{ "idToken": "<google-id-token>" }`
- **Optional fields:**
   - `accessToken` — Google OAuth access token, used when provided by the client
   - `requestUri` — Any valid HTTP/HTTPS URL allowed by Firebase (defaults to `http://localhost`)
- **Responses:**
   - `200 OK` — Returns `{ idToken, refreshToken, expiresIn, localId, email, displayName, photoUrl, isNewUser, profile }`
   - `503 Service Unavailable` — API key not configured
   - `401 Unauthorized` — Invalid Google credential or Firebase rejected the request

### `POST /auth/verify-token`
Validate a Firebase ID token issued to the client.

- **Body:** `{ "idToken": "<firebase-id-token>" }`
- **Responses:**
  - `200 OK` — Returns `{ uid, email, claims }`
  - `401 Unauthorized` — Invalid or expired token

### `POST /chats`
Create a new chat container.

- **Body:** `{ "uid": "<firebase-uid>", "title": "Project kickoff", "systemPrompt": "You are a helpful assistant." }`
- **Responses:**
   - `201 Created` — Returns chat metadata `{ id, uid, title, systemPrompt, createdAt, updatedAt }`

### `GET /chats?uid=<firebase-uid>`
List chats owned by the specified user ordered by `updatedAt`.

- **Responses:**
   - `200 OK` — Returns `{ items: [ ...chat metadata... ] }`

### `GET /chats/<chat_id>?uid=<firebase-uid>`
Fetch a chat plus its ordered message history.

- **Responses:**
   - `200 OK` — Returns `{ chat, messages }`
   - `403 Forbidden` — Requesting user is not the chat owner

### `PATCH /chats/<chat_id>`
Update chat properties such as the title or system prompt.

- **Body:** `{ "uid": "<firebase-uid>", "title": "Renamed chat" }`
- **Responses:**
   - `200 OK` — Returns the updated chat metadata

### `DELETE /chats/<chat_id>`
Delete a chat and all associated messages.

- **Body:** `{ "uid": "<firebase-uid>" }`
- **Responses:**
   - `204 No Content`

### `POST /chats/<chat_id>/messages`
Append a message to a chat and receive the Gemini-generated assistant reply.

- **Body:** `{ "uid": "<firebase-uid>", "content": "What's our roadmap?" }`
- **Responses:**
   - `201 Created` — Returns `{ userMessage, assistantMessage }`
   - `503 Service Unavailable` — Gemini API key not configured
   - `502 Bad Gateway` — Gemini API error while generating a reply

### `GET /health`
Health probe endpoint; returns `{ "status": "ok" }`.

### `GET /users/<uid>`
Fetch the stored profile for the given Firebase UID.

- **Responses:**
   - `200 OK` — Returns `{ uid, email, displayName, photoUrl, createdAt, updatedAt }`
   - `404 Not Found` — No profile exists yet

### `PATCH /users/<uid>`
Update profile attributes (currently `displayName` and `photoUrl`). Supply at least one of the supported fields in the request body.

- **Body:** `{ "displayName": "New name", "photoUrl": "https://example.com/avatar.png" }`
- **Responses:**
   - `200 OK` — Returns the updated profile
   - `400 Bad Request` — No supported fields provided

## Next Steps

- Add role/permission management using custom claims
- Persist long-term memories and task scheduling primitives
- Expand integrations (calendar, email, messaging)
- Wire the desktop/mobile clients to the new auth & chat APIs
