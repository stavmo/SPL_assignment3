#!/bin/bash

# Test Suite: Channel Subscription & Lifecycle
# Tests join, exit, multiple subscriptions, re-join scenarios

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIENT_BIN="$SCRIPT_DIR/client/bin/StompClient"
SERVER_HOST="127.0.0.1:7777"

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

# Test 1: Join single channel
test_join_single_channel() {
    log_test "Test 1: Join single channel"
    cleanup_client
    
    TESTUSER="join1_$(date +%s)"
    
    OUTPUT=$(timeout 5 $CLIENT_BIN <<EOF 2>&1 || true
login $SERVER_HOST $TESTUSER password123
join Germany_Spain
logout
EOF
)
    
    if echo "$OUTPUT" | grep -q "Joined channel Germany_Spain"; then
        log_pass "Single channel join successful"
    else
        log_fail "Single channel join failed"
        echo "$OUTPUT"
    fi
}

# Test 2: Join multiple channels
test_join_multiple_channels() {
    log_test "Test 2: Join multiple channels"
    cleanup_client
    
    TESTUSER="join2_$(date +%s)"
    
    OUTPUT=$(timeout 5 $CLIENT_BIN <<EOF 2>&1 || true
login $SERVER_HOST $TESTUSER password123
join Germany_Spain
join Italy_France
join England_Portugal
logout
EOF
)
    
    JOIN_COUNT=$(echo "$OUTPUT" | grep -c "Joined channel" || echo 0)
    
    if [ "$JOIN_COUNT" -eq 3 ]; then
        log_pass "Multiple channel join successful ($JOIN_COUNT channels)"
    else
        log_fail "Multiple channel join failed (only $JOIN_COUNT joins detected)"
        echo "$OUTPUT"
    fi
}

# Test 3: Exit subscribed channel
test_exit_subscribed() {
    log_test "Test 3: Exit subscribed channel"
    cleanup_client
    
    TESTUSER="exit1_$(date +%s)"
    
    OUTPUT=$(timeout 5 $CLIENT_BIN <<EOF 2>&1 || true
login $SERVER_HOST $TESTUSER password123
join Germany_Spain
exit Germany_Spain
logout
EOF
)
    
    if echo "$OUTPUT" | grep -q "Exited channel Germany_Spain"; then
        log_pass "Exit subscribed channel successful"
    else
        log_fail "Exit subscribed channel failed"
        echo "$OUTPUT"
    fi
}

# Test 4: Exit non-existent channel
test_exit_nonexistent() {
    log_test "Test 4: Exit non-existent channel"
    cleanup_client
    
    TESTUSER="exit2_$(date +%s)"
    
    OUTPUT=$(timeout 5 $CLIENT_BIN <<EOF 2>&1 || true
login $SERVER_HOST $TESTUSER password123
exit Germany_Spain
logout
EOF
)
    
    if echo "$OUTPUT" | grep -q "not subscribed"; then
        log_pass "Exit non-existent channel handled correctly"
    else
        log_fail "Exit non-existent channel not handled"
        echo "$OUTPUT"
    fi
}

# Test 5: Join -> Exit -> Re-join same channel
test_rejoin_channel() {
    log_test "Test 5: Join -> Exit -> Re-join same channel"
    cleanup_client
    
    TESTUSER="rejoin_$(date +%s)"
    
    OUTPUT=$(timeout 5 $CLIENT_BIN <<EOF 2>&1 || true
login $SERVER_HOST $TESTUSER password123
join Germany_Spain
exit Germany_Spain
join Germany_Spain
logout
EOF
)
    
    JOIN_COUNT=$(echo "$OUTPUT" | grep -c "Joined channel Germany_Spain" || echo 0)
    EXIT_COUNT=$(echo "$OUTPUT" | grep -c "Exited channel Germany_Spain" || echo 0)
    
    if [ "$JOIN_COUNT" -eq 2 ] && [ "$EXIT_COUNT" -eq 1 ]; then
        log_pass "Re-join after exit successful"
    else
        log_fail "Re-join failed (joins: $JOIN_COUNT, exits: $EXIT_COUNT)"
        echo "$OUTPUT"
    fi
}

# Test 6: Join 2 channels, exit 1, verify state
test_partial_exit() {
    log_test "Test 6: Partial channel exit (join 2, exit 1)"
    cleanup_client
    
    TESTUSER="partial_$(date +%s)"
    
    OUTPUT=$(timeout 5 $CLIENT_BIN <<EOF 2>&1 || true
login $SERVER_HOST $TESTUSER password123
join Germany_Spain
join Italy_France
exit Germany_Spain
logout
EOF
)
    
    if echo "$OUTPUT" | grep -q "Exited channel Germany_Spain" && \
       echo "$OUTPUT" | grep -q "Joined channel Italy_France"; then
        log_pass "Partial channel exit successful"
    else
        log_fail "Partial channel exit failed"
        echo "$OUTPUT"
    fi
}

# Test 7: Join before login (should fail)
test_join_without_login() {
    log_test "Test 7: Join before login (should fail)"
    cleanup_client
    
    OUTPUT=$(timeout 3 $CLIENT_BIN <<EOF 2>&1 || true
join Germany_Spain
EOF
)
    
    if echo "$OUTPUT" | grep -q "login first"; then
        log_pass "Join before login blocked correctly"
    else
        log_fail "Join before login not blocked"
        echo "$OUTPUT"
    fi
}

# Test 8: Logout unsubscribes from all channels
test_logout_unsubscribes_all() {
    log_test "Test 8: Logout unsubscribes from all channels"
    cleanup_client
    
    TESTUSER="logout_unsub_$(date +%s)"
    
    OUTPUT=$(timeout 5 $CLIENT_BIN <<EOF 2>&1 || true
login $SERVER_HOST $TESTUSER password123
join Germany_Spain
join Italy_France
join England_Portugal
logout
EOF
)
    
    if echo "$OUTPUT" | grep -q "Disconnected"; then
        log_pass "Logout with multiple subscriptions successful"
    else
        log_fail "Logout with multiple subscriptions failed"
        echo "$OUTPUT"
    fi
}

# Run all tests
echo "========================================"
echo "Channel Subscription & Lifecycle Tests"
echo "========================================"

test_join_single_channel
test_join_multiple_channels
test_exit_subscribed
test_exit_nonexistent
test_rejoin_channel
test_partial_exit
test_join_without_login
test_logout_unsubscribes_all

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
