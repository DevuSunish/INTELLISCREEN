"""Authorization rules shared by the endpoints.

- The four demo profiles are shared: every signed-in account can view them and
  run assessments for them.
- Other child profiles are visible only to the account that owns them. Legacy
  profiles without an owner that are not demo profiles are not exposed.
- Assessments, their activity statuses and screening results belong to the
  account that started the assessment. Other accounts get 404, so record ids
  of other users are not disclosed.
"""

from fastapi import HTTPException
from sqlalchemy import and_, or_
from sqlalchemy.orm import Query, Session

from app.core.constants import DEMO_PARTICIPANT_CODES
from app.models.assessment import Assessment
from app.models.child import ChildProfile
from app.models.user import User


def accessible_children(db: Session, user: User) -> Query:
    return db.query(ChildProfile).filter(
        or_(
            ChildProfile.owner_id == user.id,
            and_(
                ChildProfile.owner_id.is_(None),
                ChildProfile.participant_code.in_(DEMO_PARTICIPANT_CODES),
            ),
        )
    )


def get_accessible_child(db: Session, user: User, child_id: int) -> ChildProfile:
    child = accessible_children(db, user).filter(ChildProfile.id == child_id).first()
    if child is None:
        raise HTTPException(status_code=404, detail="Child profile not found")
    return child


def owned_assessments(db: Session, user: User) -> Query:
    return db.query(Assessment).filter(Assessment.user_id == user.id)


def get_owned_assessment(db: Session, user: User, assessment_id: int) -> Assessment:
    assessment = (
        owned_assessments(db, user).filter(Assessment.id == assessment_id).first()
    )
    if assessment is None:
        raise HTTPException(status_code=404, detail="Assessment not found")
    return assessment
