#!/usr/bin/env bash
set -e

FW="fw"
EXEC="ip netns exec $FW"

echo "=== Flush old rules ==="
$EXEC iptables -F
$EXEC iptables -t nat -F
$EXEC iptables -X
$EXEC iptables -t nat -X

echo "=== Set default policies ==="
$EXEC iptables -P FORWARD DROP
$EXEC iptables -P INPUT DROP
$EXEC iptables -P OUTPUT ACCEPT

echo "=== Allow established/related ==="
$EXEC iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
$EXEC iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

echo "=== Office zone ==="
$EXEC iptables -A FORWARD -p tcp -i veth-fw-office -o veth-fw-dmz -s 10.20.0.0/24 -d 10.40.0.0/24 --dport 8080 -j ACCEPT
$EXEC iptables -A FORWARD -i veth-fw-office -o veth-fw-inet -s 10.20.0.0/24 -j ACCEPT
$EXEC iptables -A FORWARD -p tcp -i veth-fw-office -o veth-fw-dmz -s 10.20.0.0/24 -d 10.40.0.0/24 --dport 22 -j LOG --log-prefix "FW-DENY-OFFICE-SSH: "
$EXEC iptables -A FORWARD -p tcp -i veth-fw-office -o veth-fw-dmz -s 10.20.0.0/24 -d 10.40.0.0/24 --dport 22 -j REJECT

echo "=== Guest zone ==="
$EXEC iptables -A FORWARD -i veth-fw-guest -o veth-fw-inet -s 10.30.0.0/24 -j ACCEPT
$EXEC iptables -A FORWARD -i veth-fw-guest -o veth-fw-office -s 10.30.0.0/24 -j LOG --log-prefix "FW-DENY-GUEST-OFFICE: "
$EXEC iptables -A FORWARD -i veth-fw-guest -o veth-fw-office -s 10.30.0.0/24 -j REJECT
$EXEC iptables -A FORWARD -i veth-fw-guest -o veth-fw-dmz -s 10.30.0.0/24 -j LOG --log-prefix "FW-DENY-GUEST-DMZ: "
$EXEC iptables -A FORWARD -i veth-fw-guest -o veth-fw-dmz -s 10.30.0.0/24 -j REJECT

echo "=== Internet -> DMZ DNAT ==="
$EXEC iptables -A FORWARD -p tcp -i veth-fw-inet -o veth-fw-dmz -d 10.40.0.2 --dport 8080 -j ACCEPT
$EXEC iptables -t nat -A PREROUTING -p tcp -i veth-fw-inet -d 203.0.113.1 --dport 80 -j DNAT --to-destination 10.40.0.2:8080
$EXEC iptables -A FORWARD -p tcp -i veth-fw-inet -o veth-fw-dmz -d 203.0.113.1 --dport 22 -j LOG --log-prefix "FW-DENY-INET-SSH: "
$EXEC iptables -A FORWARD -p tcp -i veth-fw-inet -o veth-fw-dmz -d 203.0.113.1 --dport 22 -j REJECT

echo "=== SNAT ==="
$EXEC iptables -t nat -A POSTROUTING -o veth-fw-inet -j MASQUERADE

echo "=== INPUT rules (allow WireGuard + ICMP + lo) ==="
$EXEC iptables -A INPUT -i lo -j ACCEPT
$EXEC iptables -A INPUT -p udp --dport 51820 -j ACCEPT
$EXEC iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT

echo "=== Firewall rules applied ==="
$EXEC iptables -L -v -n
