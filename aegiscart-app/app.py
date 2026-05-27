import json
import logging
import os
from datetime import date, datetime, timezone
from decimal import Decimal
from logging.handlers import RotatingFileHandler

import pymysql
import requests
import urllib3
from dotenv import load_dotenv
from flask import (
    Flask,
    flash,
    jsonify,
    redirect,
    render_template,
    request,
    session,
    url_for,
)


load_dotenv()
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
logging.basicConfig(level=logging.INFO)

APP_SERVER_NAME = os.getenv("APP_SERVER_NAME", "srv-app")
APP_PROJECT = os.getenv("APP_PROJECT", "AegisCart")
APP_ENV = os.getenv("APP_ENV", "development")

DB_HOST = os.getenv("DB_HOST", "192.168.6.143")
DB_PORT = int(os.getenv("DB_PORT", "3306"))
DB_NAME = os.getenv("DB_NAME", "aegiscart")
DB_USER = os.getenv("DB_USER", "aegiscart_user")
DB_PASSWORD = os.getenv("DB_PASSWORD", "")

ELASTIC_URL = os.getenv("ELASTIC_URL", "https://192.168.6.200:9200").rstrip("/")
ELASTIC_USER = os.getenv("ELASTIC_USER", "elastic")
ELASTIC_PASSWORD = os.getenv("ELASTIC_PASSWORD", "")
ELASTIC_INDEX = os.getenv("ELASTIC_INDEX", "aegiscart-app-logs")
ELASTIC_VERIFY_SSL = os.getenv("ELASTIC_VERIFY_SSL", "false").lower() in ("1", "true", "yes")


LOG_DIR = os.path.join(os.path.dirname(__file__), "logs")
LOG_FILE = os.path.join(LOG_DIR, "aegiscart.log")
os.makedirs(LOG_DIR, exist_ok=True)

app = Flask(__name__)
app.secret_key = os.getenv("FLASK_SECRET_KEY", "change-me-only-for-local")

logger = logging.getLogger("aegiscart")
logger.setLevel(logging.INFO)
if not logger.handlers:
    handler = RotatingFileHandler(LOG_FILE, maxBytes=1_000_000, backupCount=5, encoding="utf-8")
    handler.setFormatter(logging.Formatter("%(message)s"))
    logger.addHandler(handler)

SEED_PRODUCTS = [
    ("Aegis Keyboard K1", "Teclado mecanico para estaciones de soporte.", Decimal("79.99"), 12, "active"),
    ("Aegis Mouse M2", "Mouse de precision para operadores e-commerce.", Decimal("39.50"), 18, "active"),
    ("Operations Monitor 27", "Monitor QHD para tableros de control.", Decimal("249.00"), 7, "active"),
    ("NVMe Catalog Cache 1TB", "SSD para catalogos y busquedas rapidas.", Decimal("94.75"), 10, "active"),
]


def make_json_safe(value):
    if isinstance(value, Decimal):
        return float(value)
    if isinstance(value, (datetime, date)):
        return value.isoformat()
    if isinstance(value, dict):
        return {str(key): make_json_safe(item) for key, item in value.items()}
    if isinstance(value, (list, tuple, set)):
        return [make_json_safe(item) for item in value]
    if value is None or isinstance(value, (str, int, float, bool)):
        return value
    return str(value)


def decimal_to_float(value):
    return make_json_safe(value)


def normalize_row(row):
    return {key: make_json_safe(value) for key, value in row.items()}


def get_db_connection():
    """Create a MariaDB connection using only environment variables."""
    if not DB_PASSWORD:
        raise RuntimeError("DB_PASSWORD is not configured")
    return pymysql.connect(
        host=DB_HOST,
        port=DB_PORT,
        user=DB_USER,
        password=DB_PASSWORD,
        database=DB_NAME,
        cursorclass=pymysql.cursors.DictCursor,
        autocommit=False,
        charset="utf8mb4",
        connect_timeout=5,
        read_timeout=8,
        write_timeout=8,
    )


