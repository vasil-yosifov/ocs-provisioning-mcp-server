#!/bin/bash

# X-Transaction-ID Header Integration Tests
# Tests the X-Transaction-ID header functionality across all endpoints

set -e

BASE_URL="http://localhost:8080/ocs/prov/v1"
CONTENT_TYPE="Content-Type: application/json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
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

# Function to generate random IMSI (macOS compatible)
generate_imsi() {
    echo "$(date +%s)$(printf '%05d' $((RANDOM % 100000)))"
}

# Function to extract header value from curl response
extract_header() {
    local headers=$1
    local header_name=$2
    echo "$headers" | grep -i "^$header_name:" | sed "s/^$header_name: //i" | tr -d '\r'
}

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}X-Transaction-ID Header Integration Tests${NC}"
echo -e "${CYAN}========================================${NC}"

# ==============================================
# Test Suite 1: Custom X-Transaction-ID Header
# ==============================================
print_section "Test Suite 1: Custom X-Transaction-ID Provided"

# Test 1.1: Custom transaction ID is echoed back
echo "Test 1.1: Custom transaction ID is echoed back in response"
CUSTOM_TXN_ID="MY-CUSTOM-TXN-$(generate_uuid)"
RESPONSE=$(curl -s -D - -H "X-Transaction-ID: $CUSTOM_TXN_ID" "$BASE_URL/health-check" 2>&1)
RESPONSE_TXN_ID=$(echo "$RESPONSE" | grep -i "^X-Transaction-ID:" | sed 's/^X-Transaction-ID: //i' | tr -d '\r')

if [ "$RESPONSE_TXN_ID" = "$CUSTOM_TXN_ID" ]; then
    print_test_result "Custom transaction ID echoed back" 0
else
    echo "Expected: $CUSTOM_TXN_ID"
    echo "Got: $RESPONSE_TXN_ID"
    print_test_result "Custom transaction ID echoed back" 1
fi

# Test 1.2: Custom transaction ID with special characters
echo -e "\nTest 1.2: Transaction ID with alphanumeric and dashes"
SPECIAL_TXN_ID="TXN-2024-12-04-ABC123-XYZ"
RESPONSE=$(curl -s -D - -H "X-Transaction-ID: $SPECIAL_TXN_ID" "$BASE_URL/health-check" 2>&1)
RESPONSE_TXN_ID=$(echo "$RESPONSE" | grep -i "^X-Transaction-ID:" | sed 's/^X-Transaction-ID: //i' | tr -d '\r')

if [ "$RESPONSE_TXN_ID" = "$SPECIAL_TXN_ID" ]; then
    print_test_result "Transaction ID with alphanumeric and dashes preserved" 0
else
    echo "Expected: $SPECIAL_TXN_ID"
    echo "Got: $RESPONSE_TXN_ID"
    print_test_result "Transaction ID with alphanumeric and dashes preserved" 1
fi

# Test 1.3: UUID format transaction ID
echo -e "\nTest 1.3: UUID format transaction ID"
UUID_TXN_ID=$(generate_uuid)
RESPONSE=$(curl -s -D - -H "X-Transaction-ID: $UUID_TXN_ID" "$BASE_URL/health-check" 2>&1)
RESPONSE_TXN_ID=$(echo "$RESPONSE" | grep -i "^X-Transaction-ID:" | sed 's/^X-Transaction-ID: //i' | tr -d '\r')

if [ "$RESPONSE_TXN_ID" = "$UUID_TXN_ID" ]; then
    print_test_result "UUID transaction ID preserved" 0
else
    echo "Expected: $UUID_TXN_ID"
    echo "Got: $RESPONSE_TXN_ID"
    print_test_result "UUID transaction ID preserved" 1
fi

# Test 1.4: Long transaction ID (50+ characters)
echo -e "\nTest 1.4: Long transaction ID"
LONG_TXN_ID="TXN-$(date +%Y%m%d%H%M%S)-$(generate_uuid)-$(generate_uuid)"
RESPONSE=$(curl -s -D - -H "X-Transaction-ID: $LONG_TXN_ID" "$BASE_URL/health-check" 2>&1)
RESPONSE_TXN_ID=$(echo "$RESPONSE" | grep -i "^X-Transaction-ID:" | sed 's/^X-Transaction-ID: //i' | tr -d '\r')

