from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date, datetime
from typing import Any, Dict, List, Optional, Union


@dataclass
class User:
    id: str
    email: str
    timezone: str = "UTC"
    garmin_connected: bool = False
    created_at: datetime = field(default_factory=datetime.utcnow)


@dataclass
class GarminAccount:
    user_id: str
    email: str
    token_path: str
    display_name: Optional[str] = None
    last_synced_at: Optional[datetime] = None
    created_at: datetime = field(default_factory=datetime.utcnow)


@dataclass
class GarminMFASession:
    token: str
    user_id: str
    email: str
    created_at: datetime = field(default_factory=datetime.utcnow)
    client_state: Dict[str, Any] = field(default_factory=dict)
    garmin_object: Any = field(repr=False, default=None)


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
    value: Union[bool, int]  # Support both boolean and integer values
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
        self.garmin_accounts: Dict[str, GarminAccount] = {}
        self.garmin_mfa_sessions: Dict[str, GarminMFASession] = {}

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

    def upsert_sleep_session(self, user_id: str, session: SleepSession) -> None:
        """Add or update a sleep session for a specific date."""
        existing = self.sleep_sessions.setdefault(user_id, [])
        # Remove any existing session for this date
        existing[:] = [s for s in existing if s.date != session.date]
        # Add the new session
        existing.append(session)
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

    # Garmin credential operations ------------------------------------
    def set_garmin_account(self, account: GarminAccount) -> None:
        self.garmin_accounts[account.user_id] = account

    def get_garmin_account(self, user_id: str) -> Optional[GarminAccount]:
        return self.garmin_accounts.get(user_id)

    def delete_garmin_account(self, user_id: str) -> None:
        self.garmin_accounts.pop(user_id, None)

    def save_mfa_session(self, session: GarminMFASession) -> None:
        self.garmin_mfa_sessions[session.token] = session

    def pop_mfa_session(self, token: str) -> Optional[GarminMFASession]:
        return self.garmin_mfa_sessions.pop(token, None)


store = InMemoryStore()
