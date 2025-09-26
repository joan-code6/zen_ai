# Backend (Flask)

This folder contains the Flask API server for Zen.

Quick start (Windows PowerShell):

# Create a virtualenv and activate
python -m venv venv; .\venv\Scripts\Activate.ps1

# Install dependencies
pip install -r requirements.txt

# Run the server
$env:FLASK_APP = "app.py"; flask run

What's included:
- `app.py` — minimal Flask app with health endpoint
- `requirements.txt` — dependencies
- `routes/` — place for route handlers
- `README.md` — this file
