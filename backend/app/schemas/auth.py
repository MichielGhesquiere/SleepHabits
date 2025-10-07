from pydantic import BaseModel, EmailStr


class LoginRequest(BaseModel):
    email: EmailStr


class LoginResponse(BaseModel):
    access_token: str
    email: EmailStr
    user_id: str
    garmin_connected: bool = False
