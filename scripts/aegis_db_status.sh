#!/usr/bin/env bash
# AegisCart - Proyecto final Sistemas Operativos
# Proposito: validar conectividad desde srv-app hacia MariaDB en srv-db.
# Formato: timestamp,server,target,status,message

set -uo pipefail

PRIMARY_LOG_DIR="/var/log/aegiscart"
FALLBACK_LOG_DIR="/opt/aegiscart/evidencias/runtime_logs"
LOG_DIR="$PRIMARY_LOG_DIR"
if ! mkdir -p "$LOG_DIR" 2>/dev/null || [[ ! -w "$LOG_DIR" ]]; then
  LOG_DIR="$FALLBACK_LOG_DIR"
  mkdir -p "$LOG_DIR"
  echo "warning=primary_log_dir_unwritable primary=$PRIMARY_LOG_DIR fallback=$LOG_DIR" >&2
fi
LOG_FILE="$LOG_DIR/db_status.log"
APP_DIR="/opt/aegiscart/aegiscart-app"
ENV_FILE="$APP_DIR/.env"
SERVER="$(hostname -f 2>/dev/null || hostname)"
TARGET="192.168.6.143:3306"
TIMESTAMP="$(date -Is)"
DB_HOST="192.168.6.143"
DB_USER="aegiscart_user"
DB_NAME="aegiscart"
DB_PASSWORD=""

if [[ -r "$ENV_FILE" ]]; then
  DB_HOST="$(awk -F= '/^DB_HOST=/{print $2}' "$ENV_FILE" | tail -n1)"
  DB_USER="$(awk -F= '/^DB_USER=/{print $2}' "$ENV_FILE" | tail -n1)"
  DB_NAME="$(awk -F= '/^DB_NAME=/{print $2}' "$ENV_FILE" | tail -n1)"
  DB_PASSWORD="$(awk -F= '/^DB_PASSWORD=/{print $2}' "$ENV_FILE" | tail -n1)"
  TARGET="$DB_HOST:3306"
fi

if command -v mysqladmin >/dev/null 2>&1 && [[ -n "$DB_PASSWORD" ]]; then
  if MYSQL_PWD="$DB_PASSWORD" mysqladmin ping -h "$DB_HOST" -u "$DB_USER" --silent >/dev/null 2>&1; then
    echo "$TIMESTAMP,$SERVER,$TARGET,ok,mysqladmin_ping_ok" >> "$LOG_FILE"
  else
    echo "$TIMESTAMP,$SERVER,$TARGET,error,mysqladmin_ping_failed" >> "$LOG_FILE"
  fi
elif command -v mysql >/dev/null 2>&1 && [[ -n "$DB_PASSWORD" ]]; then
  if MYSQL_PWD="$DB_PASSWORD" mysql -h "$DB_HOST" -u "$DB_USER" "$DB_NAME" -e "SELECT 1;" >/dev/null 2>&1; then
    echo "$TIMESTAMP,$SERVER,$TARGET,ok,mysql_select_ok" >> "$LOG_FILE"
  else
    echo "$TIMESTAMP,$SERVER,$TARGET,error,mysql_select_failed" >> "$LOG_FILE"
  fi
else
  echo "$TIMESTAMP,$SERVER,$TARGET,error,mysql_client_or_password_missing" >> "$LOG_FILE"
fi
