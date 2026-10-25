import os
from pathlib import Path

APP_NAME = "INTELLISCREEN"
APP_VERSION = "1.0.0"
API_V1_PREFIX = "/api/v1"

DEBUG = True

# The backend directory, so the default database and secret file do not depend
# on the directory uvicorn happens to be started from.
BACKEND_DIR = Path(__file__).resolve().parents[2]

DATABASE_URL = os.environ.get(
    "INTELLISCREEN_DATABASE_URL",
    f"sqlite:///{BACKEND_DIR / 'intelliscreen.db'}",
)

# Signing secret for access tokens. Set INTELLISCREEN_TOKEN_SECRET in production;
# otherwise a random secret is generated once into this git-ignored file.
TOKEN_SECRET_FILE = BACKEND_DIR / ".intelliscreen_secret"
ACCESS_TOKEN_EXPIRE_MINUTES = int(
    os.environ.get("INTELLISCREEN_ACCESS_TOKEN_EXPIRE_MINUTES", 60 * 12)
)
PASSWORD_HASH_ITERATIONS = int(
    os.environ.get("INTELLISCREEN_PASSWORD_HASH_ITERATIONS", 600_000)
)

# Local origins allowed to call the API from a browser (Flutter web debug runs).
CORS_ORIGIN_REGEX = r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$"

# Screening model adapter as "package.module:factory". Unset means no model is
# connected; the rest of the application works without one.
SCREENING_ADAPTER = os.environ.get("INTELLISCREEN_SCREENING_ADAPTER", "").strip()
