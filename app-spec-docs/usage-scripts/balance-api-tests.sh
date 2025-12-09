#!/bin/bash

# Balance API Integration Tests
# Tests all balance-related endpoints and use cases
# Usage: ./balance-api-tests.sh [--skip-cleanup]

# Don't exit on errors - we want to run all tests
# set -e

# Parse command line arguments
SKIP_CLEANUP=false
for arg in "$@"; do
    case $arg in
        --skip-cleanup)
            SKIP_CLEANUP=true
            shift
            ;;
    esac
done

# Configuration
BASE_URL="${BASE_URL:-http://localhost:8080/ocs/prov/v1}"
CONTENT_TYPE="Content-Type: application/json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"
    
    ((TESTS_RUN++))
    if [ "$expected" = "$actual" ]; then
        log_success "$test_name"
    else
        log_error "$test_name - Expected: $expected, Got: $actual"
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local test_name="$3"
    
    ((TESTS_RUN++))
    if [[ "$haystack" == *"$needle"* ]]; then
        log_success "$test_name"
    else
        log_error "$test_name - Expected to contain: $needle"
    fi
}

assert_not_empty() {
    local value="$1"
    local test_name="$2"
    
    ((TESTS_RUN++))
    if [ -n "$value" ]; then
        log_success "$test_name"
    else
        log_error "$test_name - Value is empty"
    fi
}

cleanup() {
    if [ "$SKIP_CLEANUP" = true ]; then
        log_info "Skipping cleanup (--skip-cleanup flag set)"
        log_info "Created subscriber: $CREATED_SUBSCRIBER_ID"
        log_info "Created subscription: $CREATED_SUBSCRIPTION_ID"
        log_info "Created balances: ${CREATED_BALANCE_IDS[@]}"
        return
    fi
    
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
}

