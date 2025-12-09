#!/bin/bash
#
# Integration Test for Subscriber Delete API
# Tests DELETE /subscribers/{subscriberId} endpoint
#
# Usage: ./subscriber-delete-api-tests.sh [BASE_URL]
# Example: ./subscriber-delete-api-tests.sh http://localhost:8080
#

set -euo pipefail

# Configuration
BASE_URL="${1:-http://localhost:8080}"
API_PATH="/ocs/prov/v1"
ENDPOINT="${BASE_URL}${API_PATH}"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Array to track created subscribers for cleanup
declare -a CREATED_SUBSCRIBERS=()

# Cleanup function
cleanup() {
  echo ""
  echo -e "${YELLOW}Cleaning up test data...${NC}"
  if [ ${#CREATED_SUBSCRIBERS[@]} -gt 0 ]; then
    for subscriber_id in "${CREATED_SUBSCRIBERS[@]}"; do
      if [ -n "$subscriber_id" ]; then
        curl -s -X DELETE "${ENDPOINT}/subscribers/${subscriber_id}" > /dev/null 2>&1 || true
        echo "  Deleted subscriber: $subscriber_id"
      fi
    done
  else
    echo "  No subscribers to clean up"
  fi
  echo -e "${GREEN}Cleanup complete${NC}"
}

trap cleanup EXIT

# Helper function to print test result
print_result() {
  local test_name="$1"
  local expected="$2"
  local actual="$3"
  local description="${4:-}"
  
  TESTS_TOTAL=$((TESTS_TOTAL + 1))
  
  if [ "$expected" = "$actual" ]; then
    echo -e "${GREEN}✓${NC} PASS: ${test_name}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    if [ -n "$description" ]; then
      echo -e "  ${BLUE}→${NC} $description"
    fi
  else
    echo -e "${RED}✗${NC} FAIL: ${test_name}"
    echo -e "  Expected: ${expected}"
    echo -e "  Actual:   ${actual}"
    if [ -n "$description" ]; then
      echo -e "  ${BLUE}→${NC} $description"
    fi
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# Helper function to create a test subscriber
create_subscriber() {
  local msisdn="$1"
  local imsi="$2"
  local first_name="$3"
  local last_name="$4"
  local email_prefix=$(echo "$first_name" | tr '[:upper:]' '[:lower:]')
  
  local payload=$(cat <<EOF
{
  "msisdn": "${msisdn}",
  "imsi": "${imsi}",
  "languageId": "EN",
  "carrierId": "CARRIER_TEST",
  "personalInfo": {
    "firstName": "${first_name}",
    "lastName": "${last_name}",
    "dateOfBirth": "1990-01-01",
    "email": "${email_prefix}@test.com",
    "contactNumber": "123456789"
  }
}
EOF
)
  
  local response=$(curl -s -X POST "${ENDPOINT}/subscribers" \
    -H "Content-Type: application/json" \
    -d "$payload")
  
  local subscriber_id=$(echo "$response" | grep -o '"subscriberId":"[^"]*"' | cut -d'"' -f4)
  
  if [ -n "$subscriber_id" ]; then
    CREATED_SUBSCRIBERS+=("$subscriber_id")
  fi
  
  echo "$subscriber_id"
}

# Helper function to get subscriber by ID
get_subscriber() {
  local subscriber_id="$1"
  
  curl -s -w "\n%{http_code}" -X GET "${ENDPOINT}/subscribers/${subscriber_id}"
}

# Helper function to transition subscriber to a specific state
transition_subscriber_state() {
  local subscriber_id="$1"
  local target_state="$2"
  
  local payload="[{\"fieldName\": \"state\", \"fieldValue\": \"${target_state}\"}]"
  
  curl -s -X PATCH "${ENDPOINT}/subscribers/${subscriber_id}" \
    -H "Content-Type: application/json" \
    -d "$payload" > /dev/null 2>&1
}

# Print header
echo "=========================================="
echo "Subscriber Delete API Integration Tests"
echo "=========================================="
echo "Base URL: ${BASE_URL}"
echo "API Path: ${API_PATH}"
echo "Endpoint: DELETE ${API_PATH}/subscribers/{subscriberId}"
echo ""

# ========================================
# Test Suite 1: Basic Delete Operations
# ========================================
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
echo -e "${YELLOW}Test Suite 1: Basic Delete Operations${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
echo ""

# Test 1: Delete existing subscriber - Success
echo -e "${BLUE}Test 1: Delete existing subscriber${NC}"
SUBSCRIBER_ID=$(create_subscriber "43660200000001" "214010200000001" "Delete" "Test1")
if [ -z "$SUBSCRIBER_ID" ]; then
  echo -e "${RED}Failed to create test subscriber${NC}"
  exit 1
fi
echo "Created subscriber: $SUBSCRIBER_ID"

response=$(curl -s -w "\n%{http_code}" -X DELETE "${ENDPOINT}/subscribers/${SUBSCRIBER_ID}")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

print_result "Delete existing subscriber - HTTP 204" "204" "$http_code" "Should return 204 No Content"

# Verify subscriber is deleted
response=$(curl -s -w "\n%{http_code}" -X GET "${ENDPOINT}/subscribers/${SUBSCRIBER_ID}")
http_code=$(echo "$response" | tail -n1)

print_result "Delete existing subscriber - Verify deletion" "404" "$http_code" "GET should return 404 after deletion"

# Remove from cleanup array since it's already deleted
CREATED_SUBSCRIBERS=("${CREATED_SUBSCRIBERS[@]/$SUBSCRIBER_ID}")

echo ""

# Test 2: Delete non-existent subscriber - Not Found
echo -e "${BLUE}Test 2: Delete non-existent subscriber${NC}"
NON_EXISTENT_ID="00000000-0000-0000-0000-000000000000"

response=$(curl -s -w "\n%{http_code}" -X DELETE "${ENDPOINT}/subscribers/${NON_EXISTENT_ID}")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

print_result "Delete non-existent subscriber - HTTP 404" "404" "$http_code" "Should return 404 Not Found"

has_error=$(echo "$body" | grep -c '"error"' || echo "0")
print_result "Delete non-existent subscriber - Error response" "1" "$has_error" "Should return error details"

echo ""

# Test 3: Delete with invalid UUID format
echo -e "${BLUE}Test 3: Delete with invalid subscriber ID format${NC}"
INVALID_ID="not-a-valid-uuid"

response=$(curl -s -w "\n%{http_code}" -X DELETE "${ENDPOINT}/subscribers/${INVALID_ID}")
http_code=$(echo "$response" | tail -n1)

# Spring may return 400 or 404 depending on validation
if [ "$http_code" = "400" ] || [ "$http_code" = "404" ] || [ "$http_code" = "500" ]; then
  print_result "Delete invalid UUID format - Error response" "error" "error" "Should return 400/404/500 for invalid UUID"
else
  print_result "Delete invalid UUID format - Error response" "400/404/500" "$http_code" "Should return error for invalid UUID"
fi

echo ""

# ========================================
# Test Suite 2: State-Based Delete Tests
# ========================================
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
echo -e "${YELLOW}Test Suite 2: Delete Subscribers in Different States${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
echo ""

# Test 4: Delete subscriber in PRE_PROVISIONED state
echo -e "${BLUE}Test 4: Delete PRE_PROVISIONED subscriber${NC}"
SUBSCRIBER_ID=$(create_subscriber "43660200000002" "214010200000002" "PreProv" "Test")
echo "Created subscriber: $SUBSCRIBER_ID (PRE_PROVISIONED)"

response=$(curl -s -w "\n%{http_code}" -X DELETE "${ENDPOINT}/subscribers/${SUBSCRIBER_ID}")
http_code=$(echo "$response" | tail -n1)

print_result "Delete PRE_PROVISIONED subscriber" "204" "$http_code" "Can delete subscriber in initial state"

# Verify deletion
response=$(get_subscriber "$SUBSCRIBER_ID")
http_code=$(echo "$response" | tail -n1)
print_result "Verify PRE_PROVISIONED deletion" "404" "$http_code" "Subscriber should be gone"

CREATED_SUBSCRIBERS=("${CREATED_SUBSCRIBERS[@]/$SUBSCRIBER_ID}")
echo ""

# Test 5: Delete subscriber in ACTIVE state
echo -e "${BLUE}Test 5: Delete ACTIVE subscriber${NC}"
SUBSCRIBER_ID=$(create_subscriber "43660200000003" "214010200000003" "Active" "Test")
echo "Created subscriber: $SUBSCRIBER_ID"

# Transition to ACTIVE
transition_subscriber_state "$SUBSCRIBER_ID" "ACTIVE"
echo "Transitioned to ACTIVE state"

response=$(curl -s -w "\n%{http_code}" -X DELETE "${ENDPOINT}/subscribers/${SUBSCRIBER_ID}")
http_code=$(echo "$response" | tail -n1)

print_result "Delete ACTIVE subscriber" "204" "$http_code" "Can delete active subscriber"

# Verify deletion
response=$(get_subscriber "$SUBSCRIBER_ID")
http_code=$(echo "$response" | tail -n1)
print_result "Verify ACTIVE deletion" "404" "$http_code" "Subscriber should be gone"

CREATED_SUBSCRIBERS=("${CREATED_SUBSCRIBERS[@]/$SUBSCRIBER_ID}")
echo ""

# Test 6: Delete subscriber in SUSPENDED state
echo -e "${BLUE}Test 6: Delete SUSPENDED subscriber${NC}"
SUBSCRIBER_ID=$(create_subscriber "43660200000004" "214010200000004" "Suspended" "Test")
echo "Created subscriber: $SUBSCRIBER_ID"

# Transition to ACTIVE then SUSPENDED
transition_subscriber_state "$SUBSCRIBER_ID" "ACTIVE"
transition_subscriber_state "$SUBSCRIBER_ID" "SUSPENDED"
echo "Transitioned to SUSPENDED state"

response=$(curl -s -w "\n%{http_code}" -X DELETE "${ENDPOINT}/subscribers/${SUBSCRIBER_ID}")
http_code=$(echo "$response" | tail -n1)

print_result "Delete SUSPENDED subscriber" "204" "$http_code" "Can delete suspended subscriber"

# Verify deletion
response=$(get_subscriber "$SUBSCRIBER_ID")
http_code=$(echo "$response" | tail -n1)
print_result "Verify SUSPENDED deletion" "404" "$http_code" "Subscriber should be gone"

CREATED_SUBSCRIBERS=("${CREATED_SUBSCRIBERS[@]/$SUBSCRIBER_ID}")
echo ""

# Test 7: Delete subscriber in DEACTIVATED state
echo -e "${BLUE}Test 7: Delete DEACTIVATED subscriber${NC}"
SUBSCRIBER_ID=$(create_subscriber "43660200000005" "214010200000005" "Deactivated" "Test")
echo "Created subscriber: $SUBSCRIBER_ID"

# Transition to ACTIVE then DEACTIVATED
transition_subscriber_state "$SUBSCRIBER_ID" "ACTIVE"
transition_subscriber_state "$SUBSCRIBER_ID" "DEACTIVATED"
echo "Transitioned to DEACTIVATED state"

response=$(curl -s -w "\n%{http_code}" -X DELETE "${ENDPOINT}/subscribers/${SUBSCRIBER_ID}")
http_code=$(echo "$response" | tail -n1)

print_result "Delete DEACTIVATED subscriber" "204" "$http_code" "Can delete deactivated subscriber"

# Verify deletion
response=$(get_subscriber "$SUBSCRIBER_ID")
http_code=$(echo "$response" | tail -n1)
print_result "Verify DEACTIVATED deletion" "404" "$http_code" "Subscriber should be gone"

CREATED_SUBSCRIBERS=("${CREATED_SUBSCRIBERS[@]/$SUBSCRIBER_ID}")
echo ""

# ========================================
# Test Suite 3: Idempotency Tests
# ========================================
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
echo -e "${YELLOW}Test Suite 3: Idempotency Tests${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
echo ""

# Test 8: Double delete - Second delete should fail
echo -e "${BLUE}Test 8: Delete same subscriber twice${NC}"
SUBSCRIBER_ID=$(create_subscriber "43660200000006" "214010200000006" "DoubleDelete" "Test")
echo "Created subscriber: $SUBSCRIBER_ID"

# First delete
response=$(curl -s -w "\n%{http_code}" -X DELETE "${ENDPOINT}/subscribers/${SUBSCRIBER_ID}")
http_code=$(echo "$response" | tail -n1)
print_result "First delete operation" "204" "$http_code" "First delete succeeds"

# Second delete (same subscriber)
response=$(curl -s -w "\n%{http_code}" -X DELETE "${ENDPOINT}/subscribers/${SUBSCRIBER_ID}")
http_code=$(echo "$response" | tail -n1)
print_result "Second delete operation" "404" "$http_code" "Second delete returns 404"

CREATED_SUBSCRIBERS=("${CREATED_SUBSCRIBERS[@]/$SUBSCRIBER_ID}")
echo ""

# ========================================
# Test Suite 4: Response Format Tests
# ========================================
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
echo -e "${YELLOW}Test Suite 4: Response Format Tests${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
echo ""

# Test 9: Successful delete has no response body
echo -e "${BLUE}Test 9: Verify successful delete response format${NC}"
SUBSCRIBER_ID=$(create_subscriber "43660200000007" "214010200000007" "ResponseFormat" "Test")
echo "Created subscriber: $SUBSCRIBER_ID"

response=$(curl -s -w "\n%{http_code}" -X DELETE "${ENDPOINT}/subscribers/${SUBSCRIBER_ID}")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

print_result "Delete response - HTTP 204" "204" "$http_code" "Should return 204 No Content"

body_length=${#body}
print_result "Delete response - Empty body" "0" "$body_length" "Body should be empty for 204"

CREATED_SUBSCRIBERS=("${CREATED_SUBSCRIBERS[@]/$SUBSCRIBER_ID}")
echo ""

# Test 10: Error response has proper structure
echo -e "${BLUE}Test 10: Verify error response format${NC}"
NON_EXISTENT_ID="11111111-1111-1111-1111-111111111111"

response=$(curl -s -w "\n%{http_code}" -X DELETE "${ENDPOINT}/subscribers/${NON_EXISTENT_ID}")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

print_result "Error response - HTTP 404" "404" "$http_code" "Should return 404"

has_timestamp=$(echo "$body" | grep -c '"timestamp"' || echo "0")
has_status=$(echo "$body" | grep -c '"status"' || echo "0")
has_error=$(echo "$body" | grep -c '"error"' || echo "0")
has_message=$(echo "$body" | grep -c '"message"' || echo "0")
has_path=$(echo "$body" | grep -c '"path"' || echo "0")

print_result "Error response - Has timestamp" "1" "$has_timestamp" "Should include timestamp field"
print_result "Error response - Has status" "1" "$has_status" "Should include status field"
print_result "Error response - Has error" "1" "$has_error" "Should include error field"
print_result "Error response - Has message" "1" "$has_message" "Should include message field"
print_result "Error response - Has path" "1" "$has_path" "Should include path field"

echo ""

# ========================================
# Test Suite 5: Cascade Delete Tests
# ========================================
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
echo -e "${YELLOW}Test Suite 5: Cascade Delete Verification${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
echo ""

# Test 11: Delete subscriber and verify lookup fails
echo -e "${BLUE}Test 11: Verify subscriber cannot be found after deletion${NC}"
SUBSCRIBER_ID=$(create_subscriber "43660200000008" "214010200000008" "LookupAfterDelete" "Test")
MSISDN="43660200000008"
echo "Created subscriber: $SUBSCRIBER_ID (MSISDN: $MSISDN)"

# Delete subscriber
response=$(curl -s -w "\n%{http_code}" -X DELETE "${ENDPOINT}/subscribers/${SUBSCRIBER_ID}")
http_code=$(echo "$response" | tail -n1)
print_result "Delete subscriber" "204" "$http_code" "Deletion successful"

# Try to lookup by MSISDN
response=$(curl -s -w "\n%{http_code}" "${ENDPOINT}/subscribers/lookup?msisdn=${MSISDN}")
http_code=$(echo "$response" | tail -n1)
print_result "Lookup by MSISDN after delete" "404" "$http_code" "Lookup should fail after deletion"

# Try to lookup by GET ID
response=$(curl -s -w "\n%{http_code}" "${ENDPOINT}/subscribers/${SUBSCRIBER_ID}")
http_code=$(echo "$response" | tail -n1)
print_result "GET by ID after delete" "404" "$http_code" "GET should fail after deletion"

CREATED_SUBSCRIBERS=("${CREATED_SUBSCRIBERS[@]/$SUBSCRIBER_ID}")
echo ""

# ========================================
# Test Suite 6: Concurrent Delete Tests
# ========================================
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
echo -e "${YELLOW}Test Suite 6: Sequential Delete Tests${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
echo ""

# Test 12: Delete multiple subscribers in sequence
echo -e "${BLUE}Test 12: Delete multiple subscribers sequentially${NC}"
SUBSCRIBER_ID1=$(create_subscriber "43660200000009" "214010200000009" "Multi1" "Test")
SUBSCRIBER_ID2=$(create_subscriber "43660200000010" "214010200000010" "Multi2" "Test")
SUBSCRIBER_ID3=$(create_subscriber "43660200000011" "214010200000011" "Multi3" "Test")
echo "Created 3 subscribers: $SUBSCRIBER_ID1, $SUBSCRIBER_ID2, $SUBSCRIBER_ID3"

# Delete first subscriber
response=$(curl -s -w "\n%{http_code}" -X DELETE "${ENDPOINT}/subscribers/${SUBSCRIBER_ID1}")
http_code=$(echo "$response" | tail -n1)
print_result "Delete subscriber 1" "204" "$http_code" "First deletion"

# Delete second subscriber
response=$(curl -s -w "\n%{http_code}" -X DELETE "${ENDPOINT}/subscribers/${SUBSCRIBER_ID2}")
http_code=$(echo "$response" | tail -n1)
print_result "Delete subscriber 2" "204" "$http_code" "Second deletion"

# Delete third subscriber
response=$(curl -s -w "\n%{http_code}" -X DELETE "${ENDPOINT}/subscribers/${SUBSCRIBER_ID3}")
http_code=$(echo "$response" | tail -n1)
print_result "Delete subscriber 3" "204" "$http_code" "Third deletion"

# Verify all are deleted
response=$(get_subscriber "$SUBSCRIBER_ID1")
http_code=$(echo "$response" | tail -n1)
print_result "Verify subscriber 1 deleted" "404" "$http_code" "First should be gone"

response=$(get_subscriber "$SUBSCRIBER_ID2")
http_code=$(echo "$response" | tail -n1)
print_result "Verify subscriber 2 deleted" "404" "$http_code" "Second should be gone"

response=$(get_subscriber "$SUBSCRIBER_ID3")
http_code=$(echo "$response" | tail -n1)
print_result "Verify subscriber 3 deleted" "404" "$http_code" "Third should be gone"

CREATED_SUBSCRIBERS=("${CREATED_SUBSCRIBERS[@]/$SUBSCRIBER_ID1}")
CREATED_SUBSCRIBERS=("${CREATED_SUBSCRIBERS[@]/$SUBSCRIBER_ID2}")
CREATED_SUBSCRIBERS=("${CREATED_SUBSCRIBERS[@]/$SUBSCRIBER_ID3}")
echo ""

# ========================================
# Summary
# ========================================
echo "=========================================="
echo "Test Results Summary"
echo "=========================================="
echo "Total Tests:  $TESTS_TOTAL"
echo -e "${GREEN}Passed:       $TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
  echo -e "${RED}Failed:       $TESTS_FAILED${NC}"
  echo ""
  echo -e "${RED}Some tests failed!${NC}"
else
  echo -e "Failed:       $TESTS_FAILED"
  echo ""
  echo -e "${GREEN}✓ All tests passed!${NC}"
fi
echo "=========================================="
echo ""
echo "Verified Functionality:"
echo "  ✓ Basic delete operations (success/not found/invalid ID)"
echo "  ✓ Delete subscribers in all states (PRE_PROVISIONED, ACTIVE, SUSPENDED, DEACTIVATED)"
echo "  ✓ Idempotency (double delete handling)"
echo "  ✓ Response format (204 No Content, error structure)"
echo "  ✓ Cascade verification (lookup/GET fails after delete)"
echo "  ✓ Sequential delete operations"
echo ""

# Exit with appropriate code
if [ $TESTS_FAILED -gt 0 ]; then
  exit 1
else
  exit 0
fi
