# AegisCart - Tareas manuales pendientes

Estas acciones deben ejecutarse manualmente en cada VM o desde Laptop A. No incluyen contrasenas.

## srv-db - RAID/LVM/datadir/backup

Solo validar primero:

```bash
hostnamectl
ip -br a
lsblk
lsblk -f
cat /proc/mdstat
sudo mdadm --detail /dev/md0
sudo pvs
sudo vgs
sudo lvs
sudo systemctl status mariadb --no-pager
sudo mysql -e "SHOW VARIABLES LIKE 'datadir';"
sudo mysql -e "SHOW DATABASES;"
```

Validar backup de MariaDB:

```bash
mkdir -p ~/aegiscart-backups
mysqldump -u aegiscart_user -p aegiscart > ~/aegiscart-backups/aegiscart_$(date +%Y%m%d_%H%M%S).sql
ls -lh ~/aegiscart-backups
```

Si el enunciado exige mover datadir a LVM/RAID-1, hacerlo solo con backup confirmado, servicio detenido y procedimiento aprobado.

## srv-zbx - Zabbix

```bash
hostnamectl
ip -br a
sudo systemctl status zabbix-server --no-pager
sudo systemctl status zabbix-agent --no-pager
sudo ss -tulpn
sudo ufw status verbose
```

En la UI de Zabbix:

1. Validar hosts `srv-app`, `srv-db`, `srv-zbx`, `srv-elk`.
2. Revisar Latest data.
3. Confirmar metricas de CPU, memoria, disco, red y disponibilidad.
4. Confirmar triggers activos/resueltos.
5. Si se reciben logs desde `srv-app`, revisar `/tmp/aegiscart-logs` o la ruta configurada.

## srv-elk - Elasticsearch/Kibana

```bash
hostnamectl
ip -br a
sudo systemctl status elasticsearch --no-pager
sudo systemctl status kibana --no-pager
sudo ss -tulpn
sudo ufw status verbose
curl -k -u elastic https://127.0.0.1:9200/_cluster/health?pretty
```

En Kibana:

1. Abrir `http://192.168.6.200:5601`.
2. Crear o validar Data View `aegiscart-app-logs*`.
3. En Discover buscar `event_type:"checkout_success"`.
4. En Discover buscar `event_type:"checkout_failed"`.
5. Confirmar `extra_data.order_id`, `server`, `status` y `@timestamp`.

## Firewall en todos los servidores

Ejecutar en cada VM:

```bash
sudo ufw status verbose
sudo ss -tulpn
```

Revisar que solo esten abiertos los puertos necesarios para SSH, app, MariaDB desde `srv-app`, Zabbix y ELK/Kibana segun el rol del servidor.

## Laptop A - SSH keys y acceso

```bash
ssh-keygen -t ed25519 -C "laptop-a-aegiscart"
ssh-copy-id adminos@192.168.6.142
ssh-copy-id adminos@192.168.6.143
ssh-copy-id adminos@192.168.6.150
ssh-copy-id adminos@192.168.6.200
ssh adminos@192.168.6.142 hostname
ssh adminos@192.168.6.143 hostname
ssh adminos@192.168.6.150 hostname
ssh adminos@192.168.6.200 hostname
```

## Cron en srv-app

Instalar cuando se autorice:

```bash
crontab /opt/aegiscart/scripts/aegiscart_crontab.txt
crontab -l
```