if [ "$RESPONSE_TXN_ID" = "$LONG_TXN_ID" ]; then
    print_test_result "Long transaction ID preserved" 0
else
    echo "Expected: $LONG_TXN_ID"
    echo "Got: $RESPONSE_TXN_ID"
    print_test_result "Long transaction ID preserved" 1
fi

# Test 1.5: Numeric only transaction ID
echo -e "\nTest 1.5: Numeric only transaction ID"
NUMERIC_TXN_ID="123456789012345"
RESPONSE=$(curl -s -D - -H "X-Transaction-ID: $NUMERIC_TXN_ID" "$BASE_URL/health-check" 2>&1)
RESPONSE_TXN_ID=$(echo "$RESPONSE" | grep -i "^X-Transaction-ID:" | sed 's/^X-Transaction-ID: //i' | tr -d '\r')

if [ "$RESPONSE_TXN_ID" = "$NUMERIC_TXN_ID" ]; then
    print_test_result "Numeric transaction ID preserved" 0
else
    echo "Expected: $NUMERIC_TXN_ID"
    echo "Got: $RESPONSE_TXN_ID"
    print_test_result "Numeric transaction ID preserved" 1
fi

# ==============================================
# Test Suite 2: Auto-Generated Transaction ID
# ==============================================
print_section "Test Suite 2: Auto-Generated Transaction ID (No Header)"

# Test 2.1: Auto-generated when header missing
echo "Test 2.1: Transaction ID auto-generated when header missing"
RESPONSE=$(curl -s -D - "$BASE_URL/health-check" 2>&1)
RESPONSE_TXN_ID=$(echo "$RESPONSE" | grep -i "^X-Transaction-ID:" | sed 's/^X-Transaction-ID: //i' | tr -d '\r')

if [ -n "$RESPONSE_TXN_ID" ]; then
    echo "Auto-generated TXN ID: $RESPONSE_TXN_ID"
    print_test_result "Transaction ID auto-generated" 0
else
    print_test_result "Transaction ID auto-generated" 1
fi

# Test 2.2: Auto-generated ID contains endpoint name
echo -e "\nTest 2.2: Auto-generated ID contains endpoint identifier"
RESPONSE=$(curl -s -D - "$BASE_URL/health-check" 2>&1)
RESPONSE_TXN_ID=$(echo "$RESPONSE" | grep -i "^X-Transaction-ID:" | sed 's/^X-Transaction-ID: //i' | tr -d '\r')

if echo "$RESPONSE_TXN_ID" | grep -q "health"; then
    print_test_result "Auto-generated ID contains endpoint identifier" 0
else
    echo "Expected 'health' in: $RESPONSE_TXN_ID"
    print_test_result "Auto-generated ID contains endpoint identifier" 1
fi

# Test 2.3: Auto-generated ID contains timestamp
echo -e "\nTest 2.3: Auto-generated ID contains Unix timestamp"
RESPONSE=$(curl -s -D - "$BASE_URL/health-check" 2>&1)
RESPONSE_TXN_ID=$(echo "$RESPONSE" | grep -i "^X-Transaction-ID:" | sed 's/^X-Transaction-ID: //i' | tr -d '\r')

# Extract the numeric part after underscore
TIMESTAMP_PART=$(echo "$RESPONSE_TXN_ID" | grep -oE '[0-9]{13}' || true)
if [ -n "$TIMESTAMP_PART" ]; then
    # Check if timestamp is reasonable (within last hour)
    CURRENT_TIME=$(date +%s)000
    DIFF=$((CURRENT_TIME - TIMESTAMP_PART))
    if [ $DIFF -lt 3600000 ] && [ $DIFF -gt -3600000 ]; then
        print_test_result "Auto-generated ID contains valid Unix timestamp" 0
    else
        echo "Timestamp seems invalid: $TIMESTAMP_PART"
        print_test_result "Auto-generated ID contains valid Unix timestamp" 1
    fi
