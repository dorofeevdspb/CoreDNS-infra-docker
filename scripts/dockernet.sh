


sudo ip link add macvlan-CoreDNS link eth0 type macvlan mode bridge
sudo ip addr add 172.20.100.254/24 dev macvlan-CoreDNS
sudo ip link set macvlan-CoreDNS up
sudo sysctl -w net.ipv4.ip_forward=1
sudo iptables -P FORWARD ACCEPT

sudo docker network create -d macvlan \
  --subnet=172.20.100.0/24 \
  --gateway=172.20.100.254 \
  -o parent=eth0 \
  macvlan-CoreDNS

