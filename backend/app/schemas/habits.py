from __future__ import annotations

from datetime import date
from typing import Optional, Union

from pydantic import BaseModel


class HabitResponse(BaseModel):
    id: str
    name: str
    type: str
    description: Optional[str]
    default_on: bool = True
    icon: Optional[str]
    value: Union[bool, int] = False  # Support both boolean and integer
    value_type: str = "boolean"
    last_check_in: Optional[str]


class HabitCheckinRequest(BaseModel):
    habit_id: str
    value: Union[bool, int]  # Support both boolean and integer
    local_date: Optional[date] = None


class HabitCheckinResponse(HabitResponse):
    pass