else
    echo "No timestamp found in: $RESPONSE_TXN_ID"
    print_test_result "Auto-generated ID contains valid Unix timestamp" 1
fi

# Test 2.4: Unique auto-generated IDs for each request
echo -e "\nTest 2.4: Unique auto-generated IDs for consecutive requests"
RESPONSE1=$(curl -s -D - "$BASE_URL/health-check" 2>&1)
TXN_ID1=$(echo "$RESPONSE1" | grep -i "^X-Transaction-ID:" | sed 's/^X-Transaction-ID: //i' | tr -d '\r')
sleep 0.1
RESPONSE2=$(curl -s -D - "$BASE_URL/health-check" 2>&1)
TXN_ID2=$(echo "$RESPONSE2" | grep -i "^X-Transaction-ID:" | sed 's/^X-Transaction-ID: //i' | tr -d '\r')

if [ "$TXN_ID1" != "$TXN_ID2" ]; then
    echo "TXN 1: $TXN_ID1"
    echo "TXN 2: $TXN_ID2"
    print_test_result "Unique auto-generated IDs" 0
else
    echo "Both requests got same ID: $TXN_ID1"
    print_test_result "Unique auto-generated IDs" 1
fi

# ==============================================
# Test Suite 3: Empty/Blank Header Handling
# ==============================================
print_section "Test Suite 3: Empty/Blank Header Handling"

# Test 3.1: Empty header value
echo "Test 3.1: Empty header value triggers auto-generation"
RESPONSE=$(curl -s -D - -H "X-Transaction-ID: " "$BASE_URL/health-check" 2>&1)
RESPONSE_TXN_ID=$(echo "$RESPONSE" | grep -i "^X-Transaction-ID:" | sed 's/^X-Transaction-ID: //i' | tr -d '\r')

if [ -n "$RESPONSE_TXN_ID" ] && echo "$RESPONSE_TXN_ID" | grep -qE "_[0-9]+$"; then
    echo "Auto-generated TXN ID: $RESPONSE_TXN_ID"
    print_test_result "Empty header triggers auto-generation" 0
else
    echo "Got: $RESPONSE_TXN_ID"
    print_test_result "Empty header triggers auto-generation" 1
fi

# Test 3.2: Whitespace-only header value
echo -e "\nTest 3.2: Whitespace-only header value triggers auto-generation"
RESPONSE=$(curl -s -D - -H "X-Transaction-ID:    " "$BASE_URL/health-check" 2>&1)
RESPONSE_TXN_ID=$(echo "$RESPONSE" | grep -i "^X-Transaction-ID:" | sed 's/^X-Transaction-ID: //i' | tr -d '\r')

if [ -n "$RESPONSE_TXN_ID" ] && echo "$RESPONSE_TXN_ID" | grep -qE "_[0-9]+$"; then
    echo "Auto-generated TXN ID: $RESPONSE_TXN_ID"
    print_test_result "Whitespace header triggers auto-generation" 0
else
    echo "Got: $RESPONSE_TXN_ID"
    print_test_result "Whitespace header triggers auto-generation" 1
fi

# ==============================================
# Test Suite 4: Different Endpoints
# ==============================================
print_section "Test Suite 4: Transaction ID Across Different Endpoints"

# Test 4.1: Subscriber lookup endpoint
echo "Test 4.1: Subscriber lookup endpoint"
CUSTOM_TXN="LOOKUP-$(generate_uuid)"
RESPONSE=$(curl -s -D - -H "X-Transaction-ID: $CUSTOM_TXN" "$BASE_URL/subscribers/lookup?msisdn=12345678901234" 2>&1)
RESPONSE_TXN_ID=$(echo "$RESPONSE" | grep -i "^X-Transaction-ID:" | sed 's/^X-Transaction-ID: //i' | tr -d '\r')

if [ "$RESPONSE_TXN_ID" = "$CUSTOM_TXN" ]; then
    print_test_result "Subscriber lookup preserves transaction ID" 0
else
    print_test_result "Subscriber lookup preserves transaction ID" 1
fi

