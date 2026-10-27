from pydantic import BaseModel, ConfigDict, Field

from app.schemas.common import UTCDateTime


class ChildProfileCreate(BaseModel):
    participant_code: str = Field(min_length=1, max_length=50)
    age_years: int | None = Field(default=None, ge=3, le=18)


class ChildProfileResponse(BaseModel):
    id: int
    participant_code: str
    age_years: int | None
    is_demo: bool
    created_at: UTCDateTime | None = None

    model_config = ConfigDict(from_attributes=True)
