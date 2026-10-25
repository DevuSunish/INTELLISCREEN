"""Runs the screening model for a completed assessment and stores its output.

Lifecycle (columns on Assessment):
    status:            in_progress -> completed | cancelled
    inference_status:  NULL (never requested) -> pending -> completed | failed
    A saved result is the ScreeningResult row; it exists iff inference completed
    (or a result was posted directly through POST /results/).

Guarantees:
    - Inference only for completed assessments; never as a side effect of completion.
    - At most one result per assessment (unique constraint). A repeated request
      returns the saved result without running the model again.
    - A failed run stores the reason and can be retried.
"""

import logging

from fastapi import HTTPException
from pydantic import ValidationError
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.constants import (
    ASSESSMENT_COMPLETED,
    INFERENCE_COMPLETED,
    INFERENCE_FAILED,
    INFERENCE_PENDING,
)
from app.models.assessment import Assessment
from app.models.child import ChildProfile
from app.models.result import ScreeningResult
from app.schemas.result import ScreeningModelOutput
from app.screening.adapter import (
    InferenceError,
    ModelUnavailableError,
    ScreeningInput,
    ScreeningModelAdapter,
)

logger = logging.getLogger(__name__)

_ERROR_LIMIT = 500


def build_screening_input(db: Session, assessment: Assessment) -> ScreeningInput:
    child = db.get(ChildProfile, assessment.child_id)
    return ScreeningInput(
        assessment_id=assessment.id,
        child_id=assessment.child_id,
        participant_code=child.participant_code,
        child_age_years=child.age_years,
        assessment_type=assessment.assessment_type,
        completed_at=assessment.completed_at,
        activity_statuses={a.activity_key: a.status for a in assessment.activities},
        inputs=(),
    )


def require_completed(assessment: Assessment) -> None:
    if assessment.status != ASSESSMENT_COMPLETED:
        raise HTTPException(
            status_code=409,
            detail="Screening is only available for completed assessments",
        )


def save_result(
    db: Session, assessment: Assessment, output: ScreeningModelOutput
) -> ScreeningResult:
    """Persist validated model output and mark inference completed, atomically."""
    require_completed(assessment)
    if assessment.result is not None:
        raise HTTPException(status_code=409, detail="A result already exists for this assessment")

    result = ScreeningResult(assessment_id=assessment.id, **output.model_dump())
    db.add(result)
    assessment.inference_status = INFERENCE_COMPLETED
    assessment.inference_error = None
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=409, detail="A result already exists for this assessment"
        ) from None
    db.refresh(result)
    return result


def _record_failure(db: Session, assessment: Assessment, reason: str) -> None:
    assessment.inference_status = INFERENCE_FAILED
    assessment.inference_error = reason[:_ERROR_LIMIT]
    db.commit()


def run_screening(
    db: Session,
    assessment: Assessment,
    adapter: ScreeningModelAdapter | None,
) -> tuple[ScreeningResult, bool]:
    """Return (result, created). created is False when a saved result is returned."""
    require_completed(assessment)

    if assessment.result is not None:
        return assessment.result, False

    if adapter is None:
        raise HTTPException(
            status_code=503,
            detail="No screening model is configured. The assessment is saved; "
            "screening can be requested once a model is connected.",
        )

    assessment.inference_status = INFERENCE_PENDING
    assessment.inference_error = None
    db.commit()

    try:
        raw_output = adapter.predict(build_screening_input(db, assessment))
    except ModelUnavailableError as error:
        _record_failure(db, assessment, f"Model unavailable: {error}")
        raise HTTPException(status_code=503, detail="The screening model is unavailable") from None
    except InferenceError as error:
        _record_failure(db, assessment, f"Inference failed: {error}")
        raise HTTPException(status_code=502, detail="The screening model could not produce a result") from None
    except Exception:
        logger.exception("Screening adapter crashed for assessment %s", assessment.id)
        _record_failure(db, assessment, "Inference failed: unexpected model error")
        raise HTTPException(status_code=502, detail="The screening model could not produce a result") from None

    try:
        # Always validate, including model instances built without validation.
        data = (
            raw_output.model_dump()
            if isinstance(raw_output, ScreeningModelOutput)
            else raw_output
        )
        output = ScreeningModelOutput.model_validate(data)
    except ValidationError as error:
        logger.warning("Invalid screening output for assessment %s: %s", assessment.id, error)
        _record_failure(db, assessment, f"Invalid model output: {error.error_count()} validation error(s)")
        raise HTTPException(status_code=502, detail="The screening model returned an invalid result") from None

    try:
        return save_result(db, assessment, output), True
    except HTTPException as error:
        if error.status_code != 409:
            raise
        # A concurrent request saved a result first; return that one.
        db.refresh(assessment)
        if assessment.result is None:
            raise
        return assessment.result, False
