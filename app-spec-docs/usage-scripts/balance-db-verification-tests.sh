#!/bin/bash

# Balance API Integration Tests with Database Verification
# Tests all balance-related endpoints and verifies database persistence

# Configuration
BASE_URL="${BASE_URL:-http://localhost:8080/ocs/prov/v1}"
CONTENT_TYPE="Content-Type: application/json"
DB_USER="ocsuser"
DB_PASS="ocspass"
DB_NAME="ocs_provisioning_dev"
CONTAINER_NAME="ocs-mysql"

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

# Cleanup variables
CREATED_SUBSCRIBER_ID=""
CREATED_SUBSCRIPTION_ID=""
CREATED_BALANCE_IDS=()

# Helper functions
log_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

log_db() {
    echo -e "${BLUE}[DB]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

# Execute MySQL query and return result
execute_db_query() {
    local query="$1"
    docker exec $CONTAINER_NAME mysql -u$DB_USER -p$DB_PASS $DB_NAME -sN -e "$query" 2>/dev/null
}

# Get balance count from database
get_balance_count() {
    execute_db_query "SELECT COUNT(*) FROM balances;"
}

# Get balance count for specific subscription
get_balance_count_for_subscription() {
    local subscription_id="$1"
    execute_db_query "SELECT COUNT(*) FROM balances WHERE subscription_id = '$subscription_id';"
}

# Get balance by ID from database
get_balance_from_db() {
    local balance_id="$1"
    execute_db_query "SELECT balance_id, subscription_id, balance_type, unit_type, balance_amount, balance_available FROM balances WHERE balance_id = '$balance_id';"
}

# Verify balance exists in database
verify_balance_in_db() {
    local balance_id="$1"
    local expected_type="$2"
    local expected_unit="$3"
    
    ((TESTS_RUN++))
    
    local result=$(get_balance_from_db "$balance_id")
    
    if [ -z "$result" ]; then
        log_error "Balance $balance_id not found in database"
        return 1
    fi
    
    log_db "Found balance in database: $result"
    
    if [[ "$result" == *"$balance_id"* ]]; then
        log_success "Balance $balance_id exists in database"
    else
        log_error "Balance $balance_id not properly stored"
        return 1
    fi
    
    # Verify type and unit
    if [[ "$result" == *"$expected_type"* ]]; then
        ((TESTS_RUN++))
        log_success "Balance type is $expected_type in database"
    else
        ((TESTS_RUN++))
        log_error "Balance type mismatch in database"
    fi
    
    if [[ "$result" == *"$expected_unit"* ]]; then
        ((TESTS_RUN++))
        log_success "Unit type is $expected_unit in database"
    else
        ((TESTS_RUN++))
        log_error "Unit type mismatch in database"
    fi
}

cleanup() {
    log_info "Cleaning up test data..."
    
    # Delete balances
    for balance_id in "${CREATED_BALANCE_IDS[@]}"; do
        curl -s -X DELETE "$BASE_URL/subscriptions/$CREATED_SUBSCRIPTION_ID/balances" \
            -H "$CONTENT_TYPE" > /dev/null 2>&1 || true
    done
    
    # Delete subscription
    if [ -n "$CREATED_SUBSCRIPTION_ID" ]; then
        curl -s -X DELETE "$BASE_URL/subscriptions/$CREATED_SUBSCRIPTION_ID" > /dev/null 2>&1 || true
    fi
    
    # Delete subscriber
    if [ -n "$CREATED_SUBSCRIBER_ID" ]; then
        curl -s -X DELETE "$BASE_URL/subscribers/$CREATED_SUBSCRIBER_ID" > /dev/null 2>&1 || true
    fi
    
    log_db "Final balance count: $(get_balance_count)"
}

# Setup test data
setup_test_data() {
    log_info "Setting up test data..."
    
    # Create subscriber with unique MSISDN
    local unique_msisdn="436649$(date +%s%N | tail -c 8)"
    local unique_imsi="21401$(date +%s%N | tail -c 10)"
    local subscriber_payload=$(cat <<EOF
{
  "msisdn": "$unique_msisdn",
  "imsi": "$unique_imsi",
  "personalInfo": {
    "firstName": "John",
    "lastName": "Doe",
    "email": "john.doe@example.com",
    "dateOfBirth": "1990-01-01"
  }
}
EOF
)
    
    local response=$(curl -s -X POST "$BASE_URL/subscribers" \
        -H "$CONTENT_TYPE" \
        -d "$subscriber_payload")
    
    CREATED_SUBSCRIBER_ID=$(echo "$response" | grep -o '"subscriberId":"[^"]*"' | cut -d'"' -f4)
    
    if [ -z "$CREATED_SUBSCRIBER_ID" ]; then
        log_error "Failed to create test subscriber"
        exit 1
    fi
    
    log_info "Created subscriber: $CREATED_SUBSCRIBER_ID"
    
    # Create subscription
    local subscription_payload=$(cat <<EOF
{
  "offerId": "DATA-PLAN-001",
  "offerName": "Data Plan",
  "subscriptionType": "PREPAID"
}
EOF
)
    
    response=$(curl -s -X POST "$BASE_URL/subscribers/$CREATED_SUBSCRIBER_ID/subscriptions" \
        -H "$CONTENT_TYPE" \
        -d "$subscription_payload")
    
    CREATED_SUBSCRIPTION_ID=$(echo "$response" | grep -o '"subscriptionId":"[^"]*"' | cut -d'"' -f4)
    
    if [ -z "$CREATED_SUBSCRIPTION_ID" ]; then
        log_error "Failed to create test subscription"
        exit 1
    fi
    
    log_info "Created subscription: $CREATED_SUBSCRIPTION_ID"
    log_db "Initial balance count: $(get_balance_count)"
}

# Test 1: Create Balance and verify in DB
test_create_balance_with_db_verification() {
    log_info "Test 1: Create Balance with DB Verification"
    
    local count_before=$(get_balance_count)
    log_db "Balance count before: $count_before"
    
    local payload=$(cat <<EOF
{
  "balanceType": "ALLOWANCE",
  "unitType": "BYTES",
  "balanceAmount": 10737418240,
  "balanceAvailable": 10737418240,
  "expirationDate": "2025-12-31T23:59:59Z",
  "isRolloverAllowed": true,
  "maxRolloverAmount": 5368709120,
  "isRecurring": false,
  "isGroupBalance": false
}
EOF
)
    
    local response=$(curl -s -w "\n%{http_code}" -X POST \
        "$BASE_URL/subscriptions/$CREATED_SUBSCRIPTION_ID/balances" \
        -H "$CONTENT_TYPE" \
        -d "$payload")
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')
    
    ((TESTS_RUN++))
    if [ "$http_code" = "201" ]; then
        log_success "Create balance returns 201 Created"
    else
        log_error "Create balance returns $http_code (expected 201)"
    fi
    
    local balance_id=$(echo "$body" | grep -o '"balanceId":"[^"]*"' | cut -d'"' -f4)
    CREATED_BALANCE_IDS+=("$balance_id")
    
    # Wait a moment for DB write
    sleep 1
    
    local count_after=$(get_balance_count)
    log_db "Balance count after: $count_after"
    
    ((TESTS_RUN++))
    if [ "$count_after" -gt "$count_before" ]; then
        log_success "Balance count increased in database ($count_before -> $count_after)"
    else
        log_error "Balance count did not increase"
    fi
    
    # Verify balance in DB
    verify_balance_in_db "$balance_id" "ALLOWANCE" "BYTES"
}

# Test 2: Create Monetary Balance and verify in DB
test_create_monetary_balance_with_db_verification() {
    log_info "Test 2: Create Monetary Balance with DB Verification"
    
    local count_before=$(get_balance_count)
    log_db "Balance count before: $count_before"
    
    local payload=$(cat <<EOF
{
  "balanceType": "ALLOWANCE",
  "unitType": "MICROCENTS",
  "balanceAmount": 500000,
  "balanceAvailable": 500000,
  "expirationDate": "2025-12-31T23:59:59Z",
  "isRolloverAllowed": false,
  "isRecurring": false,
  "isGroupBalance": false
}
EOF
)
    
    local response=$(curl -s -w "\n%{http_code}" -X POST \
        "$BASE_URL/subscriptions/$CREATED_SUBSCRIPTION_ID/balances" \
        -H "$CONTENT_TYPE" \
        -d "$payload")
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')
    
    ((TESTS_RUN++))
    if [ "$http_code" = "201" ]; then
        log_success "Create monetary balance returns 201"
    else
        log_error "Create monetary balance returns $http_code"
    fi
    
    local balance_id=$(echo "$body" | grep -o '"balanceId":"[^"]*"' | cut -d'"' -f4)
    CREATED_BALANCE_IDS+=("$balance_id")
    
    sleep 1
    
    local count_after=$(get_balance_count)
    log_db "Balance count after: $count_after"
    
    ((TESTS_RUN++))
    if [ "$count_after" -gt "$count_before" ]; then
        log_success "Balance count increased in database ($count_before -> $count_after)"
    else
        log_error "Balance count did not increase"
    fi
    
    verify_balance_in_db "$balance_id" "ALLOWANCE" "MICROCENTS"
}

# Test 3: Create Voice Balance and verify in DB
test_create_voice_balance_with_db_verification() {
    log_info "Test 3: Create Voice Balance with DB Verification"
    
    local count_before=$(get_balance_count)
    log_db "Balance count before: $count_before"
    
    local payload=$(cat <<EOF
{
  "balanceType": "ALLOWANCE",
  "unitType": "SECONDS",
  "balanceAmount": 30000,
  "balanceAvailable": 30000,
  "expirationDate": "2025-12-31T23:59:59Z",
  "isRolloverAllowed": true,
  "maxRolloverAmount": 6000,
  "isRecurring": false,
  "isGroupBalance": false
}
EOF
)
    
    local response=$(curl -s -w "\n%{http_code}" -X POST \
        "$BASE_URL/subscriptions/$CREATED_SUBSCRIPTION_ID/balances" \
        -H "$CONTENT_TYPE" \
        -d "$payload")
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')
    
    ((TESTS_RUN++))
    if [ "$http_code" = "201" ]; then
        log_success "Create voice balance returns 201"
    else
        log_error "Create voice balance returns $http_code"
    fi
    
    local balance_id=$(echo "$body" | grep -o '"balanceId":"[^"]*"' | cut -d'"' -f4)
    CREATED_BALANCE_IDS+=("$balance_id")
    
    sleep 1
    
    local count_after=$(get_balance_count)
    log_db "Balance count after: $count_after"
    
    ((TESTS_RUN++))
    if [ "$count_after" -gt "$count_before" ]; then
        log_success "Balance count increased in database ($count_before -> $count_after)"
    else
        log_error "Balance count did not increase"
    fi
    
    verify_balance_in_db "$balance_id" "ALLOWANCE" "SECONDS"
}

# Test 4: Verify all balances can be retrieved from DB
test_verify_all_balances_in_db() {
    log_info "Test 4: Verify All Balances in Database"
    
    local subscription_balance_count=$(get_balance_count_for_subscription "$CREATED_SUBSCRIPTION_ID")
    local expected_count=${#CREATED_BALANCE_IDS[@]}
    
    log_db "Balances for this subscription in database: $subscription_balance_count"
    log_db "Expected balance count: $expected_count"
    
    ((TESTS_RUN++))
    if [ "$subscription_balance_count" -eq "$expected_count" ]; then
        log_success "All $expected_count balances are in database for this subscription"
    else
        log_error "Balance count mismatch (expected: $expected_count, got: $subscription_balance_count)"
    fi
    
    # Show balances for this subscription
    log_db "Balances for subscription $CREATED_SUBSCRIPTION_ID:"
    execute_db_query "SELECT balance_id, balance_type, unit_type, balance_amount FROM balances WHERE subscription_id = '$CREATED_SUBSCRIPTION_ID';" | while read -r line; do
        log_db "  $line"
    done
}

# Test 5: Delete balances and verify deletion in DB
test_delete_balances_with_db_verification() {
    log_info "Test 5: Delete Balances with DB Verification"
    
    local count_before=$(get_balance_count_for_subscription "$CREATED_SUBSCRIPTION_ID")
    log_db "Balance count for subscription before deletion: $count_before"
    
    local response=$(curl -s -w "\n%{http_code}" -X DELETE \
        "$BASE_URL/subscriptions/$CREATED_SUBSCRIPTION_ID/balances" \
        -H "$CONTENT_TYPE")
    
    local http_code=$(echo "$response" | tail -n1)
    
    ((TESTS_RUN++))
    if [ "$http_code" = "204" ]; then
        log_success "Delete balances returns 204 No Content"
    else
        log_error "Delete balances returns $http_code"
    fi
    
    sleep 1
    
    local count_after=$(get_balance_count_for_subscription "$CREATED_SUBSCRIPTION_ID")
    log_db "Balance count for subscription after deletion: $count_after"
    
    ((TESTS_RUN++))
    if [ "$count_after" -eq 0 ]; then
        log_success "All balances deleted from database for this subscription"
    else
        log_error "Balances not deleted from database (remaining: $count_after)"
    fi
}

# Main test execution
main() {
    echo "======================================"
    echo "Balance API Database Verification Tests"
    echo "======================================"
    echo ""
    
    setup_test_data
    
    test_create_balance_with_db_verification
    echo ""
    
    test_create_monetary_balance_with_db_verification
    echo ""
    
    test_create_voice_balance_with_db_verification
    echo ""
    
    test_verify_all_balances_in_db
    echo ""
    
    test_delete_balances_with_db_verification
    echo ""
    
    cleanup
    
    echo ""
    echo "======================================"
    echo "Test Summary"
    echo "======================================"
    echo "Total Tests: $TESTS_RUN"
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $TESTS_FAILED"
    echo ""
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}Some tests failed!${NC}"
        exit 1
    fi
}

# Run tests
main
