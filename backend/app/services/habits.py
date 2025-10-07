from __future__ import annotations

from datetime import date, datetime

from app.services.storage import Habit, HabitCheckin, User, store

DEFAULT_HABITS = [
    Habit(
        id="habit-read",
        name="Read ≥15 minutes",
        type="healthy",
        description="Wind down with a book before bed.",
    ),
    Habit(
        id="habit-meditate",
        name="Meditate ≥10 minutes",
        type="healthy",
        description="Reduce stress with a short mindfulness session.",
    ),
    Habit(
        id="habit-no-screens",
        name="No screens last hour",
        type="healthy",
        description="Avoid blue light right before bed.",
    ),
    Habit(
        id="habit-consistent-bedtime",
        name="Bedtime between 22:30-23:30",
        type="healthy",
        description="Aim for a consistent bedtime window.",
    ),
    Habit(
        id="habit-no-alcohol",
        name="No alcohol tonight",
        type="healthy",
        description="Skip alcohol to improve recovery.",
    ),
    Habit(
        id="habit-no-caffeine",
        name="No caffeine after 14:00",
        type="unhealthy",
        description="Late caffeine often delays sleep.",
    ),
    Habit(
        id="habit-heavy-meal",
        name="Large meal <3h before bed",
        type="unhealthy",
        description="Heavy meals close to bedtime can disrupt sleep.",
    ),
    Habit(
        id="habit-late-screens",
        name="Screens in last hour",
        type="unhealthy",
        description="Track if screens crept back in.",
    ),
    Habit(
        id="habit-late-bedtime",
        name="Bedtime after midnight",
        type="unhealthy",
        description="Notice when bedtime slips later.",
    ),
]


class HabitService:
    def __init__(self) -> None:
        self.store = store

    def ensure_defaults(self, user: User) -> None:
        if self.store.list_habits(user.id):
            return
        cloned = [
            Habit(
                id=habit.id,
                name=habit.name,
                type=habit.type,
                description=habit.description,
                default_on=habit.default_on,
                icon=habit.icon,
            )
            for habit in DEFAULT_HABITS
        ]
        self.store.set_habits(user.id, cloned)

    def get_habits(self, user: User, target_date: date | None = None) -> list[dict]:
        self.ensure_defaults(user)
        target_date = target_date or date.today()
        results: list[dict] = []
        for habit in self.store.list_habits(user.id):
            checkin = self.store.get_checkin(user.id, target_date, habit.id)
            results.append(
                {
                    "id": habit.id,
                    "name": habit.name,
                    "type": habit.type,
                    "description": habit.description,
                    "default_on": habit.default_on,
                    "icon": habit.icon,
                    "value": checkin.value if checkin else False,
                    "value_type": "boolean",
                    "last_check_in": checkin.timestamp.isoformat()
                    if checkin
                    else None,
                }
            )
        return results

    def check_in(
        self,
        user: User,
        habit_id: str,
        value: bool,
        target_date: date | None = None,
    ) -> dict:
        target_date = target_date or date.today()
        self.ensure_defaults(user)
        stored = self.store.get_checkin(user.id, target_date, habit_id)
        if stored:
            stored.value = value
            stored.timestamp = datetime.utcnow()
            checkin = stored
        else:
            checkin = HabitCheckin(
                user_id=user.id,
                habit_id=habit_id,
                local_date=target_date,
                value=value,
                timestamp=datetime.utcnow(),
            )
            self.store.record_checkin(checkin)
        for habit in self.store.list_habits(user.id):
            if habit.id == habit_id:
                break
        else:
            habit = Habit(
                id=habit_id,
                name=habit_id,
                type="healthy",
            )
            habits = self.store.list_habits(user.id)
            habits.append(habit)
            self.store.set_habits(user.id, habits)
        return {
            "id": habit.id,
            "name": habit.name,
            "type": habit.type,
            "description": habit.description,
            "default_on": habit.default_on,
            "icon": habit.icon,
            "value": checkin.value,
            "value_type": "boolean",
            "last_check_in": checkin.timestamp.isoformat(),
        }


def get_habit_service() -> HabitService:
    return HabitService()
