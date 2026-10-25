from sqlalchemy import Column, DateTime, Integer, String
from sqlalchemy.sql import func

from app.db.database import Base


class ChildProfile(Base):
    __tablename__ = "child_profiles"

    id = Column(Integer, primary_key=True, index=True)
    participant_code = Column(String(50), unique=True, index=True, nullable=False)
    age_years = Column(Integer, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
