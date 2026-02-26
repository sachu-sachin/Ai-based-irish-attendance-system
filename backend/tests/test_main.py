import pytest
from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

def test_read_main():
    response = client.get("/")
    assert response.status_code == 200
    assert response.json() == {
        "message": "AI-Based Upper-Face Recognition Attendance System",
        "status": "running",
        "version": "1.0.0"
    }
