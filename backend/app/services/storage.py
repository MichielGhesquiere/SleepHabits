from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date, datetime
from typing import Dict, List, Optional


@dataclass
class User:
    id: str
    email: str
    timezone: str = "UTC"
    garmin_connected: bool = False
    created_at: datetime = field(default_factory=datetime.utcnow)


@dataclass
class Habit:
    id: str
    name: str
    type: str  # healthy | unhealthy
    description: Optional[str] = None
    default_on: bool = True
    icon: Optional[str] = None


@dataclass
class HabitCheckin:
    user_id: str
    habit_id: str
    local_date: date
    value: bool
    timestamp: datetime = field(default_factory=datetime.utcnow)


@dataclass
class SleepSession:
    user_id: str
    date: date
    duration_minutes: int
    sleep_score: Optional[int]
    bedtime: str
    wake_time: str
    stage_minutes: Dict[str, int]


class InMemoryStore:
    def __init__(self) -> None:
        self.users: Dict[str, User] = {}
        self.habits: Dict[str, List[Habit]] = {}
        self.habit_checkins: Dict[tuple[str, date, str], HabitCheckin] = {}
        self.sleep_sessions: Dict[str, List[SleepSession]] = {}
        self.tokens: Dict[str, str] = {}

    # User operations --------------------------------------------------
    def upsert_user(self, user: User) -> User:
        self.users[user.id] = user
        return user

    def get_user(self, user_id: str) -> Optional[User]:
        return self.users.get(user_id)

    def get_user_by_email(self, email: str) -> Optional[User]:
        lowered = email.lower()
        for user in self.users.values():
            if user.email.lower() == lowered:
                return user
        return None

    # Habit operations -------------------------------------------------
    def list_habits(self, user_id: str) -> List[Habit]:
        return list(self.habits.get(user_id, []))

    def set_habits(self, user_id: str, habits: List[Habit]) -> None:
        self.habits[user_id] = habits

    def record_checkin(self, checkin: HabitCheckin) -> HabitCheckin:
        key = (checkin.user_id, checkin.local_date, checkin.habit_id)
        self.habit_checkins[key] = checkin
        return checkin

    def get_checkin(self, user_id: str, local_date: date, habit_id: str) -> Optional[HabitCheckin]:
        return self.habit_checkins.get((user_id, local_date, habit_id))

    def list_checkins(self, user_id: str, local_date: Optional[date] = None) -> List[HabitCheckin]:
        results = []
        for (uid, checkin_date, _), checkin in self.habit_checkins.items():
            if uid != user_id:
                continue
            if local_date and checkin_date != local_date:
                continue
            results.append(checkin)
        return results

    # Sleep operations -------------------------------------------------
    def add_sleep_sessions(self, user_id: str, sessions: List[SleepSession]) -> None:
        existing = self.sleep_sessions.setdefault(user_id, [])
        existing.extend(sessions)
        existing.sort(key=lambda s: s.date, reverse=True)

    def overwrite_sleep_sessions(self, user_id: str, sessions: List[SleepSession]) -> None:
        self.sleep_sessions[user_id] = sorted(sessions, key=lambda s: s.date, reverse=True)

    def list_sleep_sessions(self, user_id: str) -> List[SleepSession]:
        return list(self.sleep_sessions.get(user_id, []))

    # Token operations -------------------------------------------------
    def store_token(self, token: str, user_id: str) -> None:
        self.tokens[token] = user_id

    def resolve_token(self, token: str) -> Optional[str]:
        return self.tokens.get(token)


store = InMemoryStore()
