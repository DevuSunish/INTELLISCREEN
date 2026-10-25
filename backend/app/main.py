from fastapi import FastAPI

from app.api.v1.endpoints.assessments import router as assessments_router
from app.api.v1.endpoints.children import router as children_router
from app.api.v1.endpoints.results import router as results_router
from app.api.v1.endpoints.progress import router as progress_router
from app.core.config import API_V1_PREFIX, APP_NAME, APP_VERSION

app = FastAPI(
    title=f"{APP_NAME} API",
    description="Backend API for dyslexia and dysgraphia screening research",
    version=APP_VERSION,
)

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