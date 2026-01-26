# CoreDNS в Docker + macvlan (systemd)

Этот репозиторий поднимает CoreDNS в Docker на macvlan-сети (фиксированный IP) и добавляет systemd-юниты, чтобы всё стартовало после ребута.
## Что внутри

- `CoreDNS/docker-compose.yml` — контейнер CoreDNS (порт 53/tcp+udp) и подключение к внешней docker macvlan-сети `macvlan-coredns`.
- `CoreDNS/Corefile` — конфигурация CoreDNS.
- `scripts/coredns-macvlan-runtime.sh` — создаёт host macvlan-интерфейс и docker macvlan network.
- `scripts/install-coredns-macvlan.sh` — устанавливает systemd-юниты + helper-скрипты.
- `scripts/uninstall-coredns-macvlan.sh` — удаляет установленные службы (и опционально сеть/интерфейс).

## Требования

- Linux с systemd
- Docker (рекомендуется Docker Compose v2: `docker compose ...`)
- root-доступ (юниты пишутся в `/etc/systemd/system`, скрипты — в `/usr/local/sbin`)

## Настройка сети (важно)

По умолчанию параметры сети захардкожены в `scripts/coredns-macvlan-runtime.sh`:
- `PARENT_IF="eth0"`
- `MACVLAN_SUBNET="172.20.100.0/24"`
- `MACVLAN_GATEWAY="172.20.100.1"`
- host-интерфейс `macvlan-coredns` получает IP `172.20.100.254/24`
- контейнер CoreDNS получает IP `172.20.100.10` (см. `CoreDNS/docker-compose.yml`)

Если у вас родительский интерфейс не `eth0` (например, `enp3s0`, `bond0`, `br0`) — сначала поправьте `PARENT_IF`.
## Установка (systemd, "как сервис")

1) Настройте `CoreDNS/Corefile` под ваши домены/форвардеры.

2) Установите и запустите службы:

# CoreDNS в Docker + macvlan (systemd)

Этот репозиторий поднимает CoreDNS в Docker на macvlan-сети (фиксированный IP) и добавляет systemd-юниты, чтобы всё стартовало после ребута.

## Что внутри

- `CoreDNS/docker-compose.yml` — контейнер CoreDNS (порт 53/tcp+udp) и подключение к внешней docker macvlan-сети `macvlan-coredns`.
- `CoreDNS/Corefile` — конфигурация CoreDNS.
- `scripts/coredns-macvlan-runtime.sh` — создаёт host macvlan-интерфейс и docker macvlan network.
- `scripts/install-coredns-macvlan.sh` — устанавливает systemd-юниты + helper-скрипты.
- `scripts/uninstall-coredns-macvlan.sh` — удаляет установленные службы (и опционально сеть/интерфейс).

## Требования

- Linux с systemd
- Docker (рекомендуется Docker Compose v2: `docker compose ...`)
- root-доступ (юниты пишутся в `/etc/systemd/system`, скрипты — в `/usr/local/sbin`)

## Настройка сети (важно)

По умолчанию параметры сети захардкожены в `scripts/coredns-macvlan-runtime.sh`:

- `PARENT_IF="eth0"`
- `MACVLAN_SUBNET="172.20.100.0/24"`
- `MACVLAN_GATEWAY="172.20.100.1"`
- host-интерфейс `macvlan-coredns` получает IP `172.20.100.254/24`
- контейнер CoreDNS получает IP `172.20.100.10` (см. `CoreDNS/docker-compose.yml`)

Если у вас родительский интерфейс не `eth0` (например, `enp3s0`, `bond0`, `br0`) — сначала поправьте `PARENT_IF`.

Важно: `scripts/install-coredns-macvlan.sh` копирует runtime-скрипт в `/usr/local/sbin/coredns-macvlan-runtime.sh`. Если вы поменяли `scripts/coredns-macvlan-runtime.sh` в репозитории — переустановите (`install-` скрипт), чтобы изменения попали в систему.

## Установка (systemd, "как сервис")

1) Настройте `CoreDNS/Corefile` под ваши домены/форвардеры.

2) Установите и запустите службы:

```sh
sudo ./scripts/install-coredns-macvlan.sh
```

Скрипт создаёт и включает 2 юнита:

- `coredns-macvlan.service` — создаёт host macvlan-интерфейс и docker сеть `macvlan-coredns`
- `coredns-docker.service` — поднимает CoreDNS через docker compose

Проверка:

```sh
systemctl status coredns-macvlan.service
systemctl status coredns-docker.service
docker ps --filter name=coredns
```

## Управление

```sh
sudo systemctl restart coredns-docker.service
sudo systemctl stop coredns-docker.service
sudo systemctl start coredns-docker.service
```

macvlan-юнит обычно трогать не нужно, но при необходимости:

```sh
sudo systemctl restart coredns-macvlan.service
```

## Удаление (uninstall)

Удаляет systemd-юниты и (по умолчанию) helper-скрипты из `/usr/local/sbin`:

```sh
sudo ./scripts/uninstall-coredns-macvlan.sh
```

Доп. опции:

- удалить контейнеры через `docker compose down` (best-effort):

```sh
sudo ./scripts/uninstall-coredns-macvlan.sh --down
```

- дополнительно удалить docker network и host macvlan-интерфейс:

```sh
sudo ./scripts/uninstall-coredns-macvlan.sh --purge-net
```

## Ручной запуск без systemd (опционально)

1) Создайте macvlan-интерфейс/сеть:

```sh
sudo ./scripts/coredns-macvlan-runtime.sh
```

2) Поднимите CoreDNS:

```sh
cd CoreDNS
docker compose up -d
```

## Troubleshooting

- Если у вас нет `eth0`, установка упадёт на `ExecStartPre=/usr/bin/test -e /sys/class/net/eth0` — поменяйте `PARENT_IF` в `scripts/coredns-macvlan-runtime.sh`. Также обновите проверку интерфейса в `scripts/install-coredns-macvlan.sh` и переустановите.
- Если сервис `coredns-docker.service` падает, он проверяет готовность:
  - наличие интерфейса `macvlan-coredns`
  - наличие IP `172.20.100.254` на нём
  - наличие docker сети `macvlan-coredns`
- Если порт 53 уже занят (часто `systemd-resolved`), CoreDNS контейнер не сможет стартовать. Освободите 53/tcp+udp на хосте или поменяйте проброс портов в `CoreDNS/docker-compose.yml`.



## настройки на MIkrotik

```sh

# dobavit addres
/ip address 
add address=172.20.100.1/24 comment=docker interface=bridge network=\
    172.20.100.0

# Dobavit DNS
/ip dns
set allow-remote-requests=yes servers=\
    172.20.100.10,8.8.4.4,8.8.8.8,2001:4860:4860::8844,2001:4860:4860::8888 \
    use-doh-server=https://dns.google/dns-query verify-doh-cert=yes

# Dobavit Route
/ip route
add comment=CoreDNS disabled=no distance=1 dst-address=172.20.100.0/24 \
    gateway=172.20.0.5 routing-table=main suppress-hw-offload=no


```



## Опасная команда (полное удаление всего Docker на хосте)

Ниже — разрушительная команда, которая останавливает/удаляет ВСЕ контейнеры/volumes/networks на хосте. Используйте только если вы точно понимаете последствия:

```sh

sudo sh -c 'docker stop $(docker ps -q) 2>/dev/null; \
docker rm $(docker ps -qa) 2>/dev/null; \
docker volume rm $(docker volume ls -q) 2>/dev/null; \
docker network rm $(docker network ls -q) 2>/dev/null; \
docker system prune -a --volumes -f'

```




