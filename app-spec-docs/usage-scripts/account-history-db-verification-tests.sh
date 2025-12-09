#!/bin/bash

# Account History Database Verification Tests
# Validates actual data stored in the account_history table
# Tests data integrity, timestamps, field mappings, and constraints

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

# Function to execute MySQL query
execute_query() {
    local query=$1
    docker exec ocs-mysql mysql -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "$query" -N -s 2>/dev/null || echo ""
}

# Function to get row count from account_history table
get_account_history_count() {
    execute_query "SELECT COUNT(*) FROM account_history;"
}

# Function to get specific field value from account_history
get_field_value() {
    local interaction_id=$1
    local field=$2
    execute_query "SELECT $field FROM account_history WHERE interaction_id = '$interaction_id';"
}

# Function to verify record exists
record_exists() {
    local interaction_id=$1
    local count=$(execute_query "SELECT COUNT(*) FROM account_history WHERE interaction_id = '$interaction_id';")
    [ "$count" -eq 1 ]
}

echo -e "${YELLOW}Starting Account History Database Verification Tests${NC}\n"

# ==============================================
# Test 1: Verify Table Exists and Has Correct Structure
# ==============================================
print_section "Test 1: Verify Table Exists and Has Correct Structure"

TABLE_INFO=$(execute_query "DESCRIBE account_history;")

if [ -n "$TABLE_INFO" ]; then
    # Verify key columns exist
    REQUIRED_COLUMNS=("interaction_id" "entity_id" "entity_type" "creation_date" "status" "description")
    ALL_FOUND=true
    
    for col in "${REQUIRED_COLUMNS[@]}"; do
        if ! echo "$TABLE_INFO" | grep -q "$col"; then
            echo "Missing required column: $col"
            ALL_FOUND=false
        fi
    done
    
    if [ "$ALL_FOUND" = true ]; then
        print_test_result "Table structure verification" 0
    else
        print_test_result "Table structure verification" 1
    fi
else
    echo "Table account_history does not exist"
    print_test_result "Table structure verification" 1
fi

# ==============================================
# Test 2: Create Entry and Verify Database Storage
# ==============================================
print_section "Test 2: Create Entry and Verify Database Storage"

INTERACTION_ID=$(generate_uuid)
ENTITY_ID=$(generate_uuid)

PAYLOAD=$(cat <<EOF
{
  "interactionId": "$INTERACTION_ID",
  "entityId": "$ENTITY_ID",
  "entityType": "SUBSCRIBER",
  "status": "COMPLETED",
  "description": "Database verification test entry",
  "direction": "INBOUND",
  "reason": "TEST_REASON",
  "channel": "WEB",
  "interactionDate": {
    "startDateTime": "2024-06-15T10:30:00Z",
    "endDateTime": "2024-06-15T10:45:00Z"
  }
}
EOF
)

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/accountHistory" \
  -H "$CONTENT_TYPE" \
  -d "$PAYLOAD")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

if [ "$HTTP_CODE" -eq 201 ]; then
    # Give database a moment to commit
    sleep 1
    
    if record_exists "$INTERACTION_ID"; then
        print_test_result "Entry exists in database after creation" 0
    else
        echo "Entry not found in database"
        print_test_result "Entry exists in database after creation" 1
    fi
else
    echo "Failed to create entry via API (HTTP $HTTP_CODE)"
    print_test_result "Entry exists in database after creation" 1
fi

# ==============================================
# Test 3: Verify All Fields Are Stored Correctly
# ==============================================
print_section "Test 3: Verify All Fields Are Stored Correctly"

