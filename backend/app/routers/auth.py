"""/api/auth — registration, login, refresh."""
from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.schemas.user import (
    AccessToken,
    LoginRequest,
    RefreshRequest,
    TokenPair,
    UserCreate,
)
from app.services import auth_service

router = APIRouter(prefix="/api/auth", tags=["auth"])


@router.post(
    "/register",
    response_model=TokenPair,
    status_code=status.HTTP_201_CREATED,
    summary="Register a new user and return a token pair",
)
async def register(
    payload: UserCreate, db: AsyncSession = Depends(get_db)
) -> TokenPair:
    user = await auth_service.register_user(db, payload)
    access, refresh = auth_service.issue_token_pair(user)
    return TokenPair(access_token=access, refresh_token=refresh)


@router.post("/login", response_model=TokenPair, summary="Email/password login")
async def login(
    payload: LoginRequest, db: AsyncSession = Depends(get_db)
) -> TokenPair:
    user = await auth_service.authenticate(db, payload.email, payload.password)
    access, refresh = auth_service.issue_token_pair(user)
    return TokenPair(access_token=access, refresh_token=refresh)


@router.post(
    "/refresh", response_model=AccessToken, summary="Exchange refresh token for access"
)
async def refresh(
    payload: RefreshRequest, db: AsyncSession = Depends(get_db)
) -> AccessToken:
    access = await auth_service.refresh_access_token(db, payload.refresh_token)
    return AccessToken(access_token=access)
