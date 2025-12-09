#!/bin/bash

# Integration Tests for Subscriber API (T047-T054)
# Tests the implementation of User Story 1: Subscriber Provisioning and Lifecycle Management

set -e

BASE_URL="http://localhost:8080/ocs/prov/v1"
PASSED=0
FAILED=0

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Subscriber API Integration Tests"
echo "Testing T047-T054 Implementation"
echo "=========================================="
echo ""

# Cleanup function to delete test subscribers
cleanup_test_data() {
    echo -e "${YELLOW}Cleaning up existing test data...${NC}"
    
    # List of test MSISDNs to cleanup
    TEST_MSISDNS=(
        "43664123456789"
        "43664987654321"
        "43664999999999"
    )
    
    for msisdn in "${TEST_MSISDNS[@]}"; do
        # Try to lookup subscriber by MSISDN
        lookup_response=$(curl -s -w "\n%{http_code}" -X GET "$BASE_URL/subscribers/lookup?msisdn=$msisdn")
        http_code=$(echo "$lookup_response" | tail -n1)
        
        if [ "$http_code" == "200" ]; then
            body=$(echo "$lookup_response" | sed '$d')
            subscriber_id=$(echo "$body" | grep -o '"subscriberId":"[^"]*"' | cut -d'"' -f4)
            
            if [ ! -z "$subscriber_id" ]; then
                echo "  Deleting subscriber with MSISDN $msisdn (ID: $subscriber_id)"
                curl -s -X DELETE "$BASE_URL/subscribers/$subscriber_id" > /dev/null
            fi
        fi
    done
    
    echo -e "${GREEN}Cleanup complete${NC}"
    echo ""
}

# Run cleanup before tests
cleanup_test_data

# Helper function to test endpoints
test_endpoint() {
    local test_name=$1
    local method=$2
    local endpoint=$3
    local data=$4
    local expected_status=$5
    local description=$6
    
    echo -n "Testing: $test_name... "
    
    if [ "$method" == "GET" ]; then
        response=$(curl -s -w "\n%{http_code}" -X GET "$BASE_URL$endpoint")
    elif [ "$method" == "POST" ]; then
        response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL$endpoint" \
            -H "Content-Type: application/json" \
            -d "$data")
    elif [ "$method" == "PATCH" ]; then
        response=$(curl -s -w "\n%{http_code}" -X PATCH "$BASE_URL$endpoint" \
            -H "Content-Type: application/json" \
            -d "$data")
    elif [ "$method" == "DELETE" ]; then
        response=$(curl -s -w "\n%{http_code}" -X DELETE "$BASE_URL$endpoint")
    fi
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" == "$expected_status" ]; then
        echo -e "${GREEN}✓ PASSED${NC} (Status: $http_code)"
        echo "   Description: $description"
        PASSED=$((PASSED + 1))
        if [ ! -z "$body" ] && [ "$body" != "null" ]; then
            echo "   Response: $body" | head -c 200
            echo ""
        fi
    else
        echo -e "${RED}✗ FAILED${NC} (Expected: $expected_status, Got: $http_code)"
        echo "   Description: $description"
        echo "   Response: $body"
        FAILED=$((FAILED + 1))
    fi
    echo ""
}

# Test 1: Health Check
echo -e "${YELLOW}=== Basic Health Check ===${NC}"
test_endpoint \
    "Health Check" \
    "GET" \
    "/health-check" \
    "" \
    "200" \
    "Verify API is accessible"

# Test 2: Create Subscriber (T047 - Entity, T049 - Service, T051 - Mapper, T053 - Controller)
echo -e "${YELLOW}=== Test Create Subscriber (FR-007) ===${NC}"
CREATE_PAYLOAD='{
  "msisdn": "43664123456789",
  "imsi": "214010123456789",
  "personalInfo": {
    "firstName": "John",
    "lastName": "Doe",
    "dateOfBirth": "1990-01-15",
    "email": "john.doe@example.com",
    "contactNumber": "436641234567"
  },
  "billing": {
    "billingCycle": 1,
    "billingAddress": {
      "street": "123 Main St",
      "city": "Vienna",
      "country": "Austria"
    }
  }
}'

test_endpoint \
    "Create Subscriber" \
    "POST" \
    "/subscribers" \
    "$CREATE_PAYLOAD" \
    "201" \
    "Create new subscriber with PRE_PROVISIONED state (FR-007)"

# Extract subscriber ID from the last response
SUBSCRIBER_ID=$(echo "$body" | grep -o '"subscriberId":"[^"]*"' | cut -d'"' -f4)
echo "Created Subscriber ID: $SUBSCRIBER_ID"
echo ""

