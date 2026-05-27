# AegisCart

AegisCart es una plataforma administrativa para operaciones e-commerce. No es una tienda publica: es un Ecommerce Management Suite para productos, carritos, ordenes, clientes, inventario, monitoreo, logs y trazabilidad.

## Arquitectura

- `srv-app` `192.168.6.142`: Flask/Gunicorn.
- `srv-db` `192.168.6.143`: MariaDB.
- `srv-zbx` `192.168.6.150`: monitoreo.
- `srv-elk` `192.168.6.200`: Elasticsearch y Kibana.
- Elasticsearch: `https://192.168.6.200:9200`.
- Kibana: `http://192.168.6.200:5601`.
- Indice: `aegiscart-app-logs*`.

## Variables de entorno

Copia `.env.example` a `.env` y edita credenciales reales:

```bash
cp .env.example .env
nano .env
```

No uses `root` ni usuario `zabbix` para MariaDB. Usa `aegiscart_user`.

## MariaDB

En `srv-db`, como administrador:

```sql
CREATE DATABASE IF NOT EXISTS aegiscart CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'aegiscart_user'@'%' IDENTIFIED BY 'TU_PASSWORD';
GRANT ALL PRIVILEGES ON aegiscart.* TO 'aegiscart_user'@'%';
FLUSH PRIVILEGES;
```

Crear tablas y productos iniciales:

```bash
mysql -h 192.168.6.143 -u aegiscart_user -p aegiscart < schema.sql
```

Validar conexion:

```bash
mysql -h 192.168.6.143 -P 3306 -u aegiscart_user -p -e "SELECT COUNT(*) FROM aegiscart.products;"
```

## Ejecutar local

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
python app.py
```

Windows PowerShell:

```powershell
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
Copy-Item .env.example .env
python app.py
```

Gunicorn:

```bash
gunicorn -w 3 -b 0.0.0.0:5000 app:app
```

## Rutas principales

- `GET /`: dashboard real.
- `GET /products`: productos desde MariaDB.
- `POST /products/create`: crear producto.
- `POST /products/update/<id>`: actualizar producto.
- `POST /products/delete/<id>`: desactivar producto.
- `GET /cart`: carrito en sesion.
- `POST /cart/add/<product_id>`: agregar producto.
- `POST /cart/remove/<product_id>`: quitar producto.
- `POST /cart/clear`: vaciar carrito.
- `POST /checkout`: crear orden, items, reducir stock y enviar logs.
- `GET /orders`: ordenes.
- `GET /orders/<id>`: detalle de orden.
- `GET /clients`: clientes derivados de ordenes.
- `GET /inventory`: inventario.
- `GET /logs`: Elasticsearch o fallback local.
- `GET /monitoring`: estado de infraestructura.
- `GET /health`: health JSON.

## API

```bash
curl http://localhost:5000/api/health
curl http://localhost:5000/api/products
curl http://localhost:5000/api/orders
curl -X POST http://localhost:5000/api/checkout-test -H "Content-Type: application/json" -d '{"force_fail": false}'
curl -X POST http://localhost:5000/api/checkout-test -H "Content-Type: application/json" -d '{"force_fail": true}'
```

## Checkout manual con curl

```bash
curl -c cookies.txt -b cookies.txt -X POST http://localhost:5000/cart/add/1
curl -c cookies.txt -b cookies.txt http://localhost:5000/cart
curl -c cookies.txt -b cookies.txt -X POST http://localhost:5000/checkout \
  -d "customer_name=Operador Aegis" \
  -d "customer_email=operator@aegiscart.local"
```

## Logs y Kibana

Los logs locales estan en:

```text
logs/aegiscart.log
```

En Kibana:

1. Stack Management.
2. Data Views.
3. Crear `aegiscart-app-logs*`.
4. Campo de tiempo: `@timestamp`.
5. Buscar:

```text
checkout_success
checkout_failed
srv-app
health_check
stock_warning
```

## Smoke test

```bash
chmod +x scripts/smoke_test.sh
BASE_URL=http://localhost:5000 ./scripts/smoke_test.sh
```
