#!/usr/bin/env bash

echo "=== Improvement: limit concurrent connections to dmz:8080 ==="

# Add connlimit rule at the top of FORWARD chain
ip netns exec fw iptables -I FORWARD 2 -p tcp -i veth-fw-inet -o veth-fw-dmz -d 10.40.0.2 --dport 8080 -m connlimit --connlimit-above 10 -j LOG --log-prefix "FW-DOS-DMZ: "
ip netns exec fw iptables -I FORWARD 3 -p tcp -i veth-fw-inet -o veth-fw-dmz -d 10.40.0.2 --dport 8080 -m connlimit --connlimit-above 10 -j REJECT

echo "Rule added. Current FORWARD chain:"
ip netns exec fw iptables -L FORWARD -v -n --line-numbers

echo ""
echo "=== Test: launch 15 concurrent connections ==="
for i in $(seq 1 15); do
    ip netns exec internet bash -c "timeout 3 bash -c 'echo ok > /dev/tcp/203.0.113.1/80' &"
done
wait
sleep 2

echo ""
echo "=== Check counters after DDoS test ==="
ip netns exec fw iptables -L FORWARD -v -n | grep -E "connlimit|FW-DOS"
