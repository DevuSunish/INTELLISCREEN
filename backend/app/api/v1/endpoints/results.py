from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.models.assessment import Assessment
from app.models.result import ScreeningResult
from app.schemas.result import (
    ScreeningResultCreate,
    ScreeningResultResponse,
)

router = APIRouter(prefix="/results", tags=["Screening Results"])


@router.post("/", response_model=ScreeningResultResponse, status_code=201)
def create_result(
    result_data: ScreeningResultCreate,
    db: Session = Depends(get_db),
):
    # Check whether the assessment exists
    assessment = (
        db.query(Assessment)
        .filter(Assessment.id == result_data.assessment_id)
        .first()
    )

    if not assessment:
        raise HTTPException(
            status_code=404,
            detail="Assessment not found",
        )

    # Ensure that an assessment has only one screening result
    existing_result = (
        db.query(ScreeningResult)
        .filter(
            ScreeningResult.assessment_id == result_data.assessment_id
        )
        .first()
    )

    if existing_result:
        raise HTTPException(
            status_code=409,
            detail="A result already exists for this assessment",
        )

    # Create and save the screening result
    result = ScreeningResult(**result_data.model_dump())

    db.add(result)

    # Mark the assessment as completed when its result is saved
    assessment.status = "completed"

    db.commit()
    db.refresh(result)

    return result


@router.get("/", response_model=list[ScreeningResultResponse])
def list_results(db: Session = Depends(get_db)):
    return (
        db.query(ScreeningResult)
        .order_by(ScreeningResult.id)
        .all()
    )


@router.get("/{result_id}", response_model=ScreeningResultResponse)
def get_result(
    result_id: int,
    db: Session = Depends(get_db),
):
    result = (
        db.query(ScreeningResult)
        .filter(ScreeningResult.id == result_id)
        .first()
    )

    if not result:
        raise HTTPException(
            status_code=404,
            detail="Screening result not found",
        )

    return result
