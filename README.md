# Vpn-over-ssh
----------------------------------------------
Bash script for tunneling all traffic over ssh

### Requierements

This script only works on linux, server and host, you need super cow
powers in both.

This script will transform your ssh server into a gateway, but all changes it makes are restored at 
reboot.

The script uses ip tables and iproute2, usually installed by default.

### Use instructions
1. Download vpn.sh
2. Change permisions so you can execute `chmod +x vpn.sh`
3. Run `./vpn.sh`
