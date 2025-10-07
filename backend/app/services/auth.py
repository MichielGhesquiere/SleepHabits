from __future__ import annotations

import secrets
import uuid

from app.schemas.auth import LoginRequest, LoginResponse
from app.services.habits import HabitService
from app.services.storage import User, store


class AuthService:
    def __init__(self, habit_service: HabitService | None = None) -> None:
        self.store = store
        self.habits = habit_service or HabitService()

    async def login(self, payload: LoginRequest) -> LoginResponse:
        user = self.store.get_user_by_email(payload.email)
        if not user:
            user = User(id=str(uuid.uuid4()), email=payload.email)
        self.store.upsert_user(user)
        self.habits.ensure_defaults(user)
        token = secrets.token_urlsafe(32)
        self.store.store_token(token, user.id)
        return LoginResponse(
            access_token=token,
            email=user.email,
            user_id=user.id,
            garmin_connected=user.garmin_connected,
        )


def get_auth_service() -> AuthService:
    return AuthService()
