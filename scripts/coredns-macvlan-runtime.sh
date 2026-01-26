#!/bin/bash
set -e

# === ИМЕНА ===
PROJECT="coredns"
MACVLAN_IF="macvlan-${PROJECT}"
DOCKER_NET="macvlan-${PROJECT}"

# === СЕТЬ ===
MACVLAN_IP="172.20.100.254/24"
MACVLAN_SUBNET="172.20.100.0/24"
MACVLAN_GATEWAY="172.20.100.1"
PARENT_IF="eth0"

# === macvlan интерфейс хоста ===
if ! ip link show "$MACVLAN_IF" &>/dev/null; then
    ip link add "$MACVLAN_IF" link "$PARENT_IF" type macvlan mode bridge
fi

ip link set "$MACVLAN_IF" up

if ! ip addr show "$MACVLAN_IF" | grep -q "${MACVLAN_IP%/*}"; then
    ip addr add "$MACVLAN_IP" dev "$MACVLAN_IF"
fi

# === системные настройки ===
sysctl -w net.ipv4.ip_forward=1 >/dev/null

# === docker macvlan сеть ===
if ! docker network inspect "$DOCKER_NET" &>/dev/null; then
    docker network create -d macvlan \
        --subnet="$MACVLAN_SUBNET" \
        --gateway="$MACVLAN_GATEWAY" \
        -o parent="$PARENT_IF" \
        "$DOCKER_NET"
fi