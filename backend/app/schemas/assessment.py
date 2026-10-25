from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class AssessmentCreate(BaseModel):
    child_id: int = Field(gt=0)
    assessment_type: str = Field(default="screening", min_length=1, max_length=50)


class AssessmentResponse(BaseModel):
    id: int
    child_id: int
    assessment_type: str
    status: str
    created_at: datetime | None = None

    model_config = ConfigDict(from_attributes=True)
