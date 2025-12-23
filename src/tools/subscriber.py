from typing import Any, Dict, List, Optional
import logging
import uuid
import random
from datetime import datetime

from src.client import ocs_client
from src.models.subscriber import Subscriber
from src.models.common import PatchOperation, SubscriberState

logger = logging.getLogger(__name__)

async def lookup_subscriber(
    msisdn: Optional[str] = None,
    imsi: Optional[str] = None,
    first_name: Optional[str] = None,
    last_name: Optional[str] = None,
    transaction_id: Optional[str] = None,
) -> Dict[str, Any]:
    """
**Tool Name:** Lookup Subscriber ID

**Purpose:** Retrieves a subscriber's unique identifier (subscriberId) using one of three lookup methods: phone number (MSISDN), SIM identifier (IMSI), or customer name (first and last name combined).

**Input Parameters:**
- `msisdn` (string, optional): Mobile Station International Subscriber Directory Number (phone number)
- `imsi` (string, optional): International Mobile Subscriber Identity (SIM card identifier)
- `firstName` (string, optional): Customer's first name (must be used with lastName)
- `lastName` (string, optional): Customer's last name (must be used with firstName)

**Requirements:**
- Provide exactly ONE of: msisdn, imsi, OR the firstName+lastName pair
- Name searches require both first AND last name

**Returns:**
- `subscriberId` (string): The unique subscriber identifier when found
Or, if not found:
- `ResultCode` (string): Status code indicating failure

**Error Handling:**
- When subscriber doesn't exist: ResultCode = "Entity not found"
- Invalid input combinations will return appropriate error codes

**Use Cases:**
- Customer service lookup by phone number
- Technical support using SIM card identifier
- Account retrieval by customer name when other identifiers unavailable
    """
    if transaction_id is None:
        transaction_id = str(uuid.uuid4())
    
    params = {}
    if msisdn:
        params["msisdn"] = msisdn
    if imsi:
        params["imsi"] = imsi
    if first_name:
        params["firstName"] = first_name
    if last_name:
        params["lastName"] = last_name
        
    logger.info(f"lookup_subscriber called with params: {params}")
    result = await ocs_client.get("/subscribers/lookup", transaction_id=transaction_id, params=params)
    logger.info(f"lookup_subscriber result: {result}")
    return result

