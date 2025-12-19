from datetime import datetime
from typing import Dict, List, Optional
from pydantic import BaseModel
from src.models.common import SubscriptionState

class Subscription(BaseModel):
    subscriberId: Optional[str] = None
    subscriptionId: str
    subscriptionType: Optional[str] = None
    offerId: Optional[str] = None
    offerName: Optional[str] = None
    state: Optional[SubscriptionState] = None
    creationDate: Optional[datetime] = None
    activationDate: Optional[datetime] = None
    expirationDate: Optional[datetime] = None
    renewalDate: Optional[datetime] = None
    recurring: Optional[bool] = None
    paidFlag: Optional[bool] = None
    isGroup: Optional[bool] = None
    maxRecurringCycles: Optional[int] = None
    recurringCyclesCompleted: Optional[int] = None
    cycleLengthUnits: Optional[int] = None
    cycleLengthType: Optional[str] = None
    customParameters: Optional[Dict[str, str]] = None
    balances: Optional[List[str]] = None
    lastModifiedDate: Optional[datetime] = None
    timers: Optional[List[str]] = None
