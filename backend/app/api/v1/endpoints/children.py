from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.api.access import accessible_children, get_accessible_child
from app.api.deps import get_current_user
from app.db.database import get_db
from app.models.child import ChildProfile
from app.models.user import User
from app.schemas.child import ChildProfileCreate, ChildProfileResponse

router = APIRouter(prefix="/children", tags=["Children"])


@router.post("/", response_model=ChildProfileResponse, status_code=201)
def create_child(
    child_data: ChildProfileCreate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """Create a profile owned by the current account (not used by the app UI)."""
    existing = (
        db.query(ChildProfile)
        .filter(ChildProfile.participant_code == child_data.participant_code)
        .first()
    )
    if existing:
        raise HTTPException(status_code=409, detail="Participant code already exists")

    child = ChildProfile(**child_data.model_dump(), owner_id=user.id)
    db.add(child)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=409, detail="Participant code already exists"
        ) from None
    db.refresh(child)
    return child


@router.get("/", response_model=list[ChildProfileResponse])
def list_children(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return accessible_children(db, user).order_by(ChildProfile.id).all()


@router.get("/{child_id}", response_model=ChildProfileResponse)
def get_child(
    child_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    return get_accessible_child(db, user, child_id)
