#!/bin/bash

# Test Suite: Authentication & Session Management
# Tests login, logout, wrong password, concurrent logins, re-login cycles

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIENT_BIN="$SCRIPT_DIR/client/bin/StompClient"
SERVER_HOST="127.0.0.1:7777"

# Colors
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
    pkill -9 -f StompClient 2>/dev/null || true
    sleep 0.2
}

# Test 1: New user registration
test_new_user_registration() {
    log_test "Test 1: New user registration"
    cleanup_client
    
    TESTUSER="testuser_$(date +%s)"
    OUTPUT=$(echo -e "login $SERVER_HOST $TESTUSER password123\nlogout" | timeout 5 $CLIENT_BIN 2>&1 || true)
    
    if echo "$OUTPUT" | grep -q "Login successful"; then
        log_pass "New user registration successful"
    else
        log_fail "New user registration failed"
        echo "$OUTPUT"
    fi
}

# Test 2: Existing user login with correct password
test_existing_user_login() {
    log_test "Test 2: Existing user login with correct password"
    cleanup_client
    
    TESTUSER="existinguser_$(date +%s)"
    
    # First login to create user
    echo -e "login $SERVER_HOST $TESTUSER password123\nlogout" | timeout 5 $CLIENT_BIN >/dev/null 2>&1 || true
    
    sleep 1
    
    # Second login with same credentials
    OUTPUT=$(echo -e "login $SERVER_HOST $TESTUSER password123\nlogout" | timeout 5 $CLIENT_BIN 2>&1 || true)
    
    if echo "$OUTPUT" | grep -q "Login successful"; then
        log_pass "Existing user login successful"
    else
        log_fail "Existing user login failed"
        echo "$OUTPUT"
    fi
}

# Test 3: Wrong password error
test_wrong_password() {
    log_test "Test 3: Wrong password error"
    cleanup_client
    
    TESTUSER="pwdtest_$(date +%s)"
    
    # Create user
    timeout 5 $CLIENT_BIN <<EOF >/dev/null 2>&1 || true
login $SERVER_HOST $TESTUSER correct_password
logout
EOF
    
    sleep 1
    
    # Try with wrong password
    OUTPUT=$(timeout 5 $CLIENT_BIN <<EOF 2>&1 || true
login $SERVER_HOST $TESTUSER wrong_password
logout
EOF
)
    
    if echo "$OUTPUT" | grep -q "Wrong password"; then
        log_pass "Wrong password detected correctly"
    else
        log_fail "Wrong password not detected"
        echo "$OUTPUT"
    fi
}

# Test 4: User already logged in (concurrent login)
test_concurrent_login() {
    log_test "Test 4: User already logged in (concurrent login)"
    cleanup_client
    
    TESTUSER="concurrent_$(date +%s)"
    
    # Start first client and keep it connected
    timeout 10 $CLIENT_BIN <<EOF >/dev/null 2>&1 &
login $SERVER_HOST $TESTUSER password123
join test_game
EOF
    
    CLIENT1_PID=$!
    sleep 2
    
    # Try to login with same user from second client
    OUTPUT=$(timeout 5 $CLIENT_BIN <<EOF 2>&1 || true
login $SERVER_HOST $TESTUSER password123
logout
EOF
)
    
    kill $CLIENT1_PID 2>/dev/null || true
    wait $CLIENT1_PID 2>/dev/null || true
    
    if echo "$OUTPUT" | grep -q "User already logged in"; then
        log_pass "Concurrent login blocked correctly"
    else
        log_fail "Concurrent login not blocked"
        echo "$OUTPUT"
    fi
}

# Test 5: Login -> Logout -> Re-login cycle
test_relogin_cycle() {
    log_test "Test 5: Login -> Logout -> Re-login cycle"
    cleanup_client
    
    TESTUSER="relogin_$(date +%s)"
    
    OUTPUT=$(timeout 10 $CLIENT_BIN <<EOF 2>&1 || true
login $SERVER_HOST $TESTUSER password123
logout
login $SERVER_HOST $TESTUSER password123
logout
EOF
)
    
    LOGIN_COUNT=$(echo "$OUTPUT" | grep -c "Login successful" || echo 0)
    LOGOUT_COUNT=$(echo "$OUTPUT" | grep -c "Disconnected" || echo 0)
    
    if [ "$LOGIN_COUNT" -eq 2 ] && [ "$LOGOUT_COUNT" -eq 2 ]; then
        log_pass "Re-login cycle works correctly"
    else
        log_fail "Re-login cycle failed (logins: $LOGIN_COUNT, logouts: $LOGOUT_COUNT)"
        echo "$OUTPUT"
    fi
}

# Test 6: Client already connected error
test_client_already_connected() {
    log_test "Test 6: Client already connected error"
    cleanup_client
    
    TESTUSER1="client1_$(date +%s)"
    TESTUSER2="client2_$(date +%s)"
    
    OUTPUT=$(timeout 5 $CLIENT_BIN <<EOF 2>&1 || true
login $SERVER_HOST $TESTUSER1 password123
login $SERVER_HOST $TESTUSER2 password456
logout
EOF
)
    
    if echo "$OUTPUT" | grep -q "already logged in"; then
        log_pass "Client already connected detected"
    else
        log_fail "Client already connected not detected"
        echo "$OUTPUT"
    fi
}

# Test 7: Logout with receipt synchronization
test_logout_receipt() {
    log_test "Test 7: Logout with receipt synchronization"
    cleanup_client
    
    TESTUSER="receipt_$(date +%s)"
    
    OUTPUT=$(timeout 5 $CLIENT_BIN <<EOF 2>&1 || true
login $SERVER_HOST $TESTUSER password123
logout
EOF
)
    
    if echo "$OUTPUT" | grep -q "Disconnected"; then
        log_pass "Logout with receipt completed"
    else
        log_fail "Logout did not complete properly"
        echo "$OUTPUT"
    fi
}

# Test 8: Connection failure handling
test_connection_failure() {
    log_test "Test 8: Connection failure handling"
    cleanup_client
    
    OUTPUT=$(timeout 3 $CLIENT_BIN <<EOF 2>&1 || true
login 127.0.0.1:9999 testuser password
EOF
)
    
    if echo "$OUTPUT" | grep -q "Could not connect"; then
        log_pass "Connection failure handled correctly"
    else
        log_fail "Connection failure not handled"
        echo "$OUTPUT"
    fi
}

# Run all tests
echo "========================================"
echo "Authentication & Session Management Tests"
echo "========================================"

test_new_user_registration
test_existing_user_login
test_wrong_password
test_concurrent_login
test_relogin_cycle
test_client_already_connected
test_logout_receipt
test_connection_failure

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
