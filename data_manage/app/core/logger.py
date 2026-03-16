from loguru import logger
import sys

logger.remove()

logger.add(
    sys.stdout,
    level="INFO"
)

logger.add(
    "logs/app.log",
    rotation="10 MB",
    retention="7 days"
)