async def create_subscriber(
    first_name: str,
    last_name: str,
    email: str,
    subscriber_type: str = "PREPAID",
    language_id: str = "EN",
    street: str = "Attemsgasse",
    city: str = "Vienna",
    country: str = "Austria",
    transaction_id: Optional[str] = None,
) -> Dict[str, Any]:
    """
**Tool Name:** Create OCS Subscriber

**Purpose:** Creates a new subscriber account in the OCS (Online Charging System) with auto-generated unique identifiers. The tool automatically generates and validates MSISDN (phone number) and IMSI (SIM identifier) to ensure uniqueness across the system.

**Required Parameters:**
- `first_name` (string): Subscriber's first name
- `last_name` (string): Subscriber's last name
- `email` (string): Subscriber's email address

**Optional Parameters:**
- `subscriber_type` (string): Account type (default: "PREPAID")
  - Common values: PREPAID, POSTPAID
- `language_id` (string): Preferred language code (default: "EN")
  - Common values: EN, DE, FR, etc.
- `street` (string): Street address (default: "Attemsgasse")
- `city` (string): City name (default: "Vienna")
- `country` (string): Country name (default: "Austria")
- `transaction_id` (string): Custom transaction identifier for tracking/logging purposes

**Automatic Generation:**
- `msisdn`: Randomly generated phone number, validated for uniqueness
- `imsi`: Randomly generated SIM card identifier

**Returns:**
- `subscriberId` (string): **Primary identifier for all future operations** - store this value
- `msisdn` (string): The generated phone number
- `imsi` (string): The generated SIM identifier
- Full subscriber details including all provided and generated fields

**Important Notes:**
- The returned `subscriberId` is required for all subsequent subscriber operations (get, updates, deletions)
- MSISDN uniqueness is automatically enforced - the tool will retry generation if conflicts occur
- All address fields have Vienna, Austria defaults for convenience
- Don't assume values for required fields—they must be explicitly provided. If any are missing, ask the user directly. For example, don't infer an email address from a name.

**Use Cases:**
- Onboarding new customers
- Bulk subscriber provisioning
- Testing and development environments
    """
    if transaction_id is None:
        transaction_id = str(uuid.uuid4())
    
    # Generate a unique MSISDN by checking if it already exists
    max_attempts = 10
    msisdn = None
    
    for attempt in range(max_attempts):
        # Generate random 7-digit number
        random_number = random.randint(1000000, 9999999)
        candidate_msisdn = f"43660{random_number:07d}"
        
        # Check if subscriber with this MSISDN exists
        logger.info(f"Checking if MSISDN {candidate_msisdn} exists (attempt {attempt + 1}/{max_attempts})")
        lookup_result = await ocs_client.get(
            "/subscribers/lookup",
            transaction_id=transaction_id,
            params={"msisdn": candidate_msisdn}
        )
        
        # If ResultCode indicates entity not found, we can use this MSISDN
        if lookup_result.get("ResultCode") == "Entity not found":
            msisdn = candidate_msisdn
            logger.info(f"Found unique MSISDN: {msisdn}")
            break
        else:
            logger.info(f"MSISDN {candidate_msisdn} already exists, trying another")
    
    if msisdn is None:
        raise Exception(f"Failed to generate unique MSISDN after {max_attempts} attempts")
    
    # Use the same random number for IMSI for consistency
    random_number = int(msisdn[-7:])
    
    # Construct the subscriber object with generated values
    subscriber_data = {
        "msisdn": msisdn,
        "imsi": f"23205660{random_number:07d}",
        "subscriberType": subscriber_type,
        "languageId": language_id,
        "carrierId": "MAGENTA",
        "currentState": SubscriberState.ACTIVE,
        "personalInfo": {
            "firstName": first_name,
            "lastName": last_name,
            "email": email,
        },
        "services": {
            "voice": True,
            "sms": True,
            "mms": True,
            "data": True,
            "roaming": False,
            "valueAddedServices": [
                "voicemail",
                "callWaiting",
                "internationalCalls"
            ]
        },
        "billing": {
            "billingAddress": {
                "street": street,
                "city": city,
                "country": country,
            }
        }
    }
    
    # Add billing cycle information only for POSTPAID subscribers
    if subscriber_type == "POSTPAID":
        current_day = datetime.now().day
        billcycle_day = 1 if current_day > 28 else current_day
        
        subscriber_data["billing"]["billcycleDay"] = billcycle_day
        subscriber_data["billing"]["billingCycle"] = "MONTHLY"

    # Validate with Pydantic model
    model = Subscriber(**subscriber_data)
    payload = model.model_dump(exclude_none=True, mode='json')

    logger.info(f"create_subscriber called with payload: {payload}")
    result = await ocs_client.post("/subscribers", transaction_id=transaction_id, json=payload)
    logger.info(f"create_subscriber result: {result}")
    return result

async def get_subscriber(
    subscriber_id: str,
    transaction_id: Optional[str] = None,
) -> Dict[str, Any]:
    """
**Tool Name:** Get Subscriber Details

**Purpose:** Retrieves complete subscriber information using their unique subscriber identifier. This tool fetches all stored details for an existing subscriber account.

**Required Parameters:**
- `subscriber_id` (string): The unique subscriber identifier
  - **Note:** If you don't have the subscriberId, use the `lookup_subscriber` tool first to find it via MSISDN, IMSI, or name

**Optional Parameters:**
- `transaction_id` (string): Custom transaction identifier for tracking/logging purposes

**Returns:**
When subscriber exists:
- Complete subscriber profile in JSON format including:
  - Personal information (first name, last name, email)
  - Identifiers (subscriberId, msisdn, imsi)
  - Account details (subscriber_type, language_id)
  - Address information (street, city, country)
  - Any additional stored attributes

When subscriber not found:
- `ResultCode`: "Entity not found"

**Workflow:**
1. If you have subscriberId → use this tool directly
2. If you only have MSISDN/IMSI/name → use `lookup_subscriber` first to get subscriberId, then use this tool

**Use Cases:**
- Viewing complete customer profile
- Verifying subscriber information before updates
- Customer service inquiries
- Account auditing and validation

**Error Handling:**
- Invalid or non-existent subscriberId returns "Entity not found" status
- Ensure subscriberId format is correct (typically returned from `create_subscriber` or `lookup_subscriber` tools)
    """
    if transaction_id is None:
        transaction_id = str(uuid.uuid4())
    
    logger.info(f"get_subscriber called with subscriber_id: {subscriber_id}")
    result = await ocs_client.get(f"/subscribers/{subscriber_id}", transaction_id=transaction_id)
    logger.info(f"get_subscriber result: {result}")
    return result