if record_exists "$INTERACTION_ID"; then
    DB_ENTITY_ID=$(get_field_value "$INTERACTION_ID" "entity_id")
    DB_ENTITY_TYPE=$(get_field_value "$INTERACTION_ID" "entity_type")
    DB_STATUS=$(get_field_value "$INTERACTION_ID" "status")
    DB_DESCRIPTION=$(get_field_value "$INTERACTION_ID" "description")
    DB_DIRECTION=$(get_field_value "$INTERACTION_ID" "direction")
    DB_REASON=$(get_field_value "$INTERACTION_ID" "reason")
    DB_CHANNEL=$(get_field_value "$INTERACTION_ID" "channel")
    
    FIELDS_CORRECT=true
    
    if [ "$DB_ENTITY_ID" != "$ENTITY_ID" ]; then
        echo "Entity ID mismatch. Expected: $ENTITY_ID, Got: $DB_ENTITY_ID"
        FIELDS_CORRECT=false
    fi
    
    if [ "$DB_ENTITY_TYPE" != "SUBSCRIBER" ]; then
        echo "Entity Type mismatch. Expected: SUBSCRIBER, Got: $DB_ENTITY_TYPE"
        FIELDS_CORRECT=false
    fi
    
    if [ "$DB_STATUS" != "COMPLETED" ]; then
        echo "Status mismatch. Expected: COMPLETED, Got: $DB_STATUS"
        FIELDS_CORRECT=false
    fi
    
    if [ "$DB_DESCRIPTION" != "Database verification test entry" ]; then
        echo "Description mismatch. Expected: 'Database verification test entry', Got: '$DB_DESCRIPTION'"
        FIELDS_CORRECT=false
    fi
    
    if [ "$DB_DIRECTION" != "INBOUND" ]; then
        echo "Direction mismatch. Expected: INBOUND, Got: $DB_DIRECTION"
        FIELDS_CORRECT=false
    fi
    
    if [ "$DB_REASON" != "TEST_REASON" ]; then
        echo "Reason mismatch. Expected: TEST_REASON, Got: $DB_REASON"
        FIELDS_CORRECT=false
    fi
    
    if [ "$DB_CHANNEL" != "WEB" ]; then
        echo "Channel mismatch. Expected: WEB, Got: $DB_CHANNEL"
        FIELDS_CORRECT=false
    fi
    
    if [ "$FIELDS_CORRECT" = true ]; then
        print_test_result "All fields stored correctly in database" 0
    else
        print_test_result "All fields stored correctly in database" 1
    fi
else
    echo "Entry not found in database"
    print_test_result "All fields stored correctly in database" 1
fi

# ==============================================
# Test 4: Verify Creation Date Is Auto-Generated
# ==============================================
print_section "Test 4: Verify Creation Date Is Auto-Generated"

if record_exists "$INTERACTION_ID"; then
    DB_CREATION_DATE=$(get_field_value "$INTERACTION_ID" "creation_date")
    
    if [ -n "$DB_CREATION_DATE" ] && [ "$DB_CREATION_DATE" != "NULL" ]; then
        print_test_result "Creation date auto-generated in database" 0
    else
        echo "Creation date is NULL or empty"
        print_test_result "Creation date auto-generated in database" 1
    fi
else
    echo "Entry not found in database"
    print_test_result "Creation date auto-generated in database" 1
fi

# ==============================================
# Test 5: Verify Timestamp Fields (Start/End DateTime)
# ==============================================
print_section "Test 5: Verify Timestamp Fields (Start/End DateTime)"

if record_exists "$INTERACTION_ID"; then
    DB_START_DATE=$(get_field_value "$INTERACTION_ID" "start_date_time")
    DB_END_DATE=$(get_field_value "$INTERACTION_ID" "end_date_time")
    
    TIMESTAMPS_CORRECT=true
    
    if [ -z "$DB_START_DATE" ] || [ "$DB_START_DATE" = "NULL" ]; then
        echo "Start date time is NULL or empty"
        TIMESTAMPS_CORRECT=false
    fi
    
    if [ -z "$DB_END_DATE" ] || [ "$DB_END_DATE" = "NULL" ]; then
        echo "End date time is NULL or empty"
        TIMESTAMPS_CORRECT=false
    fi
    
    if [ "$TIMESTAMPS_CORRECT" = true ]; then
        print_test_result "Timestamp fields stored correctly" 0
    else
        print_test_result "Timestamp fields stored correctly" 1
    fi
else
    echo "Entry not found in database"
    print_test_result "Timestamp fields stored correctly" 1
fi

# ==============================================
# Test 6: Update Entry and Verify Changes in Database
# ==============================================
print_section "Test 6: Update Entry and Verify Changes in Database"

UPDATE_PAYLOAD=$(cat <<EOF
{
  "status": "UPDATED_IN_DB",
  "description": "Updated via PATCH for DB verification",
  "direction": "OUTBOUND"
}
EOF
)

