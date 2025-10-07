from __future__ import annotations

from datetime import date
from typing import List, Optional

from fastapi import APIRouter, Depends

from app.schemas.garmin import GarminConnectResponse
from app.schemas.habits import HabitCheckinRequest, HabitCheckinResponse, HabitResponse
from app.schemas.sleep import SleepSummaryResponse
from app.services.habits import HabitService, get_habit_service
from app.services.sleep import SleepService, get_sleep_service
from app.services.storage import User
from app.services.users import get_current_user

router = APIRouter()


@router.get("/summary", response_model=SleepSummaryResponse)
async def get_summary(
    user: User = Depends(get_current_user),
    sleep_service: SleepService = Depends(get_sleep_service),
) -> SleepSummaryResponse:
    summary = sleep_service.get_summary(user)
    return SleepSummaryResponse(**summary)


@router.post("/garmin/connect", response_model=GarminConnectResponse)
async def connect_garmin(
    user: User = Depends(get_current_user),
    sleep_service: SleepService = Depends(get_sleep_service),
) -> GarminConnectResponse:
    result = sleep_service.connect_garmin(user)
    return GarminConnectResponse(
        connected=result["connected"],
        message=result["message"],
        summary=SleepSummaryResponse(**result["summary"]),
    )


@router.post("/garmin/pull", response_model=SleepSummaryResponse)
async def pull_garmin(
    user: User = Depends(get_current_user),
    sleep_service: SleepService = Depends(get_sleep_service),
) -> SleepSummaryResponse:
    summary = sleep_service.pull_latest(user)
    return SleepSummaryResponse(**summary)


@router.get("/habits", response_model=List[HabitResponse])
async def list_habits(
    target_date: Optional[date] = None,
    user: User = Depends(get_current_user),
    habit_service: HabitService = Depends(get_habit_service),
) -> List[HabitResponse]:
    habits = habit_service.get_habits(user, target_date)
    return [HabitResponse(**habit) for habit in habits]


@router.post("/habits/checkin", response_model=HabitCheckinResponse)
async def checkin_habit(
    payload: HabitCheckinRequest,
    user: User = Depends(get_current_user),
    habit_service: HabitService = Depends(get_habit_service),
) -> HabitCheckinResponse:
    habit = habit_service.check_in(
        user=user,
        habit_id=payload.habit_id,
        value=payload.value,
        target_date=payload.local_date,
    )
    return HabitCheckinResponse(**habit)
