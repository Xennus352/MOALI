from typing import Optional
from datetime import datetime

from pydantic import BaseModel, EmailStr, Field


class UserSchema(BaseModel):
    id: int
    email: EmailStr
    name: Optional[str] = None
    role: str = "user"
    is_active: bool = True
    is_superuser: bool = False
    last_login_at: Optional[datetime] = None
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class CreateUserSchema(BaseModel):
    email: EmailStr = Field(..., description="User email address")
    password: str = Field(..., min_length=8, max_length=128, description="Plain password (hashed server-side)")
    name: Optional[str] = Field(None, max_length=255)
    role: str = Field("enumerator", max_length=50)


class AdminCreateUserSchema(CreateUserSchema):
    is_active: bool = True
    is_superuser: bool = False


class UpdateUserSchema(BaseModel):
    name: Optional[str] = Field(None, max_length=255)
    role: Optional[str] = Field(None, max_length=50)
    is_active: Optional[bool] = None
    is_superuser: Optional[bool] = None


class ResetPasswordSchema(BaseModel):
    new_password: str = Field(..., min_length=8, max_length=128)


class LoginUserSchema(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=1, max_length=128)


class ChangePasswordSchema(BaseModel):
    current_password: str = Field(..., min_length=1)
    new_password: str = Field(..., min_length=8, max_length=128)


class SessionUserSchema(BaseModel):
    id: str
    name: str
    email: str
    role: str
    is_superuser: bool = False


class TokenSchema(BaseModel):
    access_token: str
    token_type: str = "bearer"