# Setup test data
setup_test_data() {
    log_info "Setting up test data..."
    
    # Generate unique MSISDN using timestamp
    local unique_msisdn="9$(date +%s)99"  # Will be 11-13 digits
    
    # Create subscriber
    local subscriber_payload=$(cat <<EOF
{
  "msisdn": "$unique_msisdn",
  "personalInfo": {
    "firstName": "Balance",
    "lastName": "Tester",
    "email": "balance.tester@example.com"
  },
  "services": {
    "voiceEnabled": true,
    "dataEnabled": true,
    "smsEnabled": true
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
  "offerName": "10GB Monthly Plan",
  "subscriptionType": "DATA",
  "recurring": true,
  "maxRecurringCycles": 12,
  "cycleLengthUnits": 1,
  "cycleLengthType": "MONTHS"
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
}

# Test 1: Create Balance
test_create_balance() {
    log_info "Test 1: Create Balance"
    
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
    
    assert_equals "201" "$http_code" "Create balance returns 201 Created"
    
    local balance_id=$(echo "$body" | grep -o '"balanceId":"[^"]*"' | cut -d'"' -f4)
    assert_not_empty "$balance_id" "Balance ID is present in response"
    
    CREATED_BALANCE_IDS+=("$balance_id")
    
    assert_contains "$body" '"balanceType":"ALLOWANCE"' "Balance type is ALLOWANCE"
    assert_contains "$body" '"unitType":"BYTES"' "Unit type is BYTES"
    assert_contains "$body" '"balanceAmount":10737418240' "Balance amount is correct"
    
    # Verify balance is in database
    sleep 0.5
    local db_result=$(docker exec ocs-mysql mysql -uocsuser -pocspass ocs_provisioning_dev -sN -e "SELECT balance_id FROM balances WHERE balance_id='$balance_id';" 2>/dev/null)
    if [ -n "$db_result" ]; then
        log_info "✓ Balance persisted to database with ID: $balance_id"
    else
        log_error "✗ Balance NOT found in database!"
    fi
}

# Test 2: Get Balance List for Subscription
test_get_balance_list() {
    log_info "Test 2: Get Balance List for Subscription"
    
    local response=$(curl -s -w "\n%{http_code}" -X GET \
        "$BASE_URL/subscriptions/$CREATED_SUBSCRIPTION_ID/balances" \
        -H "$CONTENT_TYPE")
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')
    
    assert_equals "200" "$http_code" "Get balance list returns 200 OK"
    assert_contains "$body" '"balanceId"' "Response contains balance data"
}

# Test 3: Create Balance with Monetary Credit
test_create_monetary_balance() {
    log_info "Test 3: Create Monetary Balance"
    
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
    
    assert_equals "201" "$http_code" "Create monetary balance returns 201"
    assert_contains "$body" '"balanceType":"ALLOWANCE"' "Balance type is ALLOWANCE"
    assert_contains "$body" '"unitType":"MICROCENTS"' "Unit type is MICROCENTS"
    
    local balance_id=$(echo "$body" | grep -o '"balanceId":"[^"]*"' | cut -d'"' -f4)
    CREATED_BALANCE_IDS+=("$balance_id")
}

# Test 4: Create Balance with Voice Minutes
test_create_voice_balance() {
    log_info "Test 4: Create Voice Balance"
    
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
    
    assert_equals "201" "$http_code" "Create voice balance returns 201"
    assert_contains "$body" '"unitType":"SECONDS"' "Unit type is SECONDS"
    
    local balance_id=$(echo "$body" | grep -o '"balanceId":"[^"]*"' | cut -d'"' -f4)
    CREATED_BALANCE_IDS+=("$balance_id")
}

# Test 5: Create Group Balance
test_create_group_balance() {
    log_info "Test 5: Create Group Balance"
    
    local payload=$(cat <<EOF
{
  "balanceType": "ALLOWANCE",
  "unitType": "BYTES",
  "balanceAmount": 21474836480,
  "balanceAvailable": 21474836480,
  "expirationDate": "2025-12-31T23:59:59Z",
  "isRolloverAllowed": false,
  "isRecurring": false,
  "isGroupBalance": true
}
EOF
)
    
    local response=$(curl -s -w "\n%{http_code}" -X POST \
        "$BASE_URL/subscriptions/$CREATED_SUBSCRIPTION_ID/balances" \
        -H "$CONTENT_TYPE" \
        -d "$payload")
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')
    
    assert_equals "201" "$http_code" "Create group balance returns 201"
    assert_contains "$body" '"isGroupBalance":true' "Balance is marked as group balance"
    
    local balance_id=$(echo "$body" | grep -o '"balanceId":"[^"]*"' | cut -d'"' -f4)
    CREATED_BALANCE_IDS+=("$balance_id")
}

# Test 6: Create Recurring Balance
test_create_recurring_balance() {
    log_info "Test 6: Create Recurring Balance"
    
    local payload=$(cat <<EOF
{
  "balanceType": "ALLOWANCE",
  "unitType": "BYTES",
  "balanceAmount": 10737418240,
  "balanceAvailable": 10737418240,
  "expirationDate": "2025-12-31T23:59:59Z",
  "isRolloverAllowed": true,
  "maxRolloverAmount": 5368709120,
  "isRecurring": true,
  "maxRecurringCycles": 12,
  "recurringCyclesCompleted": 0,
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
    
    assert_equals "201" "$http_code" "Create recurring balance returns 201"
    assert_contains "$body" '"isRecurring":true' "Balance is marked as recurring"
    assert_contains "$body" '"maxRecurringCycles":12' "Max recurring cycles is set"
    
    local balance_id=$(echo "$body" | grep -o '"balanceId":"[^"]*"' | cut -d'"' -f4)
    CREATED_BALANCE_IDS+=("$balance_id")
}

# Test 7: Create Recurring Balance Without Cycle Parameters (Tests Default Values)
test_recurring_balance_defaults() {
    log_info "Test 7: Create Recurring Balance Without Cycle Parameters"
    
    # Create recurring balance without cycleLengthType and cycleLengthUnits
    # Expected behavior: defaults should be set to MONTHS and 1
    local payload=$(cat <<EOF
{
  "balanceType": "ALLOWANCE",
  "unitType": "BYTES",
  "balanceAmount": 5368709120,
  "balanceAvailable": 5368709120,
  "expirationDate": "2026-01-31T23:59:59Z",
  "isRolloverAllowed": false,
  "isRecurring": true,
  "maxRecurringCycles": 6,
  "recurringCyclesCompleted": 0,
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
    
    assert_equals "201" "$http_code" "Create recurring balance without cycle params returns 201"
    assert_contains "$body" '"isRecurring":true' "Balance is marked as recurring"
    
    # Verify defaults were set
    assert_contains "$body" '"cycleLengthType":"MONTHS"' "Default cycleLengthType is MONTHS"
    assert_contains "$body" '"cycleLengthUnits":1' "Default cycleLengthUnits is 1"
    
    local balance_id=$(echo "$body" | grep -o '"balanceId":"[^"]*"' | cut -d'"' -f4)
    CREATED_BALANCE_IDS+=("$balance_id")
    
    # Verify in database
    log_info "Verifying cycle defaults in database..."
    local db_check=$(docker exec ocs-mysql mysql -uocsuser -pocspass ocs_provisioning_dev -se \
        "SELECT cycle_length_type, cycle_length_units FROM balances WHERE balance_id='$balance_id';" 2>/dev/null || echo "")
    
    if [[ -n "$db_check" ]]; then
        local cycle_type=$(echo "$db_check" | awk '{print $1}')
        local cycle_units=$(echo "$db_check" | awk '{print $2}')
        
        assert_equals "MONTHS" "$cycle_type" "DB cycle_length_type is MONTHS"
        assert_equals "1" "$cycle_units" "DB cycle_length_units is 1"
        log_info "✓ Database verification: cycle defaults correctly stored"
    else
        log_warning "Could not verify database (container may not be accessible)"
    fi
}

# Test 8: Validate Balance Constraints
test_balance_validation() {
    log_info "Test 8: Validate Balance Constraints"
    
    # Test missing required field
    local invalid_payload=$(cat <<EOF
{
  "balanceType": "ALLOWANCE",
  "balanceAmount": 10737418240
}
EOF
)
    
    local response=$(curl -s -w "\n%{http_code}" -X POST \
        "$BASE_URL/subscriptions/$CREATED_SUBSCRIPTION_ID/balances" \
        -H "$CONTENT_TYPE" \
        -d "$invalid_payload")
    
    local http_code=$(echo "$response" | tail -n1)
    
    assert_equals "400" "$http_code" "Missing required field returns 400 Bad Request"
}

# Test 9: Delete All Balances
test_delete_balances() {
    log_info "Test 9: Delete All Balances for Subscription"
    
    # Verify balances in database before deletion
    log_info "Checking database before deletion..."
    local db_count=$(docker exec ocs-mysql mysql -uocsuser -pocspass ocs_provisioning_dev -sN -e "SELECT COUNT(*) FROM balances WHERE subscription_id='$CREATED_SUBSCRIPTION_ID';" 2>/dev/null)
    log_info "📊 Database has $db_count balance(s) stored for this subscription"
    
    local response=$(curl -s -w "\n%{http_code}" -X DELETE \
        "$BASE_URL/subscriptions/$CREATED_SUBSCRIPTION_ID/balances" \
        -H "$CONTENT_TYPE")
    
    local http_code=$(echo "$response" | tail -n1)
    
    assert_equals "204" "$http_code" "Delete balances returns 204 No Content"
    
    # Verify balances are deleted
    response=$(curl -s -w "\n%{http_code}" -X GET \
        "$BASE_URL/subscriptions/$CREATED_SUBSCRIPTION_ID/balances" \
        -H "$CONTENT_TYPE")
    
    local body=$(echo "$response" | sed '$d')
    
    # Check if response is empty array or has no balances
    ((TESTS_RUN++))
    if [[ "$body" == "[]" ]] || [[ ! "$body" =~ "balanceId" ]]; then
        log_success "All balances deleted successfully"
    else
        log_error "Balances still exist after deletion"
    fi
    
    CREATED_BALANCE_IDS=()
}

# Test 10: Create Balance for Non-existent Subscription
test_create_balance_invalid_subscription() {
    log_info "Test 10: Create Balance for Non-existent Subscription"
    
    local payload=$(cat <<EOF
{
  "balanceType": "ALLOWANCE",
  "unitType": "BYTES",
  "balanceAmount": 10737418240,
  "balanceAvailable": 10737418240,
  "expirationDate": "2025-12-31T23:59:59Z",
  "isRolloverAllowed": false,
  "isRecurring": false,
  "isGroupBalance": false
}
EOF
)
    
    local response=$(curl -s -w "\n%{http_code}" -X POST \
        "$BASE_URL/subscriptions/INVALID-SUB-ID/balances" \
        -H "$CONTENT_TYPE" \
        -d "$payload")
    
    local http_code=$(echo "$response" | tail -n1)
    
    assert_equals "404" "$http_code" "Create balance for invalid subscription returns 404"
}

# Test 11: Get Balance List for Empty Subscription
test_get_empty_balance_list() {
    log_info "Test 11: Get Balance List for Subscription with No Balances"
    
    local response=$(curl -s -w "\n%{http_code}" -X GET \
        "$BASE_URL/subscriptions/$CREATED_SUBSCRIPTION_ID/balances" \
        -H "$CONTENT_TYPE")
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')
    
    assert_equals "200" "$http_code" "Get empty balance list returns 200 OK"
    
    # Check if response is empty array
    ((TESTS_RUN++))
    if [[ "$body" == "[]" ]] || [[ ! "$body" =~ "balanceId" ]]; then
        log_success "Empty balance list returns empty array"
    else
        log_error "Empty balance list should return empty array"
    fi
}

# Main execution
main() {
    echo "======================================"
    echo "Balance API Integration Tests"
    echo "======================================"
    echo ""
    
    # Check if service is running
    if ! curl -s "$BASE_URL/health-check" > /dev/null 2>&1; then
        log_error "Service is not running at $BASE_URL"
        log_info "Please start the service before running tests"
        exit 1
    fi
    
    # Setup
    setup_test_data
    
    # Run tests
    test_create_balance
    test_get_balance_list
    test_create_monetary_balance
    test_create_voice_balance
    test_create_group_balance
    test_create_recurring_balance
    test_recurring_balance_defaults
    test_balance_validation
    
    # Skip delete test if --skip-cleanup is set
    if [ "$SKIP_CLEANUP" = false ]; then
        test_delete_balances
        test_create_balance_invalid_subscription
        test_get_empty_balance_list
    else
        log_info "Skipping delete and empty list tests (--skip-cleanup flag set)"
    fi
    
    # Cleanup
    cleanup
    
    # Summary
    echo ""
    echo "======================================"
    echo "Test Summary"
    echo "======================================"
    echo "Total Tests: $TESTS_RUN"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    echo ""
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}Some tests failed!${NC}"
        exit 1
    fi
}

# Trap cleanup on exit
trap cleanup EXIT

# Run main
main