# Test 4.2: Create subscriber endpoint (POST)
echo -e "\nTest 4.2: Create subscriber endpoint (POST)"
CUSTOM_TXN="CREATE-$(generate_uuid)"
SUBSCRIBER_ID=$(generate_uuid)
PAYLOAD=$(cat <<EOF
{
    "subscriberId": "$SUBSCRIBER_ID",
    "msisdn": "1$(date +%s | tail -c 11)",
    "imsi": "$(generate_imsi)",
    "firstName": "TestTxn",
    "lastName": "User",
    "currentState": "PRE_PROVISIONED"
}
EOF
)
RESPONSE=$(curl -s -D - -H "X-Transaction-ID: $CUSTOM_TXN" -H "$CONTENT_TYPE" -X POST "$BASE_URL/subscribers/" -d "$PAYLOAD" 2>&1)
RESPONSE_TXN_ID=$(echo "$RESPONSE" | grep -i "^X-Transaction-ID:" | sed 's/^X-Transaction-ID: //i' | tr -d '\r')
HTTP_CODE=$(echo "$RESPONSE" | grep -E "^HTTP" | tail -1 | awk '{print $2}')

if [ "$RESPONSE_TXN_ID" = "$CUSTOM_TXN" ]; then
    print_test_result "POST subscriber preserves transaction ID" 0
else
    print_test_result "POST subscriber preserves transaction ID" 1
fi

# Clean up created subscriber
if [ "$HTTP_CODE" = "201" ]; then
    curl -s -X DELETE "$BASE_URL/subscribers/$SUBSCRIBER_ID" > /dev/null 2>&1
fi

# Test 4.3: Auto-generated for different endpoints have different prefixes
echo -e "\nTest 4.3: Auto-generated IDs reflect endpoint paths"
RESPONSE_HEALTH=$(curl -s -D - "$BASE_URL/health-check" 2>&1)
TXN_HEALTH=$(echo "$RESPONSE_HEALTH" | grep -i "^X-Transaction-ID:" | sed 's/^X-Transaction-ID: //i' | tr -d '\r')

RESPONSE_LOOKUP=$(curl -s -D - "$BASE_URL/subscribers/lookup?msisdn=12345678901234" 2>&1)
TXN_LOOKUP=$(echo "$RESPONSE_LOOKUP" | grep -i "^X-Transaction-ID:" | sed 's/^X-Transaction-ID: //i' | tr -d '\r')

echo "Health check TXN: $TXN_HEALTH"
echo "Subscriber lookup TXN: $TXN_LOOKUP"

# Extract endpoint parts (before underscore with timestamp)
HEALTH_PREFIX=$(echo "$TXN_HEALTH" | sed 's/_[0-9]*$//')
LOOKUP_PREFIX=$(echo "$TXN_LOOKUP" | sed 's/_[0-9]*$//')

if [ "$HEALTH_PREFIX" != "$LOOKUP_PREFIX" ]; then
    print_test_result "Different endpoints produce different prefixes" 0
else
    print_test_result "Different endpoints produce different prefixes" 1
fi

# ==============================================
# Test Suite 5: Error Response Scenarios
# ==============================================
print_section "Test Suite 5: Transaction ID in Error Responses"

# Test 5.1: 404 Not Found response includes transaction ID
echo "Test 5.1: 404 response includes transaction ID"
CUSTOM_TXN="ERROR-404-$(generate_uuid)"
RESPONSE=$(curl -s -D - -H "X-Transaction-ID: $CUSTOM_TXN" "$BASE_URL/subscribers/non-existent-id-12345" 2>&1)
RESPONSE_TXN_ID=$(echo "$RESPONSE" | grep -i "^X-Transaction-ID:" | sed 's/^X-Transaction-ID: //i' | tr -d '\r')
HTTP_CODE=$(echo "$RESPONSE" | grep -E "^HTTP" | tail -1 | awk '{print $2}')

if [ "$RESPONSE_TXN_ID" = "$CUSTOM_TXN" ] && [ "$HTTP_CODE" = "404" ]; then
    print_test_result "404 response includes transaction ID" 0
else
    echo "HTTP: $HTTP_CODE, TXN: $RESPONSE_TXN_ID"
    print_test_result "404 response includes transaction ID" 1
