
`    ./README.md    `

#### адрес для контейнера (согласно DNS на роутере)

`172.20.0.101 git.lan`

#### добавить линк в контейнер
обратить внимание интефейс **eth0**
```sh
sudo ip link add macvlan_host link eth0 type macvlan mode bridge
sudo ip link set macvlan_host up
```

#### создать сетку для докера
```sh
sudo docker network create -d macvlan \
  --subnet=172.20.100.0/24 \
  --gateway=172.20.100.1 \
  -o parent=eth0 \
  macvlan_net
```