import base64
import binascii
import hashlib
import hmac
import json
import os
import secrets
import time
from functools import lru_cache

from app.core.config import (
    ACCESS_TOKEN_EXPIRE_MINUTES,
    PASSWORD_HASH_ITERATIONS,
    TOKEN_SECRET_FILE,
)

_HASH_ALGORITHM = "pbkdf2_sha256"


class InvalidTokenError(Exception):
    pass


def _b64encode(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def _b64decode(value: str) -> bytes:
    return base64.urlsafe_b64decode(value + "=" * (-len(value) % 4))


@lru_cache
def get_token_secret() -> bytes:
    """Return the token signing secret, never from source control."""
    configured = os.environ.get("INTELLISCREEN_TOKEN_SECRET")
    if configured:
        return configured.encode()

    if TOKEN_SECRET_FILE.exists():
        stored = TOKEN_SECRET_FILE.read_text().strip()
        if stored:
            return stored.encode()

    generated = secrets.token_urlsafe(48)
    TOKEN_SECRET_FILE.write_text(generated)
    TOKEN_SECRET_FILE.chmod(0o600)
    return generated.encode()


def hash_password(password: str) -> str:
    salt = os.urandom(16)
    digest = hashlib.pbkdf2_hmac(
        "sha256", password.encode(), salt, PASSWORD_HASH_ITERATIONS
    )
    return (
        f"{_HASH_ALGORITHM}${PASSWORD_HASH_ITERATIONS}"
        f"${_b64encode(salt)}${_b64encode(digest)}"
    )


def verify_password(password: str, encoded: str) -> bool:
    try:
        algorithm, rounds, salt, expected = encoded.split("$")
        if algorithm != _HASH_ALGORITHM:
            return False
        actual = hashlib.pbkdf2_hmac(
            "sha256", password.encode(), _b64decode(salt), int(rounds)
        )
    except (ValueError, binascii.Error):
        return False
    return hmac.compare_digest(_b64encode(actual), expected)


# Used to spend comparable time on logins for unknown emails.
_DUMMY_HASH = hash_password(secrets.token_urlsafe(16))


def burn_password_check(password: str) -> None:
    verify_password(password, _DUMMY_HASH)


def _sign(message: str) -> str:
    return _b64encode(
        hmac.new(get_token_secret(), message.encode(), hashlib.sha256).digest()
    )


def create_access_token(user_id: int, expires_in_seconds: int | None = None) -> str:
    """Create an HS256 JWT identifying the user."""
    lifetime = (
        ACCESS_TOKEN_EXPIRE_MINUTES * 60
        if expires_in_seconds is None
        else expires_in_seconds
    )
    now = int(time.time())
    header = _b64encode(json.dumps({"alg": "HS256", "typ": "JWT"}).encode())
    payload = _b64encode(
        json.dumps({"sub": str(user_id), "iat": now, "exp": now + lifetime}).encode()
    )
    return f"{header}.{payload}.{_sign(f'{header}.{payload}')}"


def decode_access_token(token: str) -> int:
    """Validate a token and return the user id it was issued for."""
    try:
        header, payload, signature = token.split(".")
    except ValueError:
        raise InvalidTokenError("malformed") from None

    if not hmac.compare_digest(signature, _sign(f"{header}.{payload}")):
        raise InvalidTokenError("signature")

    try:
        header_data = json.loads(_b64decode(header))
        data = json.loads(_b64decode(payload))
    except (ValueError, binascii.Error):
        raise InvalidTokenError("malformed") from None

    if not isinstance(header_data, dict) or header_data.get("alg") != "HS256":
        raise InvalidTokenError("algorithm")
    if not isinstance(data, dict):
        raise InvalidTokenError("malformed")

    expires_at = data.get("exp")
    if not isinstance(expires_at, int) or expires_at <= int(time.time()):
        raise InvalidTokenError("expired")

    subject = data.get("sub")
    if not isinstance(subject, str) or not subject.isdigit():
        raise InvalidTokenError("subject")
    return int(subject)
