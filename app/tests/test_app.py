# Unit tests of the Northstar checkout. The pipeline runs them on every
# pull request and on every merge to main, before any image is built.
import pytest

from app import app


@pytest.fixture
def client():
    app.config["TESTING"] = True
    with app.test_client() as test_client:
        yield test_client


def test_health_answers_200(client):
    response = client.get("/health")
    assert response.status_code == 200
    data = response.get_json()
    assert data["status"] == "healthy"


def test_info_shows_version_and_environment(client):
    response = client.get("/api/info")
    data = response.get_json()
    assert data["service"] == "northstar-checkout"
    assert "version" in data
    assert "environment" in data


def test_order_total_includes_service_fee(client):
    order = {"quantity": 2, "email": "ana@example.com"}
    response = client.post("/api/orders", json=order)
    assert response.status_code == 201
    data = response.get_json()
    assert data["total"] == "€103.00"


def test_order_refuses_more_than_eight_tickets(client):
    order = {"quantity": 9, "email": "ana@example.com"}
    response = client.post("/api/orders", json=order)
    assert response.status_code == 400


def test_order_refuses_an_invalid_email(client):
    order = {"quantity": 1, "email": "ana.example.com"}
    response = client.post("/api/orders", json=order)
    assert response.status_code == 400
