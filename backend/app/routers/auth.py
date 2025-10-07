from fastapi import APIRouter, Depends

from app.schemas.auth import LoginRequest, LoginResponse
from app.services.auth import AuthService, get_auth_service

router = APIRouter()


@router.post("/login", response_model=LoginResponse)
async def login(
    payload: LoginRequest,
    service: AuthService = Depends(get_auth_service),
) -> LoginResponse:
    return await service.login(payload)