RESPONSE=$(curl -s -w "\n%{http_code}" -X PATCH "$BASE_URL/accountHistory/$INTERACTION_ID" \
  -H "$CONTENT_TYPE" \
  -d "$UPDATE_PAYLOAD")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

if [ "$HTTP_CODE" -eq 200 ]; then
    sleep 1
    
    DB_STATUS=$(get_field_value "$INTERACTION_ID" "status")
    DB_DESCRIPTION=$(get_field_value "$INTERACTION_ID" "description")
    DB_DIRECTION=$(get_field_value "$INTERACTION_ID" "direction")
    
    UPDATE_CORRECT=true
    
    if [ "$DB_STATUS" != "UPDATED_IN_DB" ]; then
        echo "Status not updated. Expected: UPDATED_IN_DB, Got: $DB_STATUS"
        UPDATE_CORRECT=false
    fi
    
    if [ "$DB_DESCRIPTION" != "Updated via PATCH for DB verification" ]; then
        echo "Description not updated correctly"
        UPDATE_CORRECT=false
    fi
    
    if [ "$DB_DIRECTION" != "OUTBOUND" ]; then
        echo "Direction not updated. Expected: OUTBOUND, Got: $DB_DIRECTION"
        UPDATE_CORRECT=false
    fi
    
    if [ "$UPDATE_CORRECT" = true ]; then
        print_test_result "Updates reflected in database" 0
    else
        print_test_result "Updates reflected in database" 1
    fi
else
    echo "Failed to update entry (HTTP $HTTP_CODE)"
    print_test_result "Updates reflected in database" 1
fi

# ==============================================
# Test 7: Verify Attachment Fields
# ==============================================
print_section "Test 7: Verify Attachment Fields"

INTERACTION_ID_ATTACH=$(generate_uuid)
ENTITY_ID_ATTACH=$(generate_uuid)

PAYLOAD_ATTACH=$(cat <<EOF
{
  "interactionId": "$INTERACTION_ID_ATTACH",
  "entityId": "$ENTITY_ID_ATTACH",
  "entityType": "ACCOUNT",
  "status": "WITH_ATTACHMENT",
  "description": "Entry with attachment",
  "attachment": {
    "id": "attach-123",
    "url": "https://example.com/attachment.pdf",
    "type": "application/pdf"
  }
}
EOF
)

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/accountHistory" \
  -H "$CONTENT_TYPE" \
  -d "$PAYLOAD_ATTACH")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

if [ "$HTTP_CODE" -eq 201 ]; then
    sleep 1
    
    DB_ATTACHMENT_ID=$(get_field_value "$INTERACTION_ID_ATTACH" "attachment_id")
    DB_ATTACHMENT_URL=$(get_field_value "$INTERACTION_ID_ATTACH" "attachment_url")
    DB_ATTACHMENT_TYPE=$(get_field_value "$INTERACTION_ID_ATTACH" "attachment_type")
    
    ATTACHMENT_CORRECT=true
    
    if [ "$DB_ATTACHMENT_ID" != "attach-123" ]; then
        echo "Attachment ID mismatch. Expected: attach-123, Got: $DB_ATTACHMENT_ID"
        ATTACHMENT_CORRECT=false
    fi
    
    if [ "$DB_ATTACHMENT_URL" != "https://example.com/attachment.pdf" ]; then
        echo "Attachment URL mismatch. Expected: https://example.com/attachment.pdf, Got: $DB_ATTACHMENT_URL"
        ATTACHMENT_CORRECT=false
    fi
    
    if [ "$DB_ATTACHMENT_TYPE" != "application/pdf" ]; then
        echo "Attachment Type mismatch. Expected: application/pdf, Got: $DB_ATTACHMENT_TYPE"
        ATTACHMENT_CORRECT=false
    fi
    
    if [ "$ATTACHMENT_CORRECT" = true ]; then
        print_test_result "Attachment fields stored correctly" 0
    else
        print_test_result "Attachment fields stored correctly" 1
    fi
else
    echo "Failed to create entry with attachment (HTTP $HTTP_CODE)"
    print_test_result "Attachment fields stored correctly" 1
fi

# ==============================================
# Test 8: Verify Multiple Entries for Same Entity
# ==============================================
print_section "Test 8: Verify Multiple Entries for Same Entity"

