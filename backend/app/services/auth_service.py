"""Auth business logic — user registration, login, refresh."""
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import conflict, credentials_error
from app.core.security import (
    REFRESH_TOKEN_TYPE,
    JWTError,
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_password,
    verify_password,
)
from app.models.user import User
from app.schemas.user import UserCreate


async def register_user(db: AsyncSession, payload: UserCreate) -> User:
    """Create a new user, enforcing email uniqueness."""
    existing = await db.execute(select(User).where(User.email == payload.email))
    if existing.scalar_one_or_none():
        raise conflict("Email already registered")

    user = User(
        email=payload.email,
        hashed_password=hash_password(payload.password),
        role="user",
        is_active=True,
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return user


async def authenticate(db: AsyncSession, email: str, password: str) -> User:
    """Return the user matching `email`/`password` or raise 401."""
    result = await db.execute(select(User).where(User.email == email))
    user = result.scalar_one_or_none()
    if user is None or not verify_password(password, user.hashed_password):
        raise credentials_error("Invalid email or password")
    if not user.is_active:
        raise credentials_error("User is inactive")
    return user


def issue_token_pair(user: User) -> tuple[str, str]:
    """Mint an (access, refresh) token pair for `user`."""
    claims = {"role": user.role, "email": user.email}
    access = create_access_token(subject=str(user.id), extra_claims=claims)
    refresh = create_refresh_token(subject=str(user.id))
    return access, refresh


async def refresh_access_token(db: AsyncSession, refresh_token: str) -> str:
    """Validate a refresh token and mint a new access token."""
    try:
        payload = decode_token(refresh_token)
    except JWTError as exc:
        raise credentials_error("Invalid refresh token") from exc

    if payload.get("type") != REFRESH_TOKEN_TYPE:
        raise credentials_error("Wrong token type")

    sub = payload.get("sub")
    if not sub:
        raise credentials_error()

    user = await db.get(User, int(sub))
    if user is None or not user.is_active:
        raise credentials_error("User not found or inactive")

    return create_access_token(
        subject=str(user.id),
        extra_claims={"role": user.role, "email": user.email},
    )