async def update_subscriber(
    subscriber_id: str,
    patches: List[Dict[str, Any]],
    transaction_id: Optional[str] = None,
) -> Dict[str, Any]:
    """
**Tool Name:** Update Subscriber

**Purpose:** Modifies existing subscriber information using JSON patch operations. Allows selective updates to one or multiple fields without affecting unchanged attributes.

**Required Parameters:**
- `subscriber_id` (string): The unique subscriber identifier
  - **Note:** Use `lookup_subscriber` to find subscriberId if you only have MSISDN, IMSI, or name
- `patches` (array): List of field update operations, each containing:
  - `fieldName` (string): The field to update. Note: must match exact field names in the subscriber schema
  - `fieldValue` (string/number/boolean): The new value for the field

**Optional Parameters:**
- `transaction_id` (string): Custom transaction identifier for tracking/logging purposes

**Patch Operations Format:**
```json
[
  {"fieldName": "email", "fieldValue": "newemail@example.com"},
  {"fieldName": "firstName", "fieldValue": "John"},
  {"fieldName": "subscriberType", "fieldValue": "POSTPAID"}
]
```

**Updatable Fields:**

*Personal Information:*
- `email` (string): Email address
- `contactNumber` (string): Contact/phone number
- `firstName` (string): First name
- `lastName` (string): Last name

*System Fields:*
- `languageId` (string): Language preference (e.g., "EN", "DE", "FR", "IT")
- `state` (string): Subscriber state (e.g., "ACTIVE", "SUSPENDED", "DEACTIVATED")

*Billing Fields:*
- `billingStreet` (string): Billing street address
- `billingCity` (string): Billing city
- `billingCountry` (string): Billing country
- `billcycleDay` (integer): Billing cycle day (e.g., 15)

**Returns:**
- Success confirmation with updated subscriber details
- Or error status if update fails

**Important Notes:**
- Only specified fields are modified; all other fields remain unchanged
- Multiple fields can be updated in a single operation
- Validate field names match exact system schema
- Some fields may have validation rules (e.g., unique MSISDN)

**Use Cases:**
- Updating customer contact information
- Changing account type (prepaid ↔ postpaid)
- Correcting address details
- Bulk field modifications

**Error Handling:**
- Invalid subscriberId returns "Entity not found"
- Invalid fieldName returns schema validation error
- Constraint violations (e.g., duplicate MSISDN) return appropriate error codes
    """
    if transaction_id is None:
        transaction_id = str(uuid.uuid4())
    
    # Validate patches
    validated_patches = [PatchOperation(**p).model_dump(mode='json') for p in patches]
    
    logger.info(f"update_subscriber called for {subscriber_id} with patches: {validated_patches}")
    result = await ocs_client.patch(
        f"/subscribers/{subscriber_id}", 
        transaction_id=transaction_id, 
        json=validated_patches
    )
    logger.info(f"update_subscriber result: {result}")
    return result

