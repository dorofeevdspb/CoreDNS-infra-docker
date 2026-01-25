#!/bin/bash




# Проверка и создание macvlan интерфейса, если не существует
if ! ip link show macvlan-CoreDNS &>/dev/null; then
  sudo ip link add macvlan-CoreDNS link eth0 type macvlan mode bridge
  echo "Создан интерфейс macvlan-CoreDNS."
else
  echo "Интерфейс macvlan-CoreDNS уже существует."
fi

# Включение интерфейса, если он не up
if ! ip link show macvlan-CoreDNS | grep -q 'state UP'; then
  sudo ip link set macvlan-CoreDNS up
  echo "Интерфейс macvlan-CoreDNS поднят."
else
  echo "Интерфейс macvlan-CoreDNS уже поднят."
fi

# Проверка наличия IP-адреса на интерфейсе (с любой маской)
if ! ip addr show macvlan-CoreDNS | grep -q '172.20.100.254'; then
  sudo ip addr add 172.20.100.254/24 dev macvlan-CoreDNS
  echo "Назначен IP 172.20.100.254/24 на macvlan-CoreDNS."
else
  echo "IP 172.20.100.254 уже назначен на macvlan-CoreDNS."
fi

sudo sysctl -w net.ipv4.ip_forward=1
sudo iptables -P FORWARD ACCEPT

# Проверка существования docker-сети
if ! sudo docker network ls --format '{{.Name}}' | grep -q '^macvlan-CoreDNS$'; then
  sudo docker network create -d macvlan \
    --subnet=172.20.100.0/24 \
    --gateway=172.20.100.254 \
    -o parent=eth0 \
    macvlan-CoreDNS
  echo "Создана docker-сеть macvlan-CoreDNS."
else
  echo "Docker-сеть macvlan-CoreDNS уже существует."
fi