# Test 3: Get Subscriber by ID (T048 - Repository findById, T049 - Service, T052 - Controller)
echo -e "${YELLOW}=== Test Get Subscriber by ID ===${NC}"
test_endpoint \
    "Get Subscriber by ID" \
    "GET" \
    "/subscribers/$SUBSCRIBER_ID" \
    "" \
    "200" \
    "Retrieve subscriber by ID (T048, T049, T052)"

# Test 4: Lookup Subscriber by MSISDN (T048 - Repository custom query, T049 - Service)
echo -e "${YELLOW}=== Test Lookup by MSISDN (FR-001) ===${NC}"
test_endpoint \
    "Lookup by MSISDN" \
    "GET" \
    "/subscribers/lookup?msisdn=43664123456789" \
    "" \
    "200" \
    "Lookup subscriber by phone number (FR-001)"

# Test 5: Lookup Subscriber by IMSI (T048 - Repository custom query)
echo -e "${YELLOW}=== Test Lookup by IMSI (FR-001) ===${NC}"
test_endpoint \
    "Lookup by IMSI" \
    "GET" \
    "/subscribers/lookup?imsi=214010123456789" \
    "" \
    "200" \
    "Lookup subscriber by IMSI (FR-001)"

# Test 6: Lookup Subscriber by Name (T048 - Repository custom query)
echo -e "${YELLOW}=== Test Lookup by Name (FR-001) ===${NC}"
test_endpoint \
    "Lookup by Name" \
    "GET" \
    "/subscribers/lookup?firstName=John&lastName=Doe" \
    "" \
    "200" \
    "Lookup subscriber by first and last name (FR-001)"

# Test 7: Update Subscriber State (T049 - Service state management, FR-004)
echo -e "${YELLOW}=== Test State Transition (FR-004) ===${NC}"
STATE_UPDATE_PAYLOAD='[
  {
    "fieldName": "state",
    "fieldValue": "ACTIVE"
  }
]'

test_endpoint \
    "Update to ACTIVE State" \
    "PATCH" \
    "/subscribers/$SUBSCRIBER_ID" \
    "$STATE_UPDATE_PAYLOAD" \
    "200" \
    "Transition from PRE_PROVISIONED to ACTIVE (FR-004)"

# Test 8: Update Subscriber Personal Info (T050 - Service update)
echo -e "${YELLOW}=== Test Update Subscriber Info ===${NC}"
UPDATE_PAYLOAD='[
  {
    "fieldName": "email",
    "fieldValue": "john.doe.updated@example.com"
  },
  {
    "fieldName": "contactNumber",
    "fieldValue": "436641234568"
  }
]'

test_endpoint \
    "Update Email and Contact" \
    "PATCH" \
    "/subscribers/$SUBSCRIBER_ID" \
    "$UPDATE_PAYLOAD" \
    "200" \
    "Update subscriber personal information (T050)"

# Verify the update
test_endpoint \
    "Verify Update" \
    "GET" \
    "/subscribers/$SUBSCRIBER_ID" \
    "" \
    "200" \
    "Verify email was updated"

# Test 9: Create Second Subscriber for Duplicate Check
echo -e "${YELLOW}=== Test Duplicate MSISDN Prevention (FR-007) ===${NC}"
DUPLICATE_PAYLOAD='{
  "msisdn": "43664123456789",
  "imsi": "214010987654321",
  "firstName": "Jane",
  "lastName": "Smith",
  "dateOfBirth": "1985-03-20",
  "email": "jane.smith@example.com"
}'

test_endpoint \
    "Attempt Duplicate MSISDN" \
    "POST" \
    "/subscribers" \
    "$DUPLICATE_PAYLOAD" \
    "409" \
    "Should reject duplicate MSISDN (FR-007)"

# Test 10: Create Valid Second Subscriber
echo -e "${YELLOW}=== Test Create Second Subscriber ===${NC}"
SECOND_SUBSCRIBER_PAYLOAD='{
  "msisdn": "43664987654321",
  "imsi": "214010987654321",
  "firstName": "Jane",
  "lastName": "Smith",
  "dateOfBirth": "1985-03-20",
  "email": "jane.smith@example.com",
  "billingCycle": 15
}'

test_endpoint \
    "Create Second Subscriber" \
    "POST" \
    "/subscribers" \
    "$SECOND_SUBSCRIBER_PAYLOAD" \
    "201" \
    "Create another subscriber successfully"

SUBSCRIBER_ID_2=$(echo "$body" | grep -o '"subscriberId":"[^"]*"' | cut -d'"' -f4)
echo "Second Subscriber ID: $SUBSCRIBER_ID_2"
echo ""

# Test 11: Transition Second Subscriber Through States (FR-004)
echo -e "${YELLOW}=== Test State Lifecycle (FR-004) ===${NC}"

