from typing import List, Dict, Any, Optional
import logging
import json

logger = logging.getLogger(__name__)

# Centralized offer catalog - shared between all offer-related functions
def _get_offers_catalog() -> List[Dict[str, Any]]:
    """
    Returns the complete offer catalog from the OCS provisioning system.
    This is a centralized source of truth for all offer data.
    """
    return [
        {
            "offerId": "1000",
            "offerName": "Basic prepaid plan",
            "description": "Basic prepaid priceplan, which covers all type of services",
            "price": 7.99,
            "type": "PREPAID",
            "recurring": True,
            "paid": True,
            "groupOffer": False,
            "maxRecurringCycles": None,
            "cycleLength": 0,
            "cycleUnit": "MONTH",
            "balances": [
                {
                    "type": "ALLOWANCE",
                    "amount": 3600,
                    "unit": "SECONDS",
                    "recurring": True,
                    "cycleLength": 1,
                    "cycleUnit": "MONTH",
                    "rolloverAllowed": False,
                    "maxRolloverAmount": 0,
                    "description": "Prepaid base balance for voice service"
                },
                {
                    "type": "ALLOWANCE",
                    "amount": 1000,
                    "unit": "EVENTS",
                    "recurring": True,
                    "cycleLength": 1,
                    "cycleUnit": "MONTH",
                    "rolloverAllowed": False,
                    "maxRolloverAmount": 0,
                    "description": "Prepaid base balance for SMS and MMS service"
                },
                {
                    "type": "ALLOWANCE",
                    "amount": 10737418240,
                    "unit": "BYTES",
                    "recurring": True,
                    "cycleLength": 1,
                    "cycleUnit": "MONTH",
                    "rolloverAllowed": False,
                    "maxRolloverAmount": 0,
                    "description": "Prepaid base balance for data service"
                }
            ]
        },
        {
            "offerId": "1001",
            "offerName": "Basic postpaid plan",
            "description": "Basic postpaid priceplan, which covers all type of services",
            "price": 15.99,
            "type": "POSTPAID",
            "recurring": True,
            "paid": True,
            "groupOffer": False,
            "maxRecurringCycles": None,
            "cycleLength": 0,
            "cycleUnit": "MONTH",
            "balances": [
                {
                    "type": "ALLOWANCE",
                    "amount": 86600,
                    "unit": "SECONDS",
                    "recurring": True,
                    "cycleLength": 1,
                    "cycleUnit": "MONTH",
                    "rolloverAllowed": False,
                    "maxRolloverAmount": 0,
                    "description": "Postpaid base balance for voice service"
                },
                {
                    "type": "ALLOWANCE",
                    "amount": 5000,
                    "unit": "EVENTS",
                    "recurring": True,
                    "cycleLength": 1,
                    "cycleUnit": "MONTH",
                    "rolloverAllowed": False,
                    "maxRolloverAmount": 0,
                    "description": "Postpaid base balance for SMS and MMS service"
                },
                {
                    "type": "ALLOWANCE",
                    "amount": 10737418240,
                    "unit": "BYTES",
                    "recurring": True,
                    "cycleLength": 1,
                    "cycleUnit": "MONTH",
                    "rolloverAllowed": False,
                    "maxRolloverAmount": 0,
                    "description": "Postpaid base balance for data service"
                }
            ]
        },
        {
            "offerId": "1002",
            "offerName": "Weekly data bundle 5GB",
            "description": "Prepaid weekly data bundle – 5GB",
            "price": 4.99,
            "type": "PREPAID",
            "recurring": True,
            "paid": True,
            "groupOffer": False,
            "maxRecurringCycles": None,
            "cycleLength": 4,
            "cycleUnit": "WEEK",
            "balances": [
                {
                    "type": "ALLOWANCE",
                    "amount": 5368709120,
                    "unit": "BYTES",
                    "recurring": True,
                    "cycleLength": 1,
                    "cycleUnit": "WEEK",
                    "rolloverAllowed": True,
                    "maxRolloverAmount": 5368709120,
                    "description": "Prepaid 5GB weekly balance"
                }
            ]
        },
        {
            "offerId": "1003",
            "offerName": "Monthly data bundle 25GB",
            "description": "Prepaid monthly data bundle – 25GB",
            "price": 12.99,
            "type": "PREPAID",
            "recurring": False,
            "paid": True,
            "groupOffer": False,
            "maxRecurringCycles": None,
            "cycleLength": 1,
            "cycleUnit": "MONTH",
            "balances": [
                {
                    "type": "ALLOWANCE",
                    "amount": 26843545600,
                    "unit": "BYTES",
                    "recurring": False,
                    "cycleLength": 1,
                    "cycleUnit": "MONTH",
                    "rolloverAllowed": True,
                    "maxRolloverAmount": 0,
                    "description": "Prepaid 25GB one time monthly balance"
                }
            ]
        },
        {
            "offerId": "1010",
            "offerName": "Premium prepaid plan",
            "description": "Premium prepaid price plan, which contains more free units for all type of services",
            "price": 9.99,
            "type": "PREPAID",
            "recurring": True,
            "paid": True,
            "groupOffer": False,
            "maxRecurringCycles": None,
            "cycleLength": 0,
            "cycleUnit": "MONTH",
            "balances": [
                {
                    "type": "ALLOWANCE",
                    "amount": 18000,
                    "unit": "SECONDS",
                    "recurring": True,
                    "cycleLength": 1,
                    "cycleUnit": "MONTH",
                    "rolloverAllowed": True,
                    "maxRolloverAmount": 7200,
                    "description": "5 hours prepaid balance for voice service with 2 hours rollover"
                },
                {
                    "type": "ALLOWANCE",
                    "amount": 5000,
                    "unit": "EVENTS",
                    "recurring": True,
                    "cycleLength": 1,
                    "cycleUnit": "MONTH",
                    "rolloverAllowed": True,
                    "maxRolloverAmount": 2000,
                    "description": "5000 events prepaid balance for SMS and MMS services with 2000 events rollover"
                },
                {
                    "type": "ALLOWANCE",
                    "amount": 21474836480,
                    "unit": "BYTES",
                    "recurring": True,
                    "cycleLength": 1,
                    "cycleUnit": "MONTH",
                    "rolloverAllowed": True,
                    "maxRolloverAmount": 10737418240,
                    "description": "20GB prepaid balance for data service with 10GB rollover"
                }
            ]
        },
        {
            "offerId": "1011",
            "offerName": "Premium postpaid plan",
            "description": "Premium postpaid price plan with enhanced allowances for all services",
            "price": 24.99,
            "type": "POSTPAID",
            "recurring": True,
            "paid": True,
            "groupOffer": False,
            "maxRecurringCycles": None,
            "cycleLength": 0,
            "cycleUnit": "MONTH",
            "balances": [
                {
                    "type": "ALLOWANCE",
                    "amount": 180000,
                    "unit": "SECONDS",
                    "recurring": True,
                    "cycleLength": 1,
                    "cycleUnit": "MONTH",
                    "rolloverAllowed": True,
                    "maxRolloverAmount": 36000,
                    "description": "50 hours postpaid balance for voice service with 10 hours rollover"
                },
                {
                    "type": "ALLOWANCE",
                    "amount": 10000,
                    "unit": "EVENTS",
                    "recurring": True,
                    "cycleLength": 1,
                    "cycleUnit": "MONTH",
                    "rolloverAllowed": True,
                    "maxRolloverAmount": 3000,
                    "description": "10000 events postpaid balance for SMS and MMS services with 3000 events rollover"
                },
                {
                    "type": "ALLOWANCE",
                    "amount": 53687091200,
                    "unit": "BYTES",
                    "recurring": True,
                    "cycleLength": 1,
                    "cycleUnit": "MONTH",
                    "rolloverAllowed": True,
                    "maxRolloverAmount": 21474836480,
                    "description": "50GB postpaid balance for data service with 20GB rollover"
                }
            ]
        },
        {
            "offerId": "1020",
            "offerName": "Weekly data bundle 10GB - Postpaid",
            "description": "Postpaid weekly data bundle – 10GB with rollover",
            "price": 6.99,
            "type": "POSTPAID",
            "recurring": True,
            "paid": True,
            "groupOffer": False,
            "maxRecurringCycles": None,
            "cycleLength": 4,
            "cycleUnit": "WEEK",
            "balances": [
                {
                    "type": "ALLOWANCE",
                    "amount": 10737418240,
                    "unit": "BYTES",
                    "recurring": True,
                    "cycleLength": 1,
                    "cycleUnit": "WEEK",
                    "rolloverAllowed": True,
                    "maxRolloverAmount": 10737418240,
                    "description": "Postpaid 10GB weekly balance with full rollover"
                }
            ]
        },
        {
            "offerId": "1021",
            "offerName": "Monthly data bundle 50GB - Postpaid",
            "description": "Postpaid monthly data bundle – 50GB with rollover",
            "price": 19.99,
            "type": "POSTPAID",
            "recurring": True,
            "paid": True,
            "groupOffer": False,
            "maxRecurringCycles": None,
            "cycleLength": 1,
            "cycleUnit": "MONTH",
            "balances": [
                {
                    "type": "ALLOWANCE",
                    "amount": 53687091200,
                    "unit": "BYTES",
                    "recurring": True,
                    "cycleLength": 1,
                    "cycleUnit": "MONTH",
                    "rolloverAllowed": True,
                    "maxRolloverAmount": 26843545600,
                    "description": "Postpaid 50GB monthly balance with 25GB rollover"
                }
            ]
        },
        {
            "offerId": "1030",
            "offerName": "Voice bundle 500 minutes - Postpaid",
            "description": "Additional 500 minutes voice bundle for postpaid subscribers",
            "price": 5.99,
            "type": "POSTPAID",
            "recurring": True,
            "paid": True,
            "groupOffer": False,
            "maxRecurringCycles": None,
            "cycleLength": 1,
            "cycleUnit": "MONTH",
            "balances": [
                {
                    "type": "ALLOWANCE",
                    "amount": 30000,
                    "unit": "SECONDS",
                    "recurring": True,
                    "cycleLength": 1,
                    "cycleUnit": "MONTH",
                    "rolloverAllowed": True,
                    "maxRolloverAmount": 15000,
                    "description": "500 minutes (30000 seconds) voice balance with 250 minutes rollover"
                }
            ]
        },
        {
            "offerId": "1031",
            "offerName": "Voice bundle 1000 minutes - Postpaid",
            "description": "Additional 1000 minutes voice bundle for postpaid subscribers",
            "price": 9.99,
            "type": "POSTPAID",
            "recurring": True,
            "paid": True,
            "groupOffer": False,
            "maxRecurringCycles": None,
            "cycleLength": 1,
            "cycleUnit": "MONTH",
            "balances": [
                {
                    "type": "ALLOWANCE",
                    "amount": 60000,
                    "unit": "SECONDS",
                    "recurring": True,
                    "cycleLength": 1,
                    "cycleUnit": "MONTH",
                    "rolloverAllowed": True,
                    "maxRolloverAmount": 30000,
                    "description": "1000 minutes (60000 seconds) voice balance with 500 minutes rollover"
                }
            ]
        },
        {
            "offerId": "1040",
            "offerName": "SMS/MMS bundle 1000 messages - Postpaid",
            "description": "Additional 1000 SMS/MMS messages bundle for postpaid subscribers",
            "price": 3.99,
            "type": "POSTPAID",
            "recurring": True,
            "paid": True,
            "groupOffer": False,
            "maxRecurringCycles": None,
            "cycleLength": 1,
            "cycleUnit": "MONTH",
            "balances": [
                {
                    "type": "ALLOWANCE",
                    "amount": 1000,
                    "unit": "EVENTS",
                    "recurring": True,
                    "cycleLength": 1,
                    "cycleUnit": "MONTH",
                    "rolloverAllowed": True,
                    "maxRolloverAmount": 500,
                    "description": "1000 SMS/MMS events balance with 500 messages rollover"
                }
            ]
        },
        {
            "offerId": "1041",
            "offerName": "SMS/MMS bundle 2500 messages - Postpaid",
            "description": "Additional 2500 SMS/MMS messages bundle for postpaid subscribers",
            "price": 7.99,
            "type": "POSTPAID",
            "recurring": True,
            "paid": True,
            "groupOffer": False,
            "maxRecurringCycles": None,
            "cycleLength": 1,
            "cycleUnit": "MONTH",
            "balances": [
                {
                    "type": "ALLOWANCE",
                    "amount": 2500,
                    "unit": "EVENTS",
                    "recurring": True,
                    "cycleLength": 1,
                    "cycleUnit": "MONTH",
                    "rolloverAllowed": True,
                    "maxRolloverAmount": 1000,
                    "description": "2500 SMS/MMS events balance with 1000 messages rollover"
                }
            ]
        }
    ]

