from sqlalchemy import Column, DateTime, ForeignKey, Integer, String
from sqlalchemy.sql import func

from app.db.database import Base


class Assessment(Base):
    __tablename__ = "assessments"

    id = Column(Integer, primary_key=True, index=True)

    child_id = Column(
        Integer,
        ForeignKey("child_profiles.id"),
        nullable=False,
        index=True,
    )

    assessment_type = Column(String(50), nullable=False, default="screening")

    status = Column(String(30), nullable=False, default="pending")

    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )