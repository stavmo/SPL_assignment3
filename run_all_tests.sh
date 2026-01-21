#!/bin/bash

# Master Test Runner
# Runs all test suites for the STOMP client-server system

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

TOTAL_PASSED=0
TOTAL_FAILED=0

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  STOMP Client-Server Comprehensive Test Suite         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if [ ! -f "$SCRIPT_DIR/client/bin/StompClient" ]; then
    echo -e "${RED}Error: Client binary not found. Run 'make' in client directory first.${NC}"
    exit 1
fi

if ! pgrep -f "StompServer" > /dev/null; then
    echo -e "${RED}Error: STOMP server not running. Tests cannot proceed.${NC}"
    echo "Start server with:"
    echo "  cd server && java -cp target/classes bgu.spl.net.impl.stomp.StompServer 7777 tpc &"
    echo ""
    exit 1
fi

if ! pgrep -f "sql_server.py" > /dev/null; then
    echo -e "${YELLOW}Warning: SQL server not running. SQL-related tests may fail.${NC}"
    echo "Start SQL server with: nohup python data/sql_server.py > /tmp/sql_server.log 2>&1 &"
    echo ""
fi

echo -e "${GREEN}✓ Prerequisites met${NC}"
echo ""

run_test_suite() {
    local suite_name=$1
    local script_path=$2
    
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}Running: $suite_name${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    
    if [ -f "$script_path" ]; then
        chmod +x "$script_path"
        if bash "$script_path"; then
            echo -e "${GREEN}✓ $suite_name completed successfully${NC}"
            return 0
        else
            echo -e "${RED}✗ $suite_name failed${NC}"
            return 1
        fi
    else
        echo -e "${RED}✗ Test suite not found: $script_path${NC}"
        return 1
    fi
    
    echo ""
}

# Run all test suites
SUITES_PASSED=0
SUITES_FAILED=0

if run_test_suite "Authentication & Session Management" "$SCRIPT_DIR/test_auth_session.sh"; then
    ((SUITES_PASSED++))
else
    ((SUITES_FAILED++))
fi

if run_test_suite "Channel Subscription & Lifecycle" "$SCRIPT_DIR/test_subscriptions.sh"; then
    ((SUITES_PASSED++))
else
    ((SUITES_FAILED++))
fi

if run_test_suite "Event Reporting & Distribution" "$SCRIPT_DIR/test_reporting.sh"; then
    ((SUITES_PASSED++))
else
    ((SUITES_FAILED++))
fi

if run_test_suite "Summary & Data Persistence" "$SCRIPT_DIR/test_summary_persistence.sh"; then
    ((SUITES_PASSED++))
else
    ((SUITES_FAILED++))
fi

if run_test_suite "Concurrency & Stress Testing" "$SCRIPT_DIR/test_concurrency.sh"; then
    ((SUITES_PASSED++))
else
    ((SUITES_FAILED++))
fi

# Final summary
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              FINAL TEST RESULTS                        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Test Suites Passed: ${GREEN}$SUITES_PASSED${NC} / 5"
echo -e "Test Suites Failed: ${RED}$SUITES_FAILED${NC} / 5"
echo ""

if [ $SUITES_FAILED -eq 0 ]; then
    echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║            ALL TESTS PASSED! ✓                         ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
    exit 0
else
    echo -e "${RED}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║         SOME TESTS FAILED ✗                            ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════╝${NC}"
    exit 1
fi
