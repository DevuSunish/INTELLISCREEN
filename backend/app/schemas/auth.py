import re

from pydantic import BaseModel, ConfigDict, Field, field_validator

_EMAIL_PATTERN = re.compile(r"[^@\s]+@[^@\s]+\.[^@\s]+")


def normalize_email(value: str) -> str:
    return value.strip().lower()


class RegisterRequest(BaseModel):
    email: str = Field(max_length=255)
    password: str = Field(min_length=8, max_length=128)
    role: str = Field(default="parent", pattern="^(parent|teacher)$")

    @field_validator("email")
    @classmethod
    def validate_email(cls, value: str) -> str:
        email = normalize_email(value)
        if not _EMAIL_PATTERN.fullmatch(email):
            raise ValueError("A valid email address is required")
        return email


class LoginRequest(BaseModel):
    email: str = Field(min_length=1, max_length=255)
    password: str = Field(min_length=1, max_length=128)

    @field_validator("email")
    @classmethod
    def normalize(cls, value: str) -> str:
        return normalize_email(value)


class UserResponse(BaseModel):
    id: int
    email: str
    role: str

    model_config = ConfigDict(from_attributes=True)


class AuthResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int
    user: UserResponse
