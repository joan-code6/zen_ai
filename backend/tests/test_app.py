import json
from app import app


def test_ping():
    client = app.test_client()
    rv = client.get('/ping')
    assert rv.status_code == 200
    data = json.loads(rv.data)
    assert data['status'] == 'ok'


def test_chat():
    client = app.test_client()
    rv = client.post('/chat', json={'prompt': 'hello'})
    assert rv.status_code == 200
    data = json.loads(rv.data)
    assert 'reply' in data
    assert 'Echo' in data['reply'] or 'Received prompt' in data['reply']
