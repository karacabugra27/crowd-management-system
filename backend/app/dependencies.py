"""FastAPI dependencies: current user, admin check, scanner API-key auth."""
from datetime import datetime, timezone
from typing import Optional

from fastapi import Depends, Header
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import credentials_error, forbidden, invalid_api_key
from app.core.security import ACCESS_TOKEN_TYPE, JWTError, decode_token
from app.database import get_db
from app.models.scanner import Scanner
from app.models.user import User

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/auth/login", auto_error=False)


async def get_current_user(
    token: Optional[str] = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db),
) -> User:
    """Resolve the bearer token to an active `User`."""
    if not token:
        raise credentials_error("Missing bearer token")
    try:
        payload = decode_token(token)
    except JWTError as exc:
        raise credentials_error() from exc

    if payload.get("type") != ACCESS_TOKEN_TYPE:
        raise credentials_error("Wrong token type")

    sub = payload.get("sub")
    if not sub:
        raise credentials_error()

    user = await db.get(User, int(sub))
    if user is None or not user.is_active:
        raise credentials_error("User not found or inactive")
    return user


async def get_current_admin(user: User = Depends(get_current_user)) -> User:
    """Require an authenticated user whose role is `admin`."""
    if user.role != "admin":
        raise forbidden("Admin role required")
    return user


async def get_scanner_by_api_key(
    x_api_key: Optional[str] = Header(default=None, alias="X-API-Key"),
    db: AsyncSession = Depends(get_db),
) -> Scanner:
    """Authenticate a request by the `X-API-Key` header.

    Updates the scanner's `last_seen` timestamp on each successful call.
    """
    if not x_api_key:
        raise invalid_api_key()

    result = await db.execute(select(Scanner).where(Scanner.api_key == x_api_key))
    scanner = result.scalar_one_or_none()
    if scanner is None or not scanner.is_active:
        raise invalid_api_key()

    scanner.last_seen = datetime.now(timezone.utc)
    await db.flush()
    return scanner