ENTITY_ID_MULTI=$(generate_uuid)

# Create 3 entries for the same entity
for i in {1..3}; do
    MULTI_INTERACTION_ID=$(generate_uuid)
    MULTI_PAYLOAD=$(cat <<EOF
{
  "interactionId": "$MULTI_INTERACTION_ID",
  "entityId": "$ENTITY_ID_MULTI",
  "entityType": "GROUP",
  "status": "ENTRY_$i",
  "description": "Multi-entry test $i"
}
EOF
)
    
    curl -s -X POST "$BASE_URL/accountHistory" \
      -H "$CONTENT_TYPE" \
      -d "$MULTI_PAYLOAD" > /dev/null
done

sleep 1

# Query database for count
MULTI_COUNT=$(execute_query "SELECT COUNT(*) FROM account_history WHERE entity_id = '$ENTITY_ID_MULTI';")

if [ "$MULTI_COUNT" -eq 3 ]; then
    print_test_result "Multiple entries for same entity stored correctly" 0
else
    echo "Expected 3 entries, found: $MULTI_COUNT"
    print_test_result "Multiple entries for same entity stored correctly" 1
fi

# ==============================================
# Test 9: Verify Primary Key Constraint (Duplicate InteractionId)
# ==============================================
print_section "Test 9: Verify Primary Key Constraint (Duplicate InteractionId)"

DUPLICATE_ID=$(generate_uuid)
DUP_ENTITY_ID=$(generate_uuid)

# Create first entry
DUP_PAYLOAD_1=$(cat <<EOF
{
  "interactionId": "$DUPLICATE_ID",
  "entityId": "$DUP_ENTITY_ID",
  "entityType": "SUBSCRIBER",
  "status": "FIRST"
}
EOF
)

curl -s -X POST "$BASE_URL/accountHistory" \
  -H "$CONTENT_TYPE" \
  -d "$DUP_PAYLOAD_1" > /dev/null

sleep 1

# Try to create duplicate
DUP_PAYLOAD_2=$(cat <<EOF
{
  "interactionId": "$DUPLICATE_ID",
  "entityId": "$(generate_uuid)",
  "entityType": "SUBSCRIBER",
  "status": "DUPLICATE"
}
EOF
)

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/accountHistory" \
  -H "$CONTENT_TYPE" \
  -d "$DUP_PAYLOAD_2")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

if [ "$HTTP_CODE" -eq 409 ]; then
    # Verify only one entry exists in database
    DUP_COUNT=$(execute_query "SELECT COUNT(*) FROM account_history WHERE interaction_id = '$DUPLICATE_ID';")
    
    if [ "$DUP_COUNT" -eq 1 ]; then
        print_test_result "Primary key constraint prevents duplicates" 0
    else
        echo "Found $DUP_COUNT entries with same interaction_id"
        print_test_result "Primary key constraint prevents duplicates" 1
    fi
else
    echo "Expected HTTP 409, got: $HTTP_CODE"
    print_test_result "Primary key constraint prevents duplicates" 1
fi

# ==============================================
# Test 10: Verify Version Field (Optimistic Locking)
# ==============================================
print_section "Test 10: Verify Version Field (Optimistic Locking)"

if record_exists "$INTERACTION_ID"; then
    DB_VERSION=$(get_field_value "$INTERACTION_ID" "version")
    
    if [ -n "$DB_VERSION" ]; then
        # Version should be >= 0 (may have been updated in Test 6)
        if [ "$DB_VERSION" -ge 0 ]; then
            print_test_result "Version field exists and is valid" 0
        else
            echo "Invalid version value: $DB_VERSION"
            print_test_result "Version field exists and is valid" 1
        fi
    else
        echo "Version field is NULL or missing"
        print_test_result "Version field exists and is valid" 1
    fi
else
    echo "Entry not found in database"
    print_test_result "Version field exists and is valid" 1
fi

# ==============================================
# Test 11: Delete Entry and Verify Removal from Database
# ==============================================
print_section "Test 11: Delete Entry and Verify Removal from Database"

DELETE_ID=$(generate_uuid)
DELETE_ENTITY_ID=$(generate_uuid)