def local_log(event_type, message, extra_data=None, status="info"):
    payload = make_json_safe({
        "@timestamp": datetime.now(timezone.utc),
        "server": APP_SERVER_NAME,
        "project": APP_PROJECT,
        "source": "flask_app",
        "event_type": event_type,
        "message": message,
        "status": status,
        "extra_data": extra_data or {},
    })
    try:
        logger.info(json.dumps(payload, ensure_ascii=True))
    except Exception:
        logging.exception("Local log write failed")
    return payload


def send_elastic_log(event_type, message, extra_data=None, status="info"):
    try:
        payload = make_json_safe(local_log(event_type, message, extra_data, status))
        if not ELASTIC_PASSWORD:
            local_log("elastic_skipped", "ELASTIC_PASSWORD is not configured", {"event_type": event_type}, "warning")
            return False
        response = requests.post(
            f"{ELASTIC_URL}/{ELASTIC_INDEX}/_doc",
            auth=(ELASTIC_USER, ELASTIC_PASSWORD),
            json=payload,
            verify=ELASTIC_VERIFY_SSL,
            timeout=5,
        )
        response.raise_for_status()
        return True
    except Exception as exc:
        try:
            local_log("elastic_send_failed", str(exc), {"event_type": event_type}, "error")
        except Exception:
            logging.exception("Elastic log failure could not be written locally")
        return False


def ensure_column(cursor, table, column, definition):
    cursor.execute(
        """
        SELECT COUNT(*) AS count
        FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA=%s AND TABLE_NAME=%s AND COLUMN_NAME=%s
        """,
        (DB_NAME, table, column),
    )
    if cursor.fetchone()["count"] == 0:
        cursor.execute(f"ALTER TABLE {table} ADD COLUMN {definition}")


def init_db():
    """Create or migrate the minimal schema required by AegisCart."""
    try:
        conn = get_db_connection()
        with conn.cursor() as cursor:
            cursor.execute(
                """
                CREATE TABLE IF NOT EXISTS products (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    name VARCHAR(160) NOT NULL,
                    description VARCHAR(500) NOT NULL,
                    price DECIMAL(10,2) NOT NULL,
                    stock INT NOT NULL DEFAULT 0,
                    status VARCHAR(20) NOT NULL DEFAULT 'active',
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
                """
            )
            cursor.execute(
                """
                CREATE TABLE IF NOT EXISTS orders (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    customer_name VARCHAR(160) NOT NULL DEFAULT 'Operador Aegis',
                    customer_email VARCHAR(180) NOT NULL DEFAULT 'operator@aegiscart.local',
                    status VARCHAR(20) NOT NULL DEFAULT 'pending',
                    total DECIMAL(10,2) NOT NULL DEFAULT 0,
                    failure_reason VARCHAR(500) NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
                """
            )
            cursor.execute(
                """
                CREATE TABLE IF NOT EXISTS order_items (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    order_id INT NOT NULL,
                    product_id INT NOT NULL,
                    quantity INT NOT NULL,
                    unit_price DECIMAL(10,2) NOT NULL,
                    subtotal DECIMAL(10,2) NOT NULL,
                    FOREIGN KEY (order_id) REFERENCES orders(id),
                    FOREIGN KEY (product_id) REFERENCES products(id)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
                """
            )
            ensure_column(cursor, "products", "status", "status VARCHAR(20) NOT NULL DEFAULT 'active'")
            ensure_column(cursor, "orders", "customer_name", "customer_name VARCHAR(160) NOT NULL DEFAULT 'Operador Aegis'")
            ensure_column(cursor, "orders", "customer_email", "customer_email VARCHAR(180) NOT NULL DEFAULT 'operator@aegiscart.local'")
            ensure_column(cursor, "orders", "failure_reason", "failure_reason VARCHAR(500) NULL")
            ensure_column(cursor, "order_items", "unit_price", "unit_price DECIMAL(10,2) NOT NULL DEFAULT 0")
            ensure_column(cursor, "order_items", "subtotal", "subtotal DECIMAL(10,2) NOT NULL DEFAULT 0")
            cursor.execute("SELECT COUNT(*) AS total FROM products")
            if cursor.fetchone()["total"] == 0:
                cursor.executemany(
                    "INSERT INTO products (name, description, price, stock, status) VALUES (%s, %s, %s, %s, %s)",
                    SEED_PRODUCTS,
                )
        conn.commit()
        conn.close()
        send_elastic_log("app_started", "AegisCart application initialized", {"env": APP_ENV}, "info")
    except Exception as exc:
        local_log("db_init_failed", str(exc), {"host": DB_HOST, "database": DB_NAME}, "error")


