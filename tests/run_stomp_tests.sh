#!/usr/bin/env bash
set -euo pipefail

########################################
# CONFIG — change these if needed
########################################

# Path to your client binary
CLIENT_BIN="${CLIENT_BIN:-./StompClient}"

CLIENT_DIR="$(cd "$(dirname "$CLIENT_BIN")" && pwd)"
CLIENT_EXE="./$(basename "$CLIENT_BIN")"

# How to start your server (YOU MAY NEED TO EDIT THIS LINE ONCE)
# Examples you can try:
#   SERVER_CMD='java -cp server/target/classes bgu.spl.net.impl.stomp.StompServer 7777 tpc'
#   SERVER_CMD='java -jar server/target/*jar-with-dependencies*.jar 7777 tpc'
#   SERVER_CMD='java -jar server/target/*.jar 7777 tpc'
SERVER_CMD="${SERVER_CMD:-}"

HOSTPORT="${HOSTPORT:-127.0.0.1:7777}"

########################################
# Helpers
########################################
fail() { echo "❌ FAIL: $1"; echo "---- OUTPUT ----"; echo "$2"; echo "--------------"; exit 1; }
pass() { echo "✅ $1"; }

need_binary() {
  if [[ ! -x "$CLIENT_BIN" ]]; then
    echo "Client binary not found/executable at: $CLIENT_BIN"
    echo "Fix it by running from the folder where StompClient exists,"
    echo "or run with: CLIENT_BIN=path/to/StompClient $0"
    exit 1
  fi
}

start_server() {
  if [[ -z "$SERVER_CMD" ]]; then
    echo "NOTE: SERVER_CMD is empty, so I'm assuming your server is ALREADY running on $HOSTPORT."
    echo "If not, run with something like:"
    echo "  SERVER_CMD='java -cp server/target/classes bgu.spl.net.impl.stomp.StompServer 7777 tpc' $0"
    return 0
  fi

  echo "Starting server: $SERVER_CMD"
  # shellcheck disable=SC2086
  bash -lc "$SERVER_CMD" > tests/server_test.log 2>&1 &
  SERVER_PID=$!
  export SERVER_PID

  # Give server a moment to bind port
  sleep 0.6

  # Ensure we clean it up
  trap 'if [[ -n "${SERVER_PID:-}" ]]; then kill "$SERVER_PID" 2>/dev/null || true; fi' EXIT
}

run_client() {
  local input="$1"
  # We use timeout so a hang doesn't freeze the tests
  local out
  out=$( (printf "%s" "$input") | timeout 8s "$CLIENT_BIN" 2>&1 ) || true
  echo "$out"
}

assert_has() {
  local name="$1"
  local out="$2"
  local pattern="$3"
  echo "$out" | grep -Eq "$pattern" || fail "$name (missing pattern: $pattern)" "$out"
}

assert_not_has() {
  local name="$1"
  local out="$2"
  local pattern="$3"
  echo "$out" | grep -Eq "$pattern" && fail "$name (should NOT contain: $pattern)" "$out"
}

########################################
# Tests
########################################

test_login_logout() {
  local name="login + logout prints Disconnected"
  local out
  out=$(run_client \
"login $HOSTPORT testuser1 pass1
logout
")

  # you might print "Login successful" (depends on your client)
  assert_has "$name" "$out" "Disconnected"
  pass "$name"
}

test_report_without_join_blocked_by_client() {
  local name="report without join should be blocked by client"
  local out
  out=$(run_client \
"login $HOSTPORT testuser2 pass2
report ../data/events1.json
logout
")

  # This assumes you added the client-side guard you asked about:
  # "You must join <game> before reporting."
  assert_has "$name" "$out" "You must join .* before reporting"
  pass "$name"
}

test_exit_not_subscribed_does_not_quit() {
  local name="exit not subscribed should NOT terminate program"
  local out
  out=$(run_client \
"login $HOSTPORT testuser3 pass3
exit Germany_Japan
logout
")

  assert_has "$name" "$out" "not subscribed to Germany_Japan"
  assert_has "$name" "$out" "Disconnected"
  pass "$name"
}

test_summary_no_info_is_ok() {
  local name="summary on empty DB prints no info (and continues)"
  local out
  out=$(run_client \
"login $HOSTPORT testuser4 pass4
summary Germany_Japan testuser4 summary.txt
logout
")

  assert_has "$name" "$out" "no info for game=Germany_Japan user=testuser4"
  assert_has "$name" "$out" "Disconnected"
  pass "$name"
}

test_wrong_password_after_registration() {
  local name="wrong password should be rejected after user exists"

  # First run: create user (register)
  run_client \
"login $HOSTPORT userX correctPass
logout
" >/dev/null

  # Second run: wrong pass
  local out
  out=$(run_client \
"login $HOSTPORT userX wrongPass
")

  # Your client prints "Wrong password" based on your listener code.
  assert_has "$name" "$out" "Wrong password"
  pass "$name"
}

########################################
# Main
########################################
need_binary
start_server

echo "Running tests against $HOSTPORT using client: $CLIENT_BIN"
echo

test_login_logout
test_report_without_join_blocked_by_client
test_exit_not_subscribed_does_not_quit
test_summary_no_info_is_ok
test_wrong_password_after_registration

echo
echo "🎉 All tests passed."
