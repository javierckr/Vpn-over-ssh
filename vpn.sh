#!/bin/bash

###### Script for making vpn connection over ssh

# Constants
ROOT_UID=0     # Only users with $UID 0 have root privileges.
ARGS=2         # Required arguments
E_NOTROOT=87   # Non-root exit error.
E_BADARGS=85   # Bad arguments exit error.


# Run as root, of course.
if [ "$UID" -ne "$ROOT_UID" ]
then
    echo "Must be root to run this script."
    exit $E_NOTROOT
fi

# Correct number of arguments passed to script?
if [ $# -ne $ARGS ]
then
    echo "Usage: $(basename $0) user server"
    exit $E_BADARGS
fi


gateway=$(ip route | grep "default" | cut -d " " -f 3 | head -n 1)
hostinterface=$(ip route | grep "default" | cut -d " " -f 5| head -n 1)
dns=$(systemd-resolve --status |\
    grep "Current DNS Server" |\
    head -n 1 |\
    cut -d " " -f 6)


#echo Set ssh domain or ip:
#read server
#echo User?
#read user
ip tuntap add dev tun3 mode tun; echo Creating interface tun3
ip link set tun3 up; echo tun3 up
ip address add 172.16.1.2/32 peer 172.16.1.1/32 dev tun3 metric 10; echo Assing ip to interfaces
# Add routes to connect to your server cause your default gateway will be
#+ your own server  ¯\_(ツ)_/¯
for i in $(host $2 | grep "has address" | cut -d " " -f 4)
do
    ip route add $i via $gateway dev $hostinterface
done
ip route add $dns via $gateway; echo Add static routes for dns and your ssh server
ip route replace default via 172.16.1.1; echo Routing all trafic via tun3
ssh -o PermitLocalCommand=yes \
    -o ServerAliveInterval=60 \
    -o TCPKeepAlive=yes \
    -w 3:3 -t $1@$2\
    'interface=$(ip route | grep "default" | cut -d " " -f 5| head -n 1);echo Nat interface: $interface;
    sudo  ip tuntap add dev tun3 mode tun 2>/dev/null;echo creating interface tun3 server;
    sudo  ip link set tun3 up 2>/dev/null;echo tun3 up;
    echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward; echo enabling ipv4 forwarding temporary;
    sudo  iptables --table nat --append POSTROUTING --out-interface $interface -j MASQUERADE;echo Creating ip tables nat rule for traslating tun3 to $interface interface;
    sudo  ip address add 172.16.1.1/32 peer 172.16.1.2/32 dev tun3 metric 10 2>/dev/null; echo tun3 ready'&

    pid=$!

    sleep 20
    clear
    sudo ip route del $dns via $gateway ; echo Change dns route to go over the tunel
    echo Press enter to exit.
    echo "If u press crt-c or you kill the process your default via won't be restored..."
    read
    sudo ip route del default via 172.16.1.1
    kill $pid

    echo Bye