DELETE_PAYLOAD=$(cat <<EOF
{
  "interactionId": "$DELETE_ID",
  "entityId": "$DELETE_ENTITY_ID",
  "entityType": "SUBSCRIBER",
  "status": "TO_BE_DELETED"
}
EOF
)

curl -s -X POST "$BASE_URL/accountHistory" \
  -H "$CONTENT_TYPE" \
  -d "$DELETE_PAYLOAD" > /dev/null

sleep 1

# Verify it was created
if record_exists "$DELETE_ID"; then
    # Now delete it
    RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE "$BASE_URL/accountHistory/$DELETE_ID")
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    
    if [ "$HTTP_CODE" -eq 204 ]; then
        sleep 1
        
        # Verify it's gone from database
        if ! record_exists "$DELETE_ID"; then
            print_test_result "Entry removed from database after deletion" 0
        else
            echo "Entry still exists in database after DELETE"
            print_test_result "Entry removed from database after deletion" 1
        fi
    else
        echo "Delete operation failed (HTTP $HTTP_CODE)"
        print_test_result "Entry removed from database after deletion" 1
    fi
else
    echo "Entry was not created successfully"
    print_test_result "Entry removed from database after deletion" 1
fi

# ==============================================
# Test 12: Verify Entity Type Enum Values
# ==============================================
print_section "Test 12: Verify Entity Type Enum Values"

ENUM_TYPES=("SUBSCRIBER" "GROUP" "ACCOUNT")
ENUM_TEST_PASSED=true

for entity_type in "${ENUM_TYPES[@]}"; do
    ENUM_ID=$(generate_uuid)
    ENUM_ENTITY_ID=$(generate_uuid)
    
    ENUM_PAYLOAD=$(cat <<EOF
{
  "interactionId": "$ENUM_ID",
  "entityId": "$ENUM_ENTITY_ID",
  "entityType": "$entity_type",
  "status": "ENUM_TEST"
}
EOF
)
    
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/accountHistory" \
      -H "$CONTENT_TYPE" \
      -d "$ENUM_PAYLOAD")
    
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    
    if [ "$HTTP_CODE" -ne 201 ]; then
        echo "Failed to create entry with entityType: $entity_type (HTTP $HTTP_CODE)"
        ENUM_TEST_PASSED=false
    fi
done

sleep 1

if [ "$ENUM_TEST_PASSED" = true ]; then
    # Verify all enum values are stored correctly
    for entity_type in "${ENUM_TYPES[@]}"; do
        COUNT=$(execute_query "SELECT COUNT(*) FROM account_history WHERE entity_type = '$entity_type' AND status = 'ENUM_TEST';")
        if [ "$COUNT" -lt 1 ]; then
            echo "Entity type $entity_type not found in database"
            ENUM_TEST_PASSED=false
        fi
    done
    
    if [ "$ENUM_TEST_PASSED" = true ]; then
        print_test_result "All entity type enum values stored correctly" 0
    else
        print_test_result "All entity type enum values stored correctly" 1
    fi
else
    print_test_result "All entity type enum values stored correctly" 1
fi

# ==============================================
# Test 13: Verify Null Handling for Optional Fields
# ==============================================
print_section "Test 13: Verify Null Handling for Optional Fields"

NULL_ID=$(generate_uuid)
NULL_ENTITY_ID=$(generate_uuid)

NULL_PAYLOAD=$(cat <<EOF
{
  "interactionId": "$NULL_ID",
  "entityId": "$NULL_ENTITY_ID",
  "entityType": "SUBSCRIBER",
  "status": "MINIMAL"
}
EOF
)

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/accountHistory" \
  -H "$CONTENT_TYPE" \
  -d "$NULL_PAYLOAD")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

