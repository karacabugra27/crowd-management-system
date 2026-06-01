"""Idempotent database seeding for Crowdly.

Seeds:
  1. A default admin user (configurable via env vars).

Run from the project root once the database is reachable:

    python -m app.seed

The script is idempotent — re-running it never duplicates rows. It is safe
(and intended) to run on every container start, right after migrations.

Areas are managed exclusively through the admin panel.
"""
import asyncio
import logging
import os

from sqlalchemy import select

from app.core.security import hash_password
from app.database import AsyncSessionLocal
from app.models.user import User

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] seed: %(message)s",
)
log = logging.getLogger("crowdly.seed")

# ─── Defaults — override via environment variables ─────────────────
DEFAULT_ADMIN_EMAIL = os.getenv("SEED_ADMIN_EMAIL", "admin@gmail.com")
DEFAULT_ADMIN_PASSWORD = os.getenv("SEED_ADMIN_PASSWORD", "123456789")


async def seed_admin() -> None:
    """Upsert the admin identified by SEED_ADMIN_EMAIL.

    Behavior on every container start:
      · If no user with that email exists  → create one as an admin.
      · If the user exists                → re-sync role/active flag and
        overwrite the password with SEED_ADMIN_PASSWORD.

    This makes credential recovery a matter of editing `.env` and restarting:
    `docker compose down -v` is *not* required.

    Any pre-existing admin accounts with a *different* email are left alone.
    """
    async with AsyncSessionLocal() as db:
        existing = await db.execute(
            select(User).where(User.email == DEFAULT_ADMIN_EMAIL)
        )
        user = existing.scalar_one_or_none()

        if user:
            user.role = "admin"
            user.is_active = True
            user.hashed_password = hash_password(DEFAULT_ADMIN_PASSWORD)
            log.info("Admin '%s' güncellendi (şifre senkronlandı).", DEFAULT_ADMIN_EMAIL)
        else:
            user = User(
                email=DEFAULT_ADMIN_EMAIL,
                hashed_password=hash_password(DEFAULT_ADMIN_PASSWORD),
                role="admin",
                is_active=True,
            )
            db.add(user)
            log.info("Admin '%s' oluşturuldu.", DEFAULT_ADMIN_EMAIL)

        await db.commit()


async def main() -> None:
    log.info("Crowdly seed başlatılıyor…")
    await seed_admin()
    log.info("✅ Seed tamamlandı.")


if __name__ == "__main__":
    asyncio.run(main())
