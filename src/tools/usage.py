from typing import List, Dict, Any, Optional
import logging
from src.models.usage import Usage
from src.client import ocs_client

logger = logging.getLogger(__name__)

async def record_usage(usage: Usage) -> Dict[str, Any]:
    """
**Tool Name:** Record Usage

**Purpose:** Records usage for a specific subscriber, impacting the specified balance. This tool creates a usage record that tracks service consumption (voice calls, data sessions, SMS/MMS messages) and automatically deducts from the subscriber's balance. This is the primary mechanism for charging subscribers based on their actual service usage.

**Parameters:**
- `usage` (required): Usage object with all required fields populated

**Usage Object Fields:**
- `usageId` (required): Unique identifier for the usage record (UUID format) (e.g., "550e8400-e29b-41d4-a716-446655440000")
- `usageTimestamp` (required): Record creation timestamp in ISO 8601 format (e.g., "2024-06-15T10:05:00Z")
- `chargedPartyId` (required): The subscriber ID being charged (e.g., "SUB123456789")
- `chargedMsisdn` (required): MSISDN being charged in international format, digits only (e.g., "436602238811")
- `aParty` (required): Originating MSISDN in international format (e.g., "436602238811")
- `bParty` (required): Terminating MSISDN or APN for data sessions (e.g., "436602238822" or "internet.telco.com")
- `usageType` (required): Type of service usage - must be one of:
  - `"VOICE"`: Voice call usage (measured in seconds)
  - `"DATA"`: Data session usage (measured in bytes)
  - `"SMS"`: SMS message usage (measured in events/messages)
  - `"MMS"`: MMS message usage (measured in events/messages)
- `recordType` (required): Type of usage record - must be one of:
  - `"START"`: Session start record (for voice/data sessions)
  - `"INTERIM"`: Interim update during active session
  - `"STOP"`: Session end record (final charging)
  - `"EVENT"`: Single event (for SMS/MMS)
- `recordOpeningTime` (optional): Record opening timestamp in ISO 8601 format (when session started)
- `recordClosingTime` (optional): Record closing timestamp in ISO 8601 format (when session ended)
- `durationSeconds` (optional): Session duration in seconds (calculated as closing time minus opening time)
- `volumeUsage` (required): Usage volume with different meanings based on usageType:
  - For VOICE: seconds (e.g., 300 = 5 minutes)
  - For DATA: bytes (e.g., 104857600 = 100MB)
  - For SMS/MMS: count (e.g., 1 = one message)
- `impactedBalanceId` (required): ID of the balance to be charged/deducted from (e.g., "BALANCE123456")
- `balanceValueBefore` (optional): Balance available value before this usage (populated by system)
- `balanceValueAfter` (optional): Balance available value after this usage (populated by system)
- `offerId` (required): Associated offer ID for tracking purposes (e.g., "OFFER123456")

**How to Obtain Required IDs:**
1. **chargedPartyId (Subscriber ID)**:
   - From `get_subscriber` response: Contains `subscriberId` field
   - From `lookup_subscriber` response: Returns `subscriberId` for given MSISDN/IMSI
   - From `create_subscriber` response: Returns created subscriber with `subscriberId`

2. **impactedBalanceId**:
   - From `list_balances` response: Returns array of balances with `balanceId` for each
   - From `create_balance` response: Returns created balance with `balanceId`
   - Use appropriate balance based on usage type:
     - Voice usage → balance with `unitType: "SECONDS"`
     - Data usage → balance with `unitType: "BYTES"`
     - SMS/MMS usage → balance with `unitType: "EVENTS"`

**Determining the Correct Balance:**

When a subscriber has multiple subscriptions (and therefore multiple balances of the same type), the system must determine which balance to charge. Follow this workflow:

1. **Filter by Unit Type**: Get all balances matching the usage type:
   - VOICE usage → filter balances where `unitType == "SECONDS"`
   - DATA usage → filter balances where `unitType == "BYTES"`
   - SMS/MMS usage → filter balances where `unitType == "EVENTS"`

2. **Filter by Validity Period**: From the filtered balances, keep only those currently valid:
   - Check: `effectiveDate <= current_timestamp <= expirationDate`
   - Exclude any expired or not-yet-effective balances

3. **Order by Offer Priority**: For each active balance:
   - Get the balance's subscription (via `subscriptionId`)
   - Get the subscription's offer (via `offerId`)
   - Get the offer's `priority` field (lower number = higher priority)
   - Order balances by priority ascending (lowest priority number first)

4. **Select Balance**: Use the balance with the lowest priority number (highest priority):
   - This ensures preferred subscriptions are used first
   - Example: Single-service data bundle (priority 1000) would be used before multi-service plan (priority 5000)

**Priority-Based Balance Selection Example:**
```
Scenario: Subscriber has two active data balances

Balance A:
- subscriptionId: "SUB-DATA-BUNDLE" (offer 1002, priority: 1000)
- unitType: "BYTES"
- balanceAvailable: 5368709120 (5GB)
- effectiveDate: "2026-01-01", expirationDate: "2026-01-31"

Balance B:
- subscriptionId: "SUB-BASIC-PLAN" (offer 1000, priority: 5000)
- unitType: "BYTES"  
- balanceAvailable: 10737418240 (10GB)
- effectiveDate: "2026-01-01", expirationDate: "2026-01-31"

Current date: 2026-01-07

Selection process:
1. Both balances match unitType "BYTES" ✓
2. Both are valid (within effective/expiration dates) ✓
3. Order by priority: Balance A (1000) < Balance B (5000)
4. Selected: Balance A (priority 1000) - data bundle used first

Result: impactedBalanceId = Balance A's balanceId
```

This ensures that add-on bundles and specialized offers are consumed before general-purpose plans, maximizing value for the subscriber.

**Typical Workflow:**
1. Determine the subscriber being charged (obtain subscriberId)
2. Identify the type of service used (voice, data, SMS, MMS)
3. Get the appropriate balance for that service type using `list_balances`
4. Create usage object with all required fields:
   - usageId (generate unique UUID)
   - usageTimestamp (current timestamp)
   - chargedPartyId (subscriber ID)
   - chargedMsisdn (subscriber MSISDN)
   - aParty (originating MSISDN)
   - bParty (terminating MSISDN or APN)
   - usageType (VOICE/DATA/SMS/MMS)
   - recordType (EVENT for SMS/MMS, STOP for completed sessions)
   - volumeUsage (amount consumed)
   - impactedBalanceId (balance to charge)
   - offerId (associated offer ID)
5. Call `record_usage` to record the usage and deduct from balance
6. System automatically updates the balance and returns before/after values

**Returns:**
- Success (201): Complete usage record including:
  - `usageId`: Generated unique identifier
  - `usageTimestamp`: When record was created
  - All provided usage details
  - `balanceValueBefore`: Balance before usage
  - `balanceValueAfter`: Balance after usage deduction
- Error (400): Bad request - invalid usage data (e.g., invalid usageType, negative volumeUsage)
- Error (404): Subscriber or balance not found
  - Check `chargedPartyId` is valid subscriber ID
  - Check `impactedBalanceId` exists and belongs to subscriber
- Error (409): Conflict - duplicate usage record (usageId already exists)

**Use Cases:**
- **Voice Call Charging**: Record completed voice calls and deduct from voice balance
  - usageType: VOICE, recordType: STOP, volumeUsage: call duration in seconds
- **Data Session Charging**: Record data usage and deduct from data balance
  - usageType: DATA, recordType: STOP, volumeUsage: bytes consumed
- **SMS Charging**: Record SMS messages and deduct from message balance
  - usageType: SMS, recordType: EVENT, volumeUsage: 1 (one message)
- **MMS Charging**: Record MMS messages and deduct from message balance
  - usageType: MMS, recordType: EVENT, volumeUsage: 1 (one message)
- **Real-time Balance Updates**: Track usage and update balances in real-time during service consumption
- **Usage History**: Maintain detailed audit trail of all subscriber usage for billing and analytics

**Important Considerations:**
- **Volume Units**: Always use correct units based on usage type:
  - VOICE: seconds (300 = 5 minutes)
  - DATA: bytes (104857600 = 100MB, 1073741824 = 1GB)
  - SMS/MMS: events (1 = one message)
- **Balance Matching**: Ensure the impactedBalanceId references a balance with matching unit type:
  - Voice usage → balance with unitType "SECONDS"
  - Data usage → balance with unitType "BYTES"
  - SMS/MMS usage → balance with unitType "EVENTS"
- **Record Types**: Use appropriate record type:
  - EVENT: For discrete events like SMS/MMS (single transaction)
  - STOP: For completed sessions like voice calls or data sessions
  - START/INTERIM: For tracking active sessions (less common in charging scenarios)
- **Insufficient Balance**: If balance is insufficient, the system may reject the usage or apply overdraft rules
- **Balance Updates**: The system automatically calculates and updates balanceValueBefore and balanceValueAfter
- **Idempotency**: Usage records with same usageId will be rejected (409 Conflict)

**Example - Recording Voice Call:**
```
Scenario: 5-minute voice call
Input:
{
  "usageId": "550e8400-e29b-41d4-a716-446655440000",
  "usageTimestamp": "2024-06-15T10:05:00Z",
  "chargedPartyId": "SUB123456789",
  "chargedMsisdn": "436602238811",
  "aParty": "436602238811",
  "bParty": "436602238822",
  "usageType": "VOICE",
  "recordType": "STOP",
  "recordOpeningTime": "2024-06-15T10:00:00Z",
  "recordClosingTime": "2024-06-15T10:05:00Z",
  "durationSeconds": 300,
  "volumeUsage": 300,
  "impactedBalanceId": "BALANCE123456",
  "offerId": "OFFER123456"
}

Response:
{
  "usageId": "550e8400-e29b-41d4-a716-446655440000",
  "usageTimestamp": "2024-06-15T10:05:00Z",
  "balanceValueBefore": 3600,
  "balanceValueAfter": 3300,
  ... (all input fields)
}
```

**Example - Recording Data Usage:**
```
Scenario: 100MB data session
Input:
{
  "usageId": "660e8400-e29b-41d4-a716-446655440001",
  "usageTimestamp": "2024-06-15T11:30:00Z",
  "chargedPartyId": "SUB123456789",
  "chargedMsisdn": "436602238811",
  "aParty": "436602238811",
  "bParty": "internet.telco.com",
  "usageType": "DATA",
  "recordType": "STOP",
  "volumeUsage": 104857600,
  "impactedBalanceId": "BALANCE789012",
  "offerId": "OFFER789012"
}

Response:
{
  "usageId": "660e8400-e29b-41d4-a716-446655440001",
  "balanceValueBefore": 10737418240,
  "balanceValueAfter": 10632560640,
  ... (all input fields)
}
```

**Example - Recording SMS:**
```
Scenario: Single SMS message
Input:
{
  "usageId": "770e8400-e29b-41d4-a716-446655440002",
  "usageTimestamp": "2024-06-15T12:00:00Z",
  "chargedPartyId": "SUB123456789",
  "chargedMsisdn": "436602238811",
  "aParty": "436602238811",
  "bParty": "436602238833",
  "usageType": "SMS",
  "recordType": "EVENT",
  "volumeUsage": 1,
  "impactedBalanceId": "BALANCE345678",
  "offerId": "OFFER345678"
}

Response:
{
  "usageId": "770e8400-e29b-41d4-a716-446655440002",
  "balanceValueBefore": 100,
  "balanceValueAfter": 99,
  ... (all input fields)
}
```
    """
    try:
        logger.info(f"Adding usage for subscriber {usage.chargedPartyId}")
        data = usage.model_dump(mode='json', exclude_none=True)
        response = await ocs_client.post("/usage", json=data)
        logger.info(f"Successfully added usage record {response.get('usageId')}")
        return response
    except Exception as e:
        logger.error(f"Error adding usage: {e}")
        raise

