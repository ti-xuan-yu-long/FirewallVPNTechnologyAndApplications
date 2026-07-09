#!/usr/bin/env bash
# firewall.sh - 防火墙规则配置 + LOG审计规则 + connlimit DDoS防御 + VPN FORWARD规则
# 用法: sudo bash firewall.sh
# 注意: 需要先运行 setup.sh 创建命名空间和 WireGuard VPN

set -e

FW="fw"
EXEC="ip netns exec $FW"

echo "=== Flush old rules ==="
$EXEC iptables -F
$EXEC iptables -t nat -F
$EXEC iptables -X
$EXEC iptables -t nat -X

echo "=== Set default policies (Default Deny) ==="
$EXEC iptables -P FORWARD DROP
$EXEC iptables -P INPUT DROP
$EXEC iptables -P OUTPUT ACCEPT

echo "=== Allow established/related (Stateful Inspection) ==="
$EXEC iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
$EXEC iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

echo "=== connlimit: DDoS defense (max 10 concurrent to dmz:8080) ==="
$EXEC iptables -A FORWARD -p tcp -i veth-fw-inet -o veth-fw-dmz -d 10.40.0.2 --dport 8080 -m connlimit --connlimit-above 10 -j LOG --log-prefix "FW-DOS-DMZ: "
$EXEC iptables -A FORWARD -p tcp -i veth-fw-inet -o veth-fw-dmz -d 10.40.0.2 --dport 8080 -m connlimit --connlimit-above 10 -j REJECT

echo "=== Office zone rules ==="
# office -> dmz:8080 允许（业务访问）
$EXEC iptables -A FORWARD -p tcp -i veth-fw-office -o veth-fw-dmz -s 10.20.0.0/24 -d 10.40.0.0/24 --dport 8080 -j ACCEPT
# office -> internet 允许（SNAT）
$EXEC iptables -A FORWARD -i veth-fw-office -o veth-fw-inet -s 10.20.0.0/24 -j ACCEPT
# office -> dmz:22 拒绝（LOG + REJECT）
$EXEC iptables -A FORWARD -p tcp -i veth-fw-office -o veth-fw-dmz -s 10.20.0.0/24 -d 10.40.0.0/24 --dport 22 -j LOG --log-prefix "FW-DENY-OFFICE-SSH: "
$EXEC iptables -A FORWARD -p tcp -i veth-fw-office -o veth-fw-dmz -s 10.20.0.0/24 -d 10.40.0.0/24 --dport 22 -j REJECT

echo "=== Guest zone rules ==="
# guest -> internet 允许（SNAT）
$EXEC iptables -A FORWARD -i veth-fw-guest -o veth-fw-inet -s 10.30.0.0/24 -j ACCEPT
# guest -> office 拒绝（LOG + REJECT）
$EXEC iptables -A FORWARD -i veth-fw-guest -o veth-fw-office -s 10.30.0.0/24 -j LOG --log-prefix "FW-DENY-GUEST-OFFICE: "
$EXEC iptables -A FORWARD -i veth-fw-guest -o veth-fw-office -s 10.30.0.0/24 -j REJECT
# guest -> dmz 拒绝（LOG + REJECT）
$EXEC iptables -A FORWARD -i veth-fw-guest -o veth-fw-dmz -s 10.30.0.0/24 -j LOG --log-prefix "FW-DENY-GUEST-DMZ: "
$EXEC iptables -A FORWARD -i veth-fw-guest -o veth-fw-dmz -s 10.30.0.0/24 -j REJECT

echo "=== Internet -> DMZ (DNAT) rules ==="
# internet -> dmz:8080 允许（DNAT后的访问）
$EXEC iptables -A FORWARD -p tcp -i veth-fw-inet -o veth-fw-dmz -d 10.40.0.2 --dport 8080 -j ACCEPT
# DNAT: 203.0.113.1:80 -> 10.40.0.2:8080
$EXEC iptables -t nat -A PREROUTING -p tcp -i veth-fw-inet -d 203.0.113.1 --dport 80 -j DNAT --to-destination 10.40.0.2:8080
# internet -> dmz:22 拒绝（LOG + REJECT）
$EXEC iptables -A FORWARD -p tcp -i veth-fw-inet -o veth-fw-dmz -d 203.0.113.1 --dport 22 -j LOG --log-prefix "FW-DENY-INET-SSH: "
$EXEC iptables -A FORWARD -p tcp -i veth-fw-inet -o veth-fw-dmz -d 203.0.113.1 --dport 22 -j REJECT

echo "=== VPN (wg0) FORWARD rules ==="
# VPN -> office 允许
$EXEC iptables -A FORWARD -i wg0 -s 10.10.10.2/32 -o veth-fw-office -d 10.20.0.0/24 -j ACCEPT
# VPN -> dmz:8080 允许
$EXEC iptables -A FORWARD -i wg0 -s 10.10.10.2/32 -o veth-fw-dmz -d 10.40.0.0/24 -p tcp --dport 8080 -j ACCEPT
# VPN -> dmz:22 拒绝（LOG + REJECT）
$EXEC iptables -A FORWARD -i wg0 -s 10.10.10.2/32 -o veth-fw-dmz -d 10.40.0.0/24 -p tcp --dport 22 -j LOG --log-prefix "FW-DENY-VPN-SSH: "
$EXEC iptables -A FORWARD -i wg0 -s 10.10.10.2/32 -o veth-fw-dmz -d 10.40.0.0/24 -p tcp --dport 22 -j REJECT
# VPN -> guest 拒绝（LOG + REJECT）
$EXEC iptables -A FORWARD -i wg0 -s 10.10.10.2/32 -o veth-fw-guest -d 10.30.0.0/24 -j LOG --log-prefix "FW-DENY-VPN-GUEST: "
$EXEC iptables -A FORWARD -i wg0 -s 10.10.10.2/32 -o veth-fw-guest -d 10.30.0.0/24 -j REJECT

echo "=== SNAT (MASQUERADE) ==="
$EXEC iptables -t nat -A POSTROUTING -o veth-fw-inet -j MASQUERADE

echo "=== INPUT rules (allow WireGuard + ICMP + lo) ==="
$EXEC iptables -A INPUT -i lo -j ACCEPT
$EXEC iptables -A INPUT -p udp --dport 51820 -j ACCEPT
$EXEC iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT

echo "=== Firewall rules applied ==="
echo ""
echo "--- FILTER table ---"
$EXEC iptables -L -v -n
echo ""
echo "--- NAT table ---"
$EXEC iptables -t nat -L -v -n
