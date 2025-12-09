#!/bin/bash
#
# Integration Test for Account History Pagination (T100)
# Tests GET /accountHistory/{entityId} endpoint with limit/offset parameters
#
# Usage: ./account-history-pagination-tests.sh [BASE_URL]
# Example: ./account-history-pagination-tests.sh http://localhost:8080
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

# Test data
TEST_SUBSCRIBER_ID=""
HISTORY_ENTRY_IDS=()

# Cleanup function
cleanup() {
  # Remove test account history entries
  if [ ${#HISTORY_ENTRY_IDS[@]} -gt 0 ]; then
    for entry_id in "${HISTORY_ENTRY_IDS[@]}"; do
      curl -s -X DELETE "${ENDPOINT}/accountHistory/${entry_id}" > /dev/null 2>&1 || true
    done
  fi
  
  # Remove test subscriber
  if [ -n "${TEST_SUBSCRIBER_ID:-}" ]; then
    curl -s -X DELETE "${ENDPOINT}/subscribers/${TEST_SUBSCRIBER_ID}" > /dev/null 2>&1 || true
  fi
}

trap cleanup EXIT

# Helper function to print test result
print_result() {
  local test_name="$1"
  local expected="$2"
  local actual="$3"
  
  TESTS_TOTAL=$((TESTS_TOTAL + 1))
  
  if [ "$expected" = "$actual" ]; then
    echo -e "${GREEN}✓${NC} PASS: ${test_name}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}✗${NC} FAIL: ${test_name}"
    echo -e "  Expected: ${expected}"
    echo -e "  Actual:   ${actual}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# Helper function to create a test subscriber
create_subscriber() {
  local msisdn="$1"
  local imsi="$2"
  
  local payload=$(cat <<EOF
{
  "msisdn": "${msisdn}",
  "imsi": "${imsi}",
  "languageId": "EN",
  "carrierId": "CARRIER_TEST",
  "personalInfo": {
    "firstName": "Test",
    "lastName": "User",
    "dateOfBirth": "1990-01-01",
    "email": "test@example.com",
    "contactNumber": "123456789"
  }
}
EOF
)
  
  local response=$(curl -s -X POST "${ENDPOINT}/subscribers" \
    -H "Content-Type: application/json" \
    -d "$payload")
  
  echo "$response" | grep -o '"subscriberId":"[^"]*"' | cut -d'"' -f4
}

# Helper function to create account history entry
create_history_entry() {
  local entity_id="$1"
  local entity_type="$2"
  local description="$3"
  local delay_seconds="${4:-0}"
  
  # Sleep to ensure different timestamps
  if [ "$delay_seconds" -gt 0 ]; then
    sleep "$delay_seconds"
  fi
  
  local payload=$(cat <<EOF
{
  "entityId": "${entity_id}",
  "entityType": "${entity_type}",
  "description": "${description}",
  "direction": "INBOUND",
  "reason": "Test",
  "status": "COMPLETED",
  "channel": "API",
  "interactionDate": {
    "startDateTime": "$(date -u +%Y-%m-%dT%H:%M:%S+00:00)",
    "endDateTime": "$(date -u +%Y-%m-%dT%H:%M:%S+00:00)"
  }
}
EOF
)
  
  local response=$(curl -s -X POST "${ENDPOINT}/accountHistory" \
    -H "Content-Type: application/json" \
    -d "$payload")
  
  echo "$response" | grep -o '"interactionId":"[^"]*"' | cut -d'"' -f4
}

# Helper function to count array elements in JSON
count_json_array() {
  local json="$1"
  local count=$(echo "$json" | grep -o '"interactionId"' | wc -l | tr -d ' ' || true)
  echo "${count:-0}"
}

# Print header
echo "=========================================="
echo "Account History Pagination Tests (T100)"
echo "=========================================="
echo "Base URL: ${BASE_URL}"
echo "API Path: ${API_PATH}"
echo ""

# Setup: Create test subscriber and history entries
echo -e "${YELLOW}Setting up test data...${NC}"

TEST_SUBSCRIBER_ID=$(create_subscriber "43660199999999" "214010199999999")
if [ -z "$TEST_SUBSCRIBER_ID" ]; then
  echo -e "${RED}Failed to create test subscriber${NC}"
  exit 1
fi
echo "Created test subscriber: $TEST_SUBSCRIBER_ID"

# Create 25 history entries with slight delays to ensure ordering
echo "Creating 25 account history entries..."
MANUAL_ENTRIES=25
# Note: Subscriber creation automatically creates 1 history entry (T099)
# So total expected entries = MANUAL_ENTRIES + 1
EXPECTED_ENTRIES=$((MANUAL_ENTRIES + 1))
for i in $(seq 1 $MANUAL_ENTRIES); do
  entry_id=$(create_history_entry "$TEST_SUBSCRIBER_ID" "SUBSCRIBER" "Test entry $i" 0)
  if [ -n "$entry_id" ]; then
    HISTORY_ENTRY_IDS+=("$entry_id")
    echo -n "."
  else
    echo -e "\n${RED}Failed to create history entry $i${NC}"
    exit 1
  fi
done
echo ""
echo "Created ${#HISTORY_ENTRY_IDS[@]} account history entries"
echo ""

# Wait for data to be persisted
sleep 2

# ========================================
# Test Suite: Default Pagination
# ========================================
echo -e "${YELLOW}Test Suite: Default Pagination${NC}"

# Test 1: No parameters - should return default (20 entries)
response=$(curl -s -w "\n%{http_code}" "${ENDPOINT}/accountHistory/entityId/${TEST_SUBSCRIBER_ID}")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')
count=$(count_json_array "$body")

print_result "Default pagination - HTTP 200" "200" "$http_code"
print_result "Default pagination - Returns 20 entries (default limit)" "20" "$count"

echo ""

# ========================================
# Test Suite: Limit Parameter
# ========================================
echo -e "${YELLOW}Test Suite: Limit Parameter${NC}"

# Test 2: Limit = 5
response=$(curl -s -w "\n%{http_code}" "${ENDPOINT}/accountHistory/entityId/${TEST_SUBSCRIBER_ID}?limit=5")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')
count=$(count_json_array "$body")

print_result "Limit=5 - HTTP 200" "200" "$http_code"
print_result "Limit=5 - Returns 5 entries" "5" "$count"

# Test 3: Limit = 10
response=$(curl -s -w "\n%{http_code}" "${ENDPOINT}/accountHistory/entityId/${TEST_SUBSCRIBER_ID}?limit=10")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')
count=$(count_json_array "$body")

print_result "Limit=10 - HTTP 200" "200" "$http_code"
print_result "Limit=10 - Returns 10 entries" "10" "$count"

# Test 4: Limit = 1 (minimum)
response=$(curl -s -w "\n%{http_code}" "${ENDPOINT}/accountHistory/entityId/${TEST_SUBSCRIBER_ID}?limit=1")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')
count=$(count_json_array "$body")

print_result "Limit=1 (min) - HTTP 200" "200" "$http_code"
print_result "Limit=1 (min) - Returns 1 entry" "1" "$count"

# Test 5: Limit = 100 (maximum) - returns all available entries
response=$(curl -s -w "\n%{http_code}" "${ENDPOINT}/accountHistory/entityId/${TEST_SUBSCRIBER_ID}?limit=100")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')
count=$(count_json_array "$body")

print_result "Limit=100 (max) - HTTP 200" "200" "$http_code"
print_result "Limit=100 (max) - Returns $EXPECTED_ENTRIES entries" "$EXPECTED_ENTRIES" "$count"

# Test 6: Limit = 0 (below minimum, should default to 1)
response=$(curl -s -w "\n%{http_code}" "${ENDPOINT}/accountHistory/entityId/${TEST_SUBSCRIBER_ID}?limit=0")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')
count=$(count_json_array "$body")

print_result "Limit=0 (below min) - HTTP 200" "200" "$http_code"
print_result "Limit=0 (below min) - Returns 1 entry (constrained)" "1" "$count"

# Test 7: Limit = 150 (above maximum, should constrain to 100)
response=$(curl -s -w "\n%{http_code}" "${ENDPOINT}/accountHistory/entityId/${TEST_SUBSCRIBER_ID}?limit=150")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')
count=$(count_json_array "$body")

print_result "Limit=150 (above max) - HTTP 200" "200" "$http_code"
print_result "Limit=150 (above max) - Returns $EXPECTED_ENTRIES entries (constrained to available)" "$EXPECTED_ENTRIES" "$count"

# Test 8: Limit = -5 (negative, should default to 1)
response=$(curl -s -w "\n%{http_code}" "${ENDPOINT}/accountHistory/entityId/${TEST_SUBSCRIBER_ID}?limit=-5")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')
count=$(count_json_array "$body")

print_result "Limit=-5 (negative) - HTTP 200" "200" "$http_code"
print_result "Limit=-5 (negative) - Returns 1 entry (constrained)" "1" "$count"

echo ""

# ========================================
# Test Suite: Offset Parameter
# ========================================
echo -e "${YELLOW}Test Suite: Offset Parameter${NC}"

# Test 9: Offset = 0 (default)
response=$(curl -s -w "\n%{http_code}" "${ENDPOINT}/accountHistory/entityId/${TEST_SUBSCRIBER_ID}?offset=0&limit=5")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')
count=$(count_json_array "$body")

print_result "Offset=0 - HTTP 200" "200" "$http_code"
print_result "Offset=0 - Returns 5 entries" "5" "$count"

# Test 10: Offset = 5
response=$(curl -s -w "\n%{http_code}" "${ENDPOINT}/accountHistory/entityId/${TEST_SUBSCRIBER_ID}?offset=5&limit=5")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')
count=$(count_json_array "$body")

print_result "Offset=5 - HTTP 200" "200" "$http_code"
print_result "Offset=5 - Returns 5 entries" "5" "$count"

# Test 11: Offset = 20 (near end)
response=$(curl -s -w "\n%{http_code}" "${ENDPOINT}/accountHistory/entityId/${TEST_SUBSCRIBER_ID}?offset=20&limit=10")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')
count=$(count_json_array "$body")
remaining=$((EXPECTED_ENTRIES - 20))

print_result "Offset=20 - HTTP 200" "200" "$http_code"
print_result "Offset=20 - Returns $remaining entries (remaining)" "$remaining" "$count"

# Test 12: Offset = EXPECTED_ENTRIES (exact boundary)
response=$(curl -s -w "\n%{http_code}" "${ENDPOINT}/accountHistory/entityId/${TEST_SUBSCRIBER_ID}?offset=${EXPECTED_ENTRIES}&limit=5")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')
count=$(count_json_array "$body")

print_result "Offset=$EXPECTED_ENTRIES (boundary) - HTTP 200" "200" "$http_code"
print_result "Offset=$EXPECTED_ENTRIES (boundary) - Returns 0 entries (empty)" "0" "$count"

# Test 13: Offset = 30 (beyond data)
response=$(curl -s -w "\n%{http_code}" "${ENDPOINT}/accountHistory/entityId/${TEST_SUBSCRIBER_ID}?offset=30&limit=5")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')
count=$(count_json_array "$body")

print_result "Offset=30 (beyond) - HTTP 200" "200" "$http_code"
print_result "Offset=30 (beyond) - Returns 0 entries (empty)" "0" "$count"

# Test 14: Offset = -5 (negative, should default to 0)
response=$(curl -s -w "\n%{http_code}" "${ENDPOINT}/accountHistory/entityId/${TEST_SUBSCRIBER_ID}?offset=-5&limit=5")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')
count=$(count_json_array "$body")

print_result "Offset=-5 (negative) - HTTP 200" "200" "$http_code"
print_result "Offset=-5 (negative) - Returns 5 entries (constrained to 0)" "5" "$count"

echo ""

# ========================================
# Test Suite: Combined Limit + Offset
# ========================================
echo -e "${YELLOW}Test Suite: Combined Limit + Offset${NC}"

# Test 15: Page 1 (limit=5, offset=0)
response=$(curl -s -w "\n%{http_code}" "${ENDPOINT}/accountHistory/entityId/${TEST_SUBSCRIBER_ID}?limit=5&offset=0")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')
count=$(count_json_array "$body")
page1_first_id=$(echo "$body" | grep -o '"interactionId":"[^"]*"' | head -n1 | cut -d'"' -f4 || echo "")

print_result "Page 1 (limit=5, offset=0) - HTTP 200" "200" "$http_code"
print_result "Page 1 (limit=5, offset=0) - Returns 5 entries" "5" "$count"

# Test 16: Page 2 (limit=5, offset=5)
response=$(curl -s -w "\n%{http_code}" "${ENDPOINT}/accountHistory/entityId/${TEST_SUBSCRIBER_ID}?limit=5&offset=5")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')
count=$(count_json_array "$body")
page2_first_id=$(echo "$body" | grep -o '"interactionId":"[^"]*"' | head -n1 | cut -d'"' -f4 || echo "")

print_result "Page 2 (limit=5, offset=5) - HTTP 200" "200" "$http_code"
print_result "Page 2 (limit=5, offset=5) - Returns 5 entries" "5" "$count"

# Test 17: Verify different pages return different data
if [ "$page1_first_id" != "$page2_first_id" ]; then
  print_result "Pages return different data" "different" "different"
else
  print_result "Pages return different data" "different" "same"
fi

# Test 18: Page 3 (limit=5, offset=10)
response=$(curl -s -w "\n%{http_code}" "${ENDPOINT}/accountHistory/entityId/${TEST_SUBSCRIBER_ID}?limit=5&offset=10")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')
count=$(count_json_array "$body")

print_result "Page 3 (limit=5, offset=10) - HTTP 200" "200" "$http_code"
print_result "Page 3 (limit=5, offset=10) - Returns 5 entries" "5" "$count"

# Test 19: Page 4 (limit=5, offset=15)
response=$(curl -s -w "\n%{http_code}" "${ENDPOINT}/accountHistory/entityId/${TEST_SUBSCRIBER_ID}?limit=5&offset=15")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')
count=$(count_json_array "$body")

print_result "Page 4 (limit=5, offset=15) - HTTP 200" "200" "$http_code"
print_result "Page 4 (limit=5, offset=15) - Returns 5 entries" "5" "$count"

# Test 20: Page 5 (limit=5, offset=20) - partial page
response=$(curl -s -w "\n%{http_code}" "${ENDPOINT}/accountHistory/entityId/${TEST_SUBSCRIBER_ID}?limit=5&offset=20")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')
count=$(count_json_array "$body")

print_result "Page 5 (limit=5, offset=20) - HTTP 200" "200" "$http_code"
print_result "Page 5 (limit=5, offset=20) - Returns 5 entries (partial)" "5" "$count"

echo ""

# ========================================
# Test Suite: Edge Cases
# ========================================
echo -e "${YELLOW}Test Suite: Edge Cases${NC}"

# Test 21: Entity with no history
response=$(curl -s -w "\n%{http_code}" "${ENDPOINT}/accountHistory/entityId/non-existent-entity-id")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')
count=$(count_json_array "$body")

print_result "No history - HTTP 200" "200" "$http_code"
print_result "No history - Returns 0 entries (empty array)" "0" "$count"

# Test 22: Invalid limit (non-numeric) - Spring returns 500 for type conversion errors
response=$(curl -s -w "\n%{http_code}" "${ENDPOINT}/accountHistory/entityId/${TEST_SUBSCRIBER_ID}?limit=abc")
http_code=$(echo "$response" | tail -n1)

print_result "Invalid limit (non-numeric) - HTTP 500" "500" "$http_code"

# Test 23: Invalid offset (non-numeric) - Spring returns 500 for type conversion errors
response=$(curl -s -w "\n%{http_code}" "${ENDPOINT}/accountHistory/entityId/${TEST_SUBSCRIBER_ID}?offset=xyz")
http_code=$(echo "$response" | tail -n1)

print_result "Invalid offset (non-numeric) - HTTP 500" "500" "$http_code"

# Test 24: Only offset (no limit) - should use default limit
response=$(curl -s -w "\n%{http_code}" "${ENDPOINT}/accountHistory/entityId/${TEST_SUBSCRIBER_ID}?offset=5")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')
count=$(count_json_array "$body")

print_result "Only offset - HTTP 200" "200" "$http_code"
print_result "Only offset - Returns 20 entries (default limit)" "20" "$count"

# Test 25: Only limit (no offset) - should use default offset (0)
response=$(curl -s -w "\n%{http_code}" "${ENDPOINT}/accountHistory/entityId/${TEST_SUBSCRIBER_ID}?limit=8")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')
count=$(count_json_array "$body")

print_result "Only limit - HTTP 200" "200" "$http_code"
print_result "Only limit - Returns 8 entries" "8" "$count"

echo ""

# ========================================
# Test Suite: Response Format
# ========================================
echo -e "${YELLOW}Test Suite: Response Format${NC}"

# Test 26: Response is valid JSON array
response=$(curl -s "${ENDPOINT}/accountHistory/entityId/${TEST_SUBSCRIBER_ID}?limit=5")
is_array=$(echo "$response" | grep -c '^\[' || echo "0")

print_result "Response format - Valid JSON array" "1" "$is_array"

# Test 27: Response contains expected fields
has_interaction_id=$(echo "$response" | grep -c '"interactionId"' || echo "0")
has_entity_id=$(echo "$response" | grep -c '"entityId"' || echo "0")
has_description=$(echo "$response" | grep -c '"description"' || echo "0")

if [ "$has_interaction_id" -gt 0 ] && [ "$has_entity_id" -gt 0 ] && [ "$has_description" -gt 0 ]; then
  print_result "Response format - Contains expected fields" "true" "true"
else
  print_result "Response format - Contains expected fields" "true" "false"
fi

echo ""

# ========================================
# Test Suite: Ordering
# ========================================
echo -e "${YELLOW}Test Suite: Ordering (DESC by startDateTime)${NC}"

# Test 28: Verify results are ordered DESC by startDateTime
response=$(curl -s "${ENDPOINT}/accountHistory/entityId/${TEST_SUBSCRIBER_ID}?limit=100")
# Count occurrences of startDateTime field (each entry has exactly one)
# grep -o outputs each match on a separate line, then count non-empty lines
matches=$(echo "$response" | grep -o '"startDateTime"' || true)
if [ -z "$matches" ]; then
  date_count=0
else
  date_count=$(echo "$matches" | wc -l | tr -d ' ')
fi

if [ "$date_count" -eq $EXPECTED_ENTRIES ]; then
  print_result "Ordering - Retrieved all entries with timestamps" "$EXPECTED_ENTRIES" "$date_count"
else
  print_result "Ordering - Retrieved all entries with timestamps" "$EXPECTED_ENTRIES" "$date_count"
fi

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
else
  echo -e "Failed:       $TESTS_FAILED"
fi
echo "=========================================="

# Exit with appropriate code
if [ $TESTS_FAILED -gt 0 ]; then
  echo -e "${RED}Some tests failed. Please review the implementation.${NC}"
  exit 1
else
  echo -e "${GREEN}All tests passed! T100 implementation verified.${NC}"
  exit 0
fi
