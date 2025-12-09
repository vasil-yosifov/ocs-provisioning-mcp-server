#!/bin/bash
#
# Integration Test for Subscriber Lookup API
# Tests GET /subscribers/lookup endpoint with MSISDN, IMSI, and Name lookup strategies
#
# Usage: ./test-lookup-api.sh [BASE_URL]
# Example: ./test-lookup-api.sh http://localhost:8080
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
NC='\033[0m' # No Color

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Cleanup function
cleanup() {
  # Remove test subscribers if they exist
  if [ -n "${TEST_SUBSCRIBER_ID1:-}" ]; then
    curl -s -X DELETE "${ENDPOINT}/subscribers/${TEST_SUBSCRIBER_ID1}" > /dev/null 2>&1 || true
  fi
  if [ -n "${TEST_SUBSCRIBER_ID2:-}" ]; then
    curl -s -X DELETE "${ENDPOINT}/subscribers/${TEST_SUBSCRIBER_ID2}" > /dev/null 2>&1 || true
  fi
  if [ -n "${TEST_SUBSCRIBER_ID3:-}" ]; then
    curl -s -X DELETE "${ENDPOINT}/subscribers/${TEST_SUBSCRIBER_ID3}" > /dev/null 2>&1 || true
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
  
  echo "$response" | grep -o '"subscriberId":"[^"]*"' | cut -d'"' -f4
}

# Print header
echo "=========================================="
echo "Subscriber Lookup API Integration Tests"
echo "=========================================="
echo "Base URL: ${BASE_URL}"
echo "API Path: ${API_PATH}"
echo ""

# Setup: Create test subscribers
echo -e "${YELLOW}Setting up test data...${NC}"

TEST_SUBSCRIBER_ID1=$(create_subscriber "43660100000001" "214010100000001" "Alice" "Johnson")
if [ -z "$TEST_SUBSCRIBER_ID1" ]; then
  echo -e "${RED}Failed to create test subscriber 1${NC}"
  exit 1
fi
echo "Created subscriber 1: $TEST_SUBSCRIBER_ID1 (Alice Johnson, msisdn: 43660100000001)"

TEST_SUBSCRIBER_ID2=$(create_subscriber "43660100000002" "214010100000002" "Bob" "Smith")
if [ -z "$TEST_SUBSCRIBER_ID2" ]; then
  echo -e "${RED}Failed to create test subscriber 2${NC}"
  exit 1
fi
echo "Created subscriber 2: $TEST_SUBSCRIBER_ID2 (Bob Smith, msisdn: 43660100000002)"

TEST_SUBSCRIBER_ID3=$(create_subscriber "43660100000003" "214010100000003" "Alice" "Johnson")
if [ -z "$TEST_SUBSCRIBER_ID3" ]; then
  echo -e "${RED}Failed to create test subscriber 3${NC}"
  exit 1
fi
echo "Created subscriber 3: $TEST_SUBSCRIBER_ID3 (Alice Johnson duplicate, msisdn: 43660100000003)"
echo ""

# Wait for data to be persisted
sleep 1

# ========================================
# Test Suite: MSISDN Lookup
# ========================================
echo -e "${YELLOW}Test Suite: MSISDN Lookup${NC}"

# Test 1: Lookup by MSISDN - Success
response=$(curl -s -w "\n%{http_code}" "${ENDPOINT}/subscribers/lookup?msisdn=43660100000001")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')
subscriber_id=$(echo "$body" | grep -o '"subscriberId":"[^"]*"' | cut -d'"' -f4 || echo "")

print_result "Lookup by MSISDN - Success (200)" "200" "$http_code"
print_result "Lookup by MSISDN - Returns correct ID" "$TEST_SUBSCRIBER_ID1" "$subscriber_id"

# Test 2: Lookup by MSISDN - Not Found
response=$(curl -s -w "\n%{http_code}" "${ENDPOINT}/subscribers/lookup?msisdn=99999999999999")
http_code=$(echo "$response" | tail -n1)

print_result "Lookup by MSISDN - Not Found (404)" "404" "$http_code"

# Test 3: Lookup by MSISDN - Empty parameter
response=$(curl -s -w "\n%{http_code}" "${ENDPOINT}/subscribers/lookup?msisdn=")
http_code=$(echo "$response" | tail -n1)

print_result "Lookup by MSISDN - Empty param (400)" "400" "$http_code"

echo ""

# ========================================
# Test Suite: IMSI Lookup
# ========================================
echo -e "${YELLOW}Test Suite: IMSI Lookup${NC}"

# Test 4: Lookup by IMSI - Success
response=$(curl -s -w "\n%{http_code}" "${ENDPOINT}/subscribers/lookup?imsi=214010100000002")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')
subscriber_id=$(echo "$body" | grep -o '"subscriberId":"[^"]*"' | cut -d'"' -f4 || echo "")

print_result "Lookup by IMSI - Success (200)" "200" "$http_code"
print_result "Lookup by IMSI - Returns correct ID" "$TEST_SUBSCRIBER_ID2" "$subscriber_id"

# Test 5: Lookup by IMSI - Not Found
response=$(curl -s -w "\n%{http_code}" "${ENDPOINT}/subscribers/lookup?imsi=999999999999999")
http_code=$(echo "$response" | tail -n1)

print_result "Lookup by IMSI - Not Found (404)" "404" "$http_code"

# Test 6: Lookup by IMSI - Empty parameter
response=$(curl -s -w "\n%{http_code}" "${ENDPOINT}/subscribers/lookup?imsi=")
http_code=$(echo "$response" | tail -n1)