def fetch_all(sql, params=None):
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute(sql, params or ())
            return cursor.fetchall()
    finally:
        conn.close()


def fetch_one(sql, params=None):
    rows = fetch_all(sql, params)
    return rows[0] if rows else None


def get_products(include_inactive=False):
    where = "" if include_inactive else "WHERE status='active'"
    return fetch_all(f"SELECT id, name, description, price, stock, status, created_at FROM products {where} ORDER BY id DESC")


def get_product(product_id, lock=False, conn=None):
    sql = "SELECT id, name, description, price, stock, status FROM products WHERE id=%s"
    if lock:
        sql += " FOR UPDATE"
    own = conn is None
    conn = conn or get_db_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute(sql, (product_id,))
            return cursor.fetchone()
    finally:
        if own:
            conn.close()


def get_cart():
    return session.setdefault("cart", {})


def save_cart(cart):
    session["cart"] = cart
    session.modified = True


def build_cart_items(conn=None, lock=False):
    cart = get_cart()
    if not cart:
        return [], Decimal("0.00")
    own = conn is None
    conn = conn or get_db_connection()
    try:
        ids = [int(product_id) for product_id in cart.keys()]
        placeholders = ",".join(["%s"] * len(ids))
        sql = f"SELECT id, name, description, price, stock, status FROM products WHERE id IN ({placeholders})"
        if lock:
            sql += " FOR UPDATE"
        with conn.cursor() as cursor:
            cursor.execute(sql, ids)
            products = {str(product["id"]): product for product in cursor.fetchall()}
        items = []
        total = Decimal("0.00")
        for product_id, quantity in cart.items():
            product = products.get(str(product_id))
            if not product:
                continue
            quantity = int(quantity)
            subtotal = product["price"] * quantity
            total += subtotal
            items.append({"product": product, "quantity": quantity, "subtotal": subtotal})
        return items, total
    finally:
        if own:
            conn.close()


def create_failed_order(conn, customer_name, customer_email, total, reason):
    with conn.cursor() as cursor:
        cursor.execute(
            "INSERT INTO orders (customer_name, customer_email, status, total, failure_reason) VALUES (%s, %s, %s, %s, %s)",
            (customer_name, customer_email, "failed", total, reason),
        )
        return cursor.lastrowid


