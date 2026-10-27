from pydantic import BaseModel

from app.schemas.assessment import ActivityStatusResponse
from app.schemas.common import UTCDateTime
from app.schemas.result import ScreeningResultResponse


class AssessmentHistoryItem(BaseModel):
    assessment_id: int
    assessment_type: str
    assessment_status: str
    assessment_date: UTCDateTime
    updated_at: UTCDateTime | None = None
    completed_at: UTCDateTime | None = None
    activities: list[ActivityStatusResponse]
    inference_status: str | None = None
    inference_error: str | None = None
    result: ScreeningResultResponse | None = None


class ChildProgressResponse(BaseModel):
    child_id: int
    participant_code: str
    total_assessments: int
    completed_assessments: int
    in_progress_assessments: int
    results_available: int
    assessment_history: list[AssessmentHistoryItem]