async def list_usage_for_subscriber(subscriberId: str, limit: Optional[int] = 100, offset: Optional[int] = 0) -> List[Dict[str, Any]]:
    """
**Tool Name:** List Usage for Subscriber

**Purpose:** Retrieves a paginated list of usage records for a specific subscriber. This tool provides visibility into the subscriber's service consumption history, including all voice calls, data sessions, SMS, and MMS messages. Essential for billing verification, usage analysis, customer support, and troubleshooting balance discrepancies.

**Parameters:**
- `subscriberId` (required): The unique identifier of the subscriber whose usage records to retrieve
- `limit` (optional): Maximum number of usage records to return per request (default: 100, maximum: 100)
- `offset` (optional): Number of records to skip for pagination (default: 0)

**How to Obtain subscriberId:**
The subscriber ID can be obtained from:
1. **From lookup_subscriber response**: Query by MSISDN, IMSI, or name to get subscriberId
2. **From get_subscriber response**: Contains subscriberId field
3. **From create_subscriber response**: Returns created subscriber with subscriberId
4. **Known subscriber ID**: If you already have the subscriber's unique identifier

**Pagination:**
- Use `limit` and `offset` to paginate through large result sets
- Example: First page (limit=100, offset=0), Second page (limit=100, offset=100)
- Records are typically returned in reverse chronological order (newest first)
- Continue pagination until fewer records than limit are returned

**Returns:**
- Success (200): Array of usage records, each containing:
  - `usageId`: Unique identifier for the usage record
  - `usageTimestamp`: When the usage was recorded
  - `chargedPartyId`: Subscriber ID who was charged
  - `chargedMsisdn`: MSISDN that was charged
  - `aParty`: Originating party (MSISDN)
  - `bParty`: Terminating party (MSISDN or APN)
  - `usageType`: Type of usage (VOICE, DATA, SMS, MMS)
  - `recordType`: Record type (START, INTERIM, STOP, EVENT)
  - `recordOpeningTime`: When session started (for session-based usage)
  - `recordClosingTime`: When session ended (for session-based usage)
  - `durationSeconds`: Session duration in seconds
  - `volumeUsage`: Amount consumed (seconds for voice, bytes for data, count for SMS/MMS)
  - `impactedBalanceId`: Balance that was charged
  - `balanceValueBefore`: Balance before this usage
  - `balanceValueAfter`: Balance after this usage
  - `offerId`: Associated offer ID
- Error (400): Bad request - invalid parameters (e.g., negative offset, limit exceeds maximum)
- Error (404): Subscriber not found

**Use Cases:**
- **Billing Verification**: Review all usage charges before generating invoice
- **Usage Analysis**: Analyze subscriber consumption patterns (peak hours, service preferences)
- **Customer Support**: Investigate customer inquiries about charges or balance deductions
- **Balance Reconciliation**: Verify balance changes by reviewing usage history
- **Fraud Detection**: Identify unusual usage patterns or suspicious activity
- **Service Quality**: Track usage for dropped calls or failed sessions
- **Reporting**: Generate usage reports for subscriber, account, or system-level analytics

**Typical Workflow:**
1. Obtain the subscriberId using `lookup_subscriber` or from subscriber record
2. Call `list_usage_for_subscriber(subscriberId)` to retrieve usage records
3. For large datasets:
   a. Start with offset=0, limit=100
   b. Process returned records
   c. If 100 records returned, fetch next page with offset=100
   d. Repeat until fewer than limit records are returned
4. Analyze usage records for:
   - Total consumption by service type
   - Usage patterns and trends
   - Balance impact verification
   - Billing accuracy

**Important Considerations:**
- **Pagination Required**: Large usage histories require pagination - don't try to fetch all records at once
- **Performance**: Use appropriate limit values (default 100 is recommended)
- **Date Range**: API returns all usage records; filter by date in your application if needed
- **Usage Types**: Records include all service types (VOICE, DATA, SMS, MMS)
- **Balance Correlation**: Each usage record shows which balance was impacted and before/after values
- **Chronological Order**: Records typically ordered by timestamp (newest first)
- **Empty Results**: Empty array returned if subscriber has no usage records

**Example - Retrieving Usage Records:**
```
Request:
subscriberId: "SUB123456789"
limit: 100
offset: 0

Response:
[
  {
    "usageId": "550e8400-e29b-41d4-a716-446655440000",
    "usageTimestamp": "2024-06-15T10:05:00Z",
    "chargedPartyId": "SUB123456789",
    "chargedMsisdn": "436602238811",
    "aParty": "436602238811",
    "bParty": "436602238822",
    "usageType": "VOICE",
    "recordType": "STOP",
    "recordOpeningTime": "2024-06-15T10:00:00Z",
    "recordClosingTime": "2024-06-15T10:05:00Z",
    "durationSeconds": 300,
    "volumeUsage": 300,
    "impactedBalanceId": "BALANCE123456",
    "balanceValueBefore": 1000,
    "balanceValueAfter": 700,
    "offerId": "OFFER123456"
  },
  {
    "usageId": "660e8400-e29b-41d4-a716-446655440001",
    "usageTimestamp": "2024-06-15T11:30:00Z",
    "chargedPartyId": "SUB123456789",
    "chargedMsisdn": "436602238811",
    "aParty": "436602238811",
    "bParty": "internet.telco.com",
    "usageType": "DATA",
    "recordType": "STOP",
    "recordOpeningTime": "2024-06-15T11:00:00Z",
    "recordClosingTime": "2024-06-15T11:30:00Z",
    "durationSeconds": 1800,
    "volumeUsage": 104857600,
    "impactedBalanceId": "BALANCE789012",
    "balanceValueBefore": 5368709120,
    "balanceValueAfter": 5263851520,
    "offerId": "OFFER789012"
  }
]
```

**Example - Paginating Through Large Result Set:**
```
# Fetch first page
page1 = list_usage_for_subscriber("SUB123456789", limit=100, offset=0)
# Returns 100 records

# Fetch second page
page2 = list_usage_for_subscriber("SUB123456789", limit=100, offset=100)
# Returns 100 records

# Fetch third page
page3 = list_usage_for_subscriber("SUB123456789", limit=100, offset=200)
# Returns 45 records - last page (fewer than limit)
```
    """
    try:
        logger.info(f"Getting usage for subscriber {subscriberId} (limit={limit}, offset={offset})")
        params = {}
        if limit is not None:
            params['limit'] = limit
        if offset is not None:
            params['offset'] = offset
        
        response = await ocs_client.get(f"/subscribers/{subscriberId}/usage", params=params)
        logger.info(f"Retrieved {len(response)} usage records for subscriber {subscriberId}")
        return response
    except Exception as e:
        logger.error(f"Error getting usage for subscriber {subscriberId}: {e}")
        raise
