import math

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.schemas.common import UTCDateTime


class ScreeningModelOutput(BaseModel):
    """What a screening model produces. Validated before anything is saved."""

    model_config = ConfigDict(extra="forbid")

    model_version: str = Field(min_length=1, max_length=50)
    result_category: str = Field(min_length=1, max_length=50)
    confidence_score: float | None = Field(default=None, ge=0, le=1)
    modality_scores: dict[str, float] | None = None

    @field_validator("modality_scores")
    @classmethod
    def validate_modality_scores(
        cls, value: dict[str, float] | None
    ) -> dict[str, float] | None:
        if value is None:
            return value
        if len(value) > 20:
            raise ValueError("At most 20 modality scores are allowed")
        for name, score in value.items():
            if not name.strip() or len(name) > 50:
                raise ValueError("Modality names must be 1-50 characters")
            if math.isnan(score) or not 0 <= score <= 1:
                raise ValueError("Modality scores must be between 0 and 1")
        return value


class ScreeningResultCreate(ScreeningModelOutput):
    assessment_id: int = Field(gt=0)


class ScreeningResultResponse(BaseModel):
    id: int
    assessment_id: int
    model_version: str | None = None
    result_category: str | None = None
    confidence_score: float | None = None
    modality_scores: dict | None = None
    created_at: UTCDateTime | None = None

    model_config = ConfigDict(from_attributes=True)
