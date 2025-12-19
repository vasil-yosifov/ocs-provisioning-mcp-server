from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import Field

class Settings(BaseSettings):
    ocs_api_base_url: str = Field(..., description="Base URL for the OCS Provisioning API")
    ocs_api_key: str = Field(..., description="API Key for authentication")
    ocs_api_timeout: float = Field(30.0, description="Timeout for API requests in seconds")
    log_level: str = Field("INFO", description="Logging level")

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

settings = Settings()
