from datetime import datetime
from typing import Optional
from pydantic import BaseModel
from enum import Enum

class UsageType(str, Enum):
    VOICE = "VOICE"
    DATA = "DATA"
    SMS = "SMS"
    MMS = "MMS"

class RecordType(str, Enum):
    START = "START"
    INTERIM = "INTERIM"
    STOP = "STOP"
    EVENT = "EVENT"

class Usage(BaseModel):
    usageId: str
    usageTimestamp: datetime
    chargedPartyId: str
    chargedMsisdn: str
    aParty: str
    bParty: str
    usageType: UsageType
    recordType: RecordType
    recordOpeningTime: Optional[datetime] = None
    recordClosingTime: Optional[datetime] = None
    durationSeconds: Optional[int] = None
    volumeUsage: float
    impactedBalanceId: str
    balanceValueBefore: Optional[float] = None
    balanceValueAfter: Optional[float] = None
    offerId: str
