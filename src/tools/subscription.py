from typing import List, Dict, Any, Optional
import logging
from src.models.subscription import Subscription
from src.models.common import PatchOperation
from src.client import ocs_client

logger = logging.getLogger(__name__)

async def create_subscription(subscriberId: str, subscription: Subscription) -> Dict[str, Any]:
    """
**Tool Name:** Create Subscription

**Purpose:** Creates an active subscription instance by assigning a selected offer to a subscriber. This transforms an offer (template) into a subscription (active service instance) for the subscriber.

**Parameters:**
- `subscriberId` (required): The unique identifier of the subscriber who will receive the subscription
- `subscription` (required): Subscription object with fields populated from the chosen offer

**CRITICAL Workflow - Populating Subscription from Offer:**
When creating a subscription, you MUST populate the subscription fields using data from the offer selected by the user via `get_available_offers`:

1. **Call get_subscriber**: Verify subscriber exists and check subscriber type (PREPAID/POSTPAID)
2. **Call get_available_offers**: Retrieve the offer catalog
3. **Filter offers by subscriber type**: Only show offers where offer.type matches subscriber.type
4. **User selects an offer**: User chooses one of the compatible offers
5. **Map offer fields to subscription fields**:
   - `offerId`: Use offer's `offerId` (REQUIRED - e.g., "1000", "1001", "1002", "1003", "1010")
   - `offerName`: Use offer's `offerName` (e.g., "Basic prepaid plan")
   - `subscriptionType`: Use offer's `type` (e.g., "PREPAID" or "POSTPAID")
   - `recurring`: Use offer's `recurring` (true/false - determines if subscription auto-renews)
   - `paidFlag`: Use offer's `paid` (typically true for paid offers)
   - `isGroup`: Use offer's `groupOffer` (false for individual subscriptions)
   - `maxRecurringCycles`: Use offer's `maxRecurringCycles` (null for unlimited)
   - `cycleLengthUnits`: Use offer's `cycleLength` (e.g., 0, 1, 4)
   - `cycleLengthType`: Use offer's `cycleUnit` (e.g., "MONTH", "WEEK")
   - `state`: Set to "pending" initially (will be activated via separate /activate endpoint if needed)
   - `balances`: Leave null initially - balances are created automatically or via separate API calls based on offer's balance definitions

6. **Generate subscription ID**: Create unique subscriptionId (e.g., "SUB-{timestamp}-{random}")
7. **Call create_subscription**: Execute with subscriberId and populated subscription object
8. **Confirm activation**: Inform user of successful subscription with offer details

**Example Mapping (Offer 1010 → Subscription):**
```
Offer (from get_available_offers):
{
  "offerId": "1010",
  "offerName": "Premium prepaid plan",
  "type": "PREPAID",
  "recurring": true,
  "paid": true,
  "groupOffer": false,
  "maxRecurringCycles": null,
  "cycleLength": 0,
  "cycleUnit": "MONTH",
  "balances": [...]
}

→ Maps to Subscription:
{
  "subscriptionId": "SUB-20231214-ABC123",
  "offerId": "1010",
  "offerName": "Premium prepaid plan",
  "subscriptionType": "PREPAID",
  "recurring": true,
  "paidFlag": true,
  "isGroup": false,
  "maxRecurringCycles": null,
  "cycleLengthUnits": 0,
  "cycleLengthType": "MONTH",
  "state": "pending"
}
```

**Important Notes:**
- **Type Matching Required**: Subscriber type MUST match offer type (PREPAID ↔ PREPAID, POSTPAID ↔ POSTPAID)
- **Always use offer data**: Never create subscriptions with arbitrary values - all subscription parameters must come from the offer catalog
- **Balances**: The offer's `balances` array defines what allowances will be provisioned (voice SECONDS, SMS EVENTS, data BYTES), but these are typically created automatically by the OCS system or via separate balance API calls
- **State Management**: Subscriptions are initially created in "pending" state and may require activation
- **Unique IDs**: Generate unique subscriptionId for each subscription

**Returns:**
- Success (201): Complete subscription object with all fields, including subscriptionId
- Error (404): Subscriber not found
- Error (409): Conflict (duplicate subscription or invalid configuration)

**Use Cases:**
- Assigning a service plan to a new subscriber during onboarding
- Adding additional data bundles to existing subscribers
- Upgrading/changing subscriber service packages
- Creating family or group subscription instances
    """
    # Convert the Pydantic model to a dict, excluding None values
    data = subscription.model_dump(mode='json', exclude_none=True)
    
    logger.info(f"create_subscription called for subscriber {subscriberId} with data: {data}")
    result = await ocs_client.request(
        method="POST",
        endpoint=f"/subscribers/{subscriberId}/subscriptions",
        json=data
    )
    logger.info(f"create_subscription result: {result}")
    return result

