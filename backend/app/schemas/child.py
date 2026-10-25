from pydantic import BaseModel, Field, ConfigDict


class ChildProfileCreate(BaseModel):
    participant_code: str = Field(min_length=1, max_length=50)
    age_years: int | None = Field(default=None, ge=3, le=18)


class ChildProfileResponse(BaseModel):
    id: int
    participant_code: str
    age_years: int | None
    model_config = ConfigDict(from_attributes=True)
