#!/bin/bash

# Account History API Integration Tests
# Tests all CRUD operations for Account History endpoints

set -e

BASE_URL="http://localhost:8080/ocs/prov/v1"
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

echo -e "${YELLOW}Starting Account History API Integration Tests${NC}\n"

# ==============================================
# Test 1: Create Account History Entry - Success
# ==============================================
print_section "Test 1: Create Account History Entry - Success"

INTERACTION_ID=$(generate_uuid)
ENTITY_ID=$(generate_uuid)

PAYLOAD=$(cat <<EOF
{
  "interactionId": "$INTERACTION_ID",
  "entityId": "$ENTITY_ID",
  "entityType": "SUBSCRIBER",
  "status": "COMPLETED",
  "description": "Test account history entry",
  "interactionDate": {
    "startDateTime": "2024-01-01T10:00:00Z",
    "endDateTime": "2024-01-01T11:00:00Z"
  }
}
EOF
)

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/accountHistory" \
  -H "$CONTENT_TYPE" \
  -d "$PAYLOAD")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 201 ]; then
    CREATED_INTERACTION_ID=$(echo "$BODY" | jq -r '.interactionId')
    if [ "$CREATED_INTERACTION_ID" == "$INTERACTION_ID" ]; then
        print_test_result "Create account history entry" 0
    else
        echo "Expected interactionId: $INTERACTION_ID, got: $CREATED_INTERACTION_ID"
        print_test_result "Create account history entry" 1
    fi
else
    echo "Expected HTTP 201, got: $HTTP_CODE"
    echo "Response: $BODY"
    print_test_result "Create account history entry" 1
fi

# ==============================================
# Test 2: Get Account History by InteractionId
# ==============================================
print_section "Test 2: Get Account History by InteractionId"

RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$BASE_URL/accountHistory/$INTERACTION_ID")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 200 ]; then
    RETRIEVED_ID=$(echo "$BODY" | jq -r '.interactionId')
    RETRIEVED_ENTITY_ID=$(echo "$BODY" | jq -r '.entityId')
    RETRIEVED_TYPE=$(echo "$BODY" | jq -r '.entityType')
    
    if [ "$RETRIEVED_ID" == "$INTERACTION_ID" ] && \
       [ "$RETRIEVED_ENTITY_ID" == "$ENTITY_ID" ] && \
       [ "$RETRIEVED_TYPE" == "SUBSCRIBER" ]; then
        print_test_result "Get account history by interactionId" 0
    else
        echo "Data mismatch in retrieved record"
        print_test_result "Get account history by interactionId" 1
    fi
else
    echo "Expected HTTP 200, got: $HTTP_CODE"
    echo "Response: $BODY"
    print_test_result "Get account history by interactionId" 1
fi

# ==============================================
# Test 3: List Account History by EntityId
# ==============================================
print_section "Test 3: List Account History by EntityId"

RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$BASE_URL/accountHistory/entityId/$ENTITY_ID")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 200 ]; then
    ENTRY_COUNT=$(echo "$BODY" | jq '. | length')
    
    if [ "$ENTRY_COUNT" -ge 1 ]; then
        FIRST_ENTRY_ID=$(echo "$BODY" | jq -r '.[0].interactionId')
        if [ "$FIRST_ENTRY_ID" == "$INTERACTION_ID" ]; then
            print_test_result "List account history by entityId" 0
        else
            echo "Expected to find interactionId: $INTERACTION_ID"
            print_test_result "List account history by entityId" 1
        fi
    else
        echo "Expected at least 1 entry, got: $ENTRY_COUNT"
        print_test_result "List account history by entityId" 1
    fi
else
    echo "Expected HTTP 200, got: $HTTP_CODE"
    echo "Response: $BODY"
    print_test_result "List account history by entityId" 1
fi

# ==============================================
# Test 4: Update Account History Entry
# ==============================================
print_section "Test 4: Update Account History Entry"

UPDATE_PAYLOAD=$(cat <<EOF
{
  "status": "UPDATED_STATUS",
  "description": "Updated description"
}
EOF
)

