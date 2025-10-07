from __future__ import annotations

import json
import statistics
from datetime import date
from pathlib import Path
from typing import List

from app.services.habits import HabitService
from app.services.storage import SleepSession, User, store

DATA_DIR = Path(__file__).resolve().parent.parent / "data"


class SleepService:
    def __init__(self, habit_service: HabitService | None = None) -> None:
        self.store = store
        self.habits = habit_service or HabitService()

    def connect_garmin(self, user: User) -> dict:
        if not user.garmin_connected:
            user.garmin_connected = True
            self.store.upsert_user(user)
        sessions = self._load_sample_sessions(user.id)
        self.store.overwrite_sleep_sessions(user.id, sessions)
        summary = self.get_summary(user)
        return {
            "connected": True,
            "message": "Garmin connected (sample data loaded).",
            "summary": summary,
        }

    def pull_latest(self, user: User) -> dict:
        # For the prototype we simply reload the sample dataset.
        sessions = self._load_sample_sessions(user.id)
        self.store.overwrite_sleep_sessions(user.id, sessions)
        summary = self.get_summary(user)
        return summary

    def get_summary(self, user: User) -> dict:
        sessions = self.store.list_sleep_sessions(user.id)
        if not sessions:
            return {
                "user": {
                    "email": user.email,
                    "garmin_connected": user.garmin_connected,
                },
                "last_night": None,
                "trailing_7d": None,
                "habits": self._habit_snapshot(user, date.today()),
            }

        last_night = sessions[0]
        trailing = sessions[:7]

        avg_duration = statistics.mean(s.duration_minutes for s in trailing)
        score_values = [s.sleep_score for s in trailing if s.sleep_score is not None]
        avg_score = statistics.mean(score_values) if score_values else None
        midpoint_minutes = statistics.mean(
            (self._clock_to_minutes(s.bedtime) + s.duration_minutes / 2)
            % (24 * 60)
            for s in trailing
        )
        consistency = statistics.pstdev(
            self._clock_to_minutes(s.bedtime) for s in trailing
        )

        summary = {
            "user": {
                "email": user.email,
                "garmin_connected": user.garmin_connected,
            },
            "last_night": {
                "date": last_night.date.isoformat(),
                "duration_minutes": last_night.duration_minutes,
                "sleep_score": last_night.sleep_score,
                "bedtime": last_night.bedtime,
                "wake_time": last_night.wake_time,
                "stages": last_night.stage_minutes,
            },
            "trailing_7d": {
                "avg_duration_minutes": avg_duration,
                "avg_score": avg_score,
                "midpoint": self._minutes_to_clock(int(midpoint_minutes)),
                "consistency_minutes": int(consistency),
            },
            "habits": self._habit_snapshot(user, last_night.date),
        }
        return summary

    def _habit_snapshot(self, user: User, target_date: date) -> dict:
        habits = self.habits.get_habits(user, target_date)
        positive = [h for h in habits if h["type"] == "healthy"]
        negative = [h for h in habits if h["type"] == "unhealthy"]
        return {
            "positive_completed": sum(1 for h in positive if bool(h["value"])),
            "positive_total": len(positive),
            "negative_completed": sum(1 for h in negative if not bool(h["value"])),
            "negative_total": len(negative),
        }

    def _load_sample_sessions(self, user_id: str) -> List[SleepSession]:
        sample_file = DATA_DIR / "sample_garmin_sleep.json"
        payload = json.loads(sample_file.read_text())
        sessions = []
        for item in payload.get("sleep_sessions", []):
            sessions.append(
                SleepSession(
                    user_id=user_id,
                    date=date.fromisoformat(item["date"]),
                    duration_minutes=int(item["duration_minutes"]),
                    sleep_score=item.get("sleep_score"),
                    bedtime=item.get("bedtime", "22:30"),
                    wake_time=item.get("wake_time", "06:30"),
                    stage_minutes={
                        key: int(value) for key, value in item.get("stage_minutes", {}).items()
                    },
                )
            )
        return sessions

    @staticmethod
    def _clock_to_minutes(value: str) -> int:
        parts = value.split(":")
        hour = int(parts[0])
        minute = int(parts[1]) if len(parts) > 1 else 0
        return hour * 60 + minute

    @staticmethod
    def _minutes_to_clock(value: int) -> str:
        value = value % (24 * 60)
        hour = value // 60
        minute = value % 60
        return f"{hour:02d}:{minute:02d}"


def get_sleep_service() -> SleepService:
    return SleepService()
