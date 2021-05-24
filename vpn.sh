#!/bin/bash

###### Script for making vpn connection over ssh
echo Set ssh domain or ip:
read server
echo User?
read user
gateway=$(ip route | grep "default" | cut -d " " -f 3 | head -n 1)
hostinterface=$(ip route | grep "default" | cut -d " " -f 5| head -n 1)
dns=$(systemd-resolve --status | grep "Current DNS Server" | head -n 1 | cut -d " " -f 6)
arr=()
while read p; do arr+=("$p");done < <(host $server | grep "has address" | cut -d " " -f 4)
(
while true; do
sudo ip tuntap add dev tun3 mode tun 2>/dev/null; echo Creating interface tun3
sudo ip link set tun3 up 2>/dev/null; echo tun3 up
sudo ip address add 172.16.1.2/32 peer 172.16.1.1/32 dev tun3 metric 10 2>/dev/null;echo Assing ip to interfaces
for i in "${arr[@]}";do sudo ip route add $i via $gateway dev $hostinterface 2>/dev/null;done
sudo ip route add $dns via $gateway 2>/dev/null;echo Add static routes for dns and your ssh server
sudo ip route replace default via 172.16.1.1;echo Routing all trafic via tun3
ssh \
  -o PermitLocalCommand=yes \
  -o ServerAliveInterval=60 \
  -o TCPKeepAlive=yes \
  -w 3:3 pi@ssh.javier.eu.org \
  'interface=$(ip route | grep "default" | cut -d " " -f 5| head -n 1);echo Nat interface: $interface;
   sudo ip tuntap add dev tun3 mode tun 2>/dev/null;echo creating interface tun3 server;
   sudo ip link set tun3 up 2>/dev/null;echo tun3 up;
   echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward; echo enabling ipv4 forwarding temporary;
   sudo iptables --table nat --append POSTROUTING --out-interface $interface -j MASQUERADE;echo Creating ip tables nat rule for traslating tun3 to $interface interface;
   sudo ip address add 172.16.1.1/32 peer 172.16.1.2/32 dev tun3 metric 10 2>/dev/null; echo tun3 ready'

echo "First time sometimes fail, retrying";
done
)&
pid=$!
sleep 40
sudo ip route del $dns via $gateway;echo Change dns route to go over the tunel
echo Press enter to exit.
echo "If u press crt-c or you kill the process your default via won't be restored..."
read
sudo ip route del default via 172.16.1.1
kill -SIGKILL -- -$(ps -o ppid=$pid)
echo Bye