async def get_available_offers() -> str:
    """
**Tool Name:** Get Available Offers

**Purpose:** Retrieves the list of all available service offers and packages that can be assigned to subscribers in the OCS system. This tool provides information about data plans, voice bundles, SMS packages, and value-added services available for subscription.

**Parameters:**
- None required

**Returns:**
A JSON-formatted list of available offers, where each offer includes:
- `offerId`: Unique identifier for the offer
- `offerName`: Human-readable name of the offer
- `description`: Detailed description of what the offer includes
- `price`: Monthly or one-time price for the offer
- `type`: Offer type ("PREPAID" or "POSTPAID")
- `recurring`: Whether the offer renews automatically (true/false)
- `paid`: Whether the offer is paid (true/false)
- `groupOffer`: Whether this is a group/shared offer (true/false)
- `maxRecurringCycles`: Maximum number of recurring cycles (null for unlimited)
- `cycleLength`: Length of the billing cycle (integer)
- `cycleUnit`: Unit for the billing cycle ("MONTH", "WEEK", etc.)
- `balances`: Array of balance allocations included in the offer, each containing:
  - `type`: Balance type (e.g., "ALLOWANCE")
  - `amount`: Balance amount in specified units
  - `unit`: Unit of measurement ("SECONDS" for voice, "EVENTS" for SMS, "BYTES" for data)
  - `recurring`: Whether the balance recurs (true/false)
  - `cycleLength`: Balance cycle length
  - `cycleUnit`: Balance cycle unit
  - `rolloverAllowed`: Whether unused balance rolls over (true/false)
  - `maxRolloverAmount`: Maximum amount that can roll over (0 = no limit)
  - `description`: Human-readable description of the balance

**Use Cases:**
- Displaying available packages to customers during onboarding
- Helping customers choose appropriate service plans
- Comparing different offers for upselling/cross-selling
- Providing information for customer service inquiries
- Planning subscription configurations

**Workflow:**
1. Call get_subscriber to verify subscriber type (PREPAID or POSTPAID)
2. Call get_available_offers to retrieve current catalog
3. Filter offers by matching subscriber type (type field must match subscriber type)
4. Present compatible offers to user or filter further based on requirements
5. Use offerId when creating subscriptions for subscribers

**Important Notes:**
- This is a static catalog - offers don't change dynamically during session
- Prices and features are current as of the query time
- **Subscriber type must match offer type**: PREPAID subscribers can only use PREPAID offers, and POSTPAID subscribers can only use POSTPAID offers
- Always verify subscriber type before recommending or assigning offers
- Bundle offers may include multiple services at discounted rates
- Available offers include base plans (1000-1011), data bundles (1002-1003, 1020-1021), voice bundles (1030-1031), and SMS/MMS bundles (1040-1041)

**Example Usage:**
```
User: "What data plans do you have for my prepaid account?"
Assistant: Calls get_subscriber to check subscriber type (PREPAID) → Calls get_available_offers → Filters by type="PREPAID" and balances containing "BYTES" → Presents matching data plans (1000, 1002, 1003, 1010)

User: "Show me all offers"
Assistant: Calls get_available_offers → Displays complete catalog (both PREPAID and POSTPAID)

User: "What's included in the Premium prepaid plan?"
Assistant: Calls get_available_offers → Finds offerId="1010" → Shows voice (18000 seconds = 5 hours), SMS (5000 events), and data (21474836480 bytes = 20GB) balances with rollover capabilities

User: "I want to add a data bundle to subscriber 123456"
Assistant: Calls get_subscriber("123456") → Checks subscriber type (e.g., PREPAID) → Calls get_available_offers → Filters by type="PREPAID" and data balances → Presents only compatible offers

```

**Response Format:**
Returns a formatted JSON string containing the complete offer catalog with all details for easy reading and comparison.
    """
    logger.info("get_available_offers called")
    
    # Get offers from centralized catalog
    offers = _get_offers_catalog()
    
    logger.info(f"Returning {len(offers)} available offers")
    return json.dumps(offers, indent=2)

