from datetime import datetime
from typing import Optional
from pydantic import BaseModel
from src.models.common import BalanceUnitType

class Balance(BaseModel):
    subscriptionId: Optional[str] = None
    balanceId: Optional[str] = None
    effectiveDate: Optional[datetime] = None
    expirationDate: Optional[datetime] = None
    creationDate: Optional[datetime] = None
    lastModifiedDate: Optional[datetime] = None
    balanceType: Optional[str] = None
    unitType: Optional[BalanceUnitType] = None
    balanceAmount: Optional[float] = None
    balanceAvailable: Optional[float] = None
    isGroupBalance: Optional[bool] = None
    isRecurring: Optional[bool] = None
    cycleLengthType: Optional[str] = None
    cycleLengthUnits: Optional[int] = None
    maxRecurringCycles: Optional[int] = None
    recurringCyclesCompleted: Optional[int] = None
    maxRolloverAmount: Optional[float] = None
    rolloverAmount: Optional[float] = None
    isRolloverAllowed: Optional[bool] = None
