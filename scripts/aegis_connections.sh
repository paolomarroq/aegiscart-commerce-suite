#!/usr/bin/env bash
# AegisCart - Proyecto final Sistemas Operativos
# Proposito: registrar conexiones de red establecidas en srv-app para evidencia operativa.
# Grupo/proyecto: AegisCart e-commerce con Flask, MariaDB, Elasticsearch/Kibana y Zabbix.

set -uo pipefail

PRIMARY_LOG_DIR="/var/log/aegiscart"
FALLBACK_LOG_DIR="/opt/aegiscart/evidencias/runtime_logs"
LOG_DIR="$PRIMARY_LOG_DIR"
if ! mkdir -p "$LOG_DIR" 2>/dev/null || [[ ! -w "$LOG_DIR" ]]; then
  LOG_DIR="$FALLBACK_LOG_DIR"
  mkdir -p "$LOG_DIR"
  echo "warning=primary_log_dir_unwritable primary=$PRIMARY_LOG_DIR fallback=$LOG_DIR" >&2
fi
LOG_FILE="$LOG_DIR/connections.log"
SERVER="$(hostname -f 2>/dev/null || hostname)"
TIMESTAMP="$(date -Is)"

{
  echo "===== timestamp=$TIMESTAMP server=$SERVER event=connections ====="
  if command -v ss >/dev/null 2>&1; then
    ss -tan state established
  elif command -v netstat >/dev/null 2>&1; then
    netstat -tan | awk 'NR==1 || /ESTABLISHED/'
  else
    echo "status=error message='ss/netstat no disponible'"
  fi
  echo
} >> "$LOG_FILE" 2>&1
