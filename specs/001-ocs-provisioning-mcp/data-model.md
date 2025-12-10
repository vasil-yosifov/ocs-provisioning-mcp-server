# Data Model

This document defines the Pydantic models that will be used to validate data within the MCP server. These models directly map to the schemas defined in the OCS Provisioning API (OpenAPI 3.0.3).

## Enums

### SubscriberState
```python
class SubscriberState(str, Enum):
    PRE_PROVISIONED = "pre-provisioned"
    ACTIVE = "active"
    SUSPENDED = "suspended"
    DEACTIVATED = "deactivated"
    TERMINATED = "terminated"
```

### SubscriptionState
```python
class SubscriptionState(str, Enum):
    PENDING = "pending"
    ACTIVE = "active"
    SUSPENDED = "suspended"
    CANCELLED = "cancelled"
    EXPIRED = "expired"
```

### BalanceUnitType
```python
class BalanceUnitType(str, Enum):
    BYTES = "BYTES"
    EVENTS = "EVENTS"
    SECONDS = "SECONDS"
    MICROCENTS = "MICROCENTS"
    MICROUNITS = "MICROUNITS"
```

### EntityType
```python
class EntityType(str, Enum):
    SUBSCRIBER = "SUBSCRIBER"
    GROUP = "GROUP"
    ACCOUNT = "ACCOUNT"
```

## Models

### PatchOperation
Represents a single field update operation.
```python
class PatchOperation(BaseModel):
    fieldName: str = Field(..., description="JSON field name (dot notation supported)")
    fieldValue: Any = Field(..., description="New value for the field")
```

### Subscriber
```python
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
```

### Subscription
```python
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
```

### Balance
```python
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
```

### AccountHistory
```python
class AccountHistory(BaseModel):
    interactionId: str
    entityId: str
    entityType: EntityType
    creationDate: datetime
    description: Optional[str] = None
    direction: Optional[str] = None
    reason: Optional[str] = None
    status: Optional[str] = None
    statusChangeDate: Optional[datetime] = None
    attachment: Optional[Dict[str, Any]] = None
    channel: Optional[str] = None
    interactionDate: Optional[Dict[str, datetime]] = None
```

### SubscriberIdResponse
```python
class SubscriberIdResponse(BaseModel):
    subscriberId: str
```

### Error
```python
class Error(BaseModel):
    code: int
    message: str
    details: Optional[Dict[str, Any]] = None
```
