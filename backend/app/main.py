from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .routers import auth, garmin, me


def create_app() -> FastAPI:
    app = FastAPI(
        title="SleepHabits API",
        version="0.0.1",
        description="Proof-of-concept API for SleepHabits.",
    )

    # Add CORS middleware to allow web app to communicate with API
    # Note: For development only. In production, specify exact origins.
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=False,  # Must be False when allow_origins is "*"
        allow_methods=["*"],
        allow_headers=["*"],
        expose_headers=["*"],
    )

    app.include_router(auth.router, prefix="/auth", tags=["auth"])
    app.include_router(me.router, prefix="/me", tags=["me"])
    app.include_router(garmin.router)

    @app.get("/health", tags=["health"])  # pragma: no cover - trivial
    async def healthcheck() -> dict[str, str]:
        return {"status": "ok"}

    return app


app = create_app()