def checkout_cart(force_fail=False, source="web", customer_name="Operador Aegis", customer_email="operator@aegiscart.local"):
    if force_fail:
        reason = "Compra fallida por simulacion controlada"
        order_id = None
        conn = get_db_connection()
        try:
            order_id = create_failed_order(conn, customer_name, customer_email, Decimal("0.00"), reason)
            conn.commit()
        except Exception:
            conn.rollback()
            logging.exception("Checkout failed")
        finally:
            conn.close()
        send_elastic_log(
            "checkout_failed",
            reason,
            {"source": source, "order_id": order_id, "failure_reason": reason},
            "error",
        )
        return False, reason, order_id

    cart = get_cart()
    if not cart:
        send_elastic_log("checkout_failed", "Checkout failed: empty cart", {"source": source}, "warning")
        return False, "El carrito esta vacio.", None

    conn = get_db_connection()
    log_events = []
    try:
        items, total = build_cart_items(conn=conn, lock=True)
        if not items:
            order_id = create_failed_order(conn, customer_name, customer_email, Decimal("0.00"), "Invalid cart")
            conn.commit()
            log_events.append(("checkout_failed", "Checkout failed: invalid cart", {"source": source, "order_id": order_id}, "error"))
            return False, "El carrito no contiene productos validos.", order_id

        for item in items:
            product = item["product"]
            if product["status"] != "active" or product["stock"] < item["quantity"]:
                reason = f"Insufficient stock for product {product['id']}"
                order_id = create_failed_order(conn, customer_name, customer_email, total, reason)
                conn.commit()
                log_events.append((
                    "checkout_failed",
                    reason,
                    {"source": source, "order_id": order_id, "product_id": product["id"], "requested": item["quantity"], "available": product["stock"]},
                    "error",
                ))
                return False, "No hay stock suficiente para completar el checkout.", order_id

        low_stock_products = []
        with conn.cursor() as cursor:
            cursor.execute(
                "INSERT INTO orders (customer_name, customer_email, status, total) VALUES (%s, %s, %s, %s)",
                (customer_name, customer_email, "success", total),
            )
            order_id = cursor.lastrowid
            for item in items:
                product = item["product"]
                subtotal = item["subtotal"]
                cursor.execute(
                    "INSERT INTO order_items (order_id, product_id, quantity, unit_price, subtotal) VALUES (%s, %s, %s, %s, %s)",
                    (order_id, product["id"], item["quantity"], product["price"], subtotal),
                )
                cursor.execute("UPDATE products SET stock=stock-%s WHERE id=%s", (item["quantity"], product["id"]))
                if product["stock"] - item["quantity"] <= 3:
                    low_stock_products.append(product["id"])
        conn.commit()

        session["cart"] = {}
        session.modified = True
        for product_id in low_stock_products:
            log_events.append(("stock_warning", "Product stock is low after checkout", {"product_id": product_id}, "warning"))
        log_events.append((
            "checkout_success",
            "Checkout procesado correctamente",
            {"source": source, "order_id": order_id, "total": total, "items": len(items), "customer_email": customer_email},
            "success",
        ))
        return True, "Checkout procesado correctamente", order_id
    except Exception as exc:
        conn.rollback()
        logging.exception("Checkout failed")
        send_elastic_log("checkout_failed", "Checkout failed by internal error", {"source": source, "error": str(exc)}, "error")
        return False, "Ocurrio un error al procesar el checkout.", None
    finally:
        conn.close()
        for event_type, message, extra_data, status in log_events:
            send_elastic_log(event_type, message, extra_data, status)


def get_dashboard_data():
    data = {
        "total_products": 0,
        "total_orders": 0,
        "total_clients": 0,
        "active_carts": sum(int(qty) for qty in session.get("cart", {}).values()),
        "revenue": Decimal("0.00"),
        "orders_success": 0,
        "orders_failed": 0,
        "conversion": "0.0%",
        "db_connected": False,
    }
    try:
        data["total_products"] = fetch_one("SELECT COUNT(*) AS value FROM products WHERE status='active'")["value"]
        order_stats = fetch_one(
            """
            SELECT
                COUNT(*) AS total_orders,
                COALESCE(SUM(CASE WHEN status='success' THEN total ELSE 0 END), 0) AS revenue,
                SUM(CASE WHEN status='success' THEN 1 ELSE 0 END) AS success_count,
                SUM(CASE WHEN status='failed' THEN 1 ELSE 0 END) AS failed_count,
                COUNT(DISTINCT customer_email) AS clients
            FROM orders
            """
        )
        if order_stats:
            data.update(
                {
                    "total_orders": order_stats["total_orders"] or 0,
                    "revenue": order_stats["revenue"] or Decimal("0.00"),
                    "orders_success": order_stats["success_count"] or 0,
                    "orders_failed": order_stats["failed_count"] or 0,
                    "total_clients": order_stats["clients"] or 0,
                    "db_connected": True,
                }
            )
        if data["total_orders"]:
            data["conversion"] = f"{(data['orders_success'] / data['total_orders']) * 100:.1f}%"
    except Exception as exc:
        local_log("dashboard_load_failed", str(exc), None, "error")
    return data


def get_orders(limit=None):
    sql = "SELECT id, customer_name, customer_email, status, total, failure_reason, created_at FROM orders ORDER BY created_at DESC"
    if limit:
        sql += " LIMIT %s"
        return fetch_all(sql, (limit,))
    return fetch_all(sql)