fi

# Test 5.2: 400 Bad Request response includes transaction ID
echo -e "\nTest 5.2: 400 response includes transaction ID"
CUSTOM_TXN="ERROR-400-$(generate_uuid)"
RESPONSE=$(curl -s -D - -H "X-Transaction-ID: $CUSTOM_TXN" "$BASE_URL/subscribers/lookup" 2>&1)
RESPONSE_TXN_ID=$(echo "$RESPONSE" | grep -i "^X-Transaction-ID:" | sed 's/^X-Transaction-ID: //i' | tr -d '\r')
HTTP_CODE=$(echo "$RESPONSE" | grep -E "^HTTP" | tail -1 | awk '{print $2}')

if [ "$RESPONSE_TXN_ID" = "$CUSTOM_TXN" ] && [ "$HTTP_CODE" = "400" ]; then
    print_test_result "400 response includes transaction ID" 0
else
    echo "HTTP: $HTTP_CODE, TXN: $RESPONSE_TXN_ID"
    print_test_result "400 response includes transaction ID" 1
fi

# Test 5.3: Validation error response includes transaction ID
echo -e "\nTest 5.3: Validation error response includes transaction ID"
CUSTOM_TXN="ERROR-VALID-$(generate_uuid)"
INVALID_PAYLOAD='{"msisdn": "invalid"}'
RESPONSE=$(curl -s -D - -H "X-Transaction-ID: $CUSTOM_TXN" -H "$CONTENT_TYPE" -X POST "$BASE_URL/subscribers/" -d "$INVALID_PAYLOAD" 2>&1)
RESPONSE_TXN_ID=$(echo "$RESPONSE" | grep -i "^X-Transaction-ID:" | sed 's/^X-Transaction-ID: //i' | tr -d '\r')

if [ "$RESPONSE_TXN_ID" = "$CUSTOM_TXN" ]; then
    print_test_result "Validation error includes transaction ID" 0
else
    print_test_result "Validation error includes transaction ID" 1
fi

# ==============================================
# Test Suite 6: HTTP Methods
# ==============================================
print_section "Test Suite 6: Transaction ID with Different HTTP Methods"

# Create a test subscriber for subsequent tests
SUBSCRIBER_ID=$(generate_uuid)
MSISDN="6$(date +%s | tail -c 13)"
PAYLOAD=$(cat <<EOF
{
    "subscriberId": "$SUBSCRIBER_ID",
    "msisdn": "$MSISDN",
    "imsi": "$(generate_imsi)",
    "firstName": "HTTPTest",
    "lastName": "User",
    "currentState": "PRE_PROVISIONED"
}
EOF
)
CREATE_RESPONSE=$(curl -s -w "\n%{http_code}" -H "$CONTENT_TYPE" -X POST "$BASE_URL/subscribers/" -d "$PAYLOAD" 2>&1)
CREATE_CODE=$(echo "$CREATE_RESPONSE" | tail -n1)
if [ "$CREATE_CODE" != "201" ]; then
    echo "Warning: Failed to create test subscriber (HTTP $CREATE_CODE), some tests may fail"
fi

# Test 6.1: GET request
echo "Test 6.1: GET request preserves transaction ID"
CUSTOM_TXN="GET-$(generate_uuid)"
RESPONSE=$(curl -s -D - -H "X-Transaction-ID: $CUSTOM_TXN" -X GET "$BASE_URL/subscribers/$SUBSCRIBER_ID" 2>&1)
RESPONSE_TXN_ID=$(echo "$RESPONSE" | grep -i "^X-Transaction-ID:" | sed 's/^X-Transaction-ID: //i' | tr -d '\r')

if [ "$RESPONSE_TXN_ID" = "$CUSTOM_TXN" ]; then
    print_test_result "GET request preserves transaction ID" 0
else
    print_test_result "GET request preserves transaction ID" 1
fi

