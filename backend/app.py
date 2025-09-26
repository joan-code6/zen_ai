from flask import Flask, jsonify, request
import os

from gemini_client import send_prompt
from firebase_client import initialize_firebase

app = Flask(__name__)

# Initialize Firebase if credentials are provided (no-op otherwise)
initialize_firebase()


@app.route('/ping')
def ping():
    return jsonify({'status': 'ok', 'service': 'zen-backend'})


@app.route('/chat', methods=['POST'])
def chat():
    data = request.get_json() or {}
    prompt = data.get('prompt', '')
    # Call the Gemini client (currently a stub that can be replaced later)
    reply = send_prompt(prompt)
    return jsonify({'reply': reply})


if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port, debug=True)