def get_order_detail(order_id):
    order = fetch_one("SELECT id, customer_name, customer_email, status, total, failure_reason, created_at FROM orders WHERE id=%s", (order_id,))
    if not order:
        return None, []
    items = fetch_all(
        """
        SELECT oi.id, oi.product_id, oi.quantity, oi.unit_price, oi.subtotal, p.name
        FROM order_items oi
        JOIN products p ON p.id=oi.product_id
        WHERE oi.order_id=%s
        ORDER BY oi.id
        """,
        (order_id,),
    )
    return order, items


def get_clients():
    return fetch_all(
        """
        SELECT customer_name, customer_email, COUNT(*) AS orders_count, COALESCE(SUM(total), 0) AS total_spent
        FROM orders
        GROUP BY customer_name, customer_email
        ORDER BY total_spent DESC
        """
    )


def get_health_status():
    health = {
        "app": "ok",
        "database": "error",
        "elasticsearch": "error",
        "server": APP_SERVER_NAME,
        "project": APP_PROJECT,
    }
    try:
        conn = get_db_connection()
        with conn.cursor() as cursor:
            cursor.execute("SELECT 1 AS ok")
            cursor.fetchone()
        conn.close()
        health["database"] = "ok"
    except Exception as exc:
        health["database_error"] = str(exc)

    try:
        response = requests.get(ELASTIC_URL, auth=(ELASTIC_USER, ELASTIC_PASSWORD), verify=ELASTIC_VERIFY_SSL, timeout=4)
        health["elasticsearch"] = "ok" if response.ok else f"error_{response.status_code}"
    except requests.RequestException as exc:
        health["elasticsearch_error"] = str(exc)
    return health


def read_local_logs(limit=80):
    if not os.path.exists(LOG_FILE):
        return []
    events = []
    with open(LOG_FILE, "r", encoding="utf-8", errors="ignore") as log_file:
        lines = log_file.readlines()[-limit:]
    for line in lines:
        line = line.strip()
        if not line:
            continue
        try:
            event = json.loads(line)
            events.append(
                {
                    "timestamp": event.get("@timestamp", ""),
                    "server": event.get("server", APP_SERVER_NAME),
                    "event_type": event.get("event_type", "local_log"),
                    "message": event.get("message", line),
                    "status": event.get("status", "info").title(),
                }
            )
        except json.JSONDecodeError:
            status = "Failed" if "ERROR" in line or "failed" in line else "Info"
            events.append({"timestamp": line[:19], "server": APP_SERVER_NAME, "event_type": "local_log", "message": line, "status": status})
    return list(reversed(events))


def get_elastic_logs(limit=50):
    if not ELASTIC_PASSWORD:
        return []
    try:
        response = requests.get(
            f"{ELASTIC_URL}/{ELASTIC_INDEX}/_search",
            auth=(ELASTIC_USER, ELASTIC_PASSWORD),
            json={"size": limit, "sort": [{"@timestamp": {"order": "desc"}}]},
            verify=ELASTIC_VERIFY_SSL,
            timeout=5,
        )
        response.raise_for_status()
        hits = response.json().get("hits", {}).get("hits", [])
        logs = []
        for hit in hits:
            source = hit.get("_source", {})
            logs.append(
                {
                    "timestamp": source.get("@timestamp", ""),
                    "server": source.get("server", APP_SERVER_NAME),
                    "event_type": source.get("event_type", ""),
                    "message": source.get("message", ""),
                    "status": source.get("status", "info").title(),
                }
            )
        return logs
    except requests.RequestException as exc:
        local_log("elastic_query_failed", str(exc), None, "warning")
        return []


@app.context_processor
def inject_layout_data():
    return {"cart_count": sum(int(qty) for qty in session.get("cart", {}).values()), "app_project": APP_PROJECT}


@app.get("/")
def dashboard():
    dashboard_data = get_dashboard_data()
    try:
        recent_orders = get_orders(limit=5)
    except Exception:
        recent_orders = []
    logs = get_elastic_logs(8) or read_local_logs(8)
    return render_template("dashboard.html", page="dashboard", dashboard=dashboard_data, orders=recent_orders, logs=logs, health=get_health_status())


