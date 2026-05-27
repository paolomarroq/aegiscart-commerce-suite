#!/usr/bin/env bash
# AegisCart - Proyecto final Sistemas Operativos
# Proposito: probar endpoints criticos Flask/API y registrar evidencia sin imprimir secretos.

set -uo pipefail

PRIMARY_LOG_DIR="/var/log/aegiscart"
FALLBACK_LOG_DIR="/opt/aegiscart/evidencias/runtime_logs"
LOG_DIR="$PRIMARY_LOG_DIR"
if ! mkdir -p "$LOG_DIR" 2>/dev/null || [[ ! -w "$LOG_DIR" ]]; then
  LOG_DIR="$FALLBACK_LOG_DIR"
  mkdir -p "$LOG_DIR"
  echo "warning=primary_log_dir_unwritable primary=$PRIMARY_LOG_DIR fallback=$LOG_DIR" >&2
fi
LOG_FILE="$LOG_DIR/app_smoke_test.log"
BASE_URL="http://127.0.0.1:5000"
SERVER="$(hostname -f 2>/dev/null || hostname)"
TIMESTAMP="$(date -Is)"

{
  echo "===== timestamp=$TIMESTAMP server=$SERVER event=app_smoke_test ====="
  echo "--- GET /health ---"
  curl -sS "$BASE_URL/health" || true
  echo
  echo "--- GET /api/products ---"
  curl -sS "$BASE_URL/api/products" || true
  echo
  echo "--- POST /api/checkout-test force_fail=false ---"
  curl -sS -X POST "$BASE_URL/api/checkout-test" -H "Content-Type: application/json" -d '{"force_fail": false}' || true
  echo
  echo "--- POST /api/checkout-test force_fail=true ---"
  curl -sS -X POST "$BASE_URL/api/checkout-test" -H "Content-Type: application/json" -d '{"force_fail": true}' || true
  echo
  echo
} >> "$LOG_FILE" 2>&1
