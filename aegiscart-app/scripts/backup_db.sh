#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${ENV_FILE:-.env}"
BACKUP_DIR="${BACKUP_DIR:-backups/db}"
REMOTE_BACKUP="${REMOTE_BACKUP:-1}"
REMOTE_USER="${REMOTE_USER:-adminos}"
REMOTE_HOST="${REMOTE_HOST:-192.168.6.143}"
REMOTE_DIR="${REMOTE_DIR:-/home/adminos/db-backups/aegiscart}"

if [ -f "${ENV_FILE}" ]; then
  set -a
  . "${ENV_FILE}"
  set +a
fi

DB_HOST="${DB_HOST:-192.168.6.143}"
DB_PORT="${DB_PORT:-3306}"
DB_NAME="${DB_NAME:-aegiscart}"
DB_USER="${DB_USER:-aegiscart_user}"

if [ -z "${DB_PASSWORD:-}" ]; then
  echo "DB_PASSWORD is required. Check ${ENV_FILE} or export DB_PASSWORD." >&2
  exit 1
fi

if command -v mariadb-dump >/dev/null 2>&1; then
  DUMP_BIN="mariadb-dump"
elif command -v mysqldump >/dev/null 2>&1; then
  DUMP_BIN="mysqldump"
else
  echo "mariadb-dump or mysqldump is required." >&2
  exit 1
fi

mkdir -p "${BACKUP_DIR}"

timestamp="$(date +%Y%m%d_%H%M%S)"
backup_file="${BACKUP_DIR}/${DB_NAME}_${timestamp}.sql.gz"

echo "Creating backup: ${backup_file}"

MYSQL_PWD="${DB_PASSWORD}" "${DUMP_BIN}" \
  -h "${DB_HOST}" \
  -P "${DB_PORT}" \
  -u "${DB_USER}" \
  --single-transaction \
  --routines \
  --triggers \
  "${DB_NAME}" | gzip > "${backup_file}"

echo "Backup completed: ${backup_file}"

if [ "${REMOTE_BACKUP}" = "1" ]; then
  if ! command -v ssh >/dev/null 2>&1; then
    echo "ssh is required to create the remote backup directory." >&2
    exit 1
  fi

  if ! command -v scp >/dev/null 2>&1; then
    echo "scp is required to copy the backup to srv-db." >&2
    exit 1
  fi

  echo "Copying backup to ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/"
  ssh "${REMOTE_USER}@${REMOTE_HOST}" "mkdir -p '${REMOTE_DIR}'"
  scp "${backup_file}" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/"
  echo "Remote backup completed: ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/$(basename "${backup_file}")"
fi