@app.get("/products")
def products():
    try:
        rows = get_products(include_inactive=True)
        db_connected = True
    except Exception as exc:
        local_log("products_load_failed", str(exc), None, "error")
        rows, db_connected = [], False
        flash("No se pudo conectar a MariaDB para cargar productos.", "error")
    return render_template("products.html", page="products", products=rows, db_connected=db_connected)


@app.post("/products/create")
def product_create():
    try:
        name = request.form.get("name", "").strip()
        description = request.form.get("description", "").strip()
        price = Decimal(request.form.get("price", "0"))
        stock = int(request.form.get("stock", "0"))
        status = request.form.get("status", "active")
        if not name or price < 0 or stock < 0:
            raise ValueError("Invalid product data")
        conn = get_db_connection()
        with conn.cursor() as cursor:
            cursor.execute(
                "INSERT INTO products (name, description, price, stock, status) VALUES (%s, %s, %s, %s, %s)",
                (name, description, price, stock, status),
            )
            product_id = cursor.lastrowid
        conn.commit()
        conn.close()
        send_elastic_log("product_created", "Product created", {"product_id": product_id, "name": name}, "success")
        flash("Producto creado correctamente.", "success")
    except Exception as exc:
        local_log("product_create_failed", str(exc), None, "error")
        flash("No se pudo crear el producto.", "error")
    return redirect(url_for("products"))


@app.post("/products/update/<int:product_id>")
def product_update(product_id):
    try:
        name = request.form.get("name", "").strip()
        description = request.form.get("description", "").strip()
        price = Decimal(request.form.get("price", "0"))
        stock = int(request.form.get("stock", "0"))
        status = request.form.get("status", "active")
        conn = get_db_connection()
        with conn.cursor() as cursor:
            cursor.execute(
                "UPDATE products SET name=%s, description=%s, price=%s, stock=%s, status=%s WHERE id=%s",
                (name, description, price, stock, status, product_id),
            )
        conn.commit()
        conn.close()
        send_elastic_log("product_updated", "Product updated", {"product_id": product_id, "stock": stock, "status": status}, "info")
        if stock <= 3:
            send_elastic_log("stock_warning", "Product stock is low", {"product_id": product_id, "stock": stock}, "warning")
        flash("Producto actualizado.", "success")
    except Exception as exc:
        local_log("product_update_failed", str(exc), {"product_id": product_id}, "error")
        flash("No se pudo actualizar el producto.", "error")
    return redirect(url_for("products"))


@app.post("/products/delete/<int:product_id>")
def product_delete(product_id):
    try:
        conn = get_db_connection()
        with conn.cursor() as cursor:
            cursor.execute("UPDATE products SET status='inactive' WHERE id=%s", (product_id,))
        conn.commit()
        conn.close()
        send_elastic_log("product_updated", "Product deactivated", {"product_id": product_id}, "warning")
        flash("Producto desactivado.", "success")
    except Exception as exc:
        local_log("product_delete_failed", str(exc), {"product_id": product_id}, "error")
        flash("No se pudo desactivar el producto.", "error")
    return redirect(url_for("products"))


@app.get("/cart")
def cart():
    try:
        items, total = build_cart_items()
        products = get_products()
    except Exception as exc:
        local_log("cart_load_failed", str(exc), None, "error")
        items, total, products = [], Decimal("0.00"), []
        flash("No se pudo cargar el carrito. Verifica MariaDB.", "error")
    return render_template("cart.html", page="cart", items=items, total=total, products=products)


@app.post("/cart/add/<int:product_id>")
def cart_add(product_id):
    try:
        product = get_product(product_id)
        if not product or product["status"] != "active" or product["stock"] <= 0:
            flash("Producto no disponible o sin stock.", "error")
            return redirect(request.referrer or url_for("cart"))
        cart_data = get_cart()
        quantity = int(cart_data.get(str(product_id), 0)) + 1
        if quantity > product["stock"]:
            flash("No hay stock suficiente para incrementar la cantidad.", "error")
            return redirect(request.referrer or url_for("cart"))
        cart_data[str(product_id)] = quantity
        save_cart(cart_data)
        send_elastic_log("cart_add", "Product added to cart", {"product_id": product_id, "quantity": quantity}, "info")
        flash("Producto agregado al carrito.", "success")
    except Exception as exc:
        local_log("cart_add_failed", str(exc), {"product_id": product_id}, "error")
        flash("No se pudo agregar el producto.", "error")
    return redirect(request.referrer or url_for("cart"))


