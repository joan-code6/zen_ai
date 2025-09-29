# Zen

Monorepo for the Zen personal AI assistant.

Structure:
- backend/ — Flask API, scheduling, integrations
- mobile/ — Flutter mobile app
- desktop/ — Flutter + Electron desktop & web

Getting started
1. Backend: see `backend/README.md`
2. Mobile: see `mobile/README.md`
3. Desktop: see `desktop/README.md`


## The idea of Zen
The idea of Zen ai is to be youre personal all knowing ai assistant.
To enhance the knowledge management not all "notes" get send to Zen in every Chat.
Instead "notes" have a propertie called trigger.
If a word from the property in trigger gets found in a users message the "note" gets send with it.
"Notes" can be created by a user or by Zen.
Zen can do the following with notes:
- create note
- search for note
- read note
- edit note
- delete note

The user has accses to all of these tools too.
