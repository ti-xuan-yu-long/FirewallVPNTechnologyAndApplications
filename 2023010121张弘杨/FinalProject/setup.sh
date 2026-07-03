#!/usr/bin/env bash
set -e

echo "=== Step 1: cleanup old environment ==="
bash cleanup.sh 2>/dev/null || true

echo "=== Step 2: create namespaces ==="
for ns in fw office guest dmz internet remote; do
    ip netns add "$ns"
    ip netns exec "$ns" ip link set lo up
done

echo "=== Step 3: create veth pairs and attach ==="
# office
ip link add veth-fw-office type veth peer name veth-office-fw
ip link set veth-fw-office netns fw
ip link set veth-office-fw netns office
ip netns exec fw ip addr add 10.20.0.1/24 dev veth-fw-office
ip netns exec fw ip link set veth-fw-office up
ip netns exec office ip addr add 10.20.0.2/24 dev veth-office-fw
ip netns exec office ip link set veth-office-fw up
ip netns exec office ip route add default via 10.20.0.1

# guest
ip link add veth-fw-guest type veth peer name veth-guest-fw
ip link set veth-fw-guest netns fw
ip link set veth-guest-fw netns guest
ip netns exec fw ip addr add 10.30.0.1/24 dev veth-fw-guest
ip netns exec fw ip link set veth-fw-guest up
ip netns exec guest ip addr add 10.30.0.2/24 dev veth-guest-fw
ip netns exec guest ip link set veth-guest-fw up
ip netns exec guest ip route add default via 10.30.0.1

# dmz
ip link add veth-fw-dmz type veth peer name veth-dmz-fw
ip link set veth-fw-dmz netns fw
ip link set veth-dmz-fw netns dmz
ip netns exec fw ip addr add 10.40.0.1/24 dev veth-fw-dmz
ip netns exec fw ip link set veth-fw-dmz up
ip netns exec dmz ip addr add 10.40.0.2/24 dev veth-dmz-fw
ip netns exec dmz ip link set veth-dmz-fw up
ip netns exec dmz ip route add default via 10.40.0.1

# internet
ip link add veth-fw-inet type veth peer name veth-inet-fw
ip link set veth-fw-inet netns fw
ip link set veth-inet-fw netns internet
ip netns exec fw ip addr add 203.0.113.1/24 dev veth-fw-inet
ip netns exec fw ip link set veth-fw-inet up
ip netns exec internet ip addr add 203.0.113.10/24 dev veth-inet-fw
ip netns exec internet ip link set veth-inet-fw up
ip netns exec internet ip route add default via 203.0.113.1

# remote physical link (for VPN)
ip link add veth-fw-vpn type veth peer name veth-remote-fw
ip link set veth-fw-vpn netns fw
ip link set veth-remote-fw netns remote
ip netns exec fw ip addr add 192.0.2.1/24 dev veth-fw-vpn
ip netns exec fw ip link set veth-fw-vpn up
ip netns exec remote ip addr add 192.0.2.2/24 dev veth-remote-fw
ip netns exec remote ip link set veth-remote-fw up

echo "=== Step 4: enable IP forwarding on fw ==="
ip netns exec fw sysctl -w net.ipv4.ip_forward=1

echo "=== Step 5: basic connectivity test ==="
ip netns exec office ping -c 1 10.20.0.1
ip netns exec guest ping -c 1 10.30.0.1
ip netns exec dmz ping -c 1 10.40.0.1
ip netns exec internet ping -c 1 203.0.113.1

echo "=== Setup complete ==="