async def delete_subscriber(
    subscriber_id: str,
    transaction_id: Optional[str] = None,
) -> str:
    """
**Tool Name:** Delete Subscriber

**Purpose:** Permanently removes a subscriber account from the OCS (Online Charging System). This operation deletes all associated subscriber data and cannot be undone.

**Required Parameters:**
- `subscriber_id` (string): The unique subscriber identifier of the account to delete.
  - **Note:** Use `lookup_subscriber` to find subscriberId if you only have MSISDN, IMSI, or name

**Optional Parameters:**
- `transaction_id` (string): Custom transaction identifier for tracking/logging purposes

**Returns:**
- `ResultCode` : "Subscriber successfully deleted" when subscriber is deleted
- `ResultCode`: "Entity not found" if subscriberId doesn't exist

**⚠️ Important Warnings:**
- **This operation is irreversible** - deleted subscriber data cannot be recovered
- Frees up the MSISDN and IMSI for potential reuse
- Any active services or balances associated with the subscriber will be lost
- Consider archiving subscriber data before deletion if audit trails are required

**Pre-Deletion Checklist:**
1. Verify you have the correct subscriberId
2. Check for outstanding balances or active services
3. Ensure regulatory/compliance requirements for data retention are met
4. Confirm deletion intent with appropriate authorization

**Use Cases:**
- Account closure/termination
- GDPR/data privacy deletion requests
- Cleaning up test/development accounts
- Removing duplicate or erroneous entries

**Error Handling:**
- Invalid or non-existent subscriberId returns "Entity not found" result code

**Alternative:** If you need to deactivate without deleting, consider using `update_subscriber` to change the account status instead.
    """
    if transaction_id is None:
        transaction_id = str(uuid.uuid4())
    
    logger.info(f"delete_subscriber called with subscriber_id: {subscriber_id}")
    await ocs_client.delete(f"/subscribers/{subscriber_id}", transaction_id=transaction_id)
    logger.info(f"delete_subscriber completed for {subscriber_id}")
    return f"Subscriber {subscriber_id} deleted successfully"

