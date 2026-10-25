from sqlalchemy import Column, DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.core.constants import ASSESSMENT_IN_PROGRESS, ASSESSMENT_TYPE_SCREENING
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

    # The account that ran the assessment; only that account can read or change it.
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True, index=True)

    assessment_type = Column(
        String(50), nullable=False, default=ASSESSMENT_TYPE_SCREENING
    )

    status = Column(String(30), nullable=False, default=ASSESSMENT_IN_PROGRESS)

    created_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=True,
    )

    completed_at = Column(DateTime(timezone=True), nullable=True)

    activities = relationship(
        "ActivityStatus",
        back_populates="assessment",
        cascade="all, delete-orphan",
        order_by="ActivityStatus.id",
        lazy="selectin",
    )

    result = relationship(
        "ScreeningResult",
        uselist=False,
        lazy="selectin",
    )

    @property
    def has_result(self) -> bool:
        return self.result is not None
