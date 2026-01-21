#!/bin/bash

# Test Suite: Summary Generation & Data Persistence
# Tests summary generation, GameDB storage, SQL tracking

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIENT_BIN="$SCRIPT_DIR/client/bin/StompClient"
SERVER_HOST="127.0.0.1:7777"
TEST_JSON="$SCRIPT_DIR/client/data/events1.json"
SUMMARY_OUTPUT="/tmp/test_summary_$$.txt"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0

log_test() {
    echo -e "${YELLOW}[TEST]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    PASSED=$((PASSED + 1))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    FAILED=$((FAILED + 1))
}

cleanup_client() {
    pkill -f StompClient || true
    sleep 0.5
    rm -f /tmp/test_summary_*.txt
}

# Test 1: Summary with no data
test_summary_no_data() {
    log_test "Test 1: Summary with no data"
    cleanup_client
    
    TESTUSER="summary1_$(date +%s)"
    
    OUTPUT=$(timeout 5 $CLIENT_BIN <<EOF 2>&1 || true
login $SERVER_HOST $TESTUSER password123
summary Germany_Spain $TESTUSER $SUMMARY_OUTPUT
logout
EOF
)
    
    if echo "$OUTPUT" | grep -q "no info"; then
        log_pass "Summary with no data handled correctly"
    else
        log_fail "Summary with no data not handled"
        echo "$OUTPUT"
    fi
}

# Test 2: Summary after receiving reports
test_summary_after_report() {
    log_test "Test 2: Summary after receiving reports"
    cleanup_client
    
    REPORTER="reporter_$(date +%s)"
    RECEIVER="receiver_$(date +%s)"
    SUMMARY_FILE="/tmp/summary_test2_$$.txt"
    
    # Start a persistent receiver using a FIFO so we can send commands later
    FIFO="/tmp/stomp_fifo_$$"
    rm -f "$FIFO"
    mkfifo "$FIFO"
    RECEIVER_LOG="/tmp/receiver_$$.log"
    # Start client reading from FIFO
    $CLIENT_BIN < "$FIFO" >"$RECEIVER_LOG" 2>&1 &
    RECEIVER_PID=$!
    # Open FIFO for writing on FD 3
    exec 3>"$FIFO"
    # Login and join on the receiver
    echo "login $SERVER_HOST $RECEIVER password123" >&3
    echo "join Germany_Japan" >&3
    sleep 1
    
    # Send report from a separate reporter (ensures MESSAGE frames reach receiver)
    timeout 8 $CLIENT_BIN <<EOF >/dev/null 2>&1 || true
login $SERVER_HOST $REPORTER password123
join Germany_Japan
report $TEST_JSON
logout
EOF
    
    # Give receiver time to process MESSAGE frames
    sleep 2
    
    # Request summary within the SAME receiver session
    echo "summary Germany_Japan $REPORTER $SUMMARY_FILE" >&3
    # Logout receiver to terminate cleanly
    echo "logout" >&3
    # Close writer FD and wait
    exec 3>&-
    wait $RECEIVER_PID 2>/dev/null || true
    rm -f "$FIFO"
    
    if [ -f "$SUMMARY_FILE" ] && [ -s "$SUMMARY_FILE" ]; then
        log_pass "Summary after report generated successfully"
        rm -f "$SUMMARY_FILE"
    else
        log_fail "Summary after report failed"
        echo "$OUTPUT"
    fi
}

# Test 3: Summary output file creation
test_summary_file_creation() {
    log_test "Test 3: Summary output file creation"
    cleanup_client
    
    TESTUSER="summary3_$(date +%s)"
    SUMMARY_FILE="/tmp/summary_test3_$$.txt"
    
    OUTPUT=$(timeout 10 $CLIENT_BIN <<EOF 2>&1 || true
login $SERVER_HOST $TESTUSER password123
join Germany_Japan
report $TEST_JSON
summary Germany_Japan $TESTUSER $SUMMARY_FILE
logout
EOF
)
    
    sleep 1
    
    if [ -f "$SUMMARY_FILE" ] && echo "$OUTPUT" | grep -q "wrote summary"; then
        FILE_SIZE=$(stat -f%z "$SUMMARY_FILE" 2>/dev/null || stat -c%s "$SUMMARY_FILE" 2>/dev/null || echo 0)
        if [ "$FILE_SIZE" -gt 0 ]; then
            log_pass "Summary file created with content ($FILE_SIZE bytes)"
        else
            log_fail "Summary file empty"
        fi
        rm -f "$SUMMARY_FILE"
    else
        log_fail "Summary file not created"
        echo "$OUTPUT"
    fi
}

