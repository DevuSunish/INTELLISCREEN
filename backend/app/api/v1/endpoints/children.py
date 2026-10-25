from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.models.child import ChildProfile
from app.schemas.child import ChildProfileCreate, ChildProfileResponse

router = APIRouter(prefix="/children", tags=["Children"])


@router.post("/", response_model=ChildProfileResponse, status_code=201)
def create_child(
    child_data: ChildProfileCreate,
    db: Session = Depends(get_db),
):
    existing = (
        db.query(ChildProfile)
        .filter(ChildProfile.participant_code == child_data.participant_code)
        .first()
    )

    if existing:
        raise HTTPException(
            status_code=409,
            detail="Participant code already exists",
        )

    child = ChildProfile(**child_data.model_dump())
    db.add(child)
    db.commit()
    db.refresh(child)
    return child


@router.get("/", response_model=list[ChildProfileResponse])
def list_children(db: Session = Depends(get_db)):
    return db.query(ChildProfile).order_by(ChildProfile.id).all()
