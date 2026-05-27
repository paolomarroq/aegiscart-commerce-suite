#!/usr/bin/env bash
# AegisCart - Proyecto final Sistemas Operativos
# Proposito: verificar eventos checkout_success y checkout_failed en Elasticsearch sin imprimir credenciales.

set -uo pipefail

PRIMARY_LOG_DIR="/var/log/aegiscart"
FALLBACK_LOG_DIR="/opt/aegiscart/evidencias/runtime_logs"
LOG_DIR="$PRIMARY_LOG_DIR"
if ! mkdir -p "$LOG_DIR" 2>/dev/null || [[ ! -w "$LOG_DIR" ]]; then
  LOG_DIR="$FALLBACK_LOG_DIR"
  mkdir -p "$LOG_DIR"
  echo "warning=primary_log_dir_unwritable primary=$PRIMARY_LOG_DIR fallback=$LOG_DIR" >&2
fi
LOG_FILE="$LOG_DIR/elastic_verify.log"
APP_DIR="/opt/aegiscart/aegiscart-app"
ENV_FILE="$APP_DIR/.env"
SERVER="$(hostname -f 2>/dev/null || hostname)"
TIMESTAMP="$(date -Is)"
ELASTIC_URL="https://192.168.6.200:9200"
ELASTIC_USER="elastic"
ELASTIC_PASSWORD=""
INDEX_PATTERN="aegiscart-app-logs*"

if [[ -r "$ENV_FILE" ]]; then
  ELASTIC_URL="$(awk -F= '/^ELASTIC_URL=/{print $2}' "$ENV_FILE" | tail -n1)"
  ELASTIC_USER="$(awk -F= '/^ELASTIC_USER=/{print $2}' "$ENV_FILE" | tail -n1)"
  ELASTIC_PASSWORD="$(awk -F= '/^ELASTIC_PASSWORD=/{print $2}' "$ENV_FILE" | tail -n1)"
fi

{
  echo "===== timestamp=$TIMESTAMP server=$SERVER event=elastic_verify url=$ELASTIC_URL index=$INDEX_PATTERN ====="
  if [[ -z "$ELASTIC_PASSWORD" ]]; then
    echo "status=error message='ELASTIC_PASSWORD no configurado'"
    exit 0
  fi
  echo "--- checkout_success ---"
  curl -ksS -u "$ELASTIC_USER:$ELASTIC_PASSWORD" "$ELASTIC_URL/$INDEX_PATTERN/_search?q=checkout_success&pretty" | sed -E 's/(Authorization: Basic )[A-Za-z0-9+\/=]+/\1REDACTED/g'
  echo "--- checkout_failed ---"
  curl -ksS -u "$ELASTIC_USER:$ELASTIC_PASSWORD" "$ELASTIC_URL/$INDEX_PATTERN/_search?q=checkout_failed&pretty" | sed -E 's/(Authorization: Basic )[A-Za-z0-9+\/=]+/\1REDACTED/g'
  echo
} >> "$LOG_FILE" 2>&1
