from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.core.security import InvalidTokenError, decode_access_token
from app.db.database import get_db
from app.models.user import User

_bearer = HTTPBearer(auto_error=False)


def _unauthorized(detail: str) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail=detail,
        headers={"WWW-Authenticate": "Bearer"},
    )


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
    db: Session = Depends(get_db),
) -> User:
    """Resolve the bearer token to an existing account or reject the request."""
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise _unauthorized("Bearer token required")

    try:
        user_id = decode_access_token(credentials.credentials)
    except InvalidTokenError:
        raise _unauthorized("Invalid or expired access token") from None

    user = db.get(User, user_id)
    if user is None:
        raise _unauthorized("Account no longer exists")
    return user
