# AegisCart - Documentacion tecnica

## Proposito

AegisCart es una aplicacion administrativa para operaciones e-commerce. Centraliza productos, carrito, ordenes, clientes, inventario, reportes, monitoreo, logs y trazabilidad operativa.

## Componentes

- `app.py`: aplicacion Flask principal, rutas web, API, conexion MariaDB y envio de eventos a Elasticsearch.
- `main.py`: punto de entrada alterno para ejecutar la aplicacion.
- `schema.sql`: definicion de base de datos y datos iniciales.
- `templates/`: vistas HTML renderizadas por Flask.
- `static/`: CSS, JavaScript e imagenes del frontend.
- `deployment/aegiscart.service`: unidad systemd para Gunicorn.
- `deployment/nginx_aegiscart.conf`: configuracion Nginx opcional.
- `scripts/backup_db.sh`: backup comprimido de MariaDB y copia remota opcional.
- `scripts/deploy_srv_app.sh`: preparacion/despliegue del servicio en `srv-app`.
- `scripts/smoke_test.sh`: pruebas basicas de salud, productos y checkout.
- `scripts/generate_real_orders.sh`: generacion de ordenes de prueba.
- `scripts/generate_checkout_load.sh`: carga de checkout para pruebas.

## Arquitectura esperada

| Servidor | IP | Rol |
|---|---:|---|
| srv-app | 192.168.6.142 | Flask/Gunicorn AegisCart |
| srv-db | 192.168.6.143 | MariaDB `aegiscart` |
| srv-zbx | 192.168.6.150 | monitoreo y recepcion de evidencias |
| srv-elk | 192.168.6.200 | Elasticsearch/Kibana |

Endpoints relevantes:

- App: `http://192.168.6.142:5000`
- Health: `GET /health` y `GET /api/health`
- Productos: `GET /api/products`
- Ordenes: `GET /api/orders`
- Checkout de prueba: `POST /api/checkout-test`
- Elasticsearch: `https://192.168.6.200:9200`
- Kibana: `http://192.168.6.200:5601`
- Data view: `aegiscart-app-logs*`

## Variables de entorno

Copiar `.env.example` a `.env` en el servidor y completar credenciales reales. No se debe versionar ni empaquetar `.env` con secretos.

Variables principales:

- `DB_HOST`
- `DB_PORT`
- `DB_NAME`
- `DB_USER`
- `DB_PASSWORD`
- `SECRET_KEY`
- `ELASTICSEARCH_URL`
- `ELASTICSEARCH_INDEX`

## Base de datos

Crear la base y usuario en `srv-db`:

```sql
CREATE DATABASE IF NOT EXISTS aegiscart CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'aegiscart_user'@'%' IDENTIFIED BY 'TU_PASSWORD';
GRANT ALL PRIVILEGES ON aegiscart.* TO 'aegiscart_user'@'%';
FLUSH PRIVILEGES;
```

Inicializar esquema desde `srv-app`:

```bash
mysql -h 192.168.6.143 -u aegiscart_user -p aegiscart < schema.sql
```

## Ejecucion local

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
python app.py
```

## Despliegue con systemd

```bash
sudo cp deployment/aegiscart.service /etc/systemd/system/aegiscart.service
sudo systemctl daemon-reload
sudo systemctl enable --now aegiscart
sudo systemctl status aegiscart --no-pager
```

## Backup de base de datos

El script incluido es `scripts/backup_db.sh`. Usa `mariadb-dump` o `mysqldump`, comprime el resultado en `backups/db` y puede copiarlo por SSH/SCP a `srv-db`.

Ejemplo:

```bash
chmod +x scripts/backup_db.sh
ENV_FILE=.env BACKUP_DIR=backups/db REMOTE_BACKUP=1 ./scripts/backup_db.sh
```

Variables aceptadas:

- `ENV_FILE`: archivo de entorno a cargar. Por defecto `.env`.
- `BACKUP_DIR`: ruta local para el dump comprimido. Por defecto `backups/db`.
- `REMOTE_BACKUP`: `1` copia remoto, `0` solo local.
- `REMOTE_USER`: usuario remoto. Por defecto `adminos`.
- `REMOTE_HOST`: host remoto. Por defecto `192.168.6.143`.
- `REMOTE_DIR`: ruta destino remota. Por defecto `/home/adminos/db-backups/aegiscart`.

## Validacion operativa

```bash
curl -sS http://127.0.0.1:5000/health
curl -sS http://127.0.0.1:5000/api/products
BASE_URL=http://127.0.0.1:5000 ./scripts/smoke_test.sh
```

Para eventos:

```bash
curl -sS -X POST http://127.0.0.1:5000/api/checkout-test \
  -H "Content-Type: application/json" \
  -d '{"force_fail": false}'

curl -sS -X POST http://127.0.0.1:5000/api/checkout-test \
  -H "Content-Type: application/json" \
  -d '{"force_fail": true}'
```

## Contenido del paquete ZIP

El ZIP operativo debe incluir codigo fuente, scripts, documentacion, configuraciones de despliegue, `schema.sql`, `requirements.txt`, assets y templates. Debe excluir `venv`, `.env`, logs, caches y backups generados.
