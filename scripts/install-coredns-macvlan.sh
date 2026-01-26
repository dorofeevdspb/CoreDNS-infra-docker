#!/bin/bash
set -euo pipefail

PROJECT="coredns"
MACVLAN_SERVICE="${PROJECT}-macvlan.service"
RUNTIME="/usr/local/sbin/${PROJECT}-macvlan-runtime.sh"

# docker-compose wrapper + unit
COMPOSE_SERVICE="${PROJECT}-docker.service"
COMPOSE_CTL="/usr/local/sbin/${PROJECT}-dockerctl.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPOSE_DIR="$REPO_ROOT/CoreDNS"
COMPOSE_FILE="$COMPOSE_DIR/docker-compose.yml"
DOCKER_NET="macvlan-coredns"

# кладём runtime-скрипт
install -m 755 "$SCRIPT_DIR/coredns-macvlan-runtime.sh" "$RUNTIME"

# systemd unit: macvlan network (rewrite to keep it up to date)
cat >"/etc/systemd/system/$MACVLAN_SERVICE" <<EOF
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

# helper script to control docker compose reliably
cat >"$COMPOSE_CTL" <<EOF
#!/bin/bash
set -euo pipefail

COMPOSE_DIR="$COMPOSE_DIR"
COMPOSE_FILE="$COMPOSE_FILE"
DOCKER_NET="$DOCKER_NET"

MACVLAN_IF="macvlan-coredns"
MACVLAN_IP="172.20.100.254"

wait_ready() {
	local timeout="${1:-30}"
	local i
	for ((i=1; i<=timeout; i++)); do
		if ip link show "$MACVLAN_IF" >/dev/null 2>&1 \
			&& ip addr show "$MACVLAN_IF" | grep -qw "$MACVLAN_IP" \
			&& /usr/bin/docker network inspect "$DOCKER_NET" >/dev/null 2>&1; then
			return 0
		fi
		sleep 1
	done
	return 1
}

if [ ! -f "$COMPOSE_FILE" ]; then
	echo "Compose file not found: $COMPOSE_FILE" >&2
	exit 1
fi

cd "$COMPOSE_DIR"

compose() {
	if /usr/bin/docker compose version >/dev/null 2>&1; then
		/usr/bin/docker compose "$@"
		return
	fi
	if command -v docker-compose >/dev/null 2>&1; then
		docker-compose "$@"
		return
	fi
	echo "Neither 'docker compose' nor 'docker-compose' found" >&2
	exit 1
}

case "${1:-}" in
	up)
		if ! wait_ready 30; then
			echo "macvlan/docker network not ready after 30s: iface=$MACVLAN_IF ip=$MACVLAN_IP net=$DOCKER_NET" >&2
			ip link show "$MACVLAN_IF" || true
			ip addr show "$MACVLAN_IF" || true
			/usr/bin/docker network ls || true
			exit 1
		fi
		exec compose -f "$COMPOSE_FILE" up -d --remove-orphans
		;;
	stop)
		exec compose -f "$COMPOSE_FILE" stop
		;;
	restart)
		compose -f "$COMPOSE_FILE" stop
		exec compose -f "$COMPOSE_FILE" up -d --remove-orphans
		;;
	*)
		echo "Usage: $0 {up|stop|restart}" >&2
		exit 2
		;;
esac
EOF
chmod 0755 "$COMPOSE_CTL"

# systemd unit: ensure CoreDNS container starts after macvlan network exists (rewrite to keep it up to date)
cat >"/etc/systemd/system/$COMPOSE_SERVICE" <<EOF
[Unit]
Description=CoreDNS (docker compose)
Requires=docker.service $MACVLAN_SERVICE
After=network-online.target docker.service $MACVLAN_SERVICE
Wants=network-online.target

[Service]
Type=oneshot
TimeoutStartSec=60
Restart=on-failure
RestartSec=2
StartLimitIntervalSec=0
ExecStartPre=/usr/bin/docker network inspect $DOCKER_NET
ExecStartPre=/usr/bin/ip link show macvlan-coredns
ExecStartPre=/bin/bash -c '/usr/sbin/ip -o -4 addr show dev macvlan-coredns | grep -qw 172.20.100.254'
ExecStart=$COMPOSE_CTL up
ExecStop=$COMPOSE_CTL stop
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

systemctl enable "$MACVLAN_SERVICE"
systemctl start "$MACVLAN_SERVICE"

systemctl enable "$COMPOSE_SERVICE"
systemctl start "$COMPOSE_SERVICE"

echo "CoreDNS macvlan + compose units installed and enabled (reboot-safe)"