#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:5000}"

curl -fsS "$BASE_URL/health"
echo
curl -fsS "$BASE_URL/api/products"
echo
curl -fsS "$BASE_URL/api/orders"
echo
curl -fsS -X POST "$BASE_URL/api/checkout-test" \
  -H "Content-Type: application/json" \
  -d '{"force_fail": false}'
echo
curl -fsS -X POST "$BASE_URL/api/checkout-test" \
  -H "Content-Type: application/json" \
  -d '{"force_fail": true}' || true
echo
