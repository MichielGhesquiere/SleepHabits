from __future__ import annotations

import json
import os
import uuid
from datetime import UTC, date, datetime, timedelta
from pathlib import Path
from typing import Any

import requests
from garminconnect import (
    Garmin,
    GarminConnectAuthenticationError,
    GarminConnectConnectionError,
    GarminConnectTooManyRequestsError,
)
from garth.data import SleepData

from app.services.storage import (
    GarminAccount,
    GarminMFASession,
    SleepSession,
    User,
    store,
)


class GarminConnectError(Exception):
    """Base error for Garmin Connect integration."""


class GarminMFARequired(GarminConnectError):
    """Raised when MFA is required to complete login."""

    def __init__(self, token: str) -> None:
        super().__init__("MFA verification required")
        self.token = token


class GarminConnectService:
    """Integrates with python-garminconnect for credential-based syncing."""

    def __init__(self) -> None:
        self.store = store
        self.base_dir = Path(__file__).resolve().parent.parent / "data"
        self.token_root = self.base_dir / "garmin_tokens"
        self.token_root.mkdir(parents=True, exist_ok=True)
        self.sample_file = self.base_dir / "sample_garmin_sleep.json"
        self.allow_sample = os.getenv("GARMIN_SAMPLE_MODE", "1") != "0"

    # ------------------------------------------------------------------
    def connect(
        self,
        *,
        user: User,
        email: str | None = None,
        password: str | None = None,
        mfa_code: str | None = None,
        mfa_token: str | None = None,
    ) -> dict[str, Any]:
        """Connect using Garmin credentials or resume an MFA challenge."""

        if mfa_token:
            return self._complete_mfa(user=user, token=mfa_token, code=mfa_code)

        if not email or not password:
            raise GarminConnectError("Email and password are required for Garmin connect")

        garmin = Garmin(email=email, password=password, return_on_mfa=True)

        try:
            result = garmin.login()
            if result and isinstance(result, tuple) and result[0] == "needs_mfa":
                token = self._store_mfa_session(user=user, email=email, garmin=garmin, client_state=result[1])
                raise GarminMFARequired(token)

            # Successful credential login; persist tokens
            self._persist_tokens(user=user, garmin=garmin, email=email)
            sessions = self.sync_recent_sleep(user=user, days=30)
            return {
                "connected": True,
                "mfa_required": False,
                "summary": sessions,
                "message": "Garmin account connected successfully.",
            }

        except GarminMFARequired as exc:
            return {
                "connected": False,
                "mfa_required": True,
                "mfa_token": exc.token,
                "message": "Multi-factor authentication required. Please supply the verification code.",
            }
        except (GarminConnectAuthenticationError, GarminConnectTooManyRequestsError) as exc:
            if not self.allow_sample:
                raise GarminConnectError(str(exc))
            summary = self._load_sample_data(user)
            return {
                "connected": True,
                "mfa_required": False,
                "summary": summary,
                "message": "Garmin login failed; loaded bundled sample dataset for demo mode.",
            }
        except (GarminConnectConnectionError, requests.exceptions.RequestException) as exc:
            if not self.allow_sample:
                raise GarminConnectError(str(exc))
            summary = self._load_sample_data(user)
            return {
                "connected": True,
                "mfa_required": False,
                "summary": summary,
                "message": "Garmin service unreachable; loaded bundled sample dataset for demo mode.",
            }

    # ------------------------------------------------------------------
    def _complete_mfa(
        self,
        *,
        user: User,
        token: str,
        code: str | None,
    ) -> dict[str, Any]:
        if not code:
            raise GarminConnectError("MFA code is required")

        session = self.store.pop_mfa_session(token)
        if not session:
            raise GarminConnectError("Invalid or expired MFA session")

        garmin = session.garmin_object
        client_state = session.client_state
        try:
            garmin.resume_login(client_state, code)
            self._persist_tokens(user=user, garmin=garmin, email=session.email)
            sessions = self.sync_recent_sleep(user=user, days=30)
            return {
                "connected": True,
                "mfa_required": False,
                "summary": sessions,
                "message": "Garmin account connected after MFA verification.",
            }
        except (GarminConnectAuthenticationError, GarminConnectConnectionError) as exc:
            raise GarminConnectError(f"Failed to complete MFA: {exc}") from exc

    # ------------------------------------------------------------------
    def sync_recent_sleep(self, *, user: User, days: int = 30) -> list[SleepSession]:
        account = self.store.get_garmin_account(user.id)
        if not account:
            if self.allow_sample:
                return self._load_sample_data(user)
            raise GarminConnectError("Garmin account not connected")

        token_path = Path(account.token_path)
        garmin = Garmin()
        try:
            garmin.login(str(token_path))
        except Exception as exc:
            if not self.allow_sample:
                raise GarminConnectError(f"Failed to use stored tokens: {exc}") from exc
            return self._load_sample_data(user)

        sessions: list[SleepSession] = []
        today = datetime.now(tz=UTC).astimezone()
        for offset in range(days):
            target_date = (today - timedelta(days=offset)).date()
            data = self._fetch_sleep_dataclass(garmin, target_date)
            if not data:
                continue
            dto = data.daily_sleep_dto
            
            # Debug logging for Garmin data
            print(f"\n[GARMIN DEBUG] Sleep data for {target_date}")
            print(f"  Calendar Date: {dto.calendar_date}")
            print(f"  Sleep Start: {dto.sleep_start}")
            print(f"  Sleep End: {dto.sleep_end}")
            print(f"  Sleep Time (seconds): {dto.sleep_time_seconds}")
            print(f"  Deep Sleep (seconds): {dto.deep_sleep_seconds}")
            print(f"  Light Sleep (seconds): {dto.light_sleep_seconds}")
            print(f"  REM Sleep (seconds): {dto.rem_sleep_seconds}")
            print(f"  Awake (seconds): {dto.awake_sleep_seconds}")
            if dto.sleep_scores:
                print(f"  Overall Score: {dto.sleep_scores.overall.value}")
                print(f"  Sleep Quality: {getattr(dto.sleep_scores, 'quality_score', 'N/A')}")
                print(f"  Sleep Recovery: {getattr(dto.sleep_scores, 'recovery_score', 'N/A')}")
                print(f"  Sleep Duration: {getattr(dto.sleep_scores, 'duration_score', 'N/A')}")
            print(f"  Validation: {getattr(dto, 'validation', 'N/A')}")
            print(f"  Naps (if any): {getattr(data, 'naps', 'N/A')}")
            print(f"  Available attributes: {dir(dto)}")
            
            duration_minutes = int(dto.sleep_time_seconds / 60) if dto.sleep_time_seconds else 0
            session = SleepSession(
                user_id=user.id,
                date=dto.calendar_date,
                duration_minutes=duration_minutes,
                sleep_score=(dto.sleep_scores.overall.value if dto.sleep_scores else None),
                bedtime=dto.sleep_start.strftime("%H:%M"),
                wake_time=dto.sleep_end.strftime("%H:%M"),
                stage_minutes={
                    "deep": int((dto.deep_sleep_seconds or 0) / 60),
                    "light": int((dto.light_sleep_seconds or 0) / 60),
                    "rem": int((dto.rem_sleep_seconds or 0) / 60),
                    "awake": int((dto.awake_sleep_seconds or 0) / 60),
                },
            )
            sessions.append(session)

        if sessions:
            self.store.overwrite_sleep_sessions(user.id, sessions)
            account.last_synced_at = datetime.now(tz=UTC)
            self.store.set_garmin_account(account)
        return sessions

    # ------------------------------------------------------------------
    def _persist_tokens(self, *, user: User, garmin: Garmin, email: str) -> None:
        token_dir = self._token_root_for(user)
        garmin.garth.dump(str(token_dir))

        account = GarminAccount(
            user_id=user.id,
            email=email,
            token_path=str(token_dir),
            display_name=getattr(garmin, "display_name", None),
            last_synced_at=datetime.now(tz=UTC),
        )
        self.store.set_garmin_account(account)
        user.garmin_connected = True
        self.store.upsert_user(user)

    def _store_mfa_session(
        self,
        *,
        user: User,
        email: str,
        garmin: Garmin,
        client_state: dict[str, Any],
    ) -> str:
        token = uuid.uuid4().hex
        session = GarminMFASession(
            token=token,
            user_id=user.id,
            email=email,
            client_state=client_state,
            garmin_object=garmin,
        )
        self.store.save_mfa_session(session)
        return token

    def _fetch_sleep_dataclass(self, garmin: Garmin, day: date) -> SleepData | None:
        try:
            return SleepData.get(day.isoformat(), client=garmin.garth)
        except Exception:
            return None

    def _token_root_for(self, user: User) -> Path:
        path = self.token_root / user.id
        path.mkdir(parents=True, exist_ok=True)
        return path

    def _load_sample_data(self, user: User) -> list[SleepSession]:
        if not self.sample_file.exists():
            return []
        payload = json.loads(self.sample_file.read_text())
        sessions: list[SleepSession] = []
        for item in payload.get("sleep_sessions", []):
            sessions.append(
                SleepSession(
                    user_id=user.id,
                    date=datetime.fromisoformat(item["date"]).date(),
                    duration_minutes=int(item.get("duration_minutes", 0)),
                    sleep_score=item.get("sleep_score"),
                    bedtime=item.get("bedtime", "22:30"),
                    wake_time=item.get("wake_time", "06:30"),
                    stage_minutes={
                        key: int(value) for key, value in item.get("stage_minutes", {}).items()
                    },
                )
            )
        if sessions:
            self.store.overwrite_sleep_sessions(user.id, sessions)
        return sessions


def get_garmin_service() -> GarminConnectService:
    return GarminConnectService()
