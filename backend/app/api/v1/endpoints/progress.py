from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.access import get_accessible_child, owned_assessments
from app.api.deps import get_current_user
from app.core.constants import ASSESSMENT_COMPLETED, ASSESSMENT_IN_PROGRESS
from app.db.database import get_db
from app.models.assessment import Assessment
from app.models.user import User
from app.schemas.progress import AssessmentHistoryItem, ChildProgressResponse

router = APIRouter(prefix="/progress", tags=["Progress Tracking"])


@router.get("/{child_id}", response_model=ChildProgressResponse)
def get_child_progress(
    child_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """Saved assessment history of a child, limited to the current account."""
    child = get_accessible_child(db, user, child_id)

    assessments = (
        owned_assessments(db, user)
        .filter(Assessment.child_id == child_id)
        .order_by(Assessment.created_at.desc(), Assessment.id.desc())
        .all()
    )

    history = [
        AssessmentHistoryItem(
            assessment_id=assessment.id,
            assessment_type=assessment.assessment_type,
            assessment_status=assessment.status,
            assessment_date=assessment.created_at,
            updated_at=assessment.updated_at,
            completed_at=assessment.completed_at,
            activities=assessment.activities,
            inference_status=assessment.inference_status,
            inference_error=assessment.inference_error,
            result=assessment.result,
        )
        for assessment in assessments
    ]

    return ChildProgressResponse(
        child_id=child.id,
        participant_code=child.participant_code,
        total_assessments=len(history),
        completed_assessments=sum(
            item.assessment_status == ASSESSMENT_COMPLETED for item in history
        ),
        in_progress_assessments=sum(
            item.assessment_status == ASSESSMENT_IN_PROGRESS for item in history
        ),
        results_available=sum(item.result is not None for item in history),
        assessment_history=history,
    )
