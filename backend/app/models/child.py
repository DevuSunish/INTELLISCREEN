from sqlalchemy import Column, DateTime, ForeignKey, Integer, String
from sqlalchemy.sql import func

from app.core.constants import DEMO_PARTICIPANT_CODES
from app.db.database import Base


class ChildProfile(Base):
    __tablename__ = "child_profiles"

    id = Column(Integer, primary_key=True, index=True)
    participant_code = Column(String(50), unique=True, index=True, nullable=False)
    age_years = Column(Integer, nullable=True)

    # NULL for shared demo profiles; set for profiles created by a specific account.
    owner_id = Column(Integer, ForeignKey("users.id"), nullable=True, index=True)

    created_at = Column(DateTime(timezone=True), server_default=func.now())

    @property
    def is_demo(self) -> bool:
        return self.owner_id is None and self.participant_code in DEMO_PARTICIPANT_CODES
