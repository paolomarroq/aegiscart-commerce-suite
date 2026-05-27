# AegisCart - Operacion final

## Arquitectura

AegisCart es una aplicacion Flask/Gunicorn en `srv-app` que expone una tienda de prueba en el puerto 5000. La aplicacion usa MariaDB en `srv-db` para productos, ordenes e items de orden, y envia eventos operativos a Elasticsearch en `srv-elk` para visualizarlos en Kibana. `srv-zbx` queda reservado para monitoreo y recepcion de evidencias/logs cuando SSH sin contrasena este configurado.

## Servidores e IPs

| Servidor | IP | Rol |
|---|---:|---|
| srv-app | 192.168.6.142 | Flask/Gunicorn AegisCart |
| srv-db | 192.168.6.143 | MariaDB `aegiscart` |
| srv-zbx | 192.168.6.150 | Zabbix |
| srv-elk | 192.168.6.200 | Elasticsearch/Kibana |

## Servicios y endpoints

- App: `http://192.168.6.142:5000`
- Health local: `http://127.0.0.1:5000/health`
- Productos API: `http://127.0.0.1:5000/api/products`
- Checkout test: `POST http://127.0.0.1:5000/api/checkout-test`
- MariaDB: `192.168.6.143:3306`
- Elasticsearch: `https://192.168.6.200:9200`
- Kibana: `http://192.168.6.200:5601`
- Indice Elastic: `aegiscart-app-logs*`

## Verificar AegisCart

Desde `srv-app`:

```bash
systemctl is-active aegiscart
curl -sS http://127.0.0.1:5000/health
curl -sS http://127.0.0.1:5000/api/products
```

Desde Laptop A:

```bash
curl -sS http://192.168.6.142:5000/health
```

## Probar checkout_success y checkout_failed

```bash
curl -sS -X POST http://127.0.0.1:5000/api/checkout-test \
  -H "Content-Type: application/json" \
  -d '{"force_fail": false}'

curl -sS -X POST http://127.0.0.1:5000/api/checkout-test \
  -H "Content-Type: application/json" \
  -d '{"force_fail": true}'
```

Resultado esperado para exito:

```json
{"ok":true,"status":"success","event_type":"checkout_success"}
```

Resultado esperado para falla controlada:

```json
{"ok":false,"status":"failed","event_type":"checkout_failed"}
```

## Verificar MariaDB desde srv-app

Usar el script operativo para no imprimir contrasenas:

```bash
/opt/aegiscart/scripts/aegis_db_status.sh
tail -n 20 /var/log/aegiscart/db_status.log
```

Consulta manual, usando `MYSQL_PWD` desde `.env` sin mostrarlo:

```bash
cd /opt/aegiscart/aegiscart-app
set -a; . ./.env; set +a
MYSQL_PWD="$DB_PASSWORD" mysql -h 192.168.6.143 -u aegiscart_user aegiscart \
  -e "SELECT id, customer_name, status, total, failure_reason, created_at FROM orders ORDER BY id DESC LIMIT 10;"
```

## Verificar Kibana y Elasticsearch

Desde `srv-app`:

```bash
/opt/aegiscart/scripts/aegis_elastic_verify.sh
tail -n 80 /var/log/aegiscart/elastic_verify.log
```

En Kibana:

1. Abrir `http://192.168.6.200:5601`.
2. Entrar a Discover.
3. Usar o crear Data View `aegiscart-app-logs*`.
4. Buscar `event_type:"checkout_success"`.
5. Buscar `event_type:"checkout_failed"`.
6. Verificar campos `server`, `project`, `source`, `status`, `extra_data.order_id`.

## Scripts obligatorios

Ruta: `/opt/aegiscart/scripts`

- `aegis_connections.sh`: registra conexiones establecidas en `/var/log/aegiscart/connections.log`.
- `aegis_db_status.sh`: valida MariaDB y registra CSV en `/var/log/aegiscart/db_status.log`.
- `aegis_db_resources.sh`: intenta CPU/memoria de `srv-db` por SSH; si falta llave registra `ssh_required`.
- `aegis_transfer_to_zbx.sh`: copia logs a `srv-zbx:/tmp/aegiscart-logs` si SSH sin contrasena existe.
- `aegis_app_smoke_test.sh`: prueba health, productos y checkout test.
- `aegis_elastic_verify.sh`: busca eventos de checkout en Elasticsearch.
- `aegis_collect_evidence.sh`: genera evidencia consolidada en `/opt/aegiscart/evidencias`.

