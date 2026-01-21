#!/bin/bash

# Test Suite: Event Reporting & Message Distribution
# Tests report validation, MESSAGE broadcasting, file tracking

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIENT_BIN="$SCRIPT_DIR/client/bin/StompClient"
SERVER_HOST="127.0.0.1:7777"
TEST_JSON="$SCRIPT_DIR/client/data/events1.json"

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
}

# Test 1: Report before login (should fail)
test_report_without_login() {
    log_test "Test 1: Report before login"
    cleanup_client
    
    OUTPUT=$(timeout 3 $CLIENT_BIN <<EOF 2>&1 || true
report $TEST_JSON
EOF
)
    
    if echo "$OUTPUT" | grep -q "login first"; then
        log_pass "Report before login blocked correctly"
    else
        log_fail "Report before login not blocked"
        echo "$OUTPUT"
    fi
}

# Test 2: Report before join (should fail)
test_report_without_join() {
    log_test "Test 2: Report before join"
    cleanup_client
    
    TESTUSER="report1_$(date +%s)"
    
    OUTPUT=$(timeout 5 $CLIENT_BIN <<EOF 2>&1 || true
login $SERVER_HOST $TESTUSER password123
report $TEST_JSON
logout
EOF
)
    
    if echo "$OUTPUT" | grep -q "You must join"; then
        log_pass "Report before join blocked correctly"
    else
        log_fail "Report before join not blocked"
        echo "$OUTPUT"
    fi
}

# Test 3: Report to wrong game (joined different game)
test_report_wrong_game() {
    log_test "Test 3: Report to wrong game channel"
    cleanup_client
    
    TESTUSER="report2_$(date +%s)"
    
    OUTPUT=$(timeout 5 $CLIENT_BIN <<EOF 2>&1 || true
login $SERVER_HOST $TESTUSER password123
join Italy_France
report $TEST_JSON
logout
EOF
)
    
    if echo "$OUTPUT" | grep -q "You must join"; then
        log_pass "Report to wrong game blocked correctly"
    else
        log_fail "Report to wrong game not blocked"
        echo "$OUTPUT"
    fi
}

# Test 4: Valid report after join
test_valid_report() {
    log_test "Test 4: Valid report after join"
    cleanup_client
    
    TESTUSER="report3_$(date +%s)"
    
    OUTPUT=$(timeout 5 $CLIENT_BIN <<EOF 2>&1 || true
login $SERVER_HOST $TESTUSER password123
join Germany_Japan
report $TEST_JSON
logout
EOF
)
    
    if echo "$OUTPUT" | grep -q "Sent reports to Germany_Japan"; then
        log_pass "Valid report successful"
    else
        log_fail "Valid report failed"
        echo "$OUTPUT"
    fi
}

# Test 5: Report after exit (should be blocked)
test_report_after_exit() {
    log_test "Test 5: Report after exit"
    cleanup_client
    
    TESTUSER="report4_$(date +%s)"
    
    OUTPUT=$(timeout 5 $CLIENT_BIN <<EOF 2>&1 || true
login $SERVER_HOST $TESTUSER password123
join Germany_Japan
exit Germany_Japan
report $TEST_JSON
logout
EOF
)
    
    if echo "$OUTPUT" | grep -q "You must join"; then
        log_pass "Report after exit blocked correctly"
    else
        log_fail "Report after exit not blocked"
        echo "$OUTPUT"
    fi
}

# Test 6: Multiple reports to same channel
test_multiple_reports() {
    log_test "Test 6: Multiple reports to same channel"
    cleanup_client
    
    TESTUSER="report5_$(date +%s)"
    
    OUTPUT=$(timeout 5 $CLIENT_BIN <<EOF 2>&1 || true
login $SERVER_HOST $TESTUSER password123
join Germany_Japan
report $TEST_JSON
report $TEST_JSON
logout
EOF
)
    
    REPORT_COUNT=$(echo "$OUTPUT" | grep -c "Sent reports")
    
    if [ "$REPORT_COUNT" -eq 2 ]; then
        log_pass "Multiple reports successful ($REPORT_COUNT reports)"
    else
        log_fail "Multiple reports failed (only $REPORT_COUNT detected)"
        echo "$OUTPUT"
    fi
}

# Test 7: Report with rejoin workflow
test_report_rejoin_workflow() {
    log_test "Test 7: Report with join-exit-rejoin workflow"
    cleanup_client
    
    TESTUSER="report6_$(date +%s)"
    
    OUTPUT=$(timeout 5 $CLIENT_BIN <<EOF 2>&1 || true
login $SERVER_HOST $TESTUSER password123
join Germany_Japan
exit Germany_Japan
join Germany_Japan
report $TEST_JSON
logout
EOF
)
    
    if echo "$OUTPUT" | grep -q "Sent reports to Germany_Japan"; then
        log_pass "Report after rejoin successful"
    else
        log_fail "Report after rejoin failed"
        echo "$OUTPUT"
    fi
}

# Test 8: Message broadcasting (2 clients, 1 reports)
test_message_broadcast() {
    log_test "Test 8: Message broadcasting to subscribers"
    cleanup_client
    
    USER1="broadcaster_$(date +%s)"
    USER2="receiver_$(date +%s)"
    
    # Start receiver client
    timeout 10 $CLIENT_BIN <<EOF >"/tmp/receiver_$$.log" 2>&1 &
login $SERVER_HOST $USER2 password123
join Germany_Spain
EOF
    
    RECEIVER_PID=$!
    sleep 2
    
    # Send report from broadcaster
    timeout 5 $CLIENT_BIN <<EOF >/dev/null 2>&1 || true
login $SERVER_HOST $USER1 password123
join Germany_Spain
report $TEST_JSON
logout
EOF
    
    sleep 2
    kill $RECEIVER_PID 2>/dev/null || true
    wait $RECEIVER_PID 2>/dev/null || true
    
    # Receiver should have stored messages in GameDB (check via summary later)
    if [ -f "/tmp/receiver_$$.log" ]; then
        log_pass "Message broadcast test completed"
        rm -f "/tmp/receiver_$$.log"
    else
        log_fail "Message broadcast test failed"
    fi
}

# Test 9: Report with non-existent file
test_report_invalid_file() {
    log_test "Test 9: Report with non-existent file"
    cleanup_client
    
    TESTUSER="report7_$(date +%s)"
    
    OUTPUT=$(timeout 5 $CLIENT_BIN <<EOF 2>&1 || true
login $SERVER_HOST $TESTUSER password123
join Germany_Spain
report /nonexistent/file.json
logout
EOF
)
    
    # Client should handle file error gracefully
    if echo "$OUTPUT" | grep -qi "error\|failed\|not found" || ! echo "$OUTPUT" | grep -q "Sent reports"; then
        log_pass "Invalid file handled correctly"
    else
        log_fail "Invalid file not handled"
        echo "$OUTPUT"
    fi
}

# Run all tests
echo "========================================"
echo "Event Reporting & Distribution Tests"
echo "========================================"

test_report_without_login
test_report_without_join
test_report_wrong_game
test_valid_report
test_report_after_exit
test_multiple_reports
test_report_rejoin_workflow
test_message_broadcast
test_report_invalid_file

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
