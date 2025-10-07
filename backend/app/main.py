from fastapi import FastAPI

from .routers import auth, me


def create_app() -> FastAPI:
    app = FastAPI(
        title="SleepHabits API",
        version="0.0.1",
        description="Proof-of-concept API for SleepHabits.",
    )

    app.include_router(auth.router, prefix="/auth", tags=["auth"])
    app.include_router(me.router, prefix="/me", tags=["me"])

    @app.get("/health", tags=["health"])  # pragma: no cover - trivial
    async def healthcheck() -> dict[str, str]:
        return {"status": "ok"}

    return app


app = create_app()
