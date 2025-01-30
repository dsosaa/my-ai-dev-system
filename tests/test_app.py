import pytest
from backend.app import app

@pytest.fixture
def client():
    with app.test_client() as client:
        yield client

def test_status(client):
    response = client.get('/api/status')
    assert response.status_code == 200
    assert response.json == {'status': 'API is working'}
