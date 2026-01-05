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

async def analyse_subscriber_account(subscriberId: str) -> str:
    """
    Comprehensive workflow guidance for analyzing a subscriber's account status, including correlating
    subscriptions, balances, and usage patterns.
    
    Args:
        subscriberId: The ID of the subscriber whose account to analyze
    
    Returns:
        Detailed analysis workflow instructions for comprehensive account review
    """
    logger.debug(f"Generating account analysis workflow for subscriberId={subscriberId}")
    
    return f"""
# Complete Workflow: Analyze Subscriber Account

**Context:**
- Subscriber ID: {subscriberId}

## Purpose
This workflow guides you through a comprehensive analysis of a subscriber's account by collecting all relevant data 
(profile, subscriptions, balances, usage, account history) and analyzing correlations between service subscriptions, 
their corresponding balances, and actual usage patterns. This analysis is essential for:
- Customer support inquiries
- Billing verification and dispute resolution
- Usage pattern analysis and recommendations
- Service health monitoring
- Fraud detection
- Account optimization opportunities

**Important:** This is guidance only. Execute the workflow by calling the individual tools in sequence and building 
your analysis from the collected data.

## Complete Analysis Workflow

### Phase 1: Data Collection

#### Step 1: Retrieve Subscriber Profile
**Call:** `get_subscriber(subscriberId="{subscriberId}")`

**Data to Extract:**
- `subscriberId`: Unique subscriber identifier
- `subscriberType`: PREPAID or POSTPAID
- `state`: Subscriber status (active, suspended, terminated)
- `personalInfo`: Name, contact details, addresses
- `msisdn`: Primary phone number
- `imsi`: SIM card identifier
- `subscriptions`: Array of subscription objects (each contains subscriptionId)
- `activationDate`: When subscriber was activated
- `terminationDate`: If subscriber was terminated

**Analysis Points:**
- Verify subscriber is in expected state (active vs suspended)
- Check if subscriber type matches subscription types
- Note primary contact information for context

---

#### Step 2: Retrieve Account History
**Call:** `get_account_history(entityId="{subscriberId}")`

**Data to Extract:**
- Complete timeline of account events
- Subscription creations and activations
- Balance provisioning events
- State changes (activations, suspensions, terminations)
- Service modifications
- Payment events (if present)

**Analysis Points:**
- Build chronological timeline of account activity
- Identify recent changes that might explain current state
- Look for patterns (e.g., repeated suspensions, frequent plan changes)
- Note any error or failed operations

---

#### Step 3: Analyze Each Subscription

For each subscription found in Step 1, execute the following:

**Call 3a:** `get_subscription(subscriptionId="[subscriptionId]")`

**Data to Extract:**
- `subscriptionId`: Unique subscription identifier
- `offerId` & `offerName`: What plan/offer this subscription is based on
- `subscriptionType`: PREPAID or POSTPAID
- `state`: Subscription status (pending, active, suspended, terminated)
- `activationDate`: When subscription became active
- `expirationDate`: When subscription expires/expired
- `recurring`: Whether subscription auto-renews
- `cycleLengthUnits` & `cycleLengthType`: Billing cycle (e.g., 1 MONTH)
- `maxRecurringCycles`: Maximum renewal cycles
- `recurringCyclesCompleted`: How many cycles completed

**Call 3b:** `list_balances(subscriptionId="[subscriptionId]")`

**Data to Extract for Each Balance:**
- `balanceId`: Unique balance identifier
- `balanceType`: Type of balance (ALLOWANCE, CREDIT, etc.)
- `unitType`: SECONDS (voice), EVENTS (SMS/MMS), BYTES (data)
- `balanceAmount`: Total allocated balance
- `balanceAvailable`: Currently remaining balance
- `balanceConsumed`: Calculated as (balanceAmount - balanceAvailable)
- `consumptionPercentage`: Calculated as (balanceConsumed / balanceAmount × 100%)
- `effectiveDate`: When balance became active
- `expirationDate`: When balance expires
- `isRecurring`: Whether balance renews automatically
- `cycleLengthType` & `cycleLengthUnits`: Renewal cycle
- `isRolloverAllowed` & `maxRolloverAmount`: Rollover configuration
- `rolloverAmount`: Amount rolled over from previous cycle

**Call 3c:** `list_usage_for_subscriber(subscriberId="{subscriberId}", limit=100, offset=0)`

**Data to Extract:**
- All usage records (paginate if necessary)
- For each usage record:
  - `usageId`: Unique usage record identifier
  - `usageTimestamp`: When usage occurred
  - `usageType`: VOICE, DATA, SMS, or MMS
  - `recordType`: START, INTERIM, STOP, EVENT
  - `volumeUsage`: Amount consumed (seconds/bytes/events)
  - `impactedBalanceId`: Which balance was charged
  - `balanceValueBefore`: Balance before this usage
  - `balanceValueAfter`: Balance after this usage
  - `aParty` & `bParty`: Call/session parties
  - `durationSeconds`: Session duration (for voice/data)
  - `offerId`: Associated offer

**Analysis Strategy:**
- Group usage records by usageType (VOICE, DATA, SMS, MMS)
- Match usage records to their impacted balances
- Calculate usage patterns (daily, peak hours, etc.)
- Identify any usage that couldn't be charged (errors, insufficient balance)

---

### Phase 2: Correlation Analysis

#### Subscription-to-Balance Correlation

For each subscription, verify:

1. **Balance Completeness Check:**
   - Does subscription have expected balances based on offer?
   - Expected balances for typical offers:
     - Voice balance (unitType: SECONDS)
     - SMS/MMS balance (unitType: EVENTS)
     - Data balance (unitType: BYTES)
   - Flag missing balances that should exist per offer definition

2. **Balance Health Check:**
   - Are all balances within their validity period (effectiveDate ≤ now ≤ expirationDate)?
   - Are any balances expired but still showing as active?
   - For recurring balances: Are they renewing correctly?

3. **Balance Allocation Analysis:**
   - Compare initial allocation (balanceAmount) vs current available (balanceAvailable)
   - Calculate consumption: `consumed = balanceAmount - balanceAvailable`
   - Calculate consumption percentage: `consumptionPct = (consumed / balanceAmount) × 100%`
   - Categorize consumption:
     - Low: 0-25% consumed
     - Moderate: 26-50% consumed
     - High: 51-75% consumed
     - Critical: 76-100% consumed
     - Overdrawn: >100% consumed (if overdraft allowed)

4. **Rollover Analysis (if applicable):**
   - Check if rollover is configured (`isRolloverAllowed = true`)
   - Verify `rolloverAmount` matches expected amount from previous cycle
   - Calculate total available including rollover: `total = balanceAvailable + rolloverAmount`

---

#### Balance-to-Usage Correlation

For each balance, analyze its usage patterns:

1. **Usage Matching:**
   - Filter usage records where `impactedBalanceId` matches current balance
   - Verify `usageType` matches balance `unitType`:
     - VOICE usage → SECONDS balance
     - DATA usage → BYTES balance
     - SMS/MMS usage → EVENTS balance
   - Flag any mismatches as potential data inconsistencies

2. **Usage Volume Analysis:**
   - Sum total `volumeUsage` for all records impacting this balance
   - Verify sum matches balance consumption: `Σ(volumeUsage) ≈ (balanceAmount - balanceAvailable)`
   - Flag discrepancies exceeding acceptable threshold (e.g., >1% difference)

3. **Usage Pattern Analysis:**
   - Calculate daily average usage
   - Identify peak usage periods (time of day, day of week)
   - Detect unusual usage patterns:
     - Sudden spikes in usage
     - Usage during unusual hours
     - Abnormally long sessions
     - High-frequency small transactions

4. **Balance Depletion Prediction:**
   - Calculate average daily consumption rate
   - Calculate days until balance exhaustion: `daysRemaining = balanceAvailable / dailyAvgConsumption`
   - Compare with expiration date to determine if balance will be exhausted before expiration
   - Categorize risk:
     - Low Risk: Will exhaust after expiration date (normal)
     - Medium Risk: Will exhaust 1-7 days before expiration
     - High Risk: Will exhaust >7 days before expiration

---

#### Cross-Service Analysis

Analyze patterns across all services:

1. **Service Usage Distribution:**
   - Calculate percentage of activity per service:
     - Voice: `Σ(VOICE usage) / total consumption`
     - Data: `Σ(DATA usage) / total consumption`
     - SMS/MMS: `Σ(SMS+MMS usage) / total consumption`
   - Identify primary service (highest usage)
   - Identify underutilized services (low usage relative to allocation)

2. **Offer Suitability Analysis:**
   - Compare allocated balances to actual usage patterns
   - Identify over-provisioning: High allocation but low usage
   - Identify under-provisioning: High usage relative to allocation, frequent exhaustion
   - Suggest alternative offers better matching usage profile

3. **Cost Efficiency Analysis (if pricing data available):**
   - Calculate cost per unit consumed
   - Compare to alternative offers
   - Identify cost optimization opportunities

---

### Phase 3: Generate Comprehensive Analysis Report

#### Account Summary Section

```
SUBSCRIBER ACCOUNT ANALYSIS REPORT
Generated: [current timestamp]
Subscriber ID: {subscriberId}
Subscriber Type: [PREPAID/POSTPAID]
Account State: [active/suspended/terminated]
Primary MSISDN: [phone number]
Account Age: [days since activation]

SUBSCRIPTIONS SUMMARY:
- Total Active Subscriptions: [count]
- Total Suspended Subscriptions: [count]
- Total Terminated Subscriptions: [count]
```

#### Subscription Details Section

For each subscription:

```
SUBSCRIPTION: [subscriptionId]
  Offer: [offerName] (ID: [offerId])
  Type: [PREPAID/POSTPAID]
  State: [state]
  Status: [Active/Expired/Expiring Soon]
  Activation Date: [date]
  Expiration Date: [date]
  Days Until Expiration: [calculated]
  Recurring: [yes/no]
  Cycle: [cycleLengthUnits] [cycleLengthType]
  Cycles Completed: [recurringCyclesCompleted]

  BALANCES:
  
  Voice Balance (SECONDS):
    Balance ID: [balanceId]
    Allocated: [balanceAmount] seconds ([converted to hours])
    Available: [balanceAvailable] seconds ([converted to hours])
    Consumed: [consumed] seconds ([converted to hours])
    Consumption: [consumptionPct]%
    Rollover: [rolloverAmount if applicable]
    Status: [Low/Moderate/High/Critical consumption]
    Expiration: [expirationDate]
    Days Remaining: [days]
    Est. Exhaustion: [predicted date based on usage rate]
    
  SMS/MMS Balance (EVENTS):
    Balance ID: [balanceId]
    Allocated: [balanceAmount] messages
    Available: [balanceAvailable] messages
    Consumed: [consumed] messages
    Consumption: [consumptionPct]%
    Rollover: [rolloverAmount if applicable]
    Status: [Low/Moderate/High/Critical consumption]
    Expiration: [expirationDate]
    Days Remaining: [days]
    Est. Exhaustion: [predicted date based on usage rate]
    
  Data Balance (BYTES):
    Balance ID: [balanceId]
    Allocated: [balanceAmount] bytes ([converted to GB])
    Available: [balanceAvailable] bytes ([converted to GB])
    Consumed: [consumed] bytes ([converted to GB])
    Consumption: [consumptionPct]%
    Rollover: [rolloverAmount if applicable]
    Status: [Low/Moderate/High/Critical consumption]
    Expiration: [expirationDate]
    Days Remaining: [days]
    Est. Exhaustion: [predicted date based on usage rate]
```

#### Usage Analysis Section

```
USAGE ANALYSIS:

Total Usage Records: [count]
Analysis Period: [first usage date] to [last usage date]

Usage Distribution:
  - Voice Calls: [count] calls, [total seconds] seconds ([hours] hours)
  - Data Sessions: [count] sessions, [total bytes] bytes ([GB] GB)
  - SMS Messages: [count] messages
  - MMS Messages: [count] messages

Daily Average Usage:
  - Voice: [avg] seconds/day ([hours] hours/day)
  - Data: [avg] bytes/day ([MB/GB] per day)
  - SMS/MMS: [avg] messages/day

Peak Usage Patterns:
  - Heaviest usage day: [date] ([usage details])
  - Most active hour: [hour range]
  - Most active day of week: [day]

Recent Usage (Last 7 Days):
  [List recent significant usage events]
```

#### Correlation Findings Section

```
BALANCE-USAGE CORRELATION:

Voice Balance Correlation:
  - Usage records matched to balance: [count]
  - Total usage volume: [sum of volumeUsage]
  - Balance deduction: [balanceAmount - balanceAvailable]
  - Correlation accuracy: [percentage match]
  - Discrepancies: [list any issues]

Data Balance Correlation:
  - Usage records matched to balance: [count]
  - Total usage volume: [sum of volumeUsage]
  - Balance deduction: [balanceAmount - balanceAvailable]
  - Correlation accuracy: [percentage match]
  - Discrepancies: [list any issues]

SMS/MMS Balance Correlation:
  - Usage records matched to balance: [count]
  - Total usage volume: [sum of volumeUsage]
  - Balance deduction: [balanceAmount - balanceAvailable]
  - Correlation accuracy: [percentage match]
  - Discrepancies: [list any issues]
```

#### Issues and Alerts Section

```
ISSUES AND ALERTS:

Critical Issues:
  - [List any critical problems requiring immediate attention]
  - Examples: Expired balances, negative balances, correlation mismatches >5%

Warnings:
  - [List warnings requiring attention]
  - Examples: Balances exhausting soon, high consumption rates, approaching limits

Anomalies:
  - [List unusual patterns or behaviors]
  - Examples: Usage spikes, off-hours activity, unusual destinations
```

#### Recommendations Section

```
RECOMMENDATIONS:

Service Optimization:
  - [Suggest plan changes based on usage patterns]
  - [Identify underutilized services to reduce costs]
  - [Identify over-consumed services needing upgrades]

Balance Management:
  - [Suggest balance adjustments]
  - [Recommend rollover configuration changes]
  - [Suggest top-up timing for prepaid]

Usage Efficiency:
  - [Provide tips to optimize consumption]
  - [Suggest alternative usage patterns to save money]

Account Health:
  - [Recommend any account maintenance actions]
  - [Suggest proactive measures to prevent issues]
```

---

### Analysis Checklist

Ensure your analysis covers all key areas:

- ✓ Subscriber profile retrieved and verified
- ✓ Account history timeline reviewed
- ✓ All subscriptions identified and analyzed
- ✓ All balances checked for completeness and validity
- ✓ Usage records collected and grouped by type
- ✓ Balance consumption calculated and categorized
- ✓ Usage-to-balance correlation verified
- ✓ Usage patterns analyzed (daily avg, peaks, anomalies)
- ✓ Balance exhaustion predictions calculated
- ✓ Service distribution analyzed
- ✓ Offer suitability assessed
- ✓ Issues and alerts identified
- ✓ Recommendations provided

---

### Key Metrics to Calculate

**Balance Health Metrics:**
```
consumption_percentage = (balanceAmount - balanceAvailable) / balanceAmount × 100%
days_until_expiration = (expirationDate - currentDate).days
daily_consumption_rate = total_consumed / days_since_effective
days_until_exhaustion = balanceAvailable / daily_consumption_rate
```

**Usage Pattern Metrics:**
```
total_usage_by_type = Σ(volumeUsage) grouped by usageType
daily_average_usage = total_usage / number_of_days
peak_usage_hour = hour with highest Σ(volumeUsage)
usage_distribution_pct = (usage_by_type / total_usage) × 100%
```

**Correlation Metrics:**
```
expected_consumption = Σ(volumeUsage for impactedBalanceId)
actual_consumption = balanceAmount - balanceAvailable
correlation_accuracy = (1 - |expected - actual| / expected) × 100%
```

---

### Example Analysis Output

```
SUBSCRIBER ACCOUNT ANALYSIS REPORT
Generated: 2026-01-05T15:30:00Z
Subscriber ID: {subscriberId}
Subscriber Type: PREPAID
Account State: active
Primary MSISDN: +436608921226
Account Age: 45 days since activation

SUBSCRIPTIONS SUMMARY:
- Total Active Subscriptions: 1
- Total Suspended Subscriptions: 0
- Total Terminated Subscriptions: 0

SUBSCRIPTION: 0bf31838-f237-4bbe-96aa-589147e8e469
  Offer: Basic Prepaid Plan (ID: 1000)
  Type: PREPAID
  State: active
  Status: Active, expiring in 18 days
  Activation Date: 2025-12-23T14:30:00Z
  Expiration Date: 2026-01-23T14:30:00Z
  Recurring: yes
  Cycle: 1 MONTH
  Cycles Completed: 0

  BALANCES:
  
  Voice Balance (SECONDS):
    Balance ID: 5ab3efcc-2dd2-4e49-853b-067a3b3b7be0
    Allocated: 3600 seconds (1.0 hours)
    Available: 3565 seconds (0.99 hours)
    Consumed: 35 seconds (0.01 hours)
    Consumption: 0.97%
    Status: Low consumption ✓
    Expiration: 2026-01-23T14:30:00Z (18 days)
    Est. Exhaustion: Not before expiration (low usage rate)
    
  SMS/MMS Balance (EVENTS):
    Balance ID: abc123...
    Allocated: 1000 messages
    Available: 985 messages
    Consumed: 15 messages
    Consumption: 1.5%
    Status: Low consumption ✓
    Expiration: 2026-01-23T14:30:00Z (18 days)
    Est. Exhaustion: Not before expiration
    
  Data Balance (BYTES):
    Balance ID: def456...
    Allocated: 10737418240 bytes (10.0 GB)
    Available: 8589934592 bytes (8.0 GB)
    Consumed: 2147483648 bytes (2.0 GB)
    Consumption: 20.0%
    Status: Low-Moderate consumption ✓
    Expiration: 2026-01-23T14:30:00Z (18 days)
    Est. Exhaustion: Not before expiration

USAGE ANALYSIS:
Total Usage Records: 16
Analysis Period: 2025-12-24 to 2026-01-05 (13 days)

Usage Distribution:
  - Voice Calls: 3 calls, 35 seconds (0.01 hours)
  - Data Sessions: 8 sessions, 2147483648 bytes (2.0 GB)
  - SMS Messages: 5 messages

Daily Average Usage:
  - Voice: 2.69 seconds/day
  - Data: 165 MB/day
  - SMS: 0.38 messages/day

BALANCE-USAGE CORRELATION:
Voice: 100% correlation ✓
Data: 100% correlation ✓
SMS: 100% correlation ✓
All usage properly recorded and deducted.

RECOMMENDATIONS:
1. Usage is well within allocated limits
2. Current plan (Basic Prepaid) appears appropriate
3. Monitor data usage - currently on track
4. Consider rollover for unused minutes (97% unused)
```

---

## Tool Call Sequence Summary

1. `get_subscriber(subscriberId)` - Get profile and subscription list
2. `get_account_history(entityId=subscriberId)` - Get event timeline  
3. For each subscription:
   - `get_subscription(subscriptionId)` - Get subscription details
   - `list_balances(subscriptionId)` - Get all balances
4. `list_usage_for_subscriber(subscriberId)` - Get usage records (paginate as needed)
5. Perform calculations and correlation analysis
6. Generate comprehensive report with findings and recommendations
"""
