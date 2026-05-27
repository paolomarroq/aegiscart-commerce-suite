# Despliegue AegisCart en srv-app

Servidor objetivo: `srv-app` `192.168.6.142`.

## Copiar desde laptop

```bash
scp -r aegiscart-app adminos@192.168.6.142:/tmp/
```

## Preparar en srv-app

```bash
sudo mkdir -p /opt/aegiscart
sudo cp -r /tmp/aegiscart-app/* /opt/aegiscart/
sudo chown -R adminos:adminos /opt/aegiscart
cd /opt/aegiscart
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
nano .env
python app.py
```

## Instalar servicio systemd

```bash
sudo cp deployment/aegiscart.service /etc/systemd/system/aegiscart.service
sudo systemctl daemon-reload
sudo systemctl enable --now aegiscart
sudo systemctl status aegiscart --no-pager
```

## Probar

```bash
curl http://localhost:5000/health
curl http://192.168.6.142:5000/health
curl http://192.168.6.142:5000/api/products
curl http://192.168.6.142:5000/api/orders
```

## Firewall

```bash
sudo ufw allow 5000/tcp
sudo ufw allow 80/tcp
sudo ufw status
```

## Logs del servicio

```bash
sudo journalctl -u aegiscart -f
tail -f /opt/aegiscart/logs/aegiscart.log
```

## Nginx opcional

```bash
sudo cp deployment/nginx_aegiscart.conf /etc/nginx/sites-available/aegiscart
sudo ln -s /etc/nginx/sites-available/aegiscart /etc/nginx/sites-enabled/aegiscart
sudo nginx -t
sudo systemctl reload nginx
```

## Kibana

Crear data view:

```text
aegiscart-app-logs*
```

Buscar:

```text
checkout_success
checkout_failed
srv-app
health_check
```

## Script automatizado

Desde `/opt/aegiscart`:

```bash
chmod +x scripts/deploy_srv_app.sh scripts/smoke_test.sh
./scripts/deploy_srv_app.sh
sudo nano /opt/aegiscart/.env
sudo systemctl enable --now aegiscart
BASE_URL=http://localhost:5000 ./scripts/smoke_test.sh
```