async def get_offer_by_id(offerId: str) -> str:
    """
**Tool Name:** Get Offer By ID

**Purpose:** Retrieves detailed information about a specific offer by its unique identifier. This tool is useful when you need complete details about a specific offer, such as when mapping offer data to a subscription during subscription creation.

**Parameters:**
- `offerId` (required): The unique identifier of the offer to retrieve (e.g., "1000", "1001", "1002", "1003", "1010")

**Returns:**
A JSON-formatted string containing the complete offer details including:
- `offerId`: Unique identifier for the offer
- `offerName`: Human-readable name of the offer
- `description`: Detailed description of what the offer includes
- `price`: Monthly or one-time price for the offer
- `type`: Offer type ("PREPAID" or "POSTPAID")
- `recurring`: Whether the offer renews automatically (true/false)
- `paid`: Whether the offer is paid (true/false)
- `groupOffer`: Whether this is a group/shared offer (true/false)
- `maxRecurringCycles`: Maximum number of recurring cycles (null for unlimited)
- `cycleLength`: Length of the billing cycle (integer)
- `cycleUnit`: Unit for the billing cycle ("MONTH", "WEEK", etc.)
- `balances`: Array of balance allocations with amounts, units, and rollover settings

If the offer is not found, returns an error message in JSON format.

**Use Cases:**
- Retrieving complete offer details before creating a subscription
- Verifying offer configuration during subscription mapping
- Getting specific offer information for customer service inquiries
- Validating that an offerId exists before proceeding with subscription creation
- Looking up detailed balance information for a specific offer

**Workflow:**
1. Call get_offer_by_id with the specific offerId
2. Verify the offer exists (check for error response)
3. Use the returned offer data to populate subscription fields
4. Proceed with subscription creation using the offer details

**Important Notes:**
- **Type Matching**: Ensure the returned offer type matches the subscriber type before creating subscriptions
- **Available Offers**: Valid offerIds are: "1000", "1001", "1002", "1003", "1010", "1011", "1020", "1021", "1030", "1031", "1040", "1041"
- **PREPAID Offers**: 1000 (basic), 1002 (data 5GB), 1003 (data 25GB), 1010 (premium)
- **POSTPAID Offers**: 1001 (basic), 1011 (premium), 1020 (data 10GB), 1021 (data 50GB), 1030 (voice 500min), 1031 (voice 1000min), 1040 (SMS 1000), 1041 (SMS 2500)
- **Not Found**: Returns error JSON if offerId doesn't exist in catalog

**Example Usage:**
```
User: "Show me details about offer 1010"
Assistant: Calls get_offer_by_id("1010") → Returns complete offer details with all balances

User: "I want to subscribe to offer 1010"
Assistant: Calls get_offer_by_id("1010") → Verifies offer details → Maps to subscription object → Creates subscription

User: "What's included in offer 1002?"
Assistant: Calls get_offer_by_id("1002") → Shows weekly data bundle with 5GB, rollover, €4.99/month
```

**Response Format:**
Returns a formatted JSON string containing the complete offer object, or an error object if the offer is not found.

**Integration with create_subscription:**
This tool is particularly useful when creating subscriptions, as it provides all the offer details needed for the offer-to-subscription field mapping:
- offerId → subscription.offerId
- offerName → subscription.offerName
- type → subscription.subscriptionType
- recurring → subscription.recurring
- paid → subscription.paidFlag
- groupOffer → subscription.isGroup
- maxRecurringCycles → subscription.maxRecurringCycles
- cycleLength → subscription.cycleLengthUnits
- cycleUnit → subscription.cycleLengthType
    """
    logger.info(f"get_offer_by_id called with offerId: {offerId}")
    
    # Get offers from centralized catalog
    offers = _get_offers_catalog()
    
    # Find the offer with matching offerId
    offer = next((o for o in offers if o["offerId"] == offerId), None)
    
    if offer:
        logger.info(f"Found offer: {offer['offerName']}")
        return json.dumps(offer, indent=2)
    else:
        logger.warning(f"Offer not found for offerId: {offerId}")
        error_response = {
            "error": "Offer not found",
            "message": f"No offer found with offerId: {offerId}",
            "availableOfferIds": ["1000", "1001", "1002", "1003", "1010", "1011", "1020", "1021", "1030", "1031", "1040", "1041"]
        }
        return json.dumps(error_response, indent=2)
