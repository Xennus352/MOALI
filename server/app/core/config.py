# backend/server/app/core/config.py
import os
import secrets
from pathlib import Path

try:  # Optional: load a local .env file if python-dotenv is available
    from dotenv import load_dotenv

    load_dotenv(Path(__file__).resolve().parent.parent.parent / ".env")
except Exception:  # pragma: no cover - dotenv is optional
    pass


def _env_bool(name: str, default: bool) -> bool:
    raw = os.environ.get(name)
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "on"}


def _env_list(name: str, default: str) -> list[str]:
    raw = os.environ.get(name, default)
    return [item.strip() for item in raw.split(",") if item.strip()]


class Settings:
    """Application settings loaded from environment variables.

    Nothing here should be a real secret. In production every value that is
    security sensitive (SECRET_KEY, ADMIN_PASSWORD, database credentials, OAuth
    client secrets) must be provided through the environment.
    """

    BASE_DIR = Path(__file__).resolve().parent.parent.parent

    # ----- Environment -----------------------------------------------------
    ENVIRONMENT: str = os.environ.get("ENVIRONMENT", "development")
    DEBUG: bool = _env_bool("DEBUG", True)

    # ----- Security --------------------------------------------------------
    # A random per-process secret is used as a fallback in development so the
    # app still boots. Sessions created with the fallback are invalidated on
    # restart, which is acceptable for local development only.
    SECRET_KEY: str = os.environ.get("SECRET_KEY", "") or secrets.token_urlsafe(48)
    ALGORITHM: str = os.environ.get("ALGORITHM", "HS256")

    # Session cookies
    SESSION_COOKIE_NAME: str = os.environ.get("SESSION_COOKIE_NAME", "moali_session")
    SESSION_MAX_AGE_SECONDS: int = int(
        os.environ.get("SESSION_MAX_AGE_SECONDS", str(60 * 60 * 24 * 7))  # 7 days
    )
    COOKIE_SECURE: bool = _env_bool("COOKIE_SECURE", ENVIRONMENT == "production")
    COOKIE_SAMESITE: str = os.environ.get("COOKIE_SAMESITE", "lax")
    COOKIE_DOMAIN: str | None = os.environ.get("COOKIE_DOMAIN") or None

    # Authentication hardening
    LOGIN_MAX_ATTEMPTS: int = int(os.environ.get("LOGIN_MAX_ATTEMPTS", "10"))
    LOGIN_LOCKOUT_SECONDS: int = int(os.environ.get("LOGIN_LOCKOUT_SECONDS", "300"))
    PASSWORD_MIN_LENGTH: int = int(os.environ.get("PASSWORD_MIN_LENGTH", "8"))

    # Rate limiting
    RATE_LIMIT_PER_MINUTE: int = int(os.environ.get("RATE_LIMIT_PER_MINUTE", "240"))
    AUTH_RATE_LIMIT_PER_MINUTE: int = int(os.environ.get("AUTH_RATE_LIMIT_PER_MINUTE", "20"))

    # ----- Database --------------------------------------------------------
    MYSQL_ROOT_PASSWORD: str = os.environ.get("MYSQL_ROOT_PASSWORD", "root")
    MYSQL_DATABASE: str = os.environ.get("MYSQL_DATABASE", "livestock_census")
    MYSQL_USER: str = os.environ.get("MYSQL_USER", "moali")
    MYSQL_PASSWORD: str = os.environ.get("MYSQL_PASSWORD", "password")
    MYSQL_HOST: str = os.environ.get("MYSQL_HOST", "127.0.0.1")
    MYSQL_PORT: int = int(os.environ.get("MYSQL_PORT", "3306"))
    DATABASE_URL: str = os.environ.get(
        "DATABASE_URL",
        f"mysql+pymysql://{MYSQL_USER}:{MYSQL_PASSWORD}@{MYSQL_HOST}:{MYSQL_PORT}/{MYSQL_DATABASE}?charset=utf8mb4",
    )

    # ----- Application -----------------------------------------------------
    APP_NAME: str = os.environ.get("APP_NAME", "MOALI | LBVD Livestock Census Administration")
    APP_VERSION: str = os.environ.get("APP_VERSION", "1.0.0")

    # ----- CORS ------------------------------------------------------------
    CORS_ORIGINS: list[str] = _env_list(
        "CORS_ORIGINS",
        "http://localhost:5173,http://127.0.0.1:5173,http://localhost:4173,http://127.0.0.1:4173",
    )
    CORS_ORIGIN_REGEX: str = os.environ.get(
        "CORS_ORIGIN_REGEX", r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$"
    )

    # Extra origins allowed to be contacted by the browser (HTTP + WebSocket).
    # The API host is included by default so the admin console can open the
    # realtime socket and call the API when it is served from another origin.
    CSP_CONNECT_SRC: list[str] = _env_list(
        "CSP_CONNECT_SRC",
        (
            "http://localhost:8000,http://127.0.0.1:8000,"
            "ws://localhost:8000,ws://127.0.0.1:8000,ws://localhost:5173"
        ),
    )

    # Timezone used to bucket "today"/"this week" dashboard figures. Stored
    # timestamps are UTC, so the boundary is computed in this zone and converted
    # back to UTC for comparison.
    APP_TIMEZONE: str = os.environ.get("APP_TIMEZONE", "Asia/Yangon")

    # ----- Bootstrap administrator ----------------------------------------
    # Used only to seed the very first administrator account on startup when no
    # administrator exists yet. The password must be overridden in production.
    ADMIN_EMAIL: str = os.environ.get("ADMIN_EMAIL", "admin@moali.gov.mm")
    ADMIN_PASSWORD: str = os.environ.get("ADMIN_PASSWORD", "Admin@12345")
    ADMIN_NAME: str = os.environ.get("ADMIN_NAME", "စနစ်အုပ်ချုပ်သူ")
    ADMIN_NAME_EN: str = os.environ.get("ADMIN_NAME_EN", "System Administrator")

    # ----- Email (optional) ------------------------------------------------
    SMTP_HOST: str = os.environ.get("SMTP_HOST", "smtp.gmail.com")
    SMTP_PORT: int = int(os.environ.get("SMTP_PORT", "587"))
    SMTP_USER: str = os.environ.get("SMTP_USER", "")
    SMTP_PASSWORD: str = os.environ.get("SMTP_PASSWORD", "")

    # ----- Google OAuth (optional) ----------------------------------------
    GOOGLE_CLIENT_ID: str = os.environ.get("GOOGLE_CLIENT_ID", "")
    GOOGLE_CLIENT_SECRET: str = os.environ.get("GOOGLE_CLIENT_SECRET", "")
    GOOGLE_REDIRECT_URI: str = os.environ.get(
        "GOOGLE_REDIRECT_URI", "http://localhost:5173/login"
    )
    FRONTEND_URL: str = os.environ.get("FRONTEND_URL", "http://localhost:5173")

    # Native (Flutter) apps complete Google sign-in via a custom-scheme deep
    # link. After the OAuth callback we redirect to this URI with a short-lived
    # handoff token the app exchanges for a real session. Only URIs on this
    # scheme (or the exact configured value) are accepted, so the endpoint can
    # never be used as an open redirect.
    MOBILE_REDIRECT_URI: str = os.environ.get("MOBILE_REDIRECT_URI", "moali://auth")
    MOBILE_URL_SCHEME: str = os.environ.get("MOBILE_URL_SCHEME", "moali")

    # ----- Reporting -------------------------------------------------------
    REPORT_CSV_ENCODING: str = "utf-8-sig"  # BOM so Excel reads Burmese correctly
    MYFONT: str = "Noto Sans Myanmar"

    @property
    def google_oauth_configured(self) -> bool:
        return bool(self.GOOGLE_CLIENT_ID and self.GOOGLE_CLIENT_SECRET)

    @property
    def is_production(self) -> bool:
        return self.ENVIRONMENT.lower() in {"production", "prod"}


settings = Settings()
