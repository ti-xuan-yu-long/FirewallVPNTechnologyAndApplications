#!/usr/bin/env bash

echo "=== Defense Analysis: iptables LOG counters ==="
ip netns exec fw iptables -L FORWARD -v -n | grep -E "LOG|REJECT"

echo ""
echo "=== Top denied sources ==="
echo "guest -> office attempts:"
ip netns exec fw iptables -L FORWARD -v -n | grep "FW-DENY-GUEST-OFFICE"

echo ""
echo "guest -> dmz attempts:"
ip netns exec fw iptables -L FORWARD -v -n | grep "FW-DENY-GUEST-DMZ"

echo ""
echo "SSH intrusion attempts:"
ip netns exec fw iptables -L FORWARD -v -n | grep -E "FW-DENY-(OFFICE|INET|VPN)-SSH"

echo ""
echo "=== Rule hit summary ==="
echo "Allow office->dmz:8080:"
ip netns exec fw iptables -L FORWARD -v -n | grep "veth-fw-office.*veth-fw-dmz.*dpt:8080"

echo ""
echo "Allow office->internet:"
ip netns exec fw iptables -L FORWARD -v -n | grep "veth-fw-office.*veth-fw-inet"

echo ""
echo "Allow guest->internet:"
ip netns exec fw iptables -L FORWARD -v -n | grep "veth-fw-guest.*veth-fw-inet"