async def list_subscriptions(subscriberId: str) -> List[Dict[str, Any]]:
    """
**Tool Name:** List Subscriptions

**Purpose:** Retrieves all subscription instances associated with a specific subscriber. This provides a complete overview of all active, pending, suspended, and expired subscriptions for the subscriber.

**Parameters:**
- `subscriberId` (required): The unique identifier of the subscriber whose subscriptions to retrieve

**Typical Workflow:**
1. Call `get_subscriber(subscriberId)` to verify subscriber exists (optional but recommended)
2. Call `list_subscriptions(subscriberId)` to retrieve all subscriptions for that subscriber
3. Review the returned list of subscription objects
4. Optionally call `get_subscription(subscriptionId)` for detailed information on specific subscriptions of interest

**Returns:**
- Success (200): Array of subscription objects, where each subscription includes:
  - `subscriptionId`: Unique identifier (use this with get_subscription for details)
  - `subscriberId`: The associated subscriber ID
  - `offerId`: The offer this subscription is based on
  - `offerName`: Name of the offer
  - `subscriptionType`: PREPAID or POSTPAID
  - `state`: Current state (pending, active, suspended, cancelled, expired)
  - `recurring`: Whether subscription auto-renews
  - `cycleLengthUnits` & `cycleLengthType`: Billing cycle information
  - `balances`: Array of balance objects (voice SECONDS, SMS EVENTS, data BYTES)
  - Lifecycle timestamps: `createdAt`, `activatedAt`, `expiresAt`, etc.
- Success (200) with empty array: Subscriber has no subscriptions
- Error (404): Subscriber not found
- Error (401/403): Authentication or authorization error

**Use Cases:**
- Getting an overview of all subscriptions for a subscriber
- Checking which offers/plans a subscriber currently has
- Identifying active vs expired subscriptions
- Finding subscriptionId values to use with get_subscription for detailed queries
- Auditing subscriber's subscription history and current service portfolio
- Displaying subscription list to end users or support agents

**When to Use:**
- Use `list_subscriptions` when you need to see all subscriptions for a subscriber at once
- Use `get_subscription` when you already have a subscriptionId and need detailed information for that specific subscription
- The `get_subscriber` response also includes a subscriptions array, but `list_subscriptions` may provide more detailed or filtered results depending on API implementation

**Example:**
```
Call: list_subscriptions("12345678")
Response: [
  {
    "subscriptionId": "SUB-001",
    "offerId": "1000",
    "offerName": "Basic prepaid plan",
    "state": "active",
    ...
  },
  {
    "subscriptionId": "SUB-002",
    "offerId": "1002",
    "offerName": "Weekly data bundle",
    "state": "expired",
    ...
  }
]
```
    """
    logger.info(f"list_subscriptions called for subscriber {subscriberId}")
    result = await ocs_client.request(
        method="GET",
        endpoint=f"/subscribers/{subscriberId}/subscriptions"
    )
    logger.info(f"list_subscriptions result: {result}")
    return result

