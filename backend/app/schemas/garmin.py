from __future__ import annotations

from pydantic import BaseModel

from app.schemas.sleep import SleepSummaryResponse


class GarminConnectResponse(BaseModel):
    connected: bool
    message: str
    summary: SleepSummaryResponse