RESPONSE=$(curl -s -w "\n%{http_code}" -X PATCH "$BASE_URL/accountHistory/$INTERACTION_ID" \
  -H "$CONTENT_TYPE" \
  -d "$UPDATE_PAYLOAD")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 200 ]; then
    UPDATED_STATUS=$(echo "$BODY" | jq -r '.status')
    UPDATED_DESC=$(echo "$BODY" | jq -r '.description')
    
    if [ "$UPDATED_STATUS" == "UPDATED_STATUS" ] && \
       [ "$UPDATED_DESC" == "Updated description" ]; then
        print_test_result "Update account history entry" 0
    else
        echo "Update values not reflected correctly"
        print_test_result "Update account history entry" 1
    fi
else
    echo "Expected HTTP 200, got: $HTTP_CODE"
    echo "Response: $BODY"
    print_test_result "Update account history entry" 1
fi

# ==============================================
# Test 5: Create Multiple Entries for Chronological Ordering Test
# ==============================================
print_section "Test 5: Create Multiple Entries for Chronological Ordering"

ENTITY_ID_2=$(generate_uuid)

# Create first entry with earlier timestamp
INTERACTION_ID_1=$(generate_uuid)
PAYLOAD_1=$(cat <<EOF
{
  "interactionId": "$INTERACTION_ID_1",
  "entityId": "$ENTITY_ID_2",
  "entityType": "GROUP",
  "status": "FIRST",
  "description": "First entry",
  "interactionDate": {
    "startDateTime": "2024-01-01T09:00:00Z"
  }
}
EOF
)

curl -s -X POST "$BASE_URL/accountHistory" \
  -H "$CONTENT_TYPE" \
  -d "$PAYLOAD_1" > /dev/null

# Create second entry with later timestamp
INTERACTION_ID_2=$(generate_uuid)
PAYLOAD_2=$(cat <<EOF
{
  "interactionId": "$INTERACTION_ID_2",
  "entityId": "$ENTITY_ID_2",
  "entityType": "GROUP",
  "status": "SECOND",
  "description": "Second entry",
  "interactionDate": {
    "startDateTime": "2024-01-01T10:00:00Z"
  }
}
EOF
)

curl -s -X POST "$BASE_URL/accountHistory" \
  -H "$CONTENT_TYPE" \
  -d "$PAYLOAD_2" > /dev/null

# Verify chronological ordering (newest first)
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$BASE_URL/accountHistory/entityId/$ENTITY_ID_2")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 200 ]; then
    FIRST_STATUS=$(echo "$BODY" | jq -r '.[0].status')
    SECOND_STATUS=$(echo "$BODY" | jq -r '.[1].status')
    
    if [ "$FIRST_STATUS" == "SECOND" ] && [ "$SECOND_STATUS" == "FIRST" ]; then
        print_test_result "Chronological ordering (newest first)" 0
    else
        echo "Expected order: SECOND, FIRST. Got: $FIRST_STATUS, $SECOND_STATUS"
        print_test_result "Chronological ordering (newest first)" 1
    fi
else
    echo "Expected HTTP 200, got: $HTTP_CODE"
    print_test_result "Chronological ordering (newest first)" 1
fi

# ==============================================
# Test 6: Create Entry with Missing Required Fields
# ==============================================
print_section "Test 6: Create Entry with Missing Required Fields (Negative Test)"

BAD_PAYLOAD=$(cat <<EOF
{
  "status": "TEST"
}
EOF
)

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/accountHistory" \
  -H "$CONTENT_TYPE" \
  -d "$BAD_PAYLOAD")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

if [ "$HTTP_CODE" -eq 400 ]; then
    print_test_result "Reject entry with missing required fields" 0
else
    echo "Expected HTTP 400, got: $HTTP_CODE"
    print_test_result "Reject entry with missing required fields" 1
fi

# ==============================================
# Test 7: Create Duplicate Entry
# ==============================================
print_section "Test 7: Create Duplicate Entry (Negative Test)"

DUPLICATE_PAYLOAD=$(cat <<EOF
{
  "interactionId": "$INTERACTION_ID",
  "entityId": "$(generate_uuid)",
  "entityType": "SUBSCRIBER",
  "status": "DUPLICATE"
}
EOF
)

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/accountHistory" \
  -H "$CONTENT_TYPE" \
  -d "$DUPLICATE_PAYLOAD")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

if [ "$HTTP_CODE" -eq 409 ]; then
    print_test_result "Reject duplicate interactionId" 0
else
    echo "Expected HTTP 409, got: $HTTP_CODE"
    print_test_result "Reject duplicate interactionId" 1
