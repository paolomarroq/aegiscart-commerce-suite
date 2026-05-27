#!/usr/bin/env bash
# AegisCart - Proyecto final Sistemas Operativos
# Proposito: recolectar CPU/memoria de srv-db via SSH; si no hay llave, dejar evidencia clara.

set -uo pipefail

PRIMARY_LOG_DIR="/var/log/aegiscart"
FALLBACK_LOG_DIR="/opt/aegiscart/evidencias/runtime_logs"
LOG_DIR="$PRIMARY_LOG_DIR"
if ! mkdir -p "$LOG_DIR" 2>/dev/null || [[ ! -w "$LOG_DIR" ]]; then
  LOG_DIR="$FALLBACK_LOG_DIR"
  mkdir -p "$LOG_DIR"
  echo "warning=primary_log_dir_unwritable primary=$PRIMARY_LOG_DIR fallback=$LOG_DIR" >&2
fi
LOG_FILE="$LOG_DIR/db_resources.log"
SERVER="$(hostname -f 2>/dev/null || hostname)"
DB_HOST="192.168.6.143"
DB_USER="adminos"
TARGET="$DB_USER@$DB_HOST"
TIMESTAMP="$(date -Is)"

{
  echo "===== timestamp=$TIMESTAMP server=$SERVER target=$TARGET event=db_resources ====="
  if ping -c 1 -W 2 "$DB_HOST" >/dev/null 2>&1; then
    echo "status=ping_ok message='srv-db responde ICMP'"
  else
    echo "status=ping_failed message='srv-db no responde ICMP o ICMP bloqueado'"
  fi

  if ssh -o BatchMode=yes -o ConnectTimeout=5 "$TARGET" "hostname; echo '--- top ---'; top -b -n1 | head -n 15; echo '--- free ---'; free -h; echo '--- vmstat ---'; vmstat 1 2" 2>&1; then
    echo "status=ok message='ssh_resource_collection_ok'"
  else
    echo "status=ssh_required message='No hay SSH sin contrasena/llave hacia $TARGET o el acceso fue rechazado'"
  fi
  echo
} >> "$LOG_FILE"
