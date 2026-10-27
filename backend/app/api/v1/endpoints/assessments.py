from fastapi import APIRouter, Depends, HTTPException, Response
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session
from sqlalchemy.sql import func

from app.api.access import get_accessible_child, get_owned_assessment, owned_assessments
from app.api.deps import get_current_user
from app.core.constants import (
    ACTIVITY_COMPLETED,
    ASSESSMENT_CANCELLED,
    ASSESSMENT_COMPLETED,
    ASSESSMENT_IN_PROGRESS,
    SCREENING_ACTIVITY_KEYS,
)
from app.db.database import get_db
from app.models.activity_status import ActivityStatus
from app.models.assessment import Assessment
from app.models.user import User
from app.schemas.assessment import (
    ActivityStatusResponse,
    ActivityStatusUpdate,
    AssessmentCreate,
    AssessmentResponse,
    AssessmentStatusUpdate,
    AssessmentStatusValue,
)
from app.schemas.result import ScreeningResultResponse
from app.screening.adapter import ScreeningModelAdapter
from app.screening.dependencies import get_screening_adapter
from app.screening.service import run_screening

router = APIRouter(prefix="/assessments", tags=["Assessments"])


@router.post(
    "/",
    response_model=AssessmentResponse,
    status_code=201,
    responses={200: {"description": "An in-progress assessment already existed"}},
)
def start_assessment(
    assessment_data: AssessmentCreate,
    response: Response,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """Start an assessment, or return the account's in-progress one for this child.

    Returning the open assessment makes retries safe and lets the app resume it.
    """
    get_accessible_child(db, user, assessment_data.child_id)

    open_assessment = (
        owned_assessments(db, user)
        .filter(
            Assessment.child_id == assessment_data.child_id,
            Assessment.assessment_type == assessment_data.assessment_type,
            Assessment.status == ASSESSMENT_IN_PROGRESS,
        )
        .order_by(Assessment.id.desc())
        .first()
    )
    if open_assessment is not None:
        response.status_code = 200
        return open_assessment

    assessment = Assessment(
        child_id=assessment_data.child_id,
        user_id=user.id,
        assessment_type=assessment_data.assessment_type,
        status=ASSESSMENT_IN_PROGRESS,
    )
    db.add(assessment)
    db.commit()
    db.refresh(assessment)
    return assessment


@router.get("/", response_model=list[AssessmentResponse])
def list_assessments(
    child_id: int | None = None,
    status: AssessmentStatusValue | None = None,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    query = owned_assessments(db, user)
    if child_id is not None:
        query = query.filter(Assessment.child_id == child_id)
    if status is not None:
        query = query.filter(Assessment.status == status)
    return query.order_by(Assessment.id).all()


@router.get("/{assessment_id}", response_model=AssessmentResponse)
def get_assessment(
    assessment_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return get_owned_assessment(db, user, assessment_id)


@router.patch("/{assessment_id}/status", response_model=AssessmentResponse)
def update_assessment_status(
    assessment_id: int,
    update: AssessmentStatusUpdate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """Move an assessment through in_progress -> completed | cancelled.

    Repeating the current status is accepted so retried requests are harmless.
    """
    assessment = get_owned_assessment(db, user, assessment_id)

    if update.status == assessment.status:
        return assessment

    if assessment.status != ASSESSMENT_IN_PROGRESS:
        raise HTTPException(
            status_code=409,
            detail=f"A {assessment.status} assessment cannot change to {update.status}",
        )

    if update.status == ASSESSMENT_COMPLETED:
        completed = {
            activity.activity_key
            for activity in assessment.activities
            if activity.status == ACTIVITY_COMPLETED
        }
        remaining = [key for key in SCREENING_ACTIVITY_KEYS if key not in completed]
        if remaining:
            raise HTTPException(
                status_code=409,
                detail="All activities must be completed first. Remaining: "
                + ", ".join(remaining),
            )
        assessment.completed_at = func.now()

    assessment.status = update.status
    db.commit()
    db.refresh(assessment)
    return assessment


@router.get(
    "/{assessment_id}/activities", response_model=list[ActivityStatusResponse]
)
def list_activity_statuses(
    assessment_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return get_owned_assessment(db, user, assessment_id).activities


@router.put(
    "/{assessment_id}/activities/{activity_key}",
    response_model=ActivityStatusResponse,
)
def set_activity_status(
    assessment_id: int,
    activity_key: str,
    update: ActivityStatusUpdate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """Create or update the status of one activity (idempotent)."""
    if activity_key not in SCREENING_ACTIVITY_KEYS:
        raise HTTPException(status_code=422, detail="Unknown activity")

    assessment = get_owned_assessment(db, user, assessment_id)
    if assessment.status != ASSESSMENT_IN_PROGRESS:
        raise HTTPException(
            status_code=409,
            detail=f"Activities of a {assessment.status} assessment cannot be changed",
        )

    def find_existing() -> ActivityStatus | None:
        return (
            db.query(ActivityStatus)
            .filter(
                ActivityStatus.assessment_id == assessment_id,
                ActivityStatus.activity_key == activity_key,
            )
            .first()
        )

    activity = find_existing()
    if activity is None:
        activity = ActivityStatus(
            assessment_id=assessment_id,
            activity_key=activity_key,
            status=update.status,
        )
        db.add(activity)
    else:
        activity.status = update.status
    assessment.updated_at = func.now()

    try:
        db.commit()
    except IntegrityError:
        # A concurrent request created the row first; apply the update to it.
        db.rollback()
        activity = find_existing()
        if activity is None:
            raise
        activity.status = update.status
        db.commit()

    db.refresh(activity)
    return activity


@router.post(
    "/{assessment_id}/screening",
    response_model=ScreeningResultResponse,
    status_code=201,
    responses={
        200: {"description": "A result was already saved; the model was not run again"},
        409: {"description": "The assessment is not completed"},
        502: {"description": "The model failed or returned invalid output; retry is allowed"},
        503: {"description": "No screening model is configured or it is unavailable"},
    },
)
def request_screening(
    assessment_id: int,
    response: Response,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    adapter: ScreeningModelAdapter | None = Depends(get_screening_adapter),
):
    """Run the configured screening model for a completed assessment."""
    assessment = get_owned_assessment(db, user, assessment_id)
    result, created = run_screening(db, assessment, adapter)
    if not created:
        response.status_code = 200
    return result
