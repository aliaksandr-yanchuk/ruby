#!/usr/bin/env bash
# End-to-end smoke test for blog_api.
# Usage: start the server (bin/rails s), then run: script/smoke.sh
# Each run uses fresh emails, so it can be re-run without resetting the DB.
set -u

BASE=${BASE:-http://localhost:3000}
RUN=$(date +%s)
PASS=0
FAIL=0

# req METHOD PATH [TOKEN] [JSON_BODY]  -> sets $STATUS and $BODY
req() {
  local method=$1 path=$2 token=${3:-} data=${4:-}
  local out
  out=$(mktemp)
  local args=(-s -X "$method" "$BASE$path" -H "Content-Type: application/json" -o "$out" -w "%{http_code}")
  [[ -n $token ]] && args+=(-H "Authorization: Bearer $token")
  [[ -n $data ]] && args+=(-d "$data")
  STATUS=$(curl "${args[@]}")
  BODY=$(cat "$out")
  rm -f "$out"
}

# json FILTER  -> extracts a value from $BODY with jq (empty if missing / not JSON).
# select(. != null) rather than `// empty`, because `//` also swallows a real `false`.
json() { echo "$BODY" | jq -r "($1) | select(. != null)" 2>/dev/null; }

pass() { PASS=$((PASS + 1)); printf "  \033[32m✓\033[0m %s\n" "$1"; }
fail() { FAIL=$((FAIL + 1)); printf "  \033[31m✗\033[0m %s\n      %s\n" "$1" "${BODY:0:300}"; }

# check "description" EXPECTED_STATUS
check() {
  if [[ $STATUS == "$2" ]]; then pass "$1 ($STATUS)"; else fail "$1: expected $2, got $STATUS"; fi
}

# check_eq "description" EXPECTED ACTUAL
check_eq() {
  if [[ $2 == "$3" ]]; then pass "$1"; else fail "$1: expected '$2', got '$3'"; fi
}

echo "== Auth"
req POST /signup "" "{\"user\":{\"name\":\"Bob\",\"email\":\"bob$RUN@x.com\",\"password\":\"secret123\"}}"
check "signup Bob" 201
BOB=$(json .token)
BOB_ID=$(json .user.id)

req POST /signup "" "{\"user\":{\"name\":\"Alice\",\"email\":\"alice$RUN@x.com\",\"password\":\"secret123\"}}"
check "signup Alice" 201
ALICE=$(json .token)
ALICE_ID=$(json .user.id)

req POST /signup "" "{\"user\":{\"name\":\"Bob2\",\"email\":\"BOB$RUN@x.com\",\"password\":\"secret123\"}}"
check "signup with duplicate email (different case)" 422

req POST /signup "" "{\"user\":{\"name\":\"Short\",\"email\":\"short$RUN@x.com\",\"password\":\"123\"}}"
check "signup with too-short password" 422

req POST /login "" "{\"email\":\"bob$RUN@x.com\",\"password\":\"wrong\"}"
check "login with wrong password" 401

req POST /login "" "{\"email\":\"bob$RUN@x.com\",\"password\":\"secret123\"}"
check "login Bob" 200

req GET /me
check "/me without token" 401

req GET /me "${BOB}x"
check "/me with tampered token" 401

req GET /me "$BOB"
check "/me with valid token" 200
check_eq "/me does not leak password_digest" "" "$(json .password_digest)"

echo "== Posts"
req GET /posts
check "list posts without token" 401

req POST /posts "$BOB" "{\"post\":{\"title\":\"Hello\",\"body\":\"First post\",\"user_id\":$ALICE_ID}}"
check "Bob creates a post" 201
POST_ID=$(json .id)
check_eq "post author is Bob even though user_id=Alice was sent" "$BOB_ID" "$(json .author.id)"
check_eq "post is unpublished by default" "false" "$(json .published)"

req POST /posts "$BOB" '{"post":{"body":"no title"}}'
check "create post without title" 422

req POST /posts "$BOB" '{"title":"Unwrapped","body":"ParamsWrapper should handle this"}'
check "create post without the {\"post\": ...} wrapper" 201

req POST /posts "$BOB" '{"post":"hello"}'
check "create post with malformed params" 400

req GET /posts "$ALICE"
check "Alice lists posts" 200

req GET "/posts/$POST_ID" "$ALICE"
check "Alice reads Bob's post" 200

req GET /posts/999999 "$BOB"
check "read non-existent post" 404

req PATCH "/posts/$POST_ID" "$ALICE" '{"post":{"title":"Hacked"}}'
check "Alice updates Bob's post" 404

req DELETE "/posts/$POST_ID" "$ALICE"
check "Alice deletes Bob's post" 404

req PATCH "/posts/$POST_ID" "$BOB" '{"post":{"title":"Hello, edited","published":true}}'
check "Bob updates his post" 200
check_eq "title was updated" "Hello, edited" "$(json .title)"

req PATCH "/posts/$POST_ID" "$BOB" '{"post":{"title":""}}'
check "Bob updates his post with blank title" 422

echo "== Comments"
req GET "/posts/$POST_ID/comments" "$BOB"
check "list comments" 200

req POST "/posts/$POST_ID/comments" "$ALICE" '{"comment":{"body":"Nice post!"}}'
check "Alice comments on Bob's post" 201
COMMENT_ID=$(json .id)
check_eq "comment author is Alice" "$ALICE_ID" "$(json .author.id)"

req POST "/posts/$POST_ID/comments" "$ALICE" '{"comment":{"body":""}}'
check "comment with blank body" 422

req POST /posts/999999/comments "$ALICE" '{"comment":{"body":"Hi"}}'
check "comment on non-existent post" 404

req GET /posts/999999/comments "$ALICE"
check "list comments of non-existent post" 404

req DELETE "/posts/$POST_ID/comments/$COMMENT_ID" "$BOB"
check "Bob deletes Alice's comment" 404

req POST /posts "$BOB" '{"post":{"title":"Other","body":"Another post"}}'
OTHER_POST_ID=$(json .id)
req DELETE "/posts/$OTHER_POST_ID/comments/$COMMENT_ID" "$ALICE"
check "Alice deletes her comment via the wrong post URL" 404

req DELETE "/posts/$POST_ID/comments/$COMMENT_ID" "$ALICE"
check "Alice deletes her own comment" 204

echo "== Cascade delete"
req POST "/posts/$POST_ID/comments" "$ALICE" '{"comment":{"body":"Another one"}}'
check "Alice comments again" 201

req DELETE "/posts/$POST_ID" "$BOB"
check "Bob deletes his post" 204
check_eq "204 response has empty body" "" "$BODY"

req GET "/posts/$POST_ID" "$BOB"
check "deleted post is gone" 404

req GET "/posts/$POST_ID/comments" "$BOB"
check "comments of deleted post are gone" 404

echo
printf "Passed: \033[32m%d\033[0m  Failed: \033[31m%d\033[0m\n" "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