@app.post("/cart/remove/<int:product_id>")
def cart_remove(product_id):
    cart_data = get_cart()
    cart_data.pop(str(product_id), None)
    save_cart(cart_data)
    send_elastic_log("cart_remove", "Product removed from cart", {"product_id": product_id}, "info")
    flash("Producto quitado del carrito.", "success")
    return redirect(url_for("cart"))


@app.post("/cart/clear")
def cart_clear():
    session["cart"] = {}
    session.modified = True
    send_elastic_log("cart_remove", "Cart cleared", None, "info")
    flash("Carrito vaciado.", "success")
    return redirect(url_for("cart"))


@app.post("/checkout")
def checkout():
    customer_name = request.form.get("customer_name", "Operador Aegis").strip() or "Operador Aegis"
    customer_email = request.form.get("customer_email", "operator@aegiscart.local").strip() or "operator@aegiscart.local"
    ok, message, order_id = checkout_cart(customer_name=customer_name, customer_email=customer_email)
    if ok:
        return redirect(url_for("checkout_success", order_id=order_id))
    return render_template("error.html", page="error", message=message, order_id=order_id), 400


@app.get("/success/<int:order_id>")
def checkout_success(order_id):
    return render_template("success.html", page="success", message="Checkout completado correctamente.", order_id=order_id)


@app.get("/orders")
def orders():
    try:
        rows = get_orders()
    except Exception as exc:
        local_log("orders_load_failed", str(exc), None, "error")
        rows = []
        flash("No se pudieron cargar las ordenes.", "error")
    return render_template("orders.html", page="orders", orders=rows)


@app.get("/orders/<int:order_id>")
def order_detail(order_id):
    try:
        order, items = get_order_detail(order_id)
        if not order:
            return render_template("error.html", page="error", message="Orden no encontrada."), 404
        related_logs = [log for log in (get_elastic_logs(80) or read_local_logs(80)) if str(order_id) in log["message"]]
    except Exception as exc:
        local_log("order_detail_failed", str(exc), {"order_id": order_id}, "error")
        return render_template("error.html", page="error", message="No se pudo cargar el detalle de orden."), 500
    return render_template("order_detail.html", page="orders", order=order, items=items, logs=related_logs)


@app.get("/clients")
def clients():
    try:
        rows = get_clients()
    except Exception as exc:
        local_log("clients_load_failed", str(exc), None, "error")
        rows = []
        flash("No se pudieron cargar los clientes.", "error")
    return render_template("clients.html", page="clients", clients=rows)


@app.get("/inventory")
def inventory():
    try:
        rows = get_products(include_inactive=True)
    except Exception as exc:
        local_log("inventory_load_failed", str(exc), None, "error")
        rows = []
        flash("No se pudo cargar inventario.", "error")
    return render_template("inventory.html", page="inventory", products=rows)


@app.post("/inventory/update/<int:product_id>")
def inventory_update(product_id):
    try:
        stock = int(request.form.get("stock", "0"))
        conn = get_db_connection()
        with conn.cursor() as cursor:
            cursor.execute("UPDATE products SET stock=%s WHERE id=%s", (stock, product_id))
        conn.commit()
        conn.close()
        send_elastic_log("product_updated", "Inventory stock updated", {"product_id": product_id, "stock": stock}, "info")
        if stock <= 3:
            send_elastic_log("stock_warning", "Product stock is low", {"product_id": product_id, "stock": stock}, "warning")
        flash("Stock actualizado.", "success")
    except Exception as exc:
        local_log("inventory_update_failed", str(exc), {"product_id": product_id}, "error")
        flash("No se pudo actualizar el stock.", "error")
    return redirect(url_for("inventory"))


@app.get("/logs")
def logs_view():
    logs = get_elastic_logs(80)
    source = "Elasticsearch"
    if not logs:
        logs = read_local_logs(80)
        source = "Archivo local"
    return render_template("logs.html", page="logs", logs=logs, source=source)


