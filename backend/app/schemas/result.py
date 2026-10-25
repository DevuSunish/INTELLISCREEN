from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class ScreeningResultCreate(BaseModel):
    assessment_id: int = Field(gt=0)
    model_version: str | None = Field(default=None, max_length=50)
    result_category: str | None = Field(default=None, max_length=50)
    confidence_score: float | None = Field(default=None, ge=0, le=1)
    modality_scores: dict[str, float] | None = None


class ScreeningResultResponse(BaseModel):
    id: int
    assessment_id: int
    model_version: str | None = None
    result_category: str | None = None
    confidence_score: float | None = None
    modality_scores: dict | None = None
    created_at: datetime | None = None

    model_config = ConfigDict(from_attributes=True)
