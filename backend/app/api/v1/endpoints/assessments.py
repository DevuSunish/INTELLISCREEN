from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.models.assessment import Assessment
from app.models.child import ChildProfile
from app.schemas.assessment import AssessmentCreate, AssessmentResponse

router = APIRouter(prefix="/assessments", tags=["Assessments"])


@router.post("/", response_model=AssessmentResponse, status_code=201)
def create_assessment(
    assessment_data: AssessmentCreate,
    db: Session = Depends(get_db),
):
    child = (
        db.query(ChildProfile)
        .filter(ChildProfile.id == assessment_data.child_id)
        .first()
    )

    if child is None:
        raise HTTPException(
            status_code=404,
            detail="Child profile not found",
        )

    assessment = Assessment(
        child_id=assessment_data.child_id,
        assessment_type=assessment_data.assessment_type,
        status="pending",
    )

    db.add(assessment)
    db.commit()
    db.refresh(assessment)

    return assessment


@router.get("/", response_model=list[AssessmentResponse])
def list_assessments(db: Session = Depends(get_db)):
    return db.query(Assessment).order_by(Assessment.id).all()


@router.get("/{assessment_id}", response_model=AssessmentResponse)
def get_assessment(
    assessment_id: int,
    db: Session = Depends(get_db),
):
    assessment = (
        db.query(Assessment)
        .filter(Assessment.id == assessment_id)
        .first()
    )

    if assessment is None:
        raise HTTPException(
            status_code=404,
            detail="Assessment not found",
        )

    return assessment

@router.patch("/{assessment_id}/status", response_model=AssessmentResponse)
def update_assessment_status(
    assessment_id: int,
    status: str,
    db: Session = Depends(get_db),
):
    allowed_statuses = {"pending", "in_progress", "completed"}

    if status not in allowed_statuses:
        raise HTTPException(
            status_code=422,
            detail="Status must be pending, in_progress, or completed",
        )

    assessment = (
        db.query(Assessment)
        .filter(Assessment.id == assessment_id)
        .first()
    )

    if assessment is None:
        raise HTTPException(
            status_code=404,
            detail="Assessment not found",
        )

    assessment.status = status
    db.commit()
    db.refresh(assessment)

    return assessment
