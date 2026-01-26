#!/bin/bash
set -e

PROJECT="coredns"
SERVICE="${PROJECT}-macvlan.service"
RUNTIME="/usr/local/sbin/${PROJECT}-macvlan-runtime.sh"

# кладём runtime-скрипт
install -m 755 coredns-macvlan-runtime.sh "$RUNTIME"

# systemd unit
if [ ! -f /etc/systemd/system/$SERVICE ]; then
cat >/etc/systemd/system/$SERVICE <<EOF
[Unit]
Description=Macvlan network for CoreDNS
After=network-online.target docker.service
Wants=network-online.target docker.service

[Service]
Type=oneshot
ExecStartPre=/usr/bin/test -e /sys/class/net/eth0
ExecStart=$RUNTIME
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
fi

systemctl daemon-reload
systemctl enable "$SERVICE"
systemctl start "$SERVICE"

echo "CoreDNS macvlan установлен и переживает reboot"