fi

# ==============================================
# Test 8: Get Non-Existent Entry
# ==============================================
print_section "Test 8: Get Non-Existent Entry (Negative Test)"

NON_EXISTENT_ID=$(generate_uuid)

RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$BASE_URL/accountHistory/$NON_EXISTENT_ID")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

if [ "$HTTP_CODE" -eq 404 ]; then
    print_test_result "Return 404 for non-existent entry" 0
else
    echo "Expected HTTP 404, got: $HTTP_CODE"
    print_test_result "Return 404 for non-existent entry" 1
fi

# ==============================================
# Test 9: Update Non-Existent Entry
# ==============================================
print_section "Test 9: Update Non-Existent Entry (Negative Test)"

RESPONSE=$(curl -s -w "\n%{http_code}" -X PATCH "$BASE_URL/accountHistory/$NON_EXISTENT_ID" \
  -H "$CONTENT_TYPE" \
  -d '{"status": "TEST"}')

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

if [ "$HTTP_CODE" -eq 404 ]; then
    print_test_result "Return 404 when updating non-existent entry" 0
else
    echo "Expected HTTP 404, got: $HTTP_CODE"
    print_test_result "Return 404 when updating non-existent entry" 1
fi

# ==============================================
# Test 10: Delete Account History Entry
# ==============================================
print_section "Test 10: Delete Account History Entry"

RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE "$BASE_URL/accountHistory/$INTERACTION_ID")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

if [ "$HTTP_CODE" -eq 204 ]; then
    # Verify deletion by trying to get the entry
    VERIFY_RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$BASE_URL/accountHistory/$INTERACTION_ID")
    VERIFY_CODE=$(echo "$VERIFY_RESPONSE" | tail -n1)
    
    if [ "$VERIFY_CODE" -eq 404 ]; then
        print_test_result "Delete account history entry" 0
    else
        echo "Entry still exists after deletion"
        print_test_result "Delete account history entry" 1
    fi
else
    echo "Expected HTTP 204, got: $HTTP_CODE"
    print_test_result "Delete account history entry" 1
fi

# ==============================================
# Test 11: Delete Non-Existent Entry
# ==============================================
print_section "Test 11: Delete Non-Existent Entry (Negative Test)"

RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE "$BASE_URL/accountHistory/$NON_EXISTENT_ID")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

if [ "$HTTP_CODE" -eq 404 ]; then
    print_test_result "Return 404 when deleting non-existent entry" 0
else
    echo "Expected HTTP 404, got: $HTTP_CODE"
    print_test_result "Return 404 when deleting non-existent entry" 1
fi

# ==============================================
# Test 12: Create Entry with Auto-Generated InteractionId
# ==============================================
print_section "Test 12: Create Entry with Auto-Generated InteractionId"

AUTO_ENTITY_ID=$(generate_uuid)
AUTO_PAYLOAD=$(cat <<EOF
{
  "entityId": "$AUTO_ENTITY_ID",
  "entityType": "ACCOUNT",
  "status": "AUTO_GENERATED"
}
EOF
)

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/accountHistory" \
  -H "$CONTENT_TYPE" \
  -d "$AUTO_PAYLOAD")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 201 ]; then
    AUTO_INTERACTION_ID=$(echo "$BODY" | jq -r '.interactionId')
    
    if [ -n "$AUTO_INTERACTION_ID" ] && [ "$AUTO_INTERACTION_ID" != "null" ]; then
        print_test_result "Auto-generate interactionId when not provided" 0
        
        # Clean up
        curl -s -X DELETE "$BASE_URL/accountHistory/$AUTO_INTERACTION_ID" > /dev/null
    else
        echo "InteractionId was not auto-generated"
        print_test_result "Auto-generate interactionId when not provided" 1
    fi
else
    echo "Expected HTTP 201, got: $HTTP_CODE"
    echo "Response: $BODY"
    print_test_result "Auto-generate interactionId when not provided" 1
fi

# ==============================================
# Test Summary
# ==============================================
print_section "Test Summary"

echo "Total Tests Run: $TESTS_RUN"
echo -e "${GREEN}Tests Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Tests Failed: $TESTS_FAILED${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}✓ All tests passed!${NC}\n"
    exit 0
else
    echo -e "\n${RED}✗ Some tests failed!${NC}\n"
    exit 1
fi
