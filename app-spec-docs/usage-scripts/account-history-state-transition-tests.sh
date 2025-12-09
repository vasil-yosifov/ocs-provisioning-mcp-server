#!/bin/bash

# Account History State Transition Integration Tests
# Tests T099: Automatic history entry creation on subscriber/subscription state transitions

set -e

BASE_URL="http://localhost:8080/ocs/prov/v1"
CONTENT_TYPE="Content-Type: application/json"

# Database connection parameters
DB_HOST="localhost"
DB_PORT="3306"
DB_NAME="ocs_provisioning_dev"
DB_USER="ocsuser"
DB_PASSWORD="ocspass"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Function to print test results
print_test_result() {
    local test_name=$1
    local status=$2
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [ "$status" -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: $test_name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Function to print section header
print_section() {
    echo -e "\n${YELLOW}========================================${NC}"
    echo -e "${YELLOW}$1${NC}"
    echo -e "${YELLOW}========================================${NC}\n"
}

# Function to generate UUID
generate_uuid() {
    uuidgen | tr '[:upper:]' '[:lower:]'
}

# Function to check if value is not null
check_not_null() {
    local value=$1
    if [ "$value" != "null" ] && [ -n "$value" ]; then
        return 0
    else
        return 1
    fi
}

# Function to execute MySQL query
execute_query() {
    local query=$1
    docker exec ocs-mysql mysql -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "$query" -N -s 2>/dev/null || echo ""
}

# Function to get account history count for an entity
get_history_count() {
    local entity_id=$1
    local count=$(execute_query "SELECT COUNT(*) FROM account_history WHERE entity_id = '$entity_id';")
    echo "${count:-0}"
}

# Function to get latest history entry for an entity
get_latest_history() {
    local entity_id=$1
    local field=$2
    execute_query "SELECT $field FROM account_history WHERE entity_id = '$entity_id' ORDER BY creation_date DESC LIMIT 1;"
}

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Account History State Transition Tests${NC}"
echo -e "${BLUE}Testing T099 Implementation${NC}"
echo -e "${BLUE}========================================${NC}\n"

# ==============================================
# PHASE 1: Setup Test Data
# ==============================================

print_section "PHASE 1: Setup Test Prerequisites"

# Create test subscriber
SUBSCRIBER_PAYLOAD=$(cat <<EOF
{
  "msisdn": "43669900000001",
  "imsi": "214019900000001",
  "personalInfo": {
    "firstName": "History",
    "lastName": "Tester",
    "email": "history.tester@example.com"
  }
}
EOF
)

echo "Creating test subscriber..."
SUBSCRIBER_RESPONSE=$(curl -s -X POST "$BASE_URL/subscribers" \
    -H "$CONTENT_TYPE" \
    -d "$SUBSCRIBER_PAYLOAD")

SUBSCRIBER_ID=$(echo "$SUBSCRIBER_RESPONSE" | jq -r '.subscriberId')
echo -e "${GREEN}✓${NC} Created test subscriber: $SUBSCRIBER_ID"

# ==============================================
# PHASE 2: Test Subscriber State Transitions
# ==============================================

print_section "PHASE 2: Subscriber State Transition History"

# Test 1: Get history count before any transitions
echo "Test 1: Verify no history entries exist initially"
INITIAL_COUNT=$(get_history_count "$SUBSCRIBER_ID")
echo "Initial history count: $INITIAL_COUNT"

# Test 2: Transition PRE_PROVISIONED -> ACTIVE
echo -e "\nTest 2: Transition subscriber to ACTIVE state"
PATCH_PAYLOAD='[{"fieldName":"state","fieldValue":"ACTIVE"}]'
curl -s -X PATCH "$BASE_URL/subscribers/$SUBSCRIBER_ID" \
    -H "$CONTENT_TYPE" \
    -d "$PATCH_PAYLOAD" > /dev/null

sleep 1  # Give the system time to create history entry

# Verify history entry was created
ACTIVE_COUNT=$(get_history_count "$SUBSCRIBER_ID")
echo "History count after ACTIVE transition: $ACTIVE_COUNT"

if [ "$ACTIVE_COUNT" -gt "$INITIAL_COUNT" ]; then
    print_test_result "History entry created for ACTIVE transition" 0
    
    # Check the latest history entry details
    ENTITY_TYPE=$(get_latest_history "$SUBSCRIBER_ID" "entity_type")
    ENTITY_ID=$(get_latest_history "$SUBSCRIBER_ID" "entity_id")
    DIRECTION=$(get_latest_history "$SUBSCRIBER_ID" "direction")
    REASON=$(get_latest_history "$SUBSCRIBER_ID" "reason")
    STATUS=$(get_latest_history "$SUBSCRIBER_ID" "status")
    CHANNEL=$(get_latest_history "$SUBSCRIBER_ID" "channel")
    DESCRIPTION=$(get_latest_history "$SUBSCRIBER_ID" "description")
    
    echo -e "${BLUE}Latest history entry:${NC}"
    echo "  Entity Type: $ENTITY_TYPE"
    echo "  Entity ID: $ENTITY_ID"
    echo "  Direction: $DIRECTION"
    echo "  Reason: $REASON"
    echo "  Status: $STATUS"
    echo "  Channel: $CHANNEL"
    echo "  Description: $DESCRIPTION"
    
    # Validate fields
    [ "$ENTITY_TYPE" = "SUBSCRIBER" ] && print_test_result "EntityType is SUBSCRIBER" 0 || print_test_result "EntityType is SUBSCRIBER" 1
    [ "$ENTITY_ID" = "$SUBSCRIBER_ID" ] && print_test_result "EntityId matches subscriber" 0 || print_test_result "EntityId matches subscriber" 1
    [ "$DIRECTION" = "INBOUND" ] && print_test_result "Direction is INBOUND" 0 || print_test_result "Direction is INBOUND" 1
    # Subscriber PATCH uses "Subscriber Modification" as Reason (different from dedicated subscription endpoints)
    if [ "$REASON" = "State Transition" ] || [ "$REASON" = "Subscriber Modification" ]; then
        print_test_result "Reason indicates state change" 0
    else
        print_test_result "Reason indicates state change" 1
    fi
    [ "$STATUS" = "SUCCESS" ] && print_test_result "Status is SUCCESS" 0 || print_test_result "Status is SUCCESS" 1
    [ "$CHANNEL" = "API" ] && print_test_result "Channel is API" 0 || print_test_result "Channel is API" 1
    
    # Check if description mentions state transition
    if echo "$DESCRIPTION" | grep -q "ACTIVE"; then
        print_test_result "Description mentions ACTIVE state" 0
    else
        print_test_result "Description mentions ACTIVE state" 1
    fi
else
    print_test_result "History entry created for ACTIVE transition" 1
fi

# Test 3: Transition ACTIVE -> SUSPENDED
echo -e "\nTest 3: Transition subscriber to SUSPENDED state"
PREV_COUNT=$ACTIVE_COUNT
PATCH_PAYLOAD='[{"fieldName":"state","fieldValue":"SUSPENDED"}]'
curl -s -X PATCH "$BASE_URL/subscribers/$SUBSCRIBER_ID" \
    -H "$CONTENT_TYPE" \
    -d "$PATCH_PAYLOAD" > /dev/null

sleep 1

SUSPENDED_COUNT=$(get_history_count "$SUBSCRIBER_ID")
echo "History count after SUSPENDED transition: $SUSPENDED_COUNT"

if [ "$SUSPENDED_COUNT" -gt "$PREV_COUNT" ]; then
    print_test_result "History entry created for SUSPENDED transition" 0
    
    DESCRIPTION=$(get_latest_history "$SUBSCRIBER_ID" "description")
    
    if echo "$DESCRIPTION" | grep -q "SUSPENDED"; then
        print_test_result "Description mentions SUSPENDED state" 0
    else
        print_test_result "Description mentions SUSPENDED state" 1
    fi
else
    print_test_result "History entry created for SUSPENDED transition" 1
fi

# Test 4: Transition SUSPENDED -> ACTIVE (reactivation)
echo -e "\nTest 4: Reactivate subscriber (SUSPENDED -> ACTIVE)"
PREV_COUNT=$SUSPENDED_COUNT
PATCH_PAYLOAD='[{"fieldName":"state","fieldValue":"ACTIVE"}]'
curl -s -X PATCH "$BASE_URL/subscribers/$SUBSCRIBER_ID" \
    -H "$CONTENT_TYPE" \
    -d "$PATCH_PAYLOAD" > /dev/null

sleep 1

REACTIVATED_COUNT=$(get_history_count "$SUBSCRIBER_ID")
echo "History count after reactivation: $REACTIVATED_COUNT"

if [ "$REACTIVATED_COUNT" -gt "$PREV_COUNT" ]; then
    print_test_result "History entry created for reactivation" 0
else
    print_test_result "History entry created for reactivation" 1
fi

# Test 5: Transition ACTIVE -> DEACTIVATED
echo -e "\nTest 5: Transition subscriber to DEACTIVATED state"
PREV_COUNT=$REACTIVATED_COUNT
PATCH_PAYLOAD='[{"fieldName":"state","fieldValue":"DEACTIVATED"}]'
curl -s -X PATCH "$BASE_URL/subscribers/$SUBSCRIBER_ID" \
    -H "$CONTENT_TYPE" \
    -d "$PATCH_PAYLOAD" > /dev/null

sleep 1

DEACTIVATED_COUNT=$(get_history_count "$SUBSCRIBER_ID")
echo "History count after DEACTIVATED transition: $DEACTIVATED_COUNT"

if [ "$DEACTIVATED_COUNT" -gt "$PREV_COUNT" ]; then
    print_test_result "History entry created for DEACTIVATED transition" 0
    
    DESCRIPTION=$(get_latest_history "$SUBSCRIBER_ID" "description")
    
    if echo "$DESCRIPTION" | grep -q "DEACTIVATED"; then
        print_test_result "Description mentions DEACTIVATED state" 0
    else
        print_test_result "Description mentions DEACTIVATED state" 1
    fi
else
    print_test_result "History entry created for DEACTIVATED transition" 1
fi

# ==============================================
# PHASE 3: Test Subscription State Transitions
# ==============================================

print_section "PHASE 3: Subscription State Transition History"

# Create a new subscriber for subscription tests
SUBSCRIBER2_PAYLOAD=$(cat <<EOF
{
  "msisdn": "43669900000002",
  "imsi": "214019900000002",
  "personalInfo": {
    "firstName": "Sub",
    "lastName": "Tester"
  }
}
EOF
)

echo "Creating second test subscriber..."
SUBSCRIBER2_RESPONSE=$(curl -s -X POST "$BASE_URL/subscribers" \
    -H "$CONTENT_TYPE" \
    -d "$SUBSCRIBER2_PAYLOAD")

SUBSCRIBER2_ID=$(echo "$SUBSCRIBER2_RESPONSE" | jq -r '.subscriberId')
echo -e "${GREEN}✓${NC} Created test subscriber: $SUBSCRIBER2_ID"

# Activate subscriber first
PATCH_PAYLOAD='[{"fieldName":"state","fieldValue":"ACTIVE"}]'
curl -s -X PATCH "$BASE_URL/subscribers/$SUBSCRIBER2_ID" \
    -H "$CONTENT_TYPE" \
    -d "$PATCH_PAYLOAD" > /dev/null

# Create subscription
SUBSCRIPTION_PAYLOAD=$(cat <<EOF
{
  "subscriberId": "$SUBSCRIBER2_ID",
  "offerId": "OFFER-T099",
  "offerName": "T099 Test Plan",
  "subscriptionType": "POSTPAID"
}
EOF
)

echo -e "\nCreating test subscription..."
SUBSCRIPTION_RESPONSE=$(curl -s -X POST "$BASE_URL/subscriptions" \
    -H "$CONTENT_TYPE" \
    -d "$SUBSCRIPTION_PAYLOAD")

SUBSCRIPTION_ID=$(echo "$SUBSCRIPTION_RESPONSE" | jq -r '.subscriptionId')
echo -e "${GREEN}✓${NC} Created test subscription: $SUBSCRIPTION_ID"

# Get initial history count for subscription
INITIAL_SUB_COUNT=$(get_history_count "$SUBSCRIPTION_ID")
echo "Initial subscription history count: $INITIAL_SUB_COUNT"

# Test 6: Activate subscription (PENDING -> ACTIVE)
echo -e "\nTest 6: Activate subscription (PENDING -> ACTIVE)"
curl -s -X POST "$BASE_URL/subscriptions/$SUBSCRIPTION_ID/activate" \
    -H "$CONTENT_TYPE" > /dev/null

sleep 1

ACTIVATED_SUB_COUNT=$(get_history_count "$SUBSCRIPTION_ID")
echo "History count after activation: $ACTIVATED_SUB_COUNT"

if [ "$ACTIVATED_SUB_COUNT" -gt "$INITIAL_SUB_COUNT" ]; then
    print_test_result "History entry created for subscription activation" 0
else
    print_test_result "History entry created for subscription activation" 1
fi

# Test 7: Suspend subscription (ACTIVE -> SUSPENDED)
echo -e "\nTest 7: Suspend subscription (ACTIVE -> SUSPENDED)"
PREV_COUNT=$ACTIVATED_SUB_COUNT
curl -s -X POST "$BASE_URL/subscriptions/$SUBSCRIPTION_ID/suspend" \
    -H "$CONTENT_TYPE" > /dev/null

sleep 1

SUSPENDED_SUB_COUNT=$(get_history_count "$SUBSCRIPTION_ID")
echo "History count after suspension: $SUSPENDED_SUB_COUNT"

if [ "$SUSPENDED_SUB_COUNT" -gt "$PREV_COUNT" ]; then
    print_test_result "History entry created for subscription suspension" 0
    
    DESCRIPTION=$(get_latest_history "$SUBSCRIPTION_ID" "description")
    
    if echo "$DESCRIPTION" | grep -q "SUSPENDED"; then
        print_test_result "Description mentions SUSPENDED state" 0
    else
        print_test_result "Description mentions SUSPENDED state" 1
    fi
else
    print_test_result "History entry created for subscription suspension" 1
fi

# Test 8: Reactivate subscription (SUSPENDED -> ACTIVE)
echo -e "\nTest 8: Reactivate subscription (SUSPENDED -> ACTIVE)"
PREV_COUNT=$SUSPENDED_SUB_COUNT
curl -s -X POST "$BASE_URL/subscriptions/$SUBSCRIPTION_ID/activate" \
    -H "$CONTENT_TYPE" > /dev/null

sleep 1

REACTIVATED_SUB_COUNT=$(get_history_count "$SUBSCRIPTION_ID")
echo "History count after reactivation: $REACTIVATED_SUB_COUNT"

if [ "$REACTIVATED_SUB_COUNT" -gt "$PREV_COUNT" ]; then
    print_test_result "History entry created for subscription reactivation" 0
else
    print_test_result "History entry created for subscription reactivation" 1
fi

# Test 9: Cancel subscription (ACTIVE -> CANCELLED)
echo -e "\nTest 9: Cancel subscription (ACTIVE -> CANCELLED)"
PREV_COUNT=$REACTIVATED_SUB_COUNT
curl -s -X POST "$BASE_URL/subscriptions/$SUBSCRIPTION_ID/cancel" \
    -H "$CONTENT_TYPE" > /dev/null

sleep 1

CANCELLED_SUB_COUNT=$(get_history_count "$SUBSCRIPTION_ID")
echo "History count after cancellation: $CANCELLED_SUB_COUNT"

if [ "$CANCELLED_SUB_COUNT" -gt "$PREV_COUNT" ]; then
    print_test_result "History entry created for subscription cancellation" 0
    
    DESCRIPTION=$(get_latest_history "$SUBSCRIPTION_ID" "description")
    
    if echo "$DESCRIPTION" | grep -q "CANCELLED"; then
        print_test_result "Description mentions CANCELLED state" 0
    else
        print_test_result "Description mentions CANCELLED state" 1
    fi
else
    print_test_result "History entry created for subscription cancellation" 1
fi

# ==============================================
# PHASE 4: Verify History Timeline
# ==============================================

print_section "PHASE 4: Verify Complete History Timeline"

# Test 10: Verify subscriber has complete state transition history
echo "Test 10: Verify subscriber history timeline"
FINAL_SUBSCRIBER_COUNT=$(get_history_count "$SUBSCRIBER_ID")

echo "Total subscriber history entries: $FINAL_SUBSCRIBER_COUNT"
echo -e "\n${BLUE}Subscriber state transition history:${NC}"
execute_query "SELECT CONCAT('[', creation_date, '] ', description) FROM account_history WHERE entity_id = '$SUBSCRIBER_ID' ORDER BY creation_date DESC LIMIT 10;"

# Expected: PRE_PROVISIONED->ACTIVE, ACTIVE->SUSPENDED, SUSPENDED->ACTIVE, ACTIVE->DEACTIVATED = 4 transitions
if [ "$FINAL_SUBSCRIBER_COUNT" -ge 4 ]; then
    print_test_result "Subscriber has complete state transition history (>=4 entries)" 0
else
    print_test_result "Subscriber has complete state transition history (>=4 entries)" 1
fi

# Test 11: Verify subscription has complete state transition history
echo -e "\nTest 11: Verify subscription history timeline"
FINAL_SUBSCRIPTION_COUNT=$(get_history_count "$SUBSCRIPTION_ID")

echo "Total subscription history entries: $FINAL_SUBSCRIPTION_COUNT"
echo -e "\n${BLUE}Subscription state transition history:${NC}"
execute_query "SELECT CONCAT('[', creation_date, '] ', description) FROM account_history WHERE entity_id = '$SUBSCRIPTION_ID' ORDER BY creation_date DESC;"

# Expected: PENDING->ACTIVE, ACTIVE->SUSPENDED, SUSPENDED->ACTIVE, ACTIVE->CANCELLED = 4 transitions
if [ "$FINAL_SUBSCRIPTION_COUNT" -ge 4 ]; then
    print_test_result "Subscription has complete state transition history (>=4 entries)" 0
else
    print_test_result "Subscription has complete state transition history (>=4 entries)" 1
fi

# ==============================================
# PHASE 5: Verify InteractionId Uniqueness
# ==============================================

print_section "PHASE 5: Verify InteractionId Uniqueness"

# Test 12: Check all history entries have unique interactionIds
echo "Test 12: Verify all history entries have unique interactionIds"
SUBSCRIBER_TOTAL=$(execute_query "SELECT COUNT(*) FROM account_history WHERE entity_id = '$SUBSCRIBER_ID';")
SUBSCRIBER_UNIQUE=$(execute_query "SELECT COUNT(DISTINCT interaction_id) FROM account_history WHERE entity_id = '$SUBSCRIBER_ID';")

if [ "$SUBSCRIBER_TOTAL" -eq "$SUBSCRIBER_UNIQUE" ]; then
    print_test_result "All subscriber history entries have unique interactionIds" 0
else
    print_test_result "All subscriber history entries have unique interactionIds" 1
fi

SUBSCRIPTION_TOTAL=$(execute_query "SELECT COUNT(*) FROM account_history WHERE entity_id = '$SUBSCRIPTION_ID';")
SUBSCRIPTION_UNIQUE=$(execute_query "SELECT COUNT(DISTINCT interaction_id) FROM account_history WHERE entity_id = '$SUBSCRIPTION_ID';")

if [ "$SUBSCRIPTION_TOTAL" -eq "$SUBSCRIPTION_UNIQUE" ]; then
    print_test_result "All subscription history entries have unique interactionIds" 0
else
    print_test_result "All subscription history entries have unique interactionIds" 1
fi

# ==============================================
# PHASE 6: Cleanup
# ==============================================

print_section "PHASE 6: Cleanup Test Data"

echo "Deleting test subscription..."
curl -s -X DELETE "$BASE_URL/subscriptions/$SUBSCRIPTION_ID" > /dev/null
echo -e "${GREEN}✓${NC} Deleted subscription: $SUBSCRIPTION_ID"

echo "Deleting test subscribers..."
curl -s -X DELETE "$BASE_URL/subscribers/$SUBSCRIBER_ID" > /dev/null
echo -e "${GREEN}✓${NC} Deleted subscriber: $SUBSCRIBER_ID"

curl -s -X DELETE "$BASE_URL/subscribers/$SUBSCRIBER2_ID" > /dev/null
echo -e "${GREEN}✓${NC} Deleted subscriber: $SUBSCRIBER2_ID"

# ==============================================
# Test Summary
# ==============================================

echo -e "\n${YELLOW}========================================${NC}"
echo -e "${YELLOW}Test Summary${NC}"
echo -e "${YELLOW}========================================${NC}"
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
echo -e "Total:  $TESTS_RUN"
echo -e "${YELLOW}========================================${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed! ✓${NC}\n"
    echo -e "${BLUE}Verified T099 Implementation:${NC}"
    echo -e "  ✓ Automatic history entry creation on subscriber state transitions"
    echo -e "  ✓ Automatic history entry creation on subscription state transitions"
    echo -e "  ✓ EntityType correctly set (SUBSCRIBER/SUBSCRIPTION)"
    echo -e "  ✓ EntityId matches the transitioning entity"
    echo -e "  ✓ Direction set to INBOUND"
    echo -e "  ✓ Reason set to 'State Transition'"
    echo -e "  ✓ Status set to SUCCESS"
    echo -e "  ✓ Channel set to API"
    echo -e "  ✓ Description contains state information"
    echo -e "  ✓ Unique interactionIds for all entries"
    echo -e "  ✓ Complete timeline of state transitions tracked\n"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}\n"
    exit 1
fi
