from __future__ import annotations

from datetime import date
from typing import Optional

from pydantic import BaseModel


class HabitResponse(BaseModel):
    id: str
    name: str
    type: str
    description: Optional[str]
    default_on: bool = True
    icon: Optional[str]
    value: bool = False
    value_type: str = "boolean"
    last_check_in: Optional[str]


class HabitCheckinRequest(BaseModel):
    habit_id: str
    value: bool
    local_date: Optional[date]


class HabitCheckinResponse(HabitResponse):
    pass
