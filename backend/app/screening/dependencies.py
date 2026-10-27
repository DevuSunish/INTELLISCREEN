from functools import lru_cache

from app.core.config import SCREENING_ADAPTER
from app.screening.adapter import ScreeningModelAdapter, load_adapter


@lru_cache
def get_screening_adapter() -> ScreeningModelAdapter | None:
    """FastAPI dependency: the configured adapter, or None when no model is connected."""
    return load_adapter(SCREENING_ADAPTER)