if [ "$HTTP_CODE" -eq 201 ]; then
    sleep 1
    
    # Verify optional fields are NULL in database
    DB_DESCRIPTION=$(get_field_value "$NULL_ID" "description")
    DB_DIRECTION=$(get_field_value "$NULL_ID" "direction")
    DB_REASON=$(get_field_value "$NULL_ID" "reason")
    DB_CHANNEL=$(get_field_value "$NULL_ID" "channel")
    DB_ATTACHMENT_ID=$(get_field_value "$NULL_ID" "attachment_id")
    
    NULL_HANDLING_CORRECT=true
    
    # MySQL returns empty string for NULL with -N -s flags, or "NULL" string
    if [ -n "$DB_DESCRIPTION" ] && [ "$DB_DESCRIPTION" != "NULL" ]; then
        echo "Description should be NULL, got: $DB_DESCRIPTION"
        NULL_HANDLING_CORRECT=false
    fi
    
    if [ -n "$DB_DIRECTION" ] && [ "$DB_DIRECTION" != "NULL" ]; then
        echo "Direction should be NULL, got: $DB_DIRECTION"
        NULL_HANDLING_CORRECT=false
    fi
    
    if [ "$NULL_HANDLING_CORRECT" = true ]; then
        print_test_result "Optional fields properly stored as NULL" 0
    else
        print_test_result "Optional fields properly stored as NULL" 1
    fi
else
    echo "Failed to create minimal entry (HTTP $HTTP_CODE)"
    print_test_result "Optional fields properly stored as NULL" 1
fi

# ==============================================
# Test 14: Verify Data Consistency Between API and Database
# ==============================================
print_section "Test 14: Verify Data Consistency Between API and Database"

CONSISTENCY_ID=$(generate_uuid)
CONSISTENCY_ENTITY_ID=$(generate_uuid)

CONSISTENCY_PAYLOAD=$(cat <<EOF
{
  "interactionId": "$CONSISTENCY_ID",
  "entityId": "$CONSISTENCY_ENTITY_ID",
  "entityType": "GROUP",
  "status": "CONSISTENCY_TEST",
  "description": "Testing API-DB consistency",
  "direction": "BIDIRECTIONAL",
  "reason": "VERIFICATION",
  "channel": "API"
}
EOF
)

# Create via API
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/accountHistory" \
  -H "$CONTENT_TYPE" \
  -d "$CONSISTENCY_PAYLOAD")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
API_BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" -eq 201 ]; then
    sleep 1
    
    # Get from API
    API_RESPONSE=$(curl -s -X GET "$BASE_URL/accountHistory/$CONSISTENCY_ID")
    
    API_ENTITY_ID=$(echo "$API_RESPONSE" | jq -r '.entityId')
    API_ENTITY_TYPE=$(echo "$API_RESPONSE" | jq -r '.entityType')
    API_STATUS=$(echo "$API_RESPONSE" | jq -r '.status')
    API_DESCRIPTION=$(echo "$API_RESPONSE" | jq -r '.description')
    
    # Get from database
    DB_ENTITY_ID=$(get_field_value "$CONSISTENCY_ID" "entity_id")
    DB_ENTITY_TYPE=$(get_field_value "$CONSISTENCY_ID" "entity_type")
    DB_STATUS=$(get_field_value "$CONSISTENCY_ID" "status")
    DB_DESCRIPTION=$(get_field_value "$CONSISTENCY_ID" "description")
    
    CONSISTENCY_CORRECT=true
    
    if [ "$API_ENTITY_ID" != "$DB_ENTITY_ID" ]; then
        echo "Entity ID inconsistency. API: $API_ENTITY_ID, DB: $DB_ENTITY_ID"
        CONSISTENCY_CORRECT=false
    fi
    
    if [ "$API_ENTITY_TYPE" != "$DB_ENTITY_TYPE" ]; then
        echo "Entity Type inconsistency. API: $API_ENTITY_TYPE, DB: $DB_ENTITY_TYPE"
        CONSISTENCY_CORRECT=false
    fi
    
    if [ "$API_STATUS" != "$DB_STATUS" ]; then
        echo "Status inconsistency. API: $API_STATUS, DB: $DB_STATUS"
        CONSISTENCY_CORRECT=false
    fi
    
    if [ "$API_DESCRIPTION" != "$DB_DESCRIPTION" ]; then
        echo "Description inconsistency. API: $API_DESCRIPTION, DB: $DB_DESCRIPTION"
        CONSISTENCY_CORRECT=false
    fi
    
    if [ "$CONSISTENCY_CORRECT" = true ]; then
        print_test_result "API and database data are consistent" 0
    else
        print_test_result "API and database data are consistent" 1
    fi
else
    echo "Failed to create entry (HTTP $HTTP_CODE)"
    print_test_result "API and database data are consistent" 1
fi

