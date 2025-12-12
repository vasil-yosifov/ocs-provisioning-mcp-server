from datetime import datetime
from typing import Any, Dict, List, Optional
from pydantic import BaseModel, Field
from src.models.common import SubscriberState

class Subscriber(BaseModel):
    subscriberId: str
    businessAccountId: Optional[str] = None
    msisdn: Optional[str] = Field(None, pattern=r"^[0-9]{11,15}$")
    imsi: Optional[str] = Field(None, pattern=r"^[0-9]{12,15}$")
    iccId: Optional[str] = None
    currentState: Optional[SubscriberState] = None
    previousState: Optional[SubscriberState] = None
    creationDate: Optional[datetime] = None
    lastTransitionDate: Optional[datetime] = None
    activationDate: Optional[datetime] = None
    expirationDate: Optional[datetime] = None
    languageId: Optional[str] = None
    carrierId: Optional[str] = None
    subscriberType: Optional[str] = None
    personalInfo: Optional[Dict[str, Any]] = None
    billing: Optional[Dict[str, Any]] = None
    groups: Optional[List[str]] = None
    subscriptions: Optional[List[str]] = None
    notificationAddresses: Optional[List[str]] = None
    services: Optional[Dict[str, Any]] = None
    customFields: Optional[Dict[str, str]] = None
    lastModifiedDate: Optional[datetime] = None
    timers: Optional[List[str]] = None
