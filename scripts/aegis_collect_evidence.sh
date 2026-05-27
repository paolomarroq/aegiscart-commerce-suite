#!/usr/bin/env bash
# AegisCart - Proyecto final Sistemas Operativos
# Proposito: recolectar evidencia operativa de srv-app para entrega final.

set -uo pipefail

EVIDENCE_DIR="/opt/aegiscart/evidencias"
PRIMARY_LOG_DIR="/var/log/aegiscart"
FALLBACK_LOG_DIR="/opt/aegiscart/evidencias/runtime_logs"
LOG_DIR="$PRIMARY_LOG_DIR"
if ! mkdir -p "$LOG_DIR" 2>/dev/null || [[ ! -w "$LOG_DIR" ]]; then
  LOG_DIR="$FALLBACK_LOG_DIR"
  mkdir -p "$LOG_DIR"
fi
SCRIPT_DIR="/opt/aegiscart/scripts"
BASE_URL="http://127.0.0.1:5000"
STAMP="$(date +%Y%m%d_%H%M%S)"
OUT="$EVIDENCE_DIR/srv-app_evidencia_$STAMP.txt"

mkdir -p "$EVIDENCE_DIR" "$LOG_DIR"
run_section() {
  local title="$1"
  shift
  {
    echo
    echo "===== $title ====="
    "$@"
  } >> "$OUT" 2>&1 || {
    local rc=$?
    echo "status=command_failed rc=$rc command=$*" >> "$OUT"
  }
}
run_sudo_section() {
  local title="$1"
  shift
  {
    echo
    echo "===== $title ====="
    if sudo -n true >/dev/null 2>&1; then
      sudo "$@"
    else
      echo "status=sudo_required message='sudo requiere contrasena interactiva; comando omitido: sudo $*'"
    fi
  } >> "$OUT" 2>&1 || {
    local rc=$?
    echo "status=command_failed rc=$rc command=sudo $*" >> "$OUT"
  }
}

{
  echo "AegisCart evidencia srv-app"
  echo "timestamp=$(date -Is)"
  echo "server=$(hostname -f 2>/dev/null || hostname)"
} > "$OUT"

run_section "hostnamectl" hostnamectl
run_section "ip -br a" ip -br a
run_sudo_section "ufw status" ufw status
run_sudo_section "systemctl status aegiscart --no-pager" systemctl status aegiscart --no-pager
run_sudo_section "ss -tulpn" ss -tulpn
run_section "curl /health" curl -sS "$BASE_URL/health"
run_section "curl /api/products" curl -sS "$BASE_URL/api/products"
run_section "crontab -l" crontab -l
run_section "lista de scripts" ls -l "$SCRIPT_DIR"
{
  echo
  echo "===== ultimas lineas logs /var/log/aegiscart/*.log ====="
  shopt -s nullglob
  for file in "$LOG_DIR"/*.log; do
    echo "--- $file ---"
    tail -n 40 "$file"
  done
} >> "$OUT" 2>&1

echo "Evidencia generada: $OUT"
