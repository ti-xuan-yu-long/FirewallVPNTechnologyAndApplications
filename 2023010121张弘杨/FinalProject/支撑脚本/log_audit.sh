#!/usr/bin/env bash

echo "=== Simulating 5 firewall violations ==="

echo "1. office -> dmz:22"
ip netns exec office bash -c "timeout 2 bash -c 'echo ok > /dev/tcp/10.40.0.2/22' || true"
sleep 1

echo "2. guest -> office"
ip netns exec guest bash -c "timeout 2 bash -c 'echo ok > /dev/tcp/10.20.0.2/8000' || true"
sleep 1

echo "3. guest -> dmz"
ip netns exec guest bash -c "timeout 2 bash -c 'echo ok > /dev/tcp/10.40.0.2/8080' || true"
sleep 1

echo "4. internet -> dmz:22"
ip netns exec internet bash -c "timeout 2 bash -c 'echo ok > /dev/tcp/203.0.113.1/22' || true"
sleep 1

echo "5. remote -> dmz:22"
ip netns exec remote bash -c "timeout 2 bash -c 'echo ok > /dev/tcp/10.40.0.2/22' || true"
sleep 1

echo ""
echo "=== Current iptables LOG counters (cumulative) ==="
ip netns exec fw iptables -L FORWARD -v -n --line-numbers | grep "LOG"

echo ""
echo "=== Current iptables REJECT counters (cumulative) ==="
ip netns exec fw iptables -L FORWARD -v -n --line-numbers | grep "REJECT"

echo ""
echo "Note: WSL2 kernel does not surface iptables LOG messages in dmesg/journalctl."
echo "      These counters serve as the audit record."
