from datetime import datetime, timezone
from typing import Annotated

from pydantic import AfterValidator


def _as_utc(value: datetime) -> datetime:
    # SQLite returns naive timestamps; they are stored in UTC (CURRENT_TIMESTAMP).
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value


UTCDateTime = Annotated[datetime, AfterValidator(_as_utc)]