## Instalar cron

Archivo sugerido: `/opt/aegiscart/scripts/aegiscart_crontab.txt`

Instalar manualmente cuando se autorice:

```bash
crontab /opt/aegiscart/scripts/aegiscart_crontab.txt
crontab -l
```

## Evidencias a tomar

Ejecutar:

```bash
/opt/aegiscart/scripts/aegis_connections.sh
/opt/aegiscart/scripts/aegis_db_status.sh
/opt/aegiscart/scripts/aegis_db_resources.sh
/opt/aegiscart/scripts/aegis_app_smoke_test.sh
/opt/aegiscart/scripts/aegis_elastic_verify.sh
/opt/aegiscart/scripts/aegis_collect_evidence.sh
```

Revisar:

```bash
ls -lh /var/log/aegiscart
ls -lh /opt/aegiscart/evidencias
```

## Pendiente manual en srv-db

Validar sin hacer cambios destructivos:

- RAID-1: `lsblk`, `cat /proc/mdstat`, `sudo mdadm --detail /dev/md*` si aplica.
- LVM: `sudo pvs`, `sudo vgs`, `sudo lvs`, `lsblk -f`.
- Datadir MariaDB: `sudo mysql -e "SHOW VARIABLES LIKE 'datadir';"` y `sudo systemctl status mariadb --no-pager`.
- Backup: crear o validar respaldo con `mysqldump` hacia ruta definida por el docente/proyecto.

No mover datadir ni reconfigurar RAID/LVM sin ventana de mantenimiento y backup validado.

## Pendiente manual en Zabbix

- Confirmar que `srv-app`, `srv-db`, `srv-zbx` y `srv-elk` existan como hosts.
- Revisar Latest data para CPU, memoria, disco, red y disponibilidad.
- Validar triggers relevantes.
- Si se usa transferencia de logs, configurar SSH sin contrasena hacia `srv-zbx` o ruta autorizada.

## Firewall

En cada servidor revisar:

```bash
sudo ufw status verbose
sudo ss -tulpn
```

Puertos esperados:

- `srv-app`: TCP 5000 desde Laptop A/red autorizada, SSH 22.
- `srv-db`: TCP 3306 desde `srv-app`, SSH 22.
- `srv-zbx`: puertos Zabbix segun instalacion, SSH 22.
- `srv-elk`: TCP 9200 para Elasticsearch desde `srv-app`, TCP 5601 para Kibana desde Laptop A/red autorizada, SSH 22.

## Demostrar SSH desde Laptop A

Desde Laptop A:

```bash
ssh adminos@192.168.6.142 hostname
ssh adminos@192.168.6.143 hostname
ssh adminos@192.168.6.150 hostname
ssh adminos@192.168.6.200 hostname
```

Si se requiere llave:

```bash
ssh-keygen -t ed25519 -C "laptop-a-aegiscart"
ssh-copy-id adminos@192.168.6.142
ssh-copy-id adminos@192.168.6.143
ssh-copy-id adminos@192.168.6.150
ssh-copy-id adminos@192.168.6.200
```

## Nota de permisos de logs

La ruta obligatoria de logs es `/var/log/aegiscart`. En esta ejecucion, la carpeta existe pero pertenece a `root:root` y el usuario `adminos` no puede escribir ahi sin sudo interactivo. Los scripts estan preparados para escribir en `/var/log/aegiscart` cuando tenga permisos y, mientras tanto, usan fallback en `/opt/aegiscart/evidencias/runtime_logs` dejando advertencia.

Para habilitar la ruta obligatoria de forma permanente, ejecutar manualmente en `srv-app` con sudo:

```bash
sudo chown adminos:adminos /var/log/aegiscart
sudo chmod 755 /var/log/aegiscart
```
