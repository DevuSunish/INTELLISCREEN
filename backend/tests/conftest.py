import os

# Configure an isolated in-memory database and test secrets before the app is
# imported, so tests never touch the developer's intelliscreen.db.
os.environ["INTELLISCREEN_DATABASE_URL"] = "sqlite://"
os.environ["INTELLISCREEN_TOKEN_SECRET"] = "test-only-secret"
os.environ["INTELLISCREEN_PASSWORD_HASH_ITERATIONS"] = "1000"

import uuid  # noqa: E402

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from app.db.database import Base, SessionLocal, engine  # noqa: E402
from app.main import app  # noqa: E402

assert str(engine.url) == "sqlite://", "tests must run against the in-memory database"

API = "/api/v1"
ACTIVITY_KEYS = ("handwriting", "reading", "phonological", "ran", "memory")


@pytest.fixture
def client():
    Base.metadata.drop_all(bind=engine)
    # Entering the client runs the app's startup, which creates tables and seeds.
    with TestClient(app) as test_client:
        yield test_client
    Base.metadata.drop_all(bind=engine)


@pytest.fixture
def db_session():
    session = SessionLocal()
    try:
        yield session
    finally:
        session.close()


def register(client: TestClient, email: str | None = None, password: str = "safePassword123"):
    email = email or f"user_{uuid.uuid4().hex[:8]}@example.com"
    response = client.post(
        f"{API}/auth/register", json={"email": email, "password": password}
    )
    assert response.status_code == 201, response.text
    return response.json()


def auth_headers(client: TestClient) -> dict[str, str]:
    return {"Authorization": f"Bearer {register(client)['access_token']}"}


@pytest.fixture
def headers(client: TestClient) -> dict[str, str]:
    return auth_headers(client)


@pytest.fixture
def other_headers(client: TestClient) -> dict[str, str]:
    return auth_headers(client)


def demo_child_id(client: TestClient, headers: dict[str, str], code: str = "demo-1") -> int:
    children = client.get(f"{API}/children/", headers=headers).json()
    return next(child["id"] for child in children if child["participant_code"] == code)


def start_assessment(client: TestClient, headers: dict[str, str], child_id: int) -> dict:
    response = client.post(
        f"{API}/assessments/", json={"child_id": child_id}, headers=headers
    )
    assert response.status_code in (200, 201), response.text
    return response.json()


def complete_all_activities(client: TestClient, headers: dict[str, str], assessment_id: int):
    for key in ACTIVITY_KEYS:
        response = client.put(
            f"{API}/assessments/{assessment_id}/activities/{key}",
            json={"status": "completed"},
            headers=headers,
        )
        assert response.status_code == 200, response.text


def complete_assessment(client: TestClient, headers: dict[str, str], child_id: int) -> int:
    assessment_id = start_assessment(client, headers, child_id)["id"]
    complete_all_activities(client, headers, assessment_id)
    response = client.patch(
        f"{API}/assessments/{assessment_id}/status",
        json={"status": "completed"},
        headers=headers,
    )
    assert response.status_code == 200, response.text
    return assessment_id
