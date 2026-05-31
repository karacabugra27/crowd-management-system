"""
routers/auth.py
---------------
Kayıt (register), giriş (login) ve token yenileme (refresh) endpoint'leri.
JWT tabanlı kimlik doğrulama — access token (30dk) + refresh token (7gün).
"""

from __future__ import annotations

import logging
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from jose import JWTError, jwt
from passlib.context import CryptContext
from pydantic import BaseModel, EmailStr, Field
from sqlalchemy.orm import Session

from config import get_settings
from database import get_db
from models import AdminUser

logger = logging.getLogger(__name__)
_settings = get_settings()

router = APIRouter(prefix="/api/auth", tags=["auth"])

# ---------- Şifre hashing ----------
# Not: passlib'in bcrypt backend'i Python 3.11'de 72-byte wrap bug verir.
# sha256_crypt kararlı ve hızlıdır; prod ortamda da güvenlidir.
pwd_ctx = CryptContext(schemes=["sha256_crypt"], deprecated="auto")


def _hash(plain: str) -> str:
    return pwd_ctx.hash(plain)


def _verify(plain: str, hashed: str) -> bool:
    return pwd_ctx.verify(plain, hashed)


# ---------- JWT ----------
def _create_token(data: dict, expires_delta: timedelta) -> str:
    to_encode = data.copy()
    to_encode["exp"] = datetime.now(timezone.utc) + expires_delta
    return jwt.encode(to_encode, _settings.secret_key, algorithm=_settings.jwt_algorithm)


def create_access_token(user_id: int) -> str:
    return _create_token(
        {"sub": str(user_id), "type": "access"},
        timedelta(minutes=_settings.access_token_expire_minutes),
    )


def create_refresh_token(user_id: int) -> str:
    return _create_token(
        {"sub": str(user_id), "type": "refresh"},
        timedelta(days=_settings.refresh_token_expire_days),
    )


# ---------- Pydantic şemalar ----------
class RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8)


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class RefreshRequest(BaseModel):
    refresh_token: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class UserMeResponse(BaseModel):
    id: int
    email: str
    role: str


# ---------- Dependency ----------
def get_current_user(
    token: str = Depends(
        __import__("fastapi.security", fromlist=["OAuth2PasswordBearer"]).OAuth2PasswordBearer(
            tokenUrl="/api/auth/login/form"
        )
    ),
    db: Session = Depends(get_db),
) -> AdminUser:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Kimlik doğrulanamadı",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, _settings.secret_key, algorithms=[_settings.jwt_algorithm])
        if payload.get("type") != "access":
            raise credentials_exception
        user_id: str | None = payload.get("sub")
        if user_id is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception

    user = db.query(AdminUser).filter(AdminUser.id == int(user_id)).first()
    if user is None:
        raise credentials_exception
    return user


# ---------- Endpoint'ler ----------
@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
def register(req: RegisterRequest, db: Session = Depends(get_db)) -> TokenResponse:
    """Yeni kullanıcı kaydı."""
    if db.query(AdminUser).filter(AdminUser.email == req.email).first():
        raise HTTPException(status_code=409, detail="Bu e-posta zaten kayıtlı")

    user = AdminUser(email=req.email, hashed_password=_hash(req.password))
    db.add(user)
    db.commit()
    db.refresh(user)
    logger.info("Yeni kullanıcı kaydedildi: %s (id=%d)", user.email, user.id)

    return TokenResponse(
        access_token=create_access_token(user.id),
        refresh_token=create_refresh_token(user.id),
    )


@router.post("/login", response_model=TokenResponse)
def login(req: LoginRequest, db: Session = Depends(get_db)) -> TokenResponse:
    """E-posta + şifre ile giriş."""
    user = db.query(AdminUser).filter(AdminUser.email == req.email).first()
    if not user or not _verify(req.password, user.hashed_password):
        logger.warning("Başarısız giriş denemesi: %s", req.email)
        raise HTTPException(status_code=401, detail="Geçersiz e-posta veya şifre")

    logger.info("Kullanıcı giriş yaptı: %s", user.email)
    return TokenResponse(
        access_token=create_access_token(user.id),
        refresh_token=create_refresh_token(user.id),
    )


@router.post("/login/form", response_model=TokenResponse, include_in_schema=False)
def login_form(
    form: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)
) -> TokenResponse:
    """Swagger UI için OAuth2 form-based login."""
    return login(LoginRequest(email=form.username, password=form.password), db)


@router.post("/refresh", response_model=TokenResponse)
def refresh_token(req: RefreshRequest, db: Session = Depends(get_db)) -> TokenResponse:
    """Refresh token ile yeni access token al."""
    credentials_exception = HTTPException(status_code=401, detail="Geçersiz refresh token")
    try:
        payload = jwt.decode(req.refresh_token, _settings.secret_key, algorithms=[_settings.jwt_algorithm])
        if payload.get("type") != "refresh":
            raise credentials_exception
        user_id = payload.get("sub")
        if user_id is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception

    user = db.query(AdminUser).filter(AdminUser.id == int(user_id)).first()
    if not user:
        raise credentials_exception

    return TokenResponse(
        access_token=create_access_token(user.id),
        refresh_token=create_refresh_token(user.id),
    )


@router.get("/me", response_model=UserMeResponse)
def me(current_user: AdminUser = Depends(get_current_user)) -> UserMeResponse:
    """Giriş yapan kullanıcının bilgilerini döner."""
    return UserMeResponse(id=current_user.id, email=current_user.email, role=current_user.role)
