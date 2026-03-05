#!/bin/bash
# validate-deployment.sh
# Validates that the lineup-optim deployment is fully operational by testing
# all service endpoints through the ALB.
#
# Tests:
#   1. Web_App health endpoint returns HTTP 200
#   2. Web_Server health endpoint returns HTTP 200
#   3. Web_App static files serve the Next.js page
#   4. Web_Server optimizer endpoint accepts POST and returns valid JSON
#
# Requirements: 14.1, 14.2, 14.3
#
# Prerequisites: curl, jq
# Usage: ./scripts/validate-deployment.sh [alb_url]
#   alb_url: optional ALB base URL (defaults to the slugger ALB)

set -euo pipefail

ALB_URL="${1:-https://slugger-alb-1518464736.us-east-2.elb.amazonaws.com}"
TIMEOUT=30
PASS_COUNT=0
FAIL_COUNT=0
RESULTS=()

echo "=== Lineup-Optim Deployment Validator ==="
echo "ALB URL: ${ALB_URL}"
echo ""

# Verify curl and jq are available
for cmd in curl jq; do
  if ! command -v "$cmd" &> /dev/null; then
    echo "ERROR: '${cmd}' is required but not installed."
    exit 1
  fi
done

# Helper: record a test result
record_result() {
  local name="$1"
  local status="$2"
  local detail="$3"

  if [ "$status" = "PASS" ]; then
    PASS_COUNT=$((PASS_COUNT + 1))
    RESULTS+=("  [PASS] ${name}")
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    RESULTS+=("  [FAIL] ${name} — ${detail}")
  fi
}

# --- Test 1: Web_App health endpoint ---
echo "--- Test 1: Web_App health endpoint ---"
ENDPOINT="/widgets/lineup/api/health"
HTTP_CODE=$(curl -k -s -o /tmp/va_health_app.json -w "%{http_code}" --max-time "$TIMEOUT" "${ALB_URL}${ENDPOINT}" 2>/dev/null || echo "000")
echo "  ${ENDPOINT} -> HTTP ${HTTP_CODE}"

if [ "$HTTP_CODE" = "200" ]; then
  record_result "Web_App health (${ENDPOINT})" "PASS" ""
else
  record_result "Web_App health (${ENDPOINT})" "FAIL" "expected HTTP 200, got ${HTTP_CODE}"
fi

# --- Test 2: Web_Server health endpoint ---
echo ""
echo "--- Test 2: Web_Server health endpoint ---"
ENDPOINT="/widgets/lineup/api/optimizer/health"
HTTP_CODE=$(curl -k -s -o /tmp/va_health_server.json -w "%{http_code}" --max-time "$TIMEOUT" "${ALB_URL}${ENDPOINT}" 2>/dev/null || echo "000")
echo "  ${ENDPOINT} -> HTTP ${HTTP_CODE}"

if [ "$HTTP_CODE" = "200" ]; then
  record_result "Web_Server health (${ENDPOINT})" "PASS" ""
else
  record_result "Web_Server health (${ENDPOINT})" "FAIL" "expected HTTP 200, got ${HTTP_CODE}"
fi

# --- Test 3: Web_App static files (Next.js page) ---
echo ""
echo "--- Test 3: Web_App static files ---"
ENDPOINT="/widgets/lineup/"
RESPONSE=$(curl -k -s --max-time "$TIMEOUT" "${ALB_URL}${ENDPOINT}" 2>/dev/null || echo "")
HTTP_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT" "${ALB_URL}${ENDPOINT}" 2>/dev/null || echo "000")
echo "  ${ENDPOINT} -> HTTP ${HTTP_CODE}"

if [ "$HTTP_CODE" = "200" ] && echo "$RESPONSE" | grep -qi "<!doctype\|<html\|__next\|_next"; then
  record_result "Web_App static files (${ENDPOINT})" "PASS" ""
elif [ "$HTTP_CODE" = "200" ]; then
  record_result "Web_App static files (${ENDPOINT})" "FAIL" "HTTP 200 but response does not look like a Next.js page"
else
  record_result "Web_App static files (${ENDPOINT})" "FAIL" "expected HTTP 200 with HTML, got ${HTTP_CODE}"
fi

# --- Test 4: Web_Server optimizer POST endpoint ---
echo ""
echo "--- Test 4: Web_Server optimizer endpoint ---"
ENDPOINT="/widgets/lineup/api/optimizer/optimize-lineup"
TEST_PAYLOAD='{"lineup":[],"settings":{}}'

HTTP_CODE=$(curl -k -s -o /tmp/va_optimizer.json -w "%{http_code}" \
  --max-time "$TIMEOUT" \
  -X POST \
  -H "Content-Type: application/json" \
  -d "$TEST_PAYLOAD" \
  "${ALB_URL}${ENDPOINT}" 2>/dev/null || echo "000")
echo "  POST ${ENDPOINT} -> HTTP ${HTTP_CODE}"

# Accept any 2xx or 4xx (400 is valid — means the server processed the request and rejected bad input)
if [ "$HTTP_CODE" -ge 200 ] 2>/dev/null && [ "$HTTP_CODE" -lt 500 ] 2>/dev/null; then
  # Verify the response is valid JSON
  if jq empty /tmp/va_optimizer.json 2>/dev/null; then
    record_result "Web_Server optimizer POST (${ENDPOINT})" "PASS" ""
  else
    record_result "Web_Server optimizer POST (${ENDPOINT})" "FAIL" "HTTP ${HTTP_CODE} but response is not valid JSON"
  fi
else
  record_result "Web_Server optimizer POST (${ENDPOINT})" "FAIL" "expected HTTP 2xx/4xx with JSON, got ${HTTP_CODE}"
fi

# --- Summary ---
echo ""
echo "=== Validation Summary ==="
TOTAL=$((PASS_COUNT + FAIL_COUNT))
echo "  Total: ${TOTAL}  |  Passed: ${PASS_COUNT}  |  Failed: ${FAIL_COUNT}"
echo ""
for result in "${RESULTS[@]}"; do
  echo "$result"
done
echo ""

# Cleanup temp files
rm -f /tmp/va_health_app.json /tmp/va_health_server.json /tmp/va_optimizer.json

if [ "$FAIL_COUNT" -gt 0 ]; then
  echo "Deployment validation FAILED."
  exit 1
fi

echo "Deployment validation PASSED — all endpoints operational."
exit 0
