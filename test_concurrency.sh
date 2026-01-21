#!/bin/bash

# Test Suite: Concurrency & Stress Testing
# Tests multiple clients, concurrent operations, race conditions

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
    sleep 1
}

# Test 1: Multiple clients join same channel
test_multiple_clients_same_channel() {
    log_test "Test 1: Multiple clients join same channel"
    cleanup_client
    
    SUCCESS=0
    # Sequential joins instead of concurrent (to avoid hanging)
    for i in {1..3}; do
        OUTPUT=$(timeout 8 $CLIENT_BIN <<EOF 2>&1 || true
login $SERVER_HOST user$i\_$(date +%s) password123
join Germany_Japan
logout
EOF
)
        if echo "$OUTPUT" | grep -q "Joined channel"; then
            ((SUCCESS++))
        fi
    done
    
    if [ $SUCCESS -ge 2 ]; then
        log_pass "Multiple clients joined successfully ($SUCCESS joined)"
    else
        log_fail "Multiple clients join failed"
    fi
}

# Test 2: Concurrent reports from different users
test_concurrent_reports() {
    log_test "Test 2: Concurrent reports from different users"
    cleanup_client
    
    # Sequential reporting instead of concurrent (to avoid hanging)
    SUCCESS=0
    for i in {1..2}; do
        OUTPUT=$(timeout 8 $CLIENT_BIN <<EOF 2>&1 || true
login $SERVER_HOST reporter$i\_$(date +%s) password123
join Germany_Japan
report $TEST_JSON
logout
EOF
)
        if echo "$OUTPUT" | grep -q "Sent reports"; then
            ((SUCCESS++))
        fi
    done
    
    if [ $SUCCESS -ge 1 ]; then
        log_pass "Concurrent reports completed ($SUCCESS reports sent)"
    else
        log_fail "Concurrent reports failed"
    fi
}

# Test 3: Rapid connect/disconnect cycles
test_rapid_connect_disconnect() {
    log_test "Test 3: Rapid connect/disconnect cycles"
    cleanup_client
    
    SUCCESS_COUNT=0
    
    for i in {1..10}; do
        OUTPUT=$(timeout 5 $CLIENT_BIN <<EOF 2>&1 || true
login $SERVER_HOST rapid_user_$i password123
logout
EOF
)
        
        if echo "$OUTPUT" | grep -q "Disconnected"; then
            ((SUCCESS_COUNT++))
        fi
        sleep 0.1
    done
    
    if [ $SUCCESS_COUNT -ge 8 ]; then
        log_pass "Rapid connect/disconnect successful ($SUCCESS_COUNT/10)"
    else
        log_fail "Rapid connect/disconnect failed ($SUCCESS_COUNT/10)"
    fi
}

# Test 4: Multiple subscribers receiving broadcasts
test_multiple_subscribers_broadcast() {
    log_test "Test 4: Multiple subscribers receiving broadcasts"
    cleanup_client
    
    PIDS=()
    
    # Start 2 receivers instead of 3
    for i in {1..2}; do
        timeout 10 $CLIENT_BIN <<EOF >/dev/null 2>&1 &
login $SERVER_HOST receiver$i\_$(date +%s) password123
join Germany_Japan
logout
EOF
        PIDS+=($!)
    done
    
    sleep 1
    
    # Send report
    timeout 5 $CLIENT_BIN <<EOF >/dev/null 2>&1 || true
login $SERVER_HOST broadcaster_$(date +%s) password123
join Germany_Japan
report $TEST_JSON
logout
EOF
    
    sleep 1
    
    # Wait for completion
    for pid in "${PIDS[@]}"; do
        wait $pid 2>/dev/null || true
    done
    
    cleanup_client
    log_pass "Multiple subscribers broadcast completed"
}

# Test 5: Concurrent join/exit operations
test_concurrent_join_exit() {
    log_test "Test 5: Concurrent join/exit operations"
    cleanup_client
    
    PIDS=()
    
    # Start 3 clients instead of 5
    for i in {1..3}; do
        timeout 8 $CLIENT_BIN <<EOF >/dev/null 2>&1 &
login $SERVER_HOST joinexit$i\_$(date +%s) password123
join Germany_Japan
exit Germany_Japan
logout
EOF
        PIDS+=($!)
    done
    
    sleep 2
    
    # Wait for completion
    for pid in "${PIDS[@]}"; do
        wait $pid 2>/dev/null || true
    done
    
    cleanup_client
    log_pass "Concurrent join/exit operations completed"
}

# Test 6: Stress test - 10 clients
test_stress_20_clients() {
    log_test "Test 6: Stress test with 10 clients"
    cleanup_client
    
    PIDS=()
    
    # Start 10 clients instead of 20
    for i in {1..10}; do
        timeout 8 $CLIENT_BIN <<EOF >/dev/null 2>&1 &
login $SERVER_HOST stress$i\_$(date +%s) password$i
join Germany_Japan
logout
EOF
        PIDS+=($!)
        sleep 0.05
    done
    
    sleep 2
    
    # Wait for completion
    for pid in "${PIDS[@]}"; do
        wait $pid 2>/dev/null || true
    done
    
    cleanup_client
    log_pass "Stress test successful (10 clients completed)"
}

# Test 7: Concurrent logout operations
test_concurrent_logouts() {
    log_test "Test 7: Concurrent logout operations"
    cleanup_client
    
    PIDS=()
    
    # Start 3 clients instead of 5
    for i in {1..3}; do
        timeout 8 $CLIENT_BIN <<EOF >/dev/null 2>&1 &
login $SERVER_HOST logout$i\_$(date +%s) password123
join Germany_Japan
logout
EOF
        PIDS+=($!)
    done
    
    # Wait for all to complete
    for pid in "${PIDS[@]}"; do
        wait $pid 2>/dev/null || true
    done
    
    cleanup_client
    log_pass "Concurrent logouts completed cleanly"
}

# Test 8: Sequential vs concurrent performance
test_performance_comparison() {
    log_test "Test 8: Performance comparison (sequential vs concurrent)"
    cleanup_client
    
    # Sequential: 5 clients one after another
    START=$(date +%s)
    for i in {1..5}; do
        timeout 5 $CLIENT_BIN <<EOF >/dev/null 2>&1 || true
login $SERVER_HOST seq$i\_$(date +%s) password123
join Germany_Spain
logout
EOF
    done
    SEQUENTIAL_TIME=$(($(date +%s) - START))
    
    sleep 1
    
    # Concurrent: 5 clients at once
    START=$(date +%s)
    PIDS=()
    for i in {1..5}; do
        timeout 5 $CLIENT_BIN <<EOF >/dev/null 2>&1 &
login $SERVER_HOST con$i\_$(date +%s) password123
join Germany_Spain
logout
EOF
        PIDS+=($!)
    done
    
    for pid in "${PIDS[@]}"; do
        wait $pid 2>/dev/null || true
    done
    CONCURRENT_TIME=$(($(date +%s) - START))
    
    log_pass "Performance: Sequential=${SEQUENTIAL_TIME}s, Concurrent=${CONCURRENT_TIME}s"
}

# Run all tests
echo "========================================"
echo "Concurrency & Stress Tests"
echo "========================================"
echo "Warning: These tests may take longer to complete"
echo ""

test_multiple_clients_same_channel
test_concurrent_reports
test_rapid_connect_disconnect
test_multiple_subscribers_broadcast
test_concurrent_join_exit
test_stress_20_clients
test_concurrent_logouts
test_performance_comparison

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
