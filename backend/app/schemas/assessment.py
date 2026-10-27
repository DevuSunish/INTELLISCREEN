from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from app.core.constants import ASSESSMENT_TYPE_SCREENING
from app.schemas.common import UTCDateTime

AssessmentStatusValue = Literal["in_progress", "completed", "cancelled"]
ActivityStatusValue = Literal["not_started", "in_progress", "completed"]


class AssessmentCreate(BaseModel):
    child_id: int = Field(gt=0)
    assessment_type: Literal["screening"] = ASSESSMENT_TYPE_SCREENING


class AssessmentStatusUpdate(BaseModel):
    status: AssessmentStatusValue


class ActivityStatusUpdate(BaseModel):
    status: ActivityStatusValue


class ActivityStatusResponse(BaseModel):
    id: int
    assessment_id: int
    activity_key: str
    status: str
    created_at: UTCDateTime | None = None
    updated_at: UTCDateTime | None = None

    model_config = ConfigDict(from_attributes=True)


class AssessmentResponse(BaseModel):
    id: int
    child_id: int
    assessment_type: str
    status: str
    created_at: UTCDateTime | None = None
    updated_at: UTCDateTime | None = None
    completed_at: UTCDateTime | None = None
    activities: list[ActivityStatusResponse] = []
    inference_status: str | None = None
    inference_error: str | None = None
    has_result: bool = False

    model_config = ConfigDict(from_attributes=True)