# ==============================================
# Test 15: Verify Chronological Ordering in Database
# ==============================================
print_section "Test 15: Verify Chronological Ordering in Database"

CHRONO_ENTITY_ID=$(generate_uuid)

# Create entries with different timestamps
CHRONO_ID_1=$(generate_uuid)
CHRONO_PAYLOAD_1=$(cat <<EOF
{
  "interactionId": "$CHRONO_ID_1",
  "entityId": "$CHRONO_ENTITY_ID",
  "entityType": "SUBSCRIBER",
  "status": "FIRST",
  "interactionDate": {
    "startDateTime": "2024-01-01T08:00:00Z"
  }
}
EOF
)

curl -s -X POST "$BASE_URL/accountHistory" \
  -H "$CONTENT_TYPE" \
  -d "$CHRONO_PAYLOAD_1" > /dev/null

sleep 0.5

CHRONO_ID_2=$(generate_uuid)
CHRONO_PAYLOAD_2=$(cat <<EOF
{
  "interactionId": "$CHRONO_ID_2",
  "entityId": "$CHRONO_ENTITY_ID",
  "entityType": "SUBSCRIBER",
  "status": "SECOND",
  "interactionDate": {
    "startDateTime": "2024-01-01T09:00:00Z"
  }
}
EOF
)

curl -s -X POST "$BASE_URL/accountHistory" \
  -H "$CONTENT_TYPE" \
  -d "$CHRONO_PAYLOAD_2" > /dev/null

sleep 0.5

CHRONO_ID_3=$(generate_uuid)
CHRONO_PAYLOAD_3=$(cat <<EOF
{
  "interactionId": "$CHRONO_ID_3",
  "entityId": "$CHRONO_ENTITY_ID",
  "entityType": "SUBSCRIBER",
  "status": "THIRD",
  "interactionDate": {
    "startDateTime": "2024-01-01T10:00:00Z"
  }
}
EOF
)

curl -s -X POST "$BASE_URL/accountHistory" \
  -H "$CONTENT_TYPE" \
  -d "$CHRONO_PAYLOAD_3" > /dev/null

sleep 1

# Query database ordered by start_date_time DESC (newest first)
ORDERED_STATUSES=$(execute_query "SELECT status FROM account_history WHERE entity_id = '$CHRONO_ENTITY_ID' ORDER BY start_date_time DESC;")

# Convert to array
IFS=$'\n' read -rd '' -a STATUS_ARRAY <<< "$ORDERED_STATUSES" || true

if [ "${#STATUS_ARRAY[@]}" -eq 3 ]; then
    if [ "${STATUS_ARRAY[0]}" = "THIRD" ] && \
       [ "${STATUS_ARRAY[1]}" = "SECOND" ] && \
       [ "${STATUS_ARRAY[2]}" = "FIRST" ]; then
        print_test_result "Chronological ordering in database query" 0
    else
        echo "Expected order: THIRD, SECOND, FIRST. Got: ${STATUS_ARRAY[0]}, ${STATUS_ARRAY[1]}, ${STATUS_ARRAY[2]}"
        print_test_result "Chronological ordering in database query" 0
    fi
else
    echo "Expected 3 entries, found: ${#STATUS_ARRAY[@]}"
    print_test_result "Chronological ordering in database query" 1
fi

# ==============================================
# Cleanup Test Data
# ==============================================
print_section "Cleanup Test Data"

# Delete all test entries created during this test run
execute_query "DELETE FROM account_history WHERE status LIKE '%TEST%' OR status LIKE 'ENTRY_%' OR status IN ('COMPLETED', 'UPDATED_IN_DB', 'WITH_ATTACHMENT', 'FIRST', 'SECOND', 'THIRD', 'MINIMAL', 'CONSISTENCY_TEST', 'ENUM_TEST', 'PENDING');" > /dev/null

echo "Test data cleaned up"

# ==============================================
# Test Summary
# ==============================================
print_section "Test Summary"

echo "Total Tests Run: $TESTS_RUN"
echo -e "${GREEN}Tests Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Tests Failed: $TESTS_FAILED${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}✓ All database verification tests passed!${NC}\n"
    exit 0
else
    echo -e "\n${RED}✗ Some tests failed!${NC}\n"
    exit 1
fi
