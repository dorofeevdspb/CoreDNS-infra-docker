
#!/bin/bash

# === Проверка и регистрация systemd-сервиса ===
SERVICE_NAME="dockernet"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
SCRIPT_PATH="$(readlink -f "$0")"

# Проверяем, существует ли unit-файл systemd
if [ ! -f "$SERVICE_FILE" ]; then
    echo "Systemd unit-файл не найден. Создаю..."
    sudo bash -c "cat > $SERVICE_FILE" <<EOF
[Unit]
Description=Dockernet network setup
After=network.target docker.service

[Service]
Type=oneshot
ExecStart=$SCRIPT_PATH
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
    sudo systemctl enable "$SERVICE_NAME"
    echo "Systemd unit создан и включён."
    # Продолжаем выполнение скрипта для создания интерфейсов
fi

# Проверяем, включён ли сервис
if ! systemctl is-enabled --quiet "$SERVICE_NAME"; then
    echo "Systemd unit найден, но не включён. Включаю..."
    sudo systemctl enable "$SERVICE_NAME"
    sudo systemctl daemon-reload
    echo "Systemd unit включён."
    # Продолжаем выполнение скрипта для создания интерфейсов
fi

# Если сервис уже добавлен и включён, продолжаем выполнение скрипта

# Имя интерфейса macvlan
MACVLAN_IF="macvlan-CoreDNS"
MACVLAN_IP="172.20.100.254/24"
MACVLAN_SUBNET="172.20.100.0/24"
MACVLAN_GATEWAY="172.20.100.1"
PARENT_IF="eth0"

# Создание интерфейса, если его нет
if ! ip link show "$MACVLAN_IF" &>/dev/null; then
    sudo ip link add "$MACVLAN_IF" link "$PARENT_IF" type macvlan mode bridge
    echo "Создан интерфейс $MACVLAN_IF."
fi

# Поднимаем интерфейс
sudo ip link set "$MACVLAN_IF" up
echo "Интерфейс $MACVLAN_IF поднят."

# Назначаем IP, если нет
if ! ip addr show "$MACVLAN_IF" | grep -wq "${MACVLAN_IP%/*}"; then
    sudo ip addr add "$MACVLAN_IP" dev "$MACVLAN_IF"
    echo "Назначен IP $MACVLAN_IP на $MACVLAN_IF."
else
    echo "IP $MACVLAN_IP уже назначен."
fi

# Включаем форвардинг и разрешаем Docker-forward
sudo sysctl -w net.ipv4.ip_forward=1
sudo iptables -P FORWARD ACCEPT

# Создаем Docker macvlan сеть, если нет
if ! sudo docker network ls --format '{{.Name}}' | grep -q '^macvlan-CoreDNS$'; then
    sudo docker network create -d macvlan \
        --subnet=$MACVLAN_SUBNET \
        --gateway=$MACVLAN_IP \
        -o parent=$PARENT_IF \
        macvlan-CoreDNS
    echo "Создана docker-сеть macvlan-CoreDNS."
else
    echo "Docker-сеть macvlan-CoreDNS уже существует."
fi