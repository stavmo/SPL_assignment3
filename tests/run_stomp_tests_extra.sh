#!/usr/bin/env bash
set -euo pipefail

HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-7777}"
CLIENT_BIN="${CLIENT_BIN:-./client/bin/StompClient}"
SERVER_CMD="${SERVER_CMD:-}"

ROOT_DIR="$(pwd)"
DATA_FILE="${DATA_FILE:-$ROOT_DIR/data/events1.json}"

if [[ ! -x "$CLIENT_BIN" ]]; then
  echo "Client binary not found/executable at: $CLIENT_BIN"
  echo "Run with: CLIENT_BIN=path/to/StompClient ./tests/run_stomp_tests_extra.sh"
  exit 1
fi

if [[ ! -f "$DATA_FILE" ]]; then
  echo "Events file not found at: $DATA_FILE"
  echo "Fix by setting DATA_FILE=... (absolute path) or ensure data/events1.json exists."
  exit 1
fi

mkdir -p tests/out_extra

# Optional: start server if user provided a command
server_pid=""
if [[ -n "$SERVER_CMD" ]]; then
  echo "Starting server with: $SERVER_CMD"
  bash -lc "$SERVER_CMD" > tests/out_extra/server.log 2>&1 &
  server_pid="$!"
  sleep 0.5
else
  echo "NOTE: SERVER_CMD is empty, assuming server is already running on $HOST:$PORT."
fi

cleanup() {
  if [[ -n "$server_pid" ]]; then
    kill "$server_pid" 2>/dev/null || true
  fi
}
trap cleanup EXIT

pass() { echo "✅ $1"; }
fail() { echo "❌ FAIL: $1"; echo "---- OUTPUT ----"; cat "$2"; echo "--------------"; exit 1; }

assert_contains() {
  local file="$1"
  local pattern="$2"
  grep -E "$pattern" "$file" >/dev/null 2>&1
}

assert_not_contains() {
  local file="$1"
  local pattern="$2"
  ! grep -E "$pattern" "$file" >/dev/null 2>&1
}

rand_user() {
  # unique-ish username per test
  echo "u$RANDOM$RANDOM"
}

# --------------------------
# Test A: join -> exit -> report should be blocked (map empty)
# --------------------------
testA_out="tests/out_extra/testA.txt"
userA="$(rand_user)"
timeout 12s bash -lc "printf '%s\n' \
  'login $HOST:$PORT $userA pass' \
  'join Germany_Japan' \
  'exit Germany_Japan' \
  'report $DATA_FILE' \
  'logout' \
| $CLIENT_BIN" >"$testA_out" 2>&1 || true

# after exit, your code blocks report with either:
# "You must join a game before reporting."
# or "You must join Germany_Japan before reporting."
if assert_contains "$testA_out" "You must join (a game|Germany_Japan) before reporting"; then
  pass "join->exit->report is blocked on client"
else
  fail "join->exit->report should be blocked on client" "$testA_out"
fi

# --------------------------
# Test B: join 2 channels, exit the relevant one, report should be blocked (map non-empty)
# --------------------------
testB_out="tests/out_extra/testB.txt"
userB="$(rand_user)"
timeout 12s bash -lc "printf '%s\n' \
  'login $HOST:$PORT $userB pass' \
  'join Germany_Japan' \
  'join Foo_Bar' \
  'exit Germany_Japan' \
  'report $DATA_FILE' \
  'logout' \
| $CLIENT_BIN" >"$testB_out" 2>&1 || true

if assert_contains "$testB_out" "You must join Germany_Japan before reporting"; then
  pass "report blocked when game not joined (even if some other channel is joined)"
else
  fail "report should be blocked if the file game != any joined channel" "$testB_out"
fi

# --------------------------
# Test C: report then summary should CREATE a non-empty file
# (needs small delay to let MESSAGE frames arrive)
# --------------------------
testC_out="tests/out_extra/testC.txt"
userC="$(rand_user)"
summaryFile="tests/out_extra/summary_${userC}.txt"

# We pipe with a sleep between report and summary
timeout 15s bash -lc "{
  echo 'login $HOST:$PORT $userC pass'
  echo 'join Germany_Japan'
  echo 'report $DATA_FILE'
  sleep 1
  echo 'summary Germany_Japan $userC $summaryFile'
  echo 'logout'
} | $CLIENT_BIN" >"$testC_out" 2>&1 || true

if [[ -f "$summaryFile" ]] && [[ -s "$summaryFile" ]]; then
  pass "report then summary produces a non-empty summary file"
else
  fail "summary file should be created + non-empty after report" "$testC_out"
fi

# --------------------------
# Test D: same user logging in twice at the same time
# - client1 logs in and stays connected
# - client2 tries login same user -> should get 'User already logged in'
# - then client1 logs out and exits
# - client2 logs in again -> should succeed
# --------------------------
testD_out1="tests/out_extra/testD_client1.txt"
testD_out2="tests/out_extra/testD_client2.txt"
testD_out3="tests/out_extra/testD_client2_after_logout.txt"

userD="$(rand_user)"
fifo="tests/out_extra/fifo_userD"
rm -f "$fifo"
mkfifo "$fifo"

# Start client1 reading from fifo; keep writer FD open
"$CLIENT_BIN" < "$fifo" > "$testD_out1" 2>&1 &
c1_pid=$!
exec 3> "$fifo"

# Send login to client1 (keep pipe open)
echo "login $HOST:$PORT $userD pass" >&3
sleep 0.7

# client2 tries same user
timeout 8s bash -lc "printf '%s\n' \
  'login $HOST:$PORT $userD pass' \
  'logout' \
| $CLIENT_BIN" >"$testD_out2" 2>&1 || true

if assert_contains "$testD_out2" "User already logged in"; then
  pass "second client rejected while first is logged in"
else
  fail "second client should be rejected with 'User already logged in'" "$testD_out2"
fi

# Now logout client1 and close fifo so it exits
echo "logout" >&3
exec 3>&-
sleep 0.5
kill "$c1_pid" 2>/dev/null || true
wait "$c1_pid" 2>/dev/null || true

# client2 tries again after logout -> should succeed
timeout 8s bash -lc "printf '%s\n' \
  'login $HOST:$PORT $userD pass' \
  'logout' \
| $CLIENT_BIN" >"$testD_out3" 2>&1 || true

if assert_contains "$testD_out3" "Login successful"; then
  pass "same user can login after previous session logged out"
else
  fail "login should succeed after previous session logs out" "$testD_out3"
fi

echo
echo "🎉 Extra tests passed."
