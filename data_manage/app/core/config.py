from pydantic import BaseSettings

class Settings(BaseSettings):

    DB_HOST: str = "mysql"
    DB_PORT: int = 3306
    DB_USER: str = "root"
    DB_PASSWORD: str = "123456"
    DB_NAME: str = "taskdb"

settings = Settings()