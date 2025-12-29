"""Workflow guidance prompts for OCS provisioning operations."""
import logging

logger = logging.getLogger(__name__)

async def create_subscription_from_offer(offerId: str, subscriberId: str) -> str:
    """
    Complete workflow guidance for creating a subscription and provisioning all its balances based on an offer.
    
    Args:
        offerId: The ID of the offer to use as the template (e.g., "1000", "1001", "1010")
        subscriberId: The ID of the subscriber who will receive the subscription
    
    Returns:
        Detailed workflow instructions for subscription and balance creation from offer
    """
    logger.debug(f"Generating subscription workflow for offerId={offerId}, subscriberId={subscriberId}")
    
    return f"""
# Complete Workflow: Create Subscription and Balances from Offer

**Context:**
- Offer ID: {offerId}
- Subscriber ID: {subscriberId}

## Purpose
This workflow guides you through creating a subscription and provisioning all its balances based on an offer. 
This ensures proper field mapping and balance provisioning following OCS best practices.

**Important:** This is guidance only. Execute the workflow by calling the individual tools in sequence.

## Complete Workflow

### Phase 1: Validation and Offer Selection

1. Call `get_subscriber(subscriberId)` to:
   - Verify subscriber exists
   - Extract subscriber type (PREPAID or POSTPAID)
   - Check current subscriptions

2. Call `get_offer_by_id(offerId)` OR `get_available_offers()` to:
   - Retrieve offer details including all balance definitions
   - Verify offer type matches subscriber type (PREPAID ↔ PREPAID, POSTPAID ↔ POSTPAID)
   - Review offer pricing, cycles, and balance allocations

### Phase 2: Create Subscription

3. Map offer fields to subscription object and call `create_subscription(subscriberId, subscription)`
4. Extract subscriptionId from response and verify subscription was created successfully
5. Create account history entry documenting the subscription creation

### Phase 3: Create Balances

6. For EACH balance defined in offer.balances array, map fields and call `create_balance(subscriptionId, balance)`
   - Create voice balance (SECONDS) if present
   - Create SMS/MMS balance (EVENTS) if present  
   - Create data balance (BYTES) if present
   - Create account history entry for each balance created
   - Verify each balance creation was successful

#### Key Balance Field Mappings:
- balanceType: Use offer_balance.type
- unitType: Map offer_balance.unit (SECONDS/EVENTS/BYTES)
- balanceAmount & balanceAvailable: Use offer_balance.amount
- isRecurring: Use offer_balance.recurring
- cycleLengthType & cycleLengthUnits: Use offer_balance.cycleUnit & cycleLength
- isRolloverAllowed & maxRolloverAmount: From offer_balance
- rolloverAmount: Set to 0 initially
- recurringCyclesCompleted: Set to 0 initially
- effectiveDate: Current timestamp
- expirationDate: Calculate from effectiveDate + cycle length

7. Call `change_subscription_state(subscriptionId, "active")` to activate the subscription
8. Create account history entry documenting the subscription activation
9. Verify by calling `get_subscription(subscriptionId)` and `list_balances(subscriptionId)`

## Account History Documentation

For each major operation, create an account history entry to maintain audit trail.

**Account History Object Structure (from OCS Provisioning API):**
- `interactionId` (required): Unique identifier for the interaction (e.g., "INT-20251223-143000-001")
- `entityId` (required): The subscriber ID
- `entityType` (required): Must be "SUBSCRIBER"
- `creationDate` (required): Timestamp when the history entry is created (ISO 8601 format)
- `description`: Free-text field containing all subscription/balance details
- `channel`: Source of the operation (e.g., "API", "CRM", "PORTAL")
- `status`: Operation status (e.g., "completed", "pending", "failed")
- `reason`: Business reason for the operation

**Subscription Creation History Template:**
```json
{{
  "interactionId": "INT-[timestamp]-[sequence]",
  "entityId": "[subscriberId]",
  "entityType": "SUBSCRIBER",
  "creationDate": "[ISO 8601 timestamp]",
  "description": "Subscription created - Offer: [offerName] (ID: [offerId]), Type: [subscriptionType], Recurring: [recurring], Cycle: [cycleLengthUnits] [cycleLengthType]",
  "channel": "API",
  "status": "completed",
  "reason": "New subscription provisioning"
}}
```

**Balance Creation History Template:**
```json
{{
  "interactionId": "INT-[timestamp]-[sequence]",
  "entityId": "[subscriberId]",
  "entityType": "SUBSCRIBER",
  "creationDate": "[ISO 8601 timestamp]",
  "description": "Balance created - Subscription: [subscriptionId], Type: [balanceType], Unit: [unitType], Amount: [balanceAmount], Cycle: [cycleLengthUnits] [cycleLengthType], Recurring: [isRecurring], Rollover: [isRolloverAllowed], Expiration: [expirationDate]",
  "channel": "API",
  "status": "completed",
  "reason": "Balance provisioning"
}}
```

**Subscription Activation History Template:**
```json
{{
  "interactionId": "INT-[timestamp]-[sequence]",
  "entityId": "[subscriberId]",
  "entityType": "SUBSCRIBER",
  "creationDate": "[ISO 8601 timestamp]",
  "description": "Subscription activated - Subscription: [subscriptionId], Offer: [offerName] (ID: [offerId])",
  "channel": "API",
  "status": "completed",
  "reason": "Subscription activation"
}}
```

## Critical Rules

- **Type Matching**: Subscriber type must match offer type (PREPAID ↔ PREPAID, POSTPAID ↔ POSTPAID)
- **Unit Types**: SECONDS (voice), EVENTS (SMS), BYTES (data)
- **Initial Values**: balanceAvailable = balanceAmount, rolloverAmount = 0, recurringCyclesCompleted = 0
- **Create all balances before activation**

## Detailed Example: Offer 1000 (Basic Prepaid Plan)

### Offer 1000 Definition
```json
{{
  "offerId": "1000",
  "offerName": "Basic prepaid plan",
  "description": "Entry-level prepaid plan with basic allowances",
  "type": "PREPAID",
  "paid": true,
  "recurring": true,
  "cycleLength": 1,
  "cycleUnit": "MONTH",
  "maxRecurringCycles": null,
  "groupOffer": false,
  "balances": [
    {{
      "type": "ALLOWANCE",
      "amount": 3600,
      "unit": "SECONDS",
      "recurring": true,
      "cycleLength": 1,
      "cycleUnit": "MONTH",
      "rolloverAllowed": false,
      "maxRolloverAmount": 0,
      "description": "1 hour (3600 seconds) voice allowance per month"
    }},
    {{
      "type": "ALLOWANCE",
      "amount": 1000,
      "unit": "EVENTS",
      "recurring": true,
      "cycleLength": 1,
      "cycleUnit": "MONTH",
      "rolloverAllowed": false,
      "maxRolloverAmount": 0,
      "description": "1000 SMS/MMS messages per month"
    }},
    {{
      "type": "ALLOWANCE",
      "amount": 10737418240,
      "unit": "BYTES",
      "recurring": true,
      "cycleLength": 1,
      "cycleUnit": "MONTH",
      "rolloverAllowed": false,
      "maxRolloverAmount": 0,
      "description": "10 GB data allowance per month"
    }}
  ]
}}
```

### Step-by-Step Implementation

**Given Context:**
- Current Date/Time: 2025-12-23T14:30:00Z
- Subscriber ID: {subscriberId}
- Subscriber Type: PREPAID (verified via get_subscriber)
- Offer ID: 1000

#### Step 1: Create Subscription

**Call:** `create_subscription(subscriberId="{subscriberId}", subscription={{...}})`

**Subscription Object:**
```json
{{
  "subscriptionId": "SUB-20251223-143000-ABC123",
  "offerId": "1000",
  "offerName": "Basic prepaid plan",
  "subscriptionType": "PREPAID",
  "recurring": true,
  "paidFlag": true,
  "isGroup": false,
  "maxRecurringCycles": null,
  "cycleLengthUnits": 1,
  "cycleLengthType": "MONTH",
  "state": "pending",
  "activationDate": null,
  "expirationDate": null
}}
```

**Response:** Returns subscription with generated subscriptionId = "SUB-20251223-143000-ABC123"

---

#### Step 2: Create Voice Balance
Subscription History Entry

**Call:** `create_account_history(subscriberId="{subscriberId}", history={{...}})`

**Account History Object:**
```json
{{
  "interactionId": "INT-20251223-143000-001",
  "entityId": "{subscriberId}",
  "entityType": "SUBSCRIBER",
  "creationDate": "2025-12-23T14:30:00Z",
  "description": "Subscription created - Offer: Basic prepaid plan (ID: 1000), Type: PREPAID, Recurring: true, Cycle: 1 MONTH",
  "channel": "API",
  "status": "completed",
  "reason": "New subscription provisioning"
}}
```

**Purpose:** Creates audit trail record documenting that subscription SUB-20251223-143000-ABC123 was created with offer 1000

---

#### Step 3: Create 
**Call:** `create_balance(subscriptionId="SUB-20251223-143000-ABC123", balance={{...}})`

**Balance Object:**
```json
{{
  "balanceType": "ALLOWANCE",
  "unitType": "SECONDS",
  "balanceAmount": 3600,
  "balanceAvailable": 3600,
  "isRecurring": true,
  "cycleLengthType": "MONTH",
  "cycleLengthUnits": 1,
  "isRolloverAllowed": false,
  "maxRolloverAmount": 0,
  "rolloverAmount": 0,
  "isGroupBalance": false,
  "maxRecurringCycles": null,
  "recurri4: Create Voice Balance History Entry

**Call:** `create_account_history(subscriberId="{subscriberId}", history={{...}})`

**Account History Object:**
```json
{{
  "interactionId": "INT-20251223-143000-002",
  "entityId": "{subscriberId}",
  "entityType": "SUBSCRIBER",
  "creationDate": "2025-12-23T14:30:00Z",
  "description": "Balance created - Subscription: SUB-20251223-143000-ABC123, Type: ALLOWANCE, Unit: SECONDS, Amount: 3600, Cycle: 1 MONTH, Recurring: true, Rollover: false, Expiration: 2026-01-23T14:30:00Z",
  "channel": "API",
  "status": "completed",
  "reason": "Balance provisioning"
}}
```

**Purpose:** Records that voice balance (3600 seconds = 1 hour) was provisioned for the subscription

---

#### Step 5gCyclesCompleted": 0,
  "effectiveDate": "2025-12-23T14:30:00Z",
  "expirationDate": "2026-01-23T14:30:00Z"
}}
```

**Date Calculation Explained:**
- **effectiveDate**: Current timestamp → `2025-12-23T14:30:00Z`
- **expirationDate**: effectiveDate + (cycleLengthUnits × cycleLengthType)
  - cycleLengthUnits = 1
  - cycleLengthType = "MONTH"
  - Calcul6: Create SMS Balance History Entry

**Call:** `create_account_history(subscriberId="{subscriberId}", history={{...}})`

**Account History Object:**
```json
{{
  "interactionId": "INT-20251223-143000-004",
  "entityId": "{subscriberId}",
  "entityType": "SUBSCRIBER",
  "creationDate": "2025-12-23T14:30:00Z",
  "description": "Balance created - Subscription: SUB-20251223-143000-ABC123, Type: ALLOWANCE, Unit: BYTES, Amount: 10737418240, Cycle: 1 MONTH, Recurring: true, Rollover: false, Expiration: 2026-01-23T14:30:00Z",
  "channel": "API",
  "status": "completed",
  "reason": "Balance provisioning"
  "status": "completed",
  "reason": "Balance provisioning"
}}
```

**Purpose:** Records that SMS/MMS balance (1000 events) was provisioned for the subscription

---

#### Step 7tion: `2025-12-23T14:30:00Z` + 1 MONTH = `2026-01-23T14:30:00Z`
  - **Note**: When adding 1 month to Dec 23, result is Jan 23 (same day, next month)
  - Time component remains the same (14:30:00)

**Result:** Voice balance valid for exactly 1 month (31 days in this case)

---

#### Step 3: Create SMS Balance

**Call:** `create_balance(subscriptionId="SUB-20251223-143000-ABC123", balance={{...}})`

**Balance Object:**
```json
{{
  "balanceType": "ALLOWANCE",
  "unitTyp8: Create Data Balance History Entry

**Call:** `create_account_history(subscriberId="{subscriberId}", history={{...}})`

**Account History Object:**
```json
{{
  "eventType": "BALANCE_CREATED",
  "# Step 10: Create Activation History Entry

**Call:** `create_account_history(subscriberId="{subscriberId}", history={{...}})`

**Account History Object:**
```json
{{
  "interactionId": "INT-20251223-143000-005",
  "entityId": "{subscriberId}",
  "entityType": "SUBSCRIBER",
  "creationDate": "2025-12-23T14:30:00Z",
  "description": "Subscription activated - Subscription: SUB-20251223-143000-ABC123, Offer: Basic prepaid plan (ID: 1000)",
  "channel": "API",
  "status": "completed",
  "reason": "Subscription activation"
}}
```

**Purpose:** Records the subscription activation event in the audit trail

---

### Complete Operation Summary

**Total Operations for Offer 1000:**
1. Create subscription (1 API call)
2. Record subscription creation (1 API call)
3. Create voice balance (1 API call)
4. Record voice balance creation (1 API call)
5. Create SMS balance (1 API call)
6. Record SMS balance creation (1 API call)
7. Create data balance (1 API call)
8. Record data balance creation (1 API call)
9. Activate subscription (1 API call)
10. Record activation (1 API call)

**Total: 10 API calls** for complete subscription provisioning with audit trail

---

###description": "Balance created - Type: ALLOWANCE, Unit: BYTES, Amount: 10737418240, Cycle: 1 MONTH",
  "eventDate": "2025-12-23T14:30:00Z",
  "amount": 0,
  "balanceBefore": 0,
  "balanceAfter": 0
}}
```

**Purpose:** Records that data balance (10 GB = 10737418240 bytes) was provisioned for the subscription

---

#### Step 9": "EVENTS",
  "balanceAmount": 1000,
  "balanceAvailable": 1000,
  "isRecurring": true,
  "cycleLengthType": "MONTH",
  "cycleLengthUnits": 1,
  "isRolloverAllowed": false,
  "maxRolloverAmount": 0,
  "rolloverAmount": 0,
  "isGroupBalance": false,
  "maxRecurringCycles": null,
  "recurringCyclesCompleted": 0,
  "effectiveDate": "2025-12-23T14:30:00Z",
  "expirationDate": "2026-01-23T14:30:00Z"
}}
```

**Date Calculation Explained:**
- **effectiveDate**: `2025-12-23T14:30:00Z` (same as subscription creation time)
- **expirationDate**: `2026-01-23T14:30:00Z` (1 month later)
- All balances in the same subscription should have synchronized expiration dates

---

#### Step 4: Create Data Balance
account_history(subscriberId, history)` - Record subscription creation
5. `create_balance(subscriptionId, balance)` - Create each balance (repeat for voice/SMS/data)
6. `create_account_history(subscriberId, history)` - Record each balance creation
7. `change_subscription_state(subscriptionId, "active")` - Activate subscription
8. `create_account_history(subscriberId, history)` - Record activation3", balance={{...}})`

**Balance Object:**
```json
{{
  "balanceType": "ALLOWANCE",
  "unitType": "BYTES",
  "balanceAmount": 10737418240,
  "balanceAvailable": 10737418240,
  "isRecurring": true,
  "cycleLengthType": "MONTH",
  "cycleLengthUnits": 1,
  "isRolloverAllowed": false,
  "maxRolloverAmount": 0,
  "rolloverAmount": 0,
  "isGroupBalance": false,
  "maxRecurringCycles": null,
  "recurringCyclesCompleted": 0,
  "effectiveDate": "2025-12-23T14:30:00Z",
  "expirationDate": "2026-01-23T14:30:00Z"
}}
```

**Data Amount Calculation:**
- 10 GB = 10 × 1024 × 1024 × 1024 bytes
- 10 GB = 10 × 1,073,741,824 bytes
- 10 GB = **10,737,418,240 bytes**

**Date Calculation:**
- **effectiveDate**: `2025-12-23T14:30:00Z`
- **expirationDate**: `2026-01-23T14:30:00Z`

---

#### Step 5: Activate Subscription

**Call:** `change_subscription_state(subscriptionId="SUB-20251223-143000-ABC123", state="active")`

**Result:** Subscription state changes from "pending" → "active", all balances become active

---

### Important Date Calculation Notes

**Monthly Cycle Examples:**
```
Start Date              + 1 MONTH   = Expiration Date
2025-12-23T14:30:00Z   →             2026-01-23T14:30:00Z  (31 days)
2026-01-23T14:30:00Z   →             2026-02-23T14:30:00Z  (31 days)
2026-02-23T14:30:00Z   →             2026-03-23T14:30:00Z  (28 days in Feb)
2026-03-23T14:30:00Z   →             2026-04-23T14:30:00Z  (31 days)
```

**Key Rules:**
1. **Calendar Month**: Adding 1 MONTH means same day number in next month
2. **Time Preservation**: Hour/minute/second remain unchanged
3. **Timezone**: Always use UTC (Z suffix)
4. **Edge Cases**: 
   - Jan 31 + 1 MONTH = Feb 28/29 (last day of Feb)
   - End of month dates adjust to last valid day

**Weekly Cycle Example (if cycleUnit="WEEK"):**
```
Start: 2025-12-23T14:30:00Z + 1 WEEK (7 days) = 2025-12-30T14:30:00Z
Start: 2025-12-23T14:30:00Z + 4 WEEKS (28 days) = 2026-01-20T14:30:00Z
```

**Daily Cycle Example (if cycleUnit="DAY"):**
```
Start: 2025-12-23T14:30:00Z + 30 DAYS = 2026-01-22T14:30:00Z
```

### Verification Commands

After completing all steps, verify the setup:

```bash
# Verify subscription
get_subscription("SUB-20251223-143000-ABC123")

# Expected: state="active", offerId="1000"

# Verify all balances
list_balances("SUB-20251223-143000-ABC123")

# Expected: 3 balances
# - Voice: 3600 SECONDS available
# - SMS: 1000 EVENTS available  
# - Data: 10737418240 BYTES available
# All with expirationDate: 2026-01-23T14:30:00Z
```

## Quick Reference

1. `get_subscriber(subscriberId)` - Verify subscriber and get type
2. `get_offer_by_id(offerId)` - Get offer details
3. `create_subscription(subscriberId, subscription)` - Create subscription
4. `create_balance(subscriptionId, balance)` - Create each balance (repeat for voice/SMS/data)
5. `change_subscription_state(subscriptionId, "active")` - Activate
"""