@app.get("/monitoring")
def monitoring():
    health = get_health_status()
    services = [
        {"name": "srv-app", "ip": "192.168.6.142", "role": "Flask/Gunicorn", "status": "Online" if health["app"] == "ok" else "Failed"},
        {"name": "srv-db", "ip": "192.168.6.143", "role": "MariaDB", "status": "Online" if health["database"] == "ok" else "Failed"},
        {"name": "srv-zbx", "ip": "192.168.6.150", "role": "Zabbix", "status": "Warning"},
        {"name": "srv-elk", "ip": "192.168.6.200", "role": "Elasticsearch/Kibana", "status": "Online" if health["elasticsearch"] == "ok" else "Failed"},
    ]
    return render_template("monitoring.html", page="monitoring", services=services, health=health)


@app.get("/reports")
def reports():
    dashboard_data = get_dashboard_data()
    return render_template("reports.html", page="reports", dashboard=dashboard_data)


@app.get("/settings")
def settings():
    return render_template("settings.html", page="settings", env=APP_ENV, elastic_index=ELASTIC_INDEX, db_host=DB_HOST)


@app.get("/health")
def health():
    send_elastic_log("health_check", "Health endpoint called", None, "info")
    status = get_health_status()
    http_status = 200 if status["database"] == "ok" else 503
    return jsonify(status), http_status


@app.get("/api/health")
def api_health():
    return health()


@app.get("/api/products")
def api_products():
    try:
        return jsonify([normalize_row(row) for row in get_products(include_inactive=True)])
    except Exception as exc:
        return jsonify({"error": str(exc)}), 500


@app.get("/api/orders")
def api_orders():
    try:
        return jsonify([normalize_row(row) for row in get_orders()])
    except Exception as exc:
        return jsonify({"error": str(exc)}), 500


@app.post("/api/checkout-test")
def api_checkout_test():
    payload = request.get_json(silent=True) or {}
    force_fail = bool(payload.get("force_fail", False))
    if force_fail:
        try:
            ok, message, _order_id = checkout_cart(force_fail=True, source="api", customer_name="API Test", customer_email="api-test@aegiscart.local")
            return jsonify({
                "status": "failed",
                "ok": ok,
                "event_type": "checkout_failed",
                "message": message,
            }), 400
        except Exception as exc:
            logging.exception("Checkout failed")
            send_elastic_log("checkout_failed", "Forced API checkout failed", {"error": str(exc)}, "error")
            return jsonify({
                "status": "failed",
                "ok": False,
                "event_type": "checkout_failed",
                "message": "Compra fallida por simulacion controlada",
            }), 400

    try:
        product = fetch_one("SELECT id FROM products WHERE status='active' AND stock > 0 ORDER BY id LIMIT 1")
        if not product:
            send_elastic_log("checkout_failed", "API checkout test failed: no stock", {"source": "api"}, "warning")
            return jsonify({
                "status": "failed",
                "ok": False,
                "event_type": "checkout_failed",
                "message": "No hay productos con stock",
                "order_id": None,
            }), 400
        session["cart"] = {str(product["id"]): 1}
        session.modified = True
        ok, message, order_id = checkout_cart(source="api", customer_name="API Test", customer_email="api-test@aegiscart.local")
        event_type = "checkout_success" if ok else "checkout_failed"
        return jsonify({
            "status": "success" if ok else "failed",
            "ok": ok,
            "event_type": event_type,
            "order_id": order_id,
            "message": message,
        }), 200 if ok else 400
    except Exception as exc:
        logging.exception("Checkout failed")
        send_elastic_log("checkout_failed", "API checkout test internal error", {"error": str(exc)}, "error")
        return jsonify({
            "status": "failed",
            "ok": False,
            "event_type": "checkout_failed",
            "message": "Ocurrio un error al procesar el checkout.",
            "order_id": None,
        }), 500


if __name__ == "__main__":
    init_db()
    host = os.getenv("FLASK_HOST", "0.0.0.0")
    port = int(os.getenv("FLASK_PORT", 5000))
    app.run(host=host, port=port, debug=APP_ENV != "production")
