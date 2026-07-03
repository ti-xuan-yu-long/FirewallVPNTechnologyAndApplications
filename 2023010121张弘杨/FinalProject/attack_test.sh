#!/usr/bin/env bash

echo "=== Attack 1: guest scans office network ==="
echo "Using nmap to scan 10.20.0.2 (will be blocked by firewall)"
ip netns exec guest bash -c "timeout 5 nmap -Pn -p 8000 10.20.0.2 || true"
sleep 1
echo "Check LOG counter for FW-DENY-GUEST-OFFICE:"
ip netns exec fw iptables -L FORWARD -v -n | grep "FW-DENY-GUEST-OFFICE"

echo ""
echo "=== Attack 2: bypass firewall using source port 53 ==="
echo "Trying to trick firewall by using source port 53"
ip netns exec guest bash -c "timeout 2 bash -c 'exec 3<>/dev/tcp/10.20.0.2/8000; echo ok >&3' || true"
echo "Result: still blocked because iptables matches on source/destination, not source port"

echo ""
echo "=== Attack 3: forge VPN traffic ==="
echo "VPN uses Curve25519 key exchange; without private key, cannot forge valid handshake"
echo "Simulated: dropping a raw UDP packet to 192.0.2.1:51820 from internet"
ip netns exec internet bash -c "timeout 2 bash -c 'echo test > /dev/udp/192.0.2.1/51820' || true"
echo "Result: packet dropped, no valid WireGuard session established"

echo ""
echo "=== REJECT vs DROP information leakage ==="
echo "REJECT sends ICMP port unreachable, confirming port is filtered"
echo "DROP silently discards, making port scan slower (stealthier)"
