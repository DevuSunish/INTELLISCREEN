import uuid

from fastapi.testclient import TestClient

from app.core.security import create_access_token
from app.models.user import User
from tests.conftest import API, register


def test_register_login_and_current_user(client: TestClient):
    email = f"user_{uuid.uuid4().hex[:8]}@example.com"
    registration = client.post(
        f"{API}/auth/register",
        json={"email": email, "password": "safePassword123", "role": "teacher"},
    )
    assert registration.status_code == 201
    body = registration.json()
    assert body["user"]["role"] == "teacher"
    assert body["token_type"] == "bearer"
    assert body["expires_in"] > 0
    assert "password" not in str(body).lower()

    login = client.post(
        f"{API}/auth/login", json={"email": email, "password": "safePassword123"}
    )
    assert login.status_code == 200
    assert login.json()["user"]["email"] == email

    me = client.get(
        f"{API}/auth/me",
        headers={"Authorization": f"Bearer {login.json()['access_token']}"},
    )
    assert me.status_code == 200
    assert me.json() == {"id": body["user"]["id"], "email": email, "role": "teacher"}


def test_email_is_normalized(client: TestClient):
    register(client, email="  Mixed.Case@Example.COM ")
    login = client.post(
        f"{API}/auth/login",
        json={"email": "mixed.case@example.com", "password": "safePassword123"},
    )
    assert login.status_code == 200
    assert login.json()["user"]["email"] == "mixed.case@example.com"


def test_register_rejects_duplicate_email(client: TestClient):
    email = f"user_{uuid.uuid4().hex[:8]}@example.com"
    register(client, email=email)
    duplicate = client.post(
        f"{API}/auth/register",
        json={"email": email.upper(), "password": "safePassword123"},
    )
    assert duplicate.status_code == 409


def test_register_rejects_invalid_input(client: TestClient):
    cases = [
        {"email": "not-an-email", "password": "safePassword123"},
        {"email": "a@example.com", "password": "short"},
        {"email": "a@example.com", "password": "safePassword123", "role": "admin"},
        {"password": "safePassword123"},
    ]
    for payload in cases:
        assert client.post(f"{API}/auth/register", json=payload).status_code == 422


def test_password_is_hashed(client: TestClient, db_session):
    email = f"user_{uuid.uuid4().hex[:8]}@example.com"
    register(client, email=email, password="safePassword123")
    user = db_session.query(User).filter(User.email == email).one()
    assert user.password_hash != "safePassword123"
    assert "safePassword123" not in user.password_hash
    assert user.password_hash.startswith("pbkdf2_sha256$")


def test_login_rejects_invalid_credentials(client: TestClient):
    email = f"user_{uuid.uuid4().hex[:8]}@example.com"
    register(client, email=email)
    wrong_password = client.post(
        f"{API}/auth/login", json={"email": email, "password": "incorrect"}
    )
    unknown_user = client.post(
        f"{API}/auth/login",
        json={"email": "nobody@example.com", "password": "safePassword123"},
    )
    assert wrong_password.status_code == 401
    assert unknown_user.status_code == 401
    assert wrong_password.json() == unknown_user.json()
    assert "access_token" not in wrong_password.json()


def test_missing_malformed_and_tampered_tokens_are_rejected(client: TestClient):
    token = register(client)["access_token"]
    header, payload, signature = token.split(".")
    bad_headers = [
        {},
        {"Authorization": token},
        {"Authorization": "Bearer not-a-token"},
        {"Authorization": f"Bearer {header}.{payload}.{signature[:-2]}xx"},
        {"Authorization": f"Basic {token}"},
    ]
    for headers in bad_headers:
        response = client.get(f"{API}/auth/me", headers=headers)
        assert response.status_code == 401, headers


def test_expired_token_is_rejected(client: TestClient):
    user_id = register(client)["user"]["id"]
    expired = create_access_token(user_id, expires_in_seconds=-1)
    response = client.get(
        f"{API}/auth/me", headers={"Authorization": f"Bearer {expired}"}
    )
    assert response.status_code == 401


def test_token_for_deleted_account_is_rejected(client: TestClient):
    token = create_access_token(999_999)
    response = client.get(f"{API}/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 401


def test_protected_endpoints_require_authentication(client: TestClient):
    protected = [
        ("get", f"{API}/children/", None),
        ("post", f"{API}/children/", {"participant_code": "x", "age_years": 7}),
        ("get", f"{API}/children/1", None),
        ("post", f"{API}/assessments/", {"child_id": 1}),
        ("get", f"{API}/assessments/", None),
        ("get", f"{API}/assessments/1", None),
        ("patch", f"{API}/assessments/1/status", {"status": "completed"}),
        ("get", f"{API}/assessments/1/activities", None),
        ("put", f"{API}/assessments/1/activities/reading", {"status": "completed"}),
        ("post", f"{API}/results/", {"assessment_id": 1, "model_version": "v", "result_category": "c"}),
        ("get", f"{API}/results/", None),
        ("get", f"{API}/results/1", None),
        ("get", f"{API}/progress/1", None),
    ]
    for method, url, body in protected:
        kwargs = {"json": body} if body is not None else {}
        for headers in ({}, {"Authorization": "Bearer invalid"}):
            response = getattr(client, method)(url, headers=headers, **kwargs)
            assert response.status_code == 401, (method, url, headers)


def test_public_endpoints(client: TestClient):
    assert client.get(f"{API}/health").status_code == 200
    assert client.get("/").status_code == 200
