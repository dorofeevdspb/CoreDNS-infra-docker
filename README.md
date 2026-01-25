
`    ./README.md    `



#### удалить все (запускать от рута)

```sh
 docker stop $(docker ps -q) 2>/dev/null; docker rm $(docker ps -qa) 2>/dev/null; docker volume rm $(docker volume ls -q) 2>/dev/null; docker network rm $(docker network ls -q) 2>/dev/null; docker system prune -a --volumes -f

```


#### адрес для контейнера (согласно DNS на роутере)

`172.20.100.10 `

#### добавить линк в контейнер
обратить внимание интефейс **eth0**

```sh

sudo ip link add macvlan-CoreDNS link eth0 type macvlan mode bridge
sudo ip addr add 172.20.100.254/24 dev macvlan-CoreDNS
sudo ip link set macvlan-CoreDNS up
sudo sysctl -w net.ipv4.ip_forward=1
sudo iptables -P FORWARD ACCEPT

```

#### создать сетку для докера
```sh

sudo docker network create -d macvlan \
  --subnet=172.20.100.0/24 \
  --gateway=172.20.100.1 \
  -o parent=eth0 \
  macvlan-CoreDNS


```



# открыть форвардинг, если фаервол блокирует (выберите ваш вариант)
# iptables (legacy):
sudo iptables -P FORWARD ACCEPT
# nftables (пример — разрешить форвардинг):
sudo nft add table inet filter
sudo nft add chain inet filter forward '{ type filter hook forward priority 0; policy accept; }'