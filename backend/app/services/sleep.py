from __future__ import annotations

import statistics
from datetime import date

from app.services.habits import HabitService
from app.services.garmin import GarminConnectService
from app.services.storage import SleepSession, User, store


class SleepService:
    def __init__(
        self,
        habit_service: HabitService | None = None,
        garmin_service: GarminConnectService | None = None,
    ) -> None:
        self.store = store
        self.habits = habit_service or HabitService()
        self.garmin = garmin_service or GarminConnectService()

    async def connect_garmin(
        self,
        user: User,
        *,
        email: str | None = None,
        password: str | None = None,
        mfa_code: str | None = None,
        mfa_token: str | None = None,
    ) -> dict:
        result = self.garmin.connect(
            user=user,
            email=email,
            password=password,
            mfa_code=mfa_code,
            mfa_token=mfa_token,
        )

        if result.get("connected") and not result.get("mfa_required"):
            result["summary"] = self.get_summary(user)
        else:
            result.pop("summary", None)
        return result

    async def pull_latest(self, user: User, days: int = 30) -> dict:
        self.garmin.sync_recent_sleep(user=user, days=days)
        summary = self.get_summary(user)
        return summary

    def add_manual_entry(
        self,
        user: User,
        local_date: date,
        sleep_score: int,
        bedtime: str,
        wake_time: str,
        duration_minutes: int,
    ) -> dict:
        """Manually add or update a sleep entry."""
        session = SleepSession(
            user_id=user.id,
            date=local_date,
            duration_minutes=duration_minutes,
            sleep_score=sleep_score,
            bedtime=bedtime,
            wake_time=wake_time,
            stage_minutes={},  # No stage data for manual entries
        )
        self.store.upsert_sleep_session(user.id, session)
        return self.get_summary(user)

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

    def get_analytics(self, user: User) -> dict:
        """Calculate correlations between habits and sleep quality."""
        sessions = self.store.list_sleep_sessions(user.id)
        print(f"[DEBUG] Analytics for user {user.id}: Found {len(sessions)} sleep sessions")
        
        if len(sessions) < 7:
            return {"correlations": [], "message": "Need at least 7 nights of data"}

        # Get all habit checkins (without date filter to get all history)
        all_checkins = self.store.list_checkins(user.id)
        print(f"[DEBUG] Found {len(all_checkins)} habit checkins")
        
        # Group checkins by date and habit
        checkins_by_date = {}
        for checkin in all_checkins:
            if checkin.local_date not in checkins_by_date:
                checkins_by_date[checkin.local_date] = {}
            checkins_by_date[checkin.local_date][checkin.habit_id] = checkin.value

        # Get all habits to lookup names
        all_habits = self.store.list_habits(user.id)
        habits_by_id = {h.id: h for h in all_habits}

        # Get unique habit IDs that have been checked in
        habit_ids = set()
        for date_checkins in checkins_by_date.values():
            habit_ids.update(date_checkins.keys())
        
        print(f"[DEBUG] Unique habit IDs found: {habit_ids}")
        print(f"[DEBUG] Available habits in system: {list(habits_by_id.keys())}")

        # Calculate average sleep score with/without each habit
        correlations = []
        for habit_id in habit_ids:
            habit = habits_by_id.get(habit_id)
            if not habit:
                print(f"[DEBUG] Skipping unknown habit ID: {habit_id}")
                continue

            scores_with = []
            scores_without = []

            for session in sessions:
                if session.sleep_score is None:
                    continue
                
                date_checkins = checkins_by_date.get(session.date, {})
                habit_value = date_checkins.get(habit_id)

                # Handle both boolean and numeric values
                # If habit was not logged for this date, assume it wasn't done (False/0)
                if habit_value is None:
                    # Not logged = didn't do it
                    scores_without.append(session.sleep_score)
                elif isinstance(habit_value, bool):
                    if habit_value:
                        scores_with.append(session.sleep_score)
                    else:
                        scores_without.append(session.sleep_score)
                else:  # numeric value (like alcohol count)
                    if habit_value > 0:
                        scores_with.append(session.sleep_score)
                    else:
                        scores_without.append(session.sleep_score)
            
            print(f"[DEBUG] Habit {habit.name}: {len(scores_with)} with, {len(scores_without)} without")

            # Need at least 3 data points in each group
            if len(scores_with) >= 3 and len(scores_without) >= 3:
                avg_with = statistics.mean(scores_with)
                avg_without = statistics.mean(scores_without)
                difference = avg_with - avg_without

                correlations.append({
                    "habit_id": habit_id,
                    "habit_name": habit.name,
                    "habit_type": habit.type,
                    "avg_score_with_habit": round(avg_with, 1),
                    "avg_score_without_habit": round(avg_without, 1),
                    "difference": round(difference, 1),
                    "sample_size_with": len(scores_with),
                    "sample_size_without": len(scores_without),
                })

        # Sort by absolute difference (biggest impact first)
        correlations.sort(key=lambda x: abs(x["difference"]), reverse=True)

        return {"correlations": correlations}

    def get_timeline(self, user: User, range_type: str = "week") -> dict:
        """Get sleep timeline data for visualization."""
        sessions = self.store.list_sleep_sessions(user.id)
        
        # Determine how many days to include
        if range_type == "year":
            limit = 365
        elif range_type == "month":
            limit = 30
        else:  # week
            limit = 7
        
        # Take the most recent sessions up to the limit
        recent_sessions = sessions[:limit]
        
        timeline_data = []
        for session in reversed(recent_sessions):  # Reverse to show oldest first
            timeline_data.append({
                "date": session.date.isoformat(),
                "bedtime": session.bedtime,
                "wake_time": session.wake_time,
                "duration_minutes": session.duration_minutes,
                "sleep_score": session.sleep_score,
                "stage_minutes": session.stage_minutes,
            })
        
        return {
            "range": range_type,
            "timeline": timeline_data,
            "total_sessions": len(timeline_data),
        }

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