# Test 6.2: PATCH request
echo -e "\nTest 6.2: PATCH request preserves transaction ID"
CUSTOM_TXN="PATCH-$(generate_uuid)"
PATCH_PAYLOAD='[{"fieldName": "email", "newValue": "test@example.com"}]'
RESPONSE=$(curl -s -D - -H "X-Transaction-ID: $CUSTOM_TXN" -H "$CONTENT_TYPE" -X PATCH "$BASE_URL/subscribers/$SUBSCRIBER_ID" -d "$PATCH_PAYLOAD" 2>&1)
RESPONSE_TXN_ID=$(echo "$RESPONSE" | grep -i "^X-Transaction-ID:" | sed 's/^X-Transaction-ID: //i' | tr -d '\r')

if [ "$RESPONSE_TXN_ID" = "$CUSTOM_TXN" ]; then
    print_test_result "PATCH request preserves transaction ID" 0
else
    print_test_result "PATCH request preserves transaction ID" 1
fi

# Test 6.3: DELETE request
echo -e "\nTest 6.3: DELETE request preserves transaction ID"
CUSTOM_TXN="DELETE-$(generate_uuid)"
RESPONSE=$(curl -s -D - -H "X-Transaction-ID: $CUSTOM_TXN" -X DELETE "$BASE_URL/subscribers/$SUBSCRIBER_ID" 2>&1)
RESPONSE_TXN_ID=$(echo "$RESPONSE" | grep -i "^X-Transaction-ID:" | sed 's/^X-Transaction-ID: //i' | tr -d '\r')
HTTP_CODE=$(echo "$RESPONSE" | grep -E "^HTTP" | tail -1 | awk '{print $2}')

# Accept 204 (success) or 404 (already deleted) as valid responses for transaction ID check
if [ "$RESPONSE_TXN_ID" = "$CUSTOM_TXN" ]; then
    print_test_result "DELETE request preserves transaction ID" 0
else
    echo "HTTP: $HTTP_CODE, TXN: $RESPONSE_TXN_ID"
    print_test_result "DELETE request preserves transaction ID" 1
fi

# ==============================================
# Test Suite 7: Case Sensitivity
# ==============================================
print_section "Test Suite 7: Header Case Sensitivity"

# Test 7.1: Lowercase header name
echo "Test 7.1: Lowercase header name"
CUSTOM_TXN="CASE-LOWER-$(generate_uuid)"
RESPONSE=$(curl -s -D - -H "x-transaction-id: $CUSTOM_TXN" "$BASE_URL/health-check" 2>&1)
RESPONSE_TXN_ID=$(echo "$RESPONSE" | grep -i "^X-Transaction-ID:" | sed 's/^X-Transaction-ID: //i' | tr -d '\r')

if [ "$RESPONSE_TXN_ID" = "$CUSTOM_TXN" ]; then
    print_test_result "Lowercase header name works" 0
else
    echo "Expected: $CUSTOM_TXN, Got: $RESPONSE_TXN_ID"
    print_test_result "Lowercase header name works" 1
fi

# Test 7.2: Mixed case header name
echo -e "\nTest 7.2: Mixed case header name"
CUSTOM_TXN="CASE-MIXED-$(generate_uuid)"
RESPONSE=$(curl -s -D - -H "X-TRANSACTION-ID: $CUSTOM_TXN" "$BASE_URL/health-check" 2>&1)
RESPONSE_TXN_ID=$(echo "$RESPONSE" | grep -i "^X-Transaction-ID:" | sed 's/^X-Transaction-ID: //i' | tr -d '\r')

if [ "$RESPONSE_TXN_ID" = "$CUSTOM_TXN" ]; then
    print_test_result "Mixed case header name works" 0
else
    echo "Expected: $CUSTOM_TXN, Got: $RESPONSE_TXN_ID"
    print_test_result "Mixed case header name works" 1
fi

# ==============================================
# Test Suite 8: Concurrent Requests
# ==============================================
print_section "Test Suite 8: Concurrent Requests"

# Test 8.1: Multiple concurrent requests with different transaction IDs
echo "Test 8.1: Concurrent requests maintain separate transaction IDs"
CONCURRENT_PASS=0
TXN_IDS=()
RESPONSE_TXNS=()