async def change_subscriber_state(
    subscriber_id: str,
    state: str,
    transaction_id: Optional[str] = None,
) -> Dict[str, Any]:
    """
**Tool Name:** Change Subscriber State

**Purpose:** Manages subscriber lifecycle by transitioning between operational states. This dedicated endpoint tracks state transitions automatically and creates audit trail entries for compliance and operational tracking.

**Required Parameters:**
- `subscriber_id` (string): The unique subscriber identifier
  - **Note:** Use `lookup_subscriber` to find subscriberId if you only have MSISDN, IMSI, or name
- `state` (string): The new subscriber state to transition to. Must be one of:
  - **"ACTIVE"**: Subscriber is active and can use services
  - **"SUSPENDED"**: Subscriber is temporarily suspended (e.g., payment issues, fraud prevention)
  - **"DEACTIVATED"**: Subscriber is deactivated but account remains (can be reactivated)
  - **"TERMINATED"**: Subscriber is permanently terminated (account closure)
  - **"PRE_PROVISIONED"**: Subscriber is pre-provisioned but not yet activated

**Optional Parameters:**
- `transaction_id` (string): Custom transaction identifier for tracking/logging purposes

**Automatic Tracking:**
This endpoint automatically tracks and updates:
- `currentState`: Set to the new state provided
- `previousState`: Automatically saved before transition
- `lastTransitionDate`: Timestamp of the state change
- **Account History**: Creates an automatic audit entry for the state change (requirement T099)

**Valid State Transitions:**

*From PRE_PROVISIONED:*
- → ACTIVE: Initial activation of subscriber
- → TERMINATED: Cancel before activation

*From ACTIVE:*
- → SUSPENDED: Temporary service suspension (payment issues, fraud, customer request)
- → DEACTIVATED: Service deactivation (voluntary or administrative)
- → TERMINATED: Permanent account termination

*From SUSPENDED:*
- → ACTIVE: Restore service after suspension resolved
- → DEACTIVATED: Move to deactivated state
- → TERMINATED: Permanent termination from suspended state

*From DEACTIVATED:*
- → ACTIVE: Reactivate deactivated subscriber
- → TERMINATED: Permanent termination from deactivated state

*From TERMINATED:*
- No transitions allowed (terminal state)

**Returns:**
- Success (200): Complete subscriber object with updated state information including:
  - `currentState`: The new state
  - `previousState`: The state before transition
  - `lastTransitionDate`: Timestamp of the transition
  - All other subscriber fields
- Error (400): Bad request - invalid state value
- Error (404): Subscriber not found
- Error (422): Invalid state transition (business rules violation)

**Use Cases:**
1. **Service Activation**: Transition PRE_PROVISIONED → ACTIVE when onboarding completes
2. **Payment Issues**: Transition ACTIVE → SUSPENDED when payment fails
3. **Service Restoration**: Transition SUSPENDED → ACTIVE when payment received
4. **Voluntary Deactivation**: Transition ACTIVE → DEACTIVATED for temporary service stop
5. **Fraud Prevention**: Transition ACTIVE → SUSPENDED for security investigation
6. **Account Closure**: Transition ACTIVE/SUSPENDED/DEACTIVATED → TERMINATED for permanent closure
7. **Reactivation**: Transition DEACTIVATED → ACTIVE when subscriber returns

**Important Notes:**
- **Automatic Audit Trail**: Every state change automatically creates an account history entry (T099)
- **State Tracking**: System automatically tracks previousState and transition timestamp (FR-004)
- **Terminal State**: TERMINATED is a final state - no further transitions possible
- **Service Impact**: State transitions may immediately affect service availability
- **Business Rules**: Some transitions may be restricted by business logic (e.g., direct PRE_PROVISIONED → TERMINATED might require approval)

**Workflow Examples:**

*Example 1: New Subscriber Activation*
```
1. Subscriber created with state PRE_PROVISIONED
2. Complete onboarding validation
3. Call change_subscriber_state(subscriberId, "ACTIVE")
4. Subscriber services become available
5. Account history entry automatically created
```

*Example 2: Payment Suspension and Restoration*
```
1. Payment fails for ACTIVE subscriber
2. Call change_subscriber_state(subscriberId, "SUSPENDED")
3. Services suspended, previousState saved as ACTIVE
4. Payment received and verified
5. Call change_subscriber_state(subscriberId, "ACTIVE")
6. Services restored
```

*Example 3: Account Closure*
```
1. Subscriber requests account closure
2. Call change_subscriber_state(subscriberId, "TERMINATED")
3. Account permanently closed
4. Audit trail entry created with reason
5. No further state transitions possible
```

*Example 4: Reactivating Existing Subscriber*
```
1. Subscriber with DEACTIVATED state requests service reactivation
2. Verify subscriber details with get_subscriber(subscriberId)
3. Confirm current state is DEACTIVATED
4. Call change_subscriber_state(subscriberId, "ACTIVE")
5. Services restored, subscriber can use all active subscriptions
6. previousState saved as DEACTIVATED, lastTransitionDate updated
7. Account history entry automatically created
```

*Example 5: Activating Pre-Provisioned Existing Subscriber*
```
1. Subscriber already exists in system with PRE_PROVISIONED state
2. Lookup subscriber: lookup_subscriber(msisdn="43660123456")
3. Get full details: get_subscriber(subscriberId)
4. Verify state is PRE_PROVISIONED and all required data is complete
5. Complete activation requirements (SIM activation, payment verification, etc.)
6. Call change_subscriber_state(subscriberId, "ACTIVE")
7. Subscriber activated, services become available
8. previousState saved as PRE_PROVISIONED, activationDate set
9. Account history entry automatically created
```

**Error Handling:**
- Invalid state value: Returns 400 with list of valid states
- Subscriber not found: Returns 404 with error details
- Invalid transition: Returns 422 with business rule violation details
- Ensure state parameter exactly matches enum values (case-sensitive)

**Best Practices:**
1. Always verify current subscriber state before transitions using `get_subscriber`
2. Document business reason for state changes in surrounding workflow
3. Confirm critical transitions (especially TERMINATED) with users
4. Use SUSPENDED for temporary issues, DEACTIVATED for voluntary stops, TERMINATED for permanent closure
5. Monitor automatic account history entries for audit compliance
6. Consider impact on active services before state transitions
7. Validate business rules and approval requirements for sensitive transitions

**Comparison with update_subscriber:**
- **Use change_subscriber_state when**: Changing subscriber operational state with automatic tracking
- **Use update_subscriber when**: Changing other subscriber fields (email, address, etc.)
- **Advantage**: Automatic previousState tracking, lastTransitionDate, and audit history creation
    """
    if transaction_id is None:
        transaction_id = str(uuid.uuid4())
    
    # Validate state parameter
    valid_states = ["ACTIVE", "SUSPENDED", "DEACTIVATED", "TERMINATED", "PRE_PROVISIONED"]
    if state not in valid_states:
        logger.error(f"Invalid state: {state}. Must be one of {valid_states}")
        return {
            "error": f"Invalid state '{state}'. Must be one of: {', '.join(valid_states)}"
        }
    
    logger.info(f"change_subscriber_state called for subscriber {subscriber_id} with state: {state}")
    result = await ocs_client.request(
        method="PUT",
        endpoint=f"/subscribers/{subscriber_id}/state",
        params={"state": state},
        transaction_id=transaction_id
    )
    logger.info(f"change_subscriber_state result: {result}")
    return result