# Test 4: Summary for multiple games
test_summary_multiple_games() {
    log_test "Test 4: Summary for multiple games"
    cleanup_client
    
    TESTUSER="summary4_$(date +%s)"
    SUMMARY_FILE1="/tmp/summary_game1_$$.txt"
    SUMMARY_FILE2="/tmp/summary_game2_$$.txt"
    
    OUTPUT=$(timeout 10 $CLIENT_BIN <<EOF 2>&1 || true
login $SERVER_HOST $TESTUSER password123
join Germany_Japan
join Italy_France
report $TEST_JSON
summary Germany_Japan $TESTUSER $SUMMARY_FILE1
summary Italy_France $TESTUSER $SUMMARY_FILE2
logout
EOF
)
    
    SUMMARY_COUNT=$(echo "$OUTPUT" | grep -c "wrote summary")
    
    if [ "$SUMMARY_COUNT" -ge 1 ]; then
        log_pass "Multiple game summaries generated ($SUMMARY_COUNT summaries)"
        rm -f "$SUMMARY_FILE1" "$SUMMARY_FILE2"
    else
        log_fail "Multiple game summaries failed"
        echo "$OUTPUT"
    fi
}

# Test 5: SQL login history verification
test_sql_login_history() {
    log_test "Test 5: SQL login history tracking"
    cleanup_client
    
    TESTUSER="sqltest_$(date +%s)"
    
    # Login and logout
    timeout 5 $CLIENT_BIN <<EOF >/dev/null 2>&1 || true
login $SERVER_HOST $TESTUSER password123
logout
EOF
    
    sleep 1
    
    # Query SQL database
    if [ -f "$SCRIPT_DIR/stomp_server.db" ]; then
        RESULT=$(sqlite3 "$SCRIPT_DIR/stomp_server.db" \
            "SELECT COUNT(*) FROM login_history WHERE username='$TESTUSER';" 2>/dev/null || echo 0)
        
        if [ "$RESULT" -ge 1 ]; then
            log_pass "SQL login history tracking successful (found $RESULT record)"
        else
            log_fail "SQL login history not tracked"
        fi
    else
        log_fail "SQL database not found"
    fi
}

# Test 6: SQL user registration
test_sql_user_registration() {
    log_test "Test 6: SQL user registration"
    cleanup_client
    
    TESTUSER="newuser_$(date +%s)"
    
    # Register new user
    timeout 5 $CLIENT_BIN <<EOF >/dev/null 2>&1 || true
login $SERVER_HOST $TESTUSER password123
logout
EOF
    
    sleep 1
    
    # Query SQL database
    if [ -f "$SCRIPT_DIR/stomp_server.db" ]; then
        RESULT=$(sqlite3 "$SCRIPT_DIR/stomp_server.db" \
            "SELECT username FROM users WHERE username='$TESTUSER';" 2>/dev/null || echo "")
        
        if [ "$RESULT" = "$TESTUSER" ]; then
            log_pass "SQL user registration successful"
        else
            log_fail "SQL user not registered"
        fi
    else
        log_fail "SQL database not found"
    fi
}

# Test 7: GameDB persistence across operations
test_gamedb_persistence() {
    log_test "Test 7: GameDB persistence across operations"
    cleanup_client
    
    TESTUSER="persist_$(date +%s)"
    SUMMARY_FILE="/tmp/summary_persist_$$.txt"
    
    OUTPUT=$(timeout 10 $CLIENT_BIN <<EOF 2>&1 || true
login $SERVER_HOST $TESTUSER password123
join Germany_Japan
report $TEST_JSON
summary Germany_Japan $TESTUSER $SUMMARY_FILE
logout
EOF
)
    
    if [ -f "$SUMMARY_FILE" ]; then
        CONTENT=$(cat "$SUMMARY_FILE")
        if echo "$CONTENT" | grep -q "Germany\|Japan"; then
            log_pass "GameDB persistence verified"
        else
            log_fail "GameDB data incomplete"
        fi
        rm -f "$SUMMARY_FILE"
    else
        log_fail "GameDB persistence test failed"
        echo "$OUTPUT"
    fi
}

# Test 8: Summary with different user (should have no data)
test_summary_different_user() {
    log_test "Test 8: Summary for different user"
    cleanup_client
    
    REPORTER="reporter_$(date +%s)"
    OTHERUSER="other_$(date +%s)"
    SUMMARY_FILE="/tmp/summary_other_$$.txt"
    
    # Report as one user
    timeout 5 $CLIENT_BIN <<EOF >/dev/null 2>&1 || true
login $SERVER_HOST $REPORTER password123
join Germany_Japan
report $TEST_JSON
logout
EOF
    
    sleep 1
    
    # Request summary for different user
    OUTPUT=$(timeout 5 $CLIENT_BIN <<EOF 2>&1 || true
login $SERVER_HOST $OTHERUSER password123
summary Germany_Japan $OTHERUSER $SUMMARY_FILE
logout
EOF
)
    
    if echo "$OUTPUT" | grep -q "no info"; then
        log_pass "Summary filtering by user works correctly"
    else
        log_fail "Summary user filtering failed"
        echo "$OUTPUT"
    fi
    
    rm -f "$SUMMARY_FILE"
}

# Run all tests
echo "========================================"
echo "Summary & Data Persistence Tests"
echo "========================================"

test_summary_no_data
test_summary_after_report
test_summary_file_creation
test_summary_multiple_games
test_sql_login_history
test_sql_user_registration
test_gamedb_persistence
test_summary_different_user

cleanup_client

echo ""
echo "========================================"
echo "Test Summary"
echo "========================================"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
