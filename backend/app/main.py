from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1.endpoints.assessments import router as assessments_router
from app.api.v1.endpoints.auth import router as auth_router
from app.api.v1.endpoints.children import router as children_router
from app.api.v1.endpoints.progress import router as progress_router
from app.api.v1.endpoints.results import router as results_router
from app.core.config import API_V1_PREFIX, APP_NAME, APP_VERSION, CORS_ORIGIN_REGEX
from app.db.init_db import init_db


@asynccontextmanager
async def lifespan(_: FastAPI):
    # Tables exist and demo profiles are seeded before the first request.
    init_db()
    yield


app = FastAPI(
    title=f"{APP_NAME} API",
    description="Backend API for dyslexia and dysgraphia screening research",
    version=APP_VERSION,
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=CORS_ORIGIN_REGEX,
    allow_methods=["*"],
    allow_headers=["Authorization", "Content-Type"],
)

app.include_router(auth_router, prefix=API_V1_PREFIX)
app.include_router(children_router, prefix=API_V1_PREFIX)
app.include_router(assessments_router, prefix=API_V1_PREFIX)
app.include_router(results_router, prefix=API_V1_PREFIX)
app.include_router(progress_router, prefix=API_V1_PREFIX)


@app.get("/")
def home():
    return {
        "message": "Welcome to INTELLISCREEN Backend",
        "status": "running",
    }


@app.get(f"{API_V1_PREFIX}/health")
def health_check():
    return {
        "status": "ok",
        "service": "intelliscreen-api",
    }
