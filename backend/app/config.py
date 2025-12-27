"""Configuration management for Wodoo application"""
from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    """Application settings loaded from environment variables"""

    # Odoo Configuration
    odoo_url: str = "https://welpakco.com"
    odoo_db: str = "welpakco"
    odoo_username: str = "admin@welpakco.com"
    odoo_password: str = ""

    # API Configuration
    api_prefix: str = "/api/v1"
    cors_origins: list = ["*"]

    # Server Configuration
    host: str = "0.0.0.0"
    port: int = 8000
    workers: int = 4

    class Config:
        env_file = ".env"
        case_sensitive = False


@lru_cache()
def get_settings() -> Settings:
    """Get cached settings instance"""
    return Settings()
