#!/usr/bin/env bash
set -euo pipefail

APP_DIR="/opt/aegiscart"
APP_USER="adminos"

sudo apt-get update
sudo apt-get install -y python3 python3-venv python3-pip nginx curl

sudo mkdir -p "$APP_DIR"
sudo rsync -a --delete --exclude ".env" --exclude "venv" --exclude ".venv" ./ "$APP_DIR/"
sudo chown -R "$APP_USER:$APP_USER" "$APP_DIR"

sudo -u "$APP_USER" python3 -m venv "$APP_DIR/venv"
sudo -u "$APP_USER" "$APP_DIR/venv/bin/pip" install --upgrade pip
sudo -u "$APP_USER" "$APP_DIR/venv/bin/pip" install -r "$APP_DIR/requirements.txt"

if [ ! -f "$APP_DIR/.env" ]; then
  sudo -u "$APP_USER" cp "$APP_DIR/.env.example" "$APP_DIR/.env"
  echo "Edita $APP_DIR/.env antes de iniciar el servicio."
fi

sudo cp "$APP_DIR/deployment/aegiscart.service" /etc/systemd/system/aegiscart.service
sudo systemctl daemon-reload

echo "Deployment preparado."
echo "Siguiente paso: sudo nano $APP_DIR/.env"
echo "Luego: sudo systemctl enable --now aegiscart"
