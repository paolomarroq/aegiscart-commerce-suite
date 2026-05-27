#!/usr/bin/env bash
set -euo pipefail

APP_URL="${APP_URL:-http://127.0.0.1:5000}"
TOTAL="${TOTAL:-500}"
CONCURRENCY="${CONCURRENCY:-20}"
RESTOCK="${RESTOCK:-1}"
RESTOCK_STOCK="${RESTOCK_STOCK:-100000}"
ENV_FILE="${ENV_FILE:-.env}"

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required" >&2
  exit 1
fi

if ! command -v xargs >/dev/null 2>&1; then
  echo "xargs is required" >&2
  exit 1
fi

if [ ! -x ./venv/bin/python ]; then
  echo "./venv/bin/python is required" >&2
  exit 1
fi

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
  echo "DB_PASSWORD is required. Check ${ENV_FILE}." >&2
  exit 1
fi

echo "Generating checkout load"
echo "APP_URL=${APP_URL}"
echo "TOTAL=${TOTAL}"
echo "CONCURRENCY=${CONCURRENCY}"
echo "MIX=75% valid / 25% failed"
echo "FAILURES=empty_cart, invalid_cart, insufficient_stock"
echo "RESTOCK=${RESTOCK}"
echo "RESTOCK_STOCK=${RESTOCK_STOCK}"
echo

if [ "${RESTOCK}" = "1" ]; then
  if command -v mysql >/dev/null 2>&1; then
    MYSQL_PWD="${DB_PASSWORD}" mysql \
      -h "${DB_HOST}" \
      -P "${DB_PORT}" \
      -u "${DB_USER}" \
      "${DB_NAME}" \
      -e "UPDATE products SET stock=${RESTOCK_STOCK}, status='active';"
  else
    ./venv/bin/python - <<'PYRESTOCK'
import os
import pymysql

conn = pymysql.connect(
    host=os.getenv('DB_HOST', '192.168.6.143'),
    port=int(os.getenv('DB_PORT', '3306')),
    user=os.getenv('DB_USER', 'aegiscart_user'),
    password=os.environ['DB_PASSWORD'],
    database=os.getenv('DB_NAME', 'aegiscart'),
    autocommit=False,
)
try:
    with conn.cursor() as cursor:
        cursor.execute('UPDATE products SET stock=%s, status=%s', (int(os.environ.get('RESTOCK_STOCK', '100000')), 'active'))
    conn.commit()
finally:
    conn.close()
PYRESTOCK
  fi
  echo "Stock recargado para permitir checkouts validos."
  echo
fi

eval "$(./venv/bin/python - <<'PYCOOKIES'
import os
import shlex
from flask.sessions import SecureCookieSessionInterface
from app import app, get_db_connection

stock = int(os.environ.get('RESTOCK_STOCK', '100000'))
conn = get_db_connection()
try:
    with conn.cursor() as cursor:
        cursor.execute("SELECT id FROM products WHERE status='active' ORDER BY id LIMIT 1")
        row = cursor.fetchone()
finally:
    conn.close()

if not row:
    raise SystemExit('No active product found for failure-cookie generation')

serializer = SecureCookieSessionInterface().get_signing_serializer(app)
invalid_cookie = serializer.dumps({'cart': {'999999999': 1}})
oversell_cookie = serializer.dumps({'cart': {str(row['id']): stock + 1}})
print('INVALID_CART_COOKIE=' + shlex.quote(invalid_cookie))
print('OVERSELL_CART_COOKIE=' + shlex.quote(oversell_cookie))
PYCOOKIES
)"

export APP_URL INVALID_CART_COOKIE OVERSELL_CART_COOKIE

seq 1 "${TOTAL}" | xargs -I{} -P "${CONCURRENCY}" sh -c '
n="$1"
case $((n % 4)) in
  0)
    case $((n % 12)) in
      0)
        curl -sS -o /dev/null -w "failed_empty_cart request=${n} http=%{http_code}\n" \
          -X POST "$APP_URL/checkout" \
          -d "customer_name=Load Test" \
          -d "customer_email=empty-cart@aegiscart.local"
        ;;
      4)
        curl -sS -o /dev/null -w "failed_invalid_cart request=${n} http=%{http_code}\n" \
          -H "Cookie: session=${INVALID_CART_COOKIE}" \
          -X POST "$APP_URL/checkout" \
          -d "customer_name=Load Test" \
          -d "customer_email=invalid-cart@aegiscart.local"
        ;;
      *)
        curl -sS -o /dev/null -w "failed_insufficient_stock request=${n} http=%{http_code}\n" \
          -H "Cookie: session=${OVERSELL_CART_COOKIE}" \
          -X POST "$APP_URL/checkout" \
          -d "customer_name=Load Test" \
          -d "customer_email=insufficient-stock@aegiscart.local"
        ;;
    esac
    ;;
  *)
    curl -sS -o /dev/null -w "valid_checkout request=${n} http=%{http_code}\n" \
      -H "Content-Type: application/json" \
      -X POST "$APP_URL/api/checkout-test" \
      -d "{}"
    ;;
esac
' sh {}