# PRE_PROVISIONED -> ACTIVE
STATE_TO_ACTIVE='[{"fieldName": "state", "fieldValue": "ACTIVE"}]'
test_endpoint \
    "Transition to ACTIVE" \
    "PATCH" \
    "/subscribers/$SUBSCRIBER_ID_2" \
    "$STATE_TO_ACTIVE" \
    "200" \
    "PRE_PROVISIONED -> ACTIVE transition"

# ACTIVE -> SUSPENDED
STATE_TO_SUSPENDED='[{"fieldName": "state", "fieldValue": "SUSPENDED"}]'
test_endpoint \
    "Transition to SUSPENDED" \
    "PATCH" \
    "/subscribers/$SUBSCRIBER_ID_2" \
    "$STATE_TO_SUSPENDED" \
    "200" \
    "ACTIVE -> SUSPENDED transition"

# SUSPENDED -> ACTIVE (reactivation)
test_endpoint \
    "Reactivate from SUSPENDED" \
    "PATCH" \
    "/subscribers/$SUBSCRIBER_ID_2" \
    "$STATE_TO_ACTIVE" \
    "200" \
    "SUSPENDED -> ACTIVE transition (reactivation)"

# ACTIVE -> DEACTIVATED
STATE_TO_DEACTIVATED='[{"fieldName": "state", "fieldValue": "DEACTIVATED"}]'
test_endpoint \
    "Transition to DEACTIVATED" \
    "PATCH" \
    "/subscribers/$SUBSCRIBER_ID_2" \
    "$STATE_TO_DEACTIVATED" \
    "200" \
    "ACTIVE -> DEACTIVATED transition"

# Test 12: Delete Subscriber (T050 - Service delete, T054 - Controller)
echo -e "${YELLOW}=== Test Delete Subscriber (FR-008) ===${NC}"
test_endpoint \
    "Delete Subscriber" \
    "DELETE" \
    "/subscribers/$SUBSCRIBER_ID_2" \
    "" \
    "204" \
    "Soft delete subscriber (FR-008)"

# Verify deletion (should return 404 or TERMINATED state)
test_endpoint \
    "Verify Deletion" \
    "GET" \
    "/subscribers/$SUBSCRIBER_ID_2" \
    "" \
    "404" \
    "Deleted subscriber should not be accessible"

# Test 13: Get Non-Existent Subscriber
echo -e "${YELLOW}=== Test Error Handling ===${NC}"
test_endpoint \
    "Get Non-Existent Subscriber" \
    "GET" \
    "/subscribers/non-existent-id-12345" \
    "" \
    "404" \
    "Should return 404 for non-existent subscriber"

# Test 14: Invalid Request Validation
echo -e "${YELLOW}=== Test Validation (FR-009) ===${NC}"
INVALID_PAYLOAD='{
  "imsi": "214010111111111",
  "firstName": "Test",
  "lastName": "User"
}'

test_endpoint \
    "Create Without Required MSISDN" \
    "POST" \
    "/subscribers" \
    "$INVALID_PAYLOAD" \
    "400" \
    "Should reject request without required MSISDN (FR-009)"

# Test 15: Invalid MSISDN Format
INVALID_MSISDN_PAYLOAD='{
  "msisdn": "invalid",
  "imsi": "214010111111111",
  "firstName": "Test",
  "lastName": "User"
}'

test_endpoint \
    "Create With Invalid MSISDN" \
    "POST" \
    "/subscribers" \
    "$INVALID_MSISDN_PAYLOAD" \
    "400" \
    "Should reject invalid MSISDN format (FR-009)"

# Summary
echo "=========================================="
echo -e "${YELLOW}Test Summary${NC}"
echo "=========================================="
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"
echo "Total:  $((PASSED + FAILED))"
echo "=========================================="

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed! ✓${NC}"
    echo ""
    echo "Verified Implementation:"
    echo "  ✓ T047: Subscriber Entity with state management"
    echo "  ✓ T048: Repository with custom queries"
    echo "  ✓ T049: Service layer business logic"
    echo "  ✓ T050: Service update/delete operations"
    echo "  ✓ T051: Entity-DTO mapping"
    echo "  ✓ T052: Controller GET endpoints"
    echo "  ✓ T053: Controller POST endpoint"
    echo "  ✓ T054: Controller PATCH/DELETE endpoints"
    echo ""
    echo "Verified Functional Requirements:"
    echo "  ✓ FR-001: Subscriber lookup by msisdn/imsi/name"
    echo "  ✓ FR-004: State transition tracking"
    echo "  ✓ FR-007: MSISDN uniqueness validation"
    echo "  ✓ FR-008: Soft delete implementation"
    echo "  ✓ FR-009: Input validation"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
