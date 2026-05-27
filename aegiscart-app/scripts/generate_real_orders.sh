#!/usr/bin/env bash
set -euo pipefail

APP_URL="${APP_URL:-http://127.0.0.1:5000}"
TOTAL="${TOTAL:-200}"
FAIL_EVERY="${FAIL_EVERY:-20}"
CONCURRENCY="${CONCURRENCY:-5}"
PLAN_FILE="${PLAN_FILE:-/tmp/aegiscart_real_orders_plan.tsv}"

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required" >&2
  exit 1
fi

if ! command -v xargs >/dev/null 2>&1; then
  echo "xargs is required" >&2
  exit 1
fi

if [ ! -x ./venv/bin/python ]; then
  echo "./venv/bin/python is required. Run this from /opt/aegiscart/aegiscart-app." >&2
  exit 1
fi

echo "Generating real order load"
echo "APP_URL=${APP_URL}"
echo "TOTAL=${TOTAL}"
echo "FAIL_EVERY=${FAIL_EVERY}"
echo "CONCURRENCY=${CONCURRENCY}"
echo "PLAN_FILE=${PLAN_FILE}"
echo

TOTAL="${TOTAL}" FAIL_EVERY="${FAIL_EVERY}" PLAN_FILE="${PLAN_FILE}" ./venv/bin/python - <<'PYPLAN'
import os
from collections import Counter

from flask.sessions import SecureCookieSessionInterface

from app import app, get_db_connection

total = int(os.environ.get("TOTAL", "200"))
fail_every = int(os.environ.get("FAIL_EVERY", "20"))
plan_file = os.environ.get("PLAN_FILE", "/tmp/aegiscart_real_orders_plan.tsv")

if total < 1:
    raise SystemExit("TOTAL must be greater than 0")
if fail_every < 2:
    raise SystemExit("FAIL_EVERY must be greater than 1")

conn = get_db_connection()
try:
    with conn.cursor() as cursor:
        cursor.execute(
            """
            INSERT INTO products (name, description, price, stock, status)
            SELECT %s, %s, %s, %s, %s
            WHERE NOT EXISTS (SELECT 1 FROM products WHERE name=%s)
            """,
            (
                "Aegis Load Failure Item",
                "Producto dedicado para pruebas reales de orden fallida por stock insuficiente.",
                "1.00",
                0,
                "active",
                "Aegis Load Failure Item",
            ),
        )
        cursor.execute(
            "SELECT id FROM products WHERE name=%s ORDER BY id LIMIT 1",
            ("Aegis Load Failure Item",),
        )
        failure_product = cursor.fetchone()
        cursor.execute(
            "UPDATE products SET stock=0, status='active' WHERE id=%s",
            (failure_product["id"],),
        )
        cursor.execute(
            """
            SELECT id
            FROM products
            WHERE status='active' AND id<>%s
            ORDER BY id
            LIMIT 4
            """,
            (failure_product["id"],),
        )
        products = cursor.fetchall()
        if not products:
            raise SystemExit("No active products found for successful orders")

        product_ids = [row["id"] for row in products]
        serializer = SecureCookieSessionInterface().get_signing_serializer(app)
        plan = []
        demand = Counter()

        for order_number in range(1, total + 1):
            if order_number % fail_every == 0:
                cart = {str(failure_product["id"]): 1}
                status = "failed_insufficient_stock"
            else:
                first = product_ids[order_number % len(product_ids)]
                if len(product_ids) > 1 and order_number % 3 == 0:
                    second = product_ids[(order_number + 1) % len(product_ids)]
                    cart = {str(first): 1, str(second): 1}
                else:
                    cart = {str(first): 1}
                for product_id, quantity in cart.items():
                    demand[int(product_id)] += int(quantity)
                status = "valid_order"

            cookie = serializer.dumps({"cart": cart})
            plan.append((order_number, status, cookie))

        for product_id, needed in demand.items():
            cursor.execute(
                "UPDATE products SET stock=%s, status='active' WHERE id=%s",
                (needed + 10, product_id),
            )

    conn.commit()
finally:
    conn.close()

with open(plan_file, "w", encoding="utf-8") as fh:
    for order_number, status, cookie in plan:
        fh.write(f"{order_number}\t{status}\t{cookie}\n")

success_count = sum(1 for _, status, _ in plan if status == "valid_order")
failed_count = total - success_count
print(f"Plan created: {success_count} valid orders, {failed_count} failed orders")
PYPLAN

export APP_URL

xargs -a "${PLAN_FILE}" -L 1 -P "${CONCURRENCY}" sh -c '
order_number="$1"
expected_status="$2"
session_cookie="$3"

http_code="$(curl -sS -o /dev/null -w "%{http_code}" \
  -H "Cookie: session=${session_cookie}" \
  -X POST "$APP_URL/checkout" \
  -d "customer_name=Real Order Load" \
  -d "customer_email=real-order-${order_number}@aegiscart.local")"

echo "${expected_status} order=${order_number} http=${http_code}"
' sh
