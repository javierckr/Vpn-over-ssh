#!/bin/bash

###### Script for making vpn connection over ssh

# Constants
ROOT_UID=0     # Only users with $UID 0 have root privileges.
ARGS=2         # Required arguments
E_NOTROOT=87   # Non-root exit error.
E_BADARGS=85   # Bad arguments exit error.
SOCKET=/tmp/vpn-ssh.socket  # Socket path for ssh control


# Run as root, of course.
if [ "$UID" -ne "$ROOT_UID" ]
then
    echo "Must be root to run this script." >&2
    exit $E_NOTROOT
fi

# Correct number of arguments passed to script?
if [ $# -ne $ARGS ]
then
    echo "Usage: $(basename $0) user server" >&2
    exit $E_BADARGS
fi

# Functions
exitn (){ # A nice exit $1: ssh pid $2: exit status
    ip route del default via 172.16.1.1 &> /dev/null
    ip tuntap del dev tun3 mode tun &> /dev/null
    for i in $serverips
    do
        ip route del $i via $gateway dev $hostinterface &> /dev/null
    done
    if [ $2 ]
    then
        ssh -S $SOCKET -O exit $server
        echo Bye
        exit $2
    else
        ip route del $dns via $gateway &> /dev/null
        echo Failed
        exit $1
    fi
}
trap ctrl_c INT
function ctrl_c() {
    exitn "$SOCKET" "0"
}

gateway=$(ip route | grep "default" | cut -d " " -f 3 | head -n 1)
hostinterface=$(ip route | grep "default" | cut -d " " -f 5| head -n 1)
dns=$(systemd-resolve --status |\
    grep "Current DNS Server" |\
    head -n 1 |\
    cut -d " " -f 6)

serverips=$(host $2 | grep "has address" | cut -d " " -f 4)
server=$2

ip tuntap add dev tun3 mode tun; echo Creating interface tun3
ip link set tun3 up; echo tun3 up
ip address add 172.16.1.2/32 peer 172.16.1.1/32 dev tun3 metric 10; echo Assing ip to interfaces
# Add routes to connect to your server cause your default gateway will be
#+ your own server  ¯\_(ツ)_/¯
for i in $serverips
do
    ip route add $i via $gateway dev $hostinterface
done
ip route add $dns via $gateway; echo Add static routes for dns and your ssh server
ip route replace default via 172.16.1.1; echo Routing all trafic via tun3
ssh -t $1@$2  'interface=$(ip route | grep "default" | cut -d " " -f 5| head -n 1);echo Nat interface: $interface;
sudo ip tuntap add dev tun3 mode tun 2>/dev/null;echo creating interface tun3 server;
sudo  ip link set tun3 up 2>/dev/null;echo tun3 up;
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward; echo enabling ipv4 forwarding temporary;
sudo  iptables --table nat --append POSTROUTING --out-interface $interface -j MASQUERADE;echo Creating ip tables nat rule for traslating tun3 to $interface interface;
sudo  ip address add 172.16.1.1/32 peer 172.16.1.2/32 dev tun3 metric 10 2>/dev/null; echo tun3 ready
exit 0' || exitn 1

ssh -NfT -o ServerAliveInterval=60 \
    -o TCPKeepAlive=yes \
    -M -S $SOCKET \
    -w 3:3 $1@$2 || exitn 1

ip route del $dns via $gateway ; echo Change dns route to go over the tunel
echo "Type # vpnoff for disconnect or /usr/local/sbin/vpnoff"
{
    # Exit code block
    echo "#!/bin/bash"
    echo "ip route del default via 172.16.1.1 &> /dev/null"
    echo "ip tuntap del dev tun3 mode tun &> /dev/null"
    for i in $serverips
    do
        echo "ip route del $i via $gateway dev $hostinterface &> /dev/null"
    done
    echo "ssh -S $SOCKET -O exit $server"
    echo "echo Bye"
    echo "rm \$0"
} > /usr/local/sbin/vpnoff
chmod 750 /usr/local/sbin/vpnoff
