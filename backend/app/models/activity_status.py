from sqlalchemy import Column, DateTime, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.core.constants import ACTIVITY_NOT_STARTED
from app.db.database import Base


class ActivityStatus(Base):
    __tablename__ = "activity_statuses"
    __table_args__ = (
        UniqueConstraint(
            "assessment_id", "activity_key", name="uq_activity_status_assessment_key"
        ),
    )

    id = Column(Integer, primary_key=True, index=True)

    assessment_id = Column(
        Integer,
        ForeignKey("assessments.id"),
        nullable=False,
        index=True,
    )

    activity_key = Column(String(50), nullable=False)

    status = Column(String(30), nullable=False, default=ACTIVITY_NOT_STARTED)

    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    assessment = relationship("Assessment", back_populates="activities")