# Send 5 concurrent requests
for i in {1..5}; do
    TXN_ID="CONCURRENT-$i-$(generate_uuid)"
    TXN_IDS+=("$TXN_ID")
    curl -s -D - -H "X-Transaction-ID: $TXN_ID" "$BASE_URL/health-check" 2>&1 > "/tmp/concurrent_test_$i.txt" &
done

# Wait for all requests to complete
wait

# Check responses
ALL_MATCH=true
for i in {1..5}; do
    EXPECTED="${TXN_IDS[$((i-1))]}"
    ACTUAL=$(grep -i "^X-Transaction-ID:" "/tmp/concurrent_test_$i.txt" | sed 's/^X-Transaction-ID: //i' | tr -d '\r')
    if [ "$EXPECTED" != "$ACTUAL" ]; then
        echo "Request $i - Expected: $EXPECTED, Got: $ACTUAL"
        ALL_MATCH=false
    fi
    rm -f "/tmp/concurrent_test_$i.txt"
done

if [ "$ALL_MATCH" = true ]; then
    print_test_result "Concurrent requests maintain separate transaction IDs" 0
else
    print_test_result "Concurrent requests maintain separate transaction IDs" 1
fi

# ==============================================
# Test Suite 9: Path Variables in Auto-Generated IDs
# ==============================================
print_section "Test Suite 9: Path Variables in Auto-Generated IDs"

# Test 9.1: Endpoint with path variable
echo "Test 9.1: Endpoint with path variable generates appropriate ID"
RESPONSE=$(curl -s -D - "$BASE_URL/subscribers/test-sub-id" 2>&1)
RESPONSE_TXN_ID=$(echo "$RESPONSE" | grep -i "^X-Transaction-ID:" | sed 's/^X-Transaction-ID: //i' | tr -d '\r')

echo "Generated TXN ID: $RESPONSE_TXN_ID"
if [ -n "$RESPONSE_TXN_ID" ] && echo "$RESPONSE_TXN_ID" | grep -q "subscribers"; then
    print_test_result "Path variable endpoint generates valid ID" 0
else
    print_test_result "Path variable endpoint generates valid ID" 1
fi

# Test 9.2: Nested path endpoint
echo -e "\nTest 9.2: Nested path endpoint"
# Create a subscriber first
SUBSCRIBER_ID=$(generate_uuid)
PAYLOAD=$(cat <<EOF
{
    "subscriberId": "$SUBSCRIBER_ID",
    "msisdn": "1$(date +%s | tail -c 11)",
    "imsi": "$(generate_imsi)",
    "firstName": "NestedTest",
    "lastName": "User",
    "currentState": "PRE_PROVISIONED"
}
EOF
)
curl -s -H "$CONTENT_TYPE" -X POST "$BASE_URL/subscribers/" -d "$PAYLOAD" > /dev/null 2>&1

RESPONSE=$(curl -s -D - "$BASE_URL/subscribers/$SUBSCRIBER_ID/subscriptions" 2>&1)
RESPONSE_TXN_ID=$(echo "$RESPONSE" | grep -i "^X-Transaction-ID:" | sed 's/^X-Transaction-ID: //i' | tr -d '\r')

echo "Generated TXN ID for nested path: $RESPONSE_TXN_ID"
if [ -n "$RESPONSE_TXN_ID" ] && echo "$RESPONSE_TXN_ID" | grep -q "subscribers"; then
    print_test_result "Nested path endpoint generates valid ID" 0
else
    print_test_result "Nested path endpoint generates valid ID" 1
fi

# Cleanup
curl -s -X DELETE "$BASE_URL/subscribers/$SUBSCRIBER_ID" > /dev/null 2>&1

# ==============================================
# Summary
# ==============================================
echo -e "\n${CYAN}========================================${NC}"
echo -e "${CYAN}Test Results Summary${NC}"
echo -e "${CYAN}========================================${NC}"
echo -e "Total Tests:  ${TESTS_RUN}"
echo -e "Passed:       ${GREEN}${TESTS_PASSED}${NC}"
echo -e "Failed:       ${RED}${TESTS_FAILED}${NC}"
echo -e "${CYAN}========================================${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}✓ All X-Transaction-ID tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}✗ Some tests failed!${NC}"
    exit 1
fi
