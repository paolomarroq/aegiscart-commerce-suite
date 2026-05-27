#!/usr/bin/env bash
# AegisCart - Proyecto final Sistemas Operativos
# Proposito: transferir logs generados en srv-app hacia srv-zbx cuando SSH sin contrasena este configurado.

set -uo pipefail

PRIMARY_LOG_DIR="/var/log/aegiscart"
FALLBACK_LOG_DIR="/opt/aegiscart/evidencias/runtime_logs"
LOG_DIR="$PRIMARY_LOG_DIR"
if ! mkdir -p "$LOG_DIR" 2>/dev/null || [[ ! -w "$LOG_DIR" ]]; then
  LOG_DIR="$FALLBACK_LOG_DIR"
  mkdir -p "$LOG_DIR"
  echo "warning=primary_log_dir_unwritable primary=$PRIMARY_LOG_DIR fallback=$LOG_DIR" >&2
fi
TRANSFER_LOG="$LOG_DIR/transfer_to_zbx.log"
ZBX_HOST="192.168.6.150"
ZBX_USER="adminos"
ZBX_TARGET="$ZBX_USER@$ZBX_HOST"
REMOTE_DIR="/tmp/aegiscart-logs"
SERVER="$(hostname -f 2>/dev/null || hostname)"
TIMESTAMP="$(date -Is)"

{
  echo "===== timestamp=$TIMESTAMP server=$SERVER target=$ZBX_TARGET event=transfer_to_zbx ====="
  shopt -s nullglob
  files=("$LOG_DIR"/*.log)
  if (( ${#files[@]} == 0 )); then
    echo "status=no_files message='No existen logs locales en $LOG_DIR/*.log'"
    exit 0
  fi

  if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "$ZBX_TARGET" "mkdir -p '$REMOTE_DIR'" >/dev/null 2>&1; then
    echo "status=ssh_required message='No hay SSH sin contrasena hacia $ZBX_TARGET; no se copian archivos'"
    exit 0
  fi

  for file in "${files[@]}"; do
    if [[ -f "$file" ]]; then
      if scp -o BatchMode=yes -o ConnectTimeout=5 "$file" "$ZBX_TARGET:$REMOTE_DIR/" >/dev/null 2>&1; then
        echo "status=ok file=$file remote=$ZBX_TARGET:$REMOTE_DIR/"
      else
        echo "status=copy_failed file=$file remote=$ZBX_TARGET:$REMOTE_DIR/"
      fi
    else
      echo "status=missing file=$file"
    fi
  done
  echo
} >> "$TRANSFER_LOG"
