from __future__ import annotations

from datetime import date
from typing import Dict, Optional

from pydantic import BaseModel


class SleepUser(BaseModel):
    email: str
    garmin_connected: bool = False


class SleepStages(BaseModel):
    deep: Optional[int]
    rem: Optional[int]
    light: Optional[int]
    awake: Optional[int]


class SleepLastNight(BaseModel):
    date: str
    duration_minutes: int
    sleep_score: Optional[int]
    bedtime: str
    wake_time: str
    stages: Dict[str, int]


class SleepTrailing(BaseModel):
    avg_duration_minutes: float
    avg_score: Optional[float]
    midpoint: str
    consistency_minutes: int


class HabitSummary(BaseModel):
    positive_completed: int
    positive_total: int
    negative_completed: int
    negative_total: int


class SleepSummaryResponse(BaseModel):
    user: SleepUser
    last_night: Optional[SleepLastNight]
    trailing_7d: Optional[SleepTrailing]
    habits: HabitSummary


class ManualSleepEntryRequest(BaseModel):
    local_date: date
    sleep_score: int
    bedtime: str
    wake_time: str
    duration_minutes: int
