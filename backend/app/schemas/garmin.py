from __future__ import annotations

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, EmailStr

from app.schemas.sleep import SleepSummaryResponse


class GarminCredentialConnectRequest(BaseModel):
    email: Optional[EmailStr] = None
    password: Optional[str] = None
    mfa_code: Optional[str] = None
    mfa_token: Optional[str] = None


class GarminCredentialConnectResponse(BaseModel):
    connected: bool
    mfa_required: bool = False
    mfa_token: Optional[str] = None
    message: str
    summary: Optional[SleepSummaryResponse] = None


class GarminPullResponse(BaseModel):
    refreshed_at: datetime
    summary: SleepSummaryResponse