print_result "Lookup by IMSI - Empty param (400)" "400" "$http_code"

echo ""

# ========================================
# Test Suite: Name Lookup
# ========================================
echo -e "${YELLOW}Test Suite: Name Lookup${NC}"

# Test 7: Lookup by Name - Success
response=$(curl -s -w "\n%{http_code}" "${ENDPOINT}/subscribers/lookup?firstName=Bob&lastName=Smith")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')
subscriber_id=$(echo "$body" | grep -o '"subscriberId":"[^"]*"' | cut -d'"' -f4 || echo "")

print_result "Lookup by Name - Success (200)" "200" "$http_code"
print_result "Lookup by Name - Returns correct ID" "$TEST_SUBSCRIBER_ID2" "$subscriber_id"

# Test 8: Lookup by Name - Multiple matches (returns first)
response=$(curl -s -w "\n%{http_code}" "${ENDPOINT}/subscribers/lookup?firstName=Alice&lastName=Johnson")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')
subscriber_id=$(echo "$body" | grep -o '"subscriberId":"[^"]*"' | cut -d'"' -f4 || echo "")

print_result "Lookup by Name - Multiple matches (200)" "200" "$http_code"
# Should return either TEST_SUBSCRIBER_ID1 or TEST_SUBSCRIBER_ID3
if [ "$subscriber_id" = "$TEST_SUBSCRIBER_ID1" ] || [ "$subscriber_id" = "$TEST_SUBSCRIBER_ID3" ]; then
  print_result "Lookup by Name - Returns one of the matches" "match" "match"
else
  print_result "Lookup by Name - Returns one of the matches" "match" "no-match"
fi

# Test 9: Lookup by Name - Not Found
response=$(curl -s -w "\n%{http_code}" "${ENDPOINT}/subscribers/lookup?firstName=NonExistent&lastName=User")
http_code=$(echo "$response" | tail -n1)

print_result "Lookup by Name - Not Found (404)" "404" "$http_code"

# Test 10: Lookup by Name - Only firstName (Bad Request)
response=$(curl -s -w "\n%{http_code}" "${ENDPOINT}/subscribers/lookup?firstName=Bob")
http_code=$(echo "$response" | tail -n1)

print_result "Lookup by Name - Only firstName (400)" "400" "$http_code"

# Test 11: Lookup by Name - Only lastName (Bad Request)
response=$(curl -s -w "\n%{http_code}" "${ENDPOINT}/subscribers/lookup?lastName=Smith")
http_code=$(echo "$response" | tail -n1)

print_result "Lookup by Name - Only lastName (400)" "400" "$http_code"

# Test 12: Lookup by Name - Empty firstName
response=$(curl -s -w "\n%{http_code}" "${ENDPOINT}/subscribers/lookup?firstName=&lastName=Smith")
http_code=$(echo "$response" | tail -n1)

print_result "Lookup by Name - Empty firstName (400)" "400" "$http_code"

echo ""

# ========================================
# Test Suite: Priority Handling
# ========================================
echo -e "${YELLOW}Test Suite: Priority Handling${NC}"

# Test 13: Priority - MSISDN over IMSI
response=$(curl -s -w "\n%{http_code}" "${ENDPOINT}/subscribers/lookup?msisdn=43660100000001&imsi=214010100000002")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')
subscriber_id=$(echo "$body" | grep -o '"subscriberId":"[^"]*"' | cut -d'"' -f4 || echo "")

print_result "Priority: MSISDN > IMSI (200)" "200" "$http_code"
print_result "Priority: MSISDN > IMSI - Returns MSISDN match" "$TEST_SUBSCRIBER_ID1" "$subscriber_id"

# Test 14: Priority - MSISDN over Name
response=$(curl -s -w "\n%{http_code}" "${ENDPOINT}/subscribers/lookup?msisdn=43660100000001&firstName=Bob&lastName=Smith")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')
subscriber_id=$(echo "$body" | grep -o '"subscriberId":"[^"]*"' | cut -d'"' -f4 || echo "")

print_result "Priority: MSISDN > Name (200)" "200" "$http_code"
print_result "Priority: MSISDN > Name - Returns MSISDN match" "$TEST_SUBSCRIBER_ID1" "$subscriber_id"

# Test 15: Priority - IMSI over Name
response=$(curl -s -w "\n%{http_code}" "${ENDPOINT}/subscribers/lookup?imsi=214010100000002&firstName=Alice&lastName=Johnson")
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')
subscriber_id=$(echo "$body" | grep -o '"subscriberId":"[^"]*"' | cut -d'"' -f4 || echo "")

print_result "Priority: IMSI > Name (200)" "200" "$http_code"
print_result "Priority: IMSI > Name - Returns IMSI match" "$TEST_SUBSCRIBER_ID2" "$subscriber_id"

echo ""

# ========================================
# Test Suite: Edge Cases
# ========================================
echo -e "${YELLOW}Test Suite: Edge Cases${NC}"

# Test 16: No parameters provided
response=$(curl -s -w "\n%{http_code}" "${ENDPOINT}/subscribers/lookup")
http_code=$(echo "$response" | tail -n1)

print_result "Edge: No parameters (400)" "400" "$http_code"

# Test 17: Response format - Only subscriberId field
response=$(curl -s "${ENDPOINT}/subscribers/lookup?msisdn=43660100000001")
has_subscriber_id=$(echo "$response" | grep -c '"subscriberId"')

print_result "Response: Contains subscriberId" "1" "$has_subscriber_id"

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
  exit 1
else
  echo -e "${GREEN}All tests passed!${NC}"
  exit 0
fi
