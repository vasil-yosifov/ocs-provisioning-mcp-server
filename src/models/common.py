from enum import Enum
from typing import Any, Dict, Optional
from pydantic import BaseModel, Field

class SubscriberState(str, Enum):
    PRE_PROVISIONED = "pre-provisioned"
    ACTIVE = "active"
    SUSPENDED = "suspended"
    DEACTIVATED = "deactivated"
    TERMINATED = "terminated"

class SubscriptionState(str, Enum):
    PENDING = "pending"
    ACTIVE = "active"
    SUSPENDED = "suspended"
    CANCELLED = "cancelled"
    EXPIRED = "expired"

class BalanceUnitType(str, Enum):
    BYTES = "BYTES"
    EVENTS = "EVENTS"
    SECONDS = "SECONDS"
    MICROCENTS = "MICROCENTS"
    MICROUNITS = "MICROUNITS"

class EntityType(str, Enum):
    SUBSCRIBER = "SUBSCRIBER"
    GROUP = "GROUP"
    ACCOUNT = "ACCOUNT"

class PatchOperation(BaseModel):
    fieldName: str = Field(..., description="JSON field name (dot notation supported)")
    fieldValue: Any = Field(..., description="New value for the field")

class Error(BaseModel):
    code: int
    message: str
    details: Optional[Dict[str, Any]] = None

class SubscriberIdResponse(BaseModel):
    subscriberId: str