async def get_subscription(subscriptionId: str) -> Dict[str, Any]:
    """
**Tool Name:** Get Subscription

**Purpose:** Retrieves detailed information about a specific subscription instance including its configuration, state, balances, and lifecycle details.

**Parameters:**
- `subscriptionId` (required): The unique identifier of the subscription to retrieve

**How to Obtain subscriptionId:**
The subscription ID is available from multiple sources:
1. **From get_subscriber response**: When calling `get_subscriber(subscriberId)`, the response includes a `subscriptions` array where each subscription object contains a `subscriptionId` field
2. **From list_subscriptions response**: When calling `list_subscriptions(subscriberId)`, each subscription in the returned list includes its `subscriptionId`
3. **From create_subscription response**: When creating a new subscription, the response includes the generated `subscriptionId`

**Typical Workflow:**
1. Call `get_subscriber(subscriberId)` to retrieve subscriber information
2. Extract `subscriptionId` values from the `subscriptions` array in the response
3. Call `get_subscription(subscriptionId)` for each subscription ID to get detailed information
4. Review subscription details including state, balances, offer information, and lifecycle dates

**Example:**
```
Step 1: Get subscriber
  → Response includes: {"subscriptions": [{"subscriptionId": "SUB-001", ...}, {"subscriptionId": "SUB-002", ...}]}

Step 2: Get details for specific subscription
  → Call get_subscription("SUB-001")
  → Returns complete subscription object with all fields
```

**Returns:**
- Success (200): Complete subscription object including:
  - `subscriptionId`: Unique identifier
  - `subscriberId`: Associated subscriber ID
  - `offerId`: The offer this subscription is based on
  - `offerName`: Name of the offer
  - `subscriptionType`: PREPAID or POSTPAID
  - `state`: Current state (pending, active, suspended, cancelled, expired)
  - `recurring`: Whether subscription auto-renews
  - `cycleLengthUnits` & `cycleLengthType`: Billing cycle information
  - `balances`: Array of balance objects (voice SECONDS, SMS EVENTS, data BYTES)
  - Lifecycle timestamps: `createdAt`, `activatedAt`, `expiresAt`, etc.
- Error (404): Subscription not found
- Error (401/403): Authentication or authorization error

**Use Cases:**
- Reviewing detailed subscription configuration after retrieving subscriber info
- Checking subscription state and balance allocations
- Verifying subscription lifecycle dates (creation, activation, expiration)
- Auditing subscription parameters before performing updates
- Displaying complete subscription details to end users

**Note:** Use `list_subscriptions(subscriberId)` if you need to retrieve all subscriptions for a subscriber at once, then use this tool to get detailed information for specific subscriptions of interest.
    """
    logger.info(f"get_subscription called for subscription {subscriptionId}")
    result = await ocs_client.request(
        method="GET",
        endpoint=f"/subscriptions/{subscriptionId}"
    )
    logger.info(f"get_subscription result: {result}")
    return result

async def update_subscription(subscriptionId: str, patches: List[PatchOperation]) -> Dict[str, Any]:
    """
    Update subscription fields.
    """
    data = [patch.model_dump(mode='json') for patch in patches]
    logger.info(f"update_subscription called for {subscriptionId} with patches: {data}")
    result = await ocs_client.request(
        method="PATCH",
        endpoint=f"/subscriptions/{subscriptionId}",
        json=data
    )
    logger.info(f"update_subscription result: {result}")
    return result

async def delete_subscription(subscriptionId: str) -> Optional[Dict[str, Any]]:
    """
**Tool Name:** Delete Subscription

**Purpose:** Permanently removes a subscription instance from the system. This action cancels the subscription and terminates the associated services for the subscriber.

**Parameters:**
- `subscriptionId` (required): The unique identifier of the subscription to delete

**How to Obtain subscriptionId:**
The subscription ID is available from multiple sources:
1. **From get_subscriber response**: When calling `get_subscriber(subscriberId)`, the response includes a `subscriptions` array where each subscription object contains a `subscriptionId` field
2. **From list_subscriptions response**: When calling `list_subscriptions(subscriberId)`, each subscription in the returned list includes its `subscriptionId`
3. **From get_subscription response**: If you already retrieved subscription details
4. **From create_subscription response**: When a subscription was just created

**Typical Workflow:**
1. Call `get_subscriber(subscriberId)` or `list_subscriptions(subscriberId)` to retrieve subscriber's subscriptions
2. Identify the subscription to delete by reviewing subscription details (offerId, state, etc.)
3. Extract the `subscriptionId` from the target subscription
4. Optionally call `get_subscription(subscriptionId)` to verify subscription details before deletion
5. Call `delete_subscription(subscriptionId)` to permanently remove the subscription
6. Confirm deletion and inform user

**Important Considerations:**
- **Permanent Action**: Deletion is typically permanent and cannot be undone
- **Service Termination**: Deleting a subscription immediately terminates the associated services
- **Balance Impact**: Any remaining balances (voice SECONDS, SMS EVENTS, data BYTES) will be lost
- **Active Services**: Consider the subscription state before deletion - deleting an active subscription will disrupt service
- **Alternative Actions**: Consider using `update_subscription` to change state to "suspended" or "cancelled" instead of permanent deletion if service needs to be temporarily disabled
- **User Confirmation**: Always confirm with the user before deleting subscriptions, especially active ones

**Returns:**
- Success (200/204): Subscription successfully deleted, may return empty response or deletion confirmation
- Error (404): Subscription not found (already deleted or invalid ID)
- Error (409): Conflict - subscription cannot be deleted due to business rules (e.g., pending transactions)
- Error (401/403): Authentication or authorization error

**Use Cases:**
- Removing expired or cancelled subscriptions from the system
- Cleaning up test or incorrectly created subscriptions
- Terminating subscriber service when account is closed
- Removing duplicate subscriptions
- Processing subscription cancellation requests from users

**Example Workflow:**
```
Step 1: Get subscriber's subscriptions
  → Call list_subscriptions("12345678")
  → Response: [{"subscriptionId": "SUB-001", "state": "expired", ...}, {"subscriptionId": "SUB-002", "state": "active", ...}]

Step 2: Identify subscription to delete
  → User wants to remove expired subscription "SUB-001"

Step 3: Delete subscription
  → Call delete_subscription("SUB-001")
  → Response: Success (subscription deleted)
```

**Best Practices:**
- Always verify the subscription details before deletion
- Confirm with the user, especially for active subscriptions
- Log deletion actions for audit purposes
- Consider state transitions (suspend/cancel) before permanent deletion
- Check for dependent resources or services before deletion
    """
    logger.info(f"delete_subscription called for {subscriptionId}")
    result = await ocs_client.request(
        method="DELETE",
        endpoint=f"/subscriptions/{subscriptionId}"
    )
    logger.info(f"delete_subscription result: {result}")
    return result

