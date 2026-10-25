from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.models.assessment import Assessment
from app.models.child import ChildProfile
from app.models.result import ScreeningResult

router = APIRouter(prefix="/progress", tags=["Progress Tracking"])


@router.get("/{child_id}")
def get_child_progress(
    child_id: int,
    db: Session = Depends(get_db),
):
    # Check whether the child exists
    child = (
        db.query(ChildProfile)
        .filter(ChildProfile.id == child_id)
        .first()
    )

    if not child:
        raise HTTPException(
            status_code=404,
            detail="Child profile not found",
        )

    # Retrieve the child's assessments and their results
    records = (
        db.query(Assessment, ScreeningResult)
        .outerjoin(
            ScreeningResult,
            Assessment.id == ScreeningResult.assessment_id,
        )
        .filter(Assessment.child_id == child_id)
        .order_by(Assessment.created_at.asc())
        .all()
    )

    # Organize the assessment history
    history = []

    for assessment, result in records:
        history.append(
            {
                "assessment_id": assessment.id,
                "assessment_type": assessment.assessment_type,
                "assessment_status": assessment.status,
                "assessment_date": assessment.created_at,
                "result": (
                    {
                        "result_id": result.id,
                        "model_version": result.model_version,
                        "result_category": result.result_category,
                        "confidence_score": result.confidence_score,
                        "modality_scores": result.modality_scores,
                        "result_date": result.created_at,
                    }
                    if result
                    else None
                ),
            }
        )

    return {
        "child_id": child.id,
        "participant_code": child.participant_code,
        "total_assessments": len(history),
        "assessment_history": history,
    }
