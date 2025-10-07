from __future__ import annotations

from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException, status

from app.schemas.garmin import (
    GarminCredentialConnectRequest,
    GarminCredentialConnectResponse,
    GarminPullResponse,
)
from app.schemas.sleep import SleepSummaryResponse
from app.services.sleep import SleepService, get_sleep_service
from app.services.storage import User
from app.services.users import get_current_user

router = APIRouter(prefix="/garmin", tags=["garmin"])


@router.post("/connect", response_model=GarminCredentialConnectResponse)
async def connect_garmin(
    payload: GarminCredentialConnectRequest,
    user: User = Depends(get_current_user),
    sleep_service: SleepService = Depends(get_sleep_service),
) -> GarminCredentialConnectResponse:
    try:
        result = await sleep_service.connect_garmin(
            user,
            email=payload.email,
            password=payload.password,
            mfa_code=payload.mfa_code,
            mfa_token=payload.mfa_token,
        )
    except Exception as exc:  # pragma: no cover - defensive catch
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc

    summary = result.get("summary")
    return GarminCredentialConnectResponse(
        connected=result.get("connected", False),
        mfa_required=result.get("mfa_required", False),
        mfa_token=result.get("mfa_token"),
        message=result.get("message", ""),
        summary=SleepSummaryResponse(**summary) if summary else None,
    )


@router.post("/pull", response_model=GarminPullResponse)
async def pull_garmin_sleep(
    user: User = Depends(get_current_user),
    sleep_service: SleepService = Depends(get_sleep_service),
) -> GarminPullResponse:
    summary = await sleep_service.pull_latest(user)
    return GarminPullResponse(
        refreshed_at=datetime.now(tz=UTC),
        summary=SleepSummaryResponse(**summary),
    )