async def change_subscription_state(subscriptionId: str, action: str) -> Dict[str, Any]:
    """
**Tool Name:** Change Subscription State

**Purpose:** Changes the state of a subscription by executing state transition operations. This tool combines activate, suspend, cancel, and renew operations into a single interface for managing the subscription lifecycle.

**Parameters:**
- `subscriptionId` (required): The unique identifier of the subscription whose state to change
- `action` (required): The state transition action to perform. Must be one of:
  - `"active"`: Activate a pending or suspended subscription
  - `"suspend"`: Suspend an active subscription
  - `"cancelled"`: Cancel an active or suspended subscription
  - `"renew"`: Renew/increment the recurring cycle for an active subscription

**How to Obtain subscriptionId:**
The subscription ID is available from multiple sources:
1. **From get_subscriber response**: When calling `get_subscriber(subscriberId)`, the response includes a `subscriptions` array where each subscription object contains a `subscriptionId` field
2. **From list_subscriptions response**: When calling `list_subscriptions(subscriberId)`, each subscription in the returned list includes its `subscriptionId`
3. **From get_subscription response**: If you already retrieved subscription details
4. **From create_subscription response**: When a subscription was just created

**State Transitions by Action:**

**Action: "active"**
- Allowed from states: PENDING, SUSPENDED
- Transitions to: ACTIVE
- Sets: activationDate and calculates renewalDate for recurring subscriptions
- Use when: Activating a new subscription or reactivating a suspended one
- Example: After creating a subscription in PENDING state, activate it to enable service

**Action: "suspend"**
- Allowed from states: ACTIVE
- Transitions to: SUSPENDED
- Use when: Temporarily disabling service for a subscriber (e.g., payment issues, customer request)
- Example: Suspend an active subscription to prevent further charges while keeping the subscription record

**Action: "cancelled"**
- Allowed from states: ACTIVE, SUSPENDED
- Transitions to: CANCELLED
- Use when: Permanently ending the subscription (cannot be reactivated)
- Example: Customer cancels service or account is closed
- Note: This is permanent - use suspend for temporary service interruption

**Action: "renew"**
- Allowed from states: ACTIVE
- Operation: Increments the recurring cycle count for recurring subscriptions
- Recalculates: renewalDate after cycle increment if subscription not expired
- Use when: Renewing a subscription for the next billing cycle
- Example: Monthly subscription cycle ends and needs renewal for next period
- Note: Only applies to subscriptions with recurring=true

**Typical Workflows:**

**Workflow 1: New Subscription Activation**
```
1. Call create_subscription() with subscription data → Returns subscription in PENDING state
2. Call change_subscription_state(subscriptionId, "active") → Transitions to ACTIVE
3. Service becomes available to subscriber
```

**Workflow 2: Subscription Suspension (Temporary)**
```
1. Call get_subscription(subscriptionId) → Verify current state is ACTIVE
2. Call change_subscription_state(subscriptionId, "suspend") → Transitions to SUSPENDED
3. Service is suspended, no charges incurred
4. Call change_subscription_state(subscriptionId, "active") → Reactivate if customer resolves issue
```

**Workflow 3: Subscription Cancellation (Permanent)**
```
1. Call get_subscription(subscriptionId) → Check current state and remaining balances
2. Call change_subscription_state(subscriptionId, "cancelled") → Transitions to CANCELLED
3. Service terminates permanently, subscription cannot be reactivated
```

**Workflow 4: Recurring Subscription Renewal**
```
1. Call get_subscription(subscriptionId) → Verify state is ACTIVE and subscription is recurring
2. Call change_subscription_state(subscriptionId, "renew") → Increments cycle count
3. renewalDate is recalculated for next cycle
4. Service continues for another billing period
```

**Returns:**
- Success (200): State transition successful, returns updated subscription object with:
  - Updated `state` field reflecting the new state
  - Updated timestamps (e.g., `activatedAt`, `suspendedAt`, `renewalDate`)
  - All other subscription fields
- Error (400): Bad request (invalid action parameter)
- Error (404): Subscription not found
- Error (409): Conflict - state transition not allowed from current state (e.g., trying to suspend a pending subscription)
- Error (422): Invalid state transition for this subscription

**Use Cases:**
- Activating newly created subscriptions to make services available
- Temporarily suspending service for subscribers (payment issues, customer request)
- Permanently cancelling subscriptions when customers leave
- Auto-renewing recurring subscriptions at the end of billing cycles
- Managing subscription lifecycle in customer onboarding flows
- Handling service interruptions and restorations

**Important Considerations:**

**Activation:**
- Only works from PENDING or SUSPENDED states
- Sets activation date and calculates first renewal date
- Required before service becomes available to subscriber

**Suspension:**
- Pauses service without terminating subscription record
- Can be reactivated by calling with "active" action
- Useful for temporary service interruptions (payment issues, maintenance, customer requests)
- Balances and subscription configuration are preserved

**Cancellation:**
- Permanent action - cannot be undone
- Any remaining balances will be lost
- Subscription cannot be reactivated after cancellation
- Consider alternatives (suspend) before cancelling

**Renewal:**
- Only applies to subscriptions where recurring=true
- Increments the recurring cycle count
- Recalculates renewalDate for next billing period
- Must be called when current cycle expires to continue service

**State Transition Rules:**
- PENDING → ACTIVE (via "active" action)
- ACTIVE → SUSPENDED (via "suspend" action)
- ACTIVE → CANCELLED (via "cancelled" action)
- SUSPENDED → ACTIVE (via "active" action)
- SUSPENDED → CANCELLED (via "cancelled" action)
- ACTIVE → ACTIVE+1 cycle (via "renew" action)
- Cannot transition from CANCELLED, EXPIRED states

**Best Practices:**
- Always verify subscription state before state transitions using get_subscription
- Check subscription type and balance allocations before suspension/cancellation
- Confirm cancellations with user - emphasize this is permanent
- Use renewal automatically for recurring subscriptions when cycles complete
- Log all state changes for audit and support purposes
- Inform subscribers of state changes (activation, suspension, cancellation, renewal)
- For temporary service stops, use suspend instead of cancel
    """
    logger.info(f"change_subscription_state called for {subscriptionId} with action: {action}")
    
    # Validate action parameter
    valid_actions = ["active", "suspend", "cancelled", "renew"]
    if action.lower() not in valid_actions:
        logger.error(f"Invalid action: {action}. Must be one of {valid_actions}")
        return {
            "error": f"Invalid action '{action}'. Must be one of: {', '.join(valid_actions)}"
        }
    
    # Map action to endpoint
    action_lower = action.lower()
    endpoint_map = {
        "active": f"/subscriptions/{subscriptionId}/activate",
        "suspend": f"/subscriptions/{subscriptionId}/suspend",
        "cancelled": f"/subscriptions/{subscriptionId}/cancel",
        "renew": f"/subscriptions/{subscriptionId}/renew"
    }
    
    endpoint = endpoint_map[action_lower]
    
    try:
        result = await ocs_client.request(
            method="POST",
            endpoint=endpoint
        )
        logger.info(f"change_subscription_state result: {result}")
        return result
    except Exception as e:
        logger.error(f"Error changing subscription state: {str(e)}")
        raise
