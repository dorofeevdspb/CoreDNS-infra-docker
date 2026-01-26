#!/bin/bash
set -euo pipefail

PROJECT="coredns"

MACVLAN_SERVICE="${PROJECT}-macvlan.service"
COMPOSE_SERVICE="${PROJECT}-docker.service"

UNIT_DIR="/etc/systemd/system"
MACVLAN_UNIT_PATH="$UNIT_DIR/$MACVLAN_SERVICE"
COMPOSE_UNIT_PATH="$UNIT_DIR/$COMPOSE_SERVICE"

RUNTIME="/usr/local/sbin/${PROJECT}-macvlan-runtime.sh"
COMPOSE_CTL="/usr/local/sbin/${PROJECT}-dockerctl.sh"

# Names used by the installed units/scripts
DOCKER_NET="macvlan-${PROJECT}"
MACVLAN_IF="macvlan-${PROJECT}"

usage() {
	cat <<EOF
Usage: $0 [--down] [--purge-net] [--keep-scripts]

Removes the systemd services installed by install-coredns-macvlan.sh:
  - $MACVLAN_SERVICE (macvlan network)
  - $COMPOSE_SERVICE (docker compose)

Options:
  --down         Try to run 'docker compose down' (best-effort) before removal.
  --purge-net    Also remove docker network '$DOCKER_NET' and host iface '$MACVLAN_IF'.
  --keep-scripts Do not remove $RUNTIME and $COMPOSE_CTL.
  -h, --help     Show this help.
EOF
}

want_down=0
want_purge_net=0
keep_scripts=0

while [ $# -gt 0 ]; do
	case "$1" in
		--down)
			want_down=1
			shift
			;;
		--purge-net)
			want_purge_net=1
			shift
			;;
		--keep-scripts)
			keep_scripts=1
			shift
			;;
		-h|--help)
			usage
			exit 0
			;;
		*)
			echo "Unknown argument: $1" >&2
			usage >&2
			exit 2
			;;
	esac
done

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
	echo "This script must be run as root (needs to manage systemd and /usr/local/sbin)." >&2
	exit 1
fi

have_cmd() { command -v "$1" >/dev/null 2>&1; }

best_effort_compose_down() {
	# Try to discover COMPOSE_FILE from the installed wrapper; fallback to repo relative path.
	local compose_file=""
	if [ -r "$COMPOSE_CTL" ]; then
		compose_file="$(grep -E '^COMPOSE_FILE=' "$COMPOSE_CTL" | head -n1 | sed -E 's/^COMPOSE_FILE=//')" || true
		# COMPOSE_CTL uses printf %q, so the value may be quoted (', ", or $'').
		# Best-effort decode without sourcing the script.
		if [[ "$compose_file" == \$\'*\' ]]; then
			compose_file="$(printf '%b' "${compose_file:2:${#compose_file}-3}")" || true
		else
			compose_file="${compose_file%\"}"; compose_file="${compose_file#\"}"
			compose_file="${compose_file%\'}"; compose_file="${compose_file#\'}"
		fi
	fi

	if [ -z "$compose_file" ]; then
		local script_dir repo_root
		script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
		repo_root="$(cd "$script_dir/.." && pwd)"
		compose_file="$repo_root/CoreDNS/docker-compose.yml"
	fi

	if [ ! -f "$compose_file" ]; then
		echo "Skip compose down: compose file not found: $compose_file" >&2
		return 0
	fi

	if have_cmd docker && docker compose version >/dev/null 2>&1; then
		echo "Running: docker compose -f $compose_file down --remove-orphans"
		docker compose -f "$compose_file" down --remove-orphans || true
		return 0
	fi

	if have_cmd docker-compose; then
		echo "Running: docker-compose -f $compose_file down --remove-orphans"
		docker-compose -f "$compose_file" down --remove-orphans || true
		return 0
	fi

	echo "Skip compose down: neither 'docker compose' nor 'docker-compose' available" >&2
}

# 1) Stop services (compose first)
if have_cmd systemctl; then
	systemctl stop "$COMPOSE_SERVICE" >/dev/null 2>&1 || true
	systemctl stop "$MACVLAN_SERVICE" >/dev/null 2>&1 || true
else
	echo "systemctl not found; cannot manage systemd units" >&2
	exit 1
fi

# Optional: remove containers
if [ "$want_down" -eq 1 ]; then
	best_effort_compose_down
fi

# 2) Disable services
systemctl disable "$COMPOSE_SERVICE" >/dev/null 2>&1 || true
systemctl disable "$MACVLAN_SERVICE" >/dev/null 2>&1 || true

# 3) Remove unit files
rm -f "$COMPOSE_UNIT_PATH" "$MACVLAN_UNIT_PATH"

systemctl daemon-reload
systemctl reset-failed "$COMPOSE_SERVICE" "$MACVLAN_SERVICE" >/dev/null 2>&1 || true

# 4) Remove helper scripts
if [ "$keep_scripts" -eq 0 ]; then
	rm -f "$RUNTIME" "$COMPOSE_CTL"
fi

# 5) Remove macvlan network interface
if have_cmd ip; then
	ip link delete "$MACVLAN_IF" >/dev/null 2>&1 || true
	echo "Removed network interface: $MACVLAN_IF"
fi

# 6) Optional: remove docker network
if [ "$want_purge_net" -eq 1 ]; then
	if have_cmd docker; then
		docker network rm "$DOCKER_NET" >/dev/null 2>&1 || true
	fi
fi

echo "Removed: $MACVLAN_SERVICE, $COMPOSE_SERVICE"
echo "Removed network interface: $MACVLAN_IF"
if [ "$keep_scripts" -eq 0 ]; then
	echo "Removed: $RUNTIME, $COMPOSE_CTL"
else
	echo "Kept scripts: $RUNTIME, $COMPOSE_CTL"
fi
if [ "$want_purge_net" -eq 1 ]; then
	echo "Purged: docker network '$DOCKER_NET' (best-effort)"
fi
