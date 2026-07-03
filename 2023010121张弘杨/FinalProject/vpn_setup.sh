#!/usr/bin/env bash
set -e

mkdir -p /etc/wireguard
mkdir -p /tmp/wgkeys

gen_keys() {
    local name=$1
    wg genkey | tee /tmp/wgkeys/${name}_private | wg pubkey > /tmp/wgkeys/${name}_public
}

gen_keys fw
gen_keys remote

FW_PRIV=$(cat /tmp/wgkeys/fw_private)
FW_PUB=$(cat /tmp/wgkeys/fw_public)
REMOTE_PRIV=$(cat /tmp/wgkeys/remote_private)
REMOTE_PUB=$(cat /tmp/wgkeys/remote_public)

cat > /etc/wireguard/fw.conf <<EOF
[Interface]
PrivateKey = ${FW_PRIV}
ListenPort = 51820

[Peer]
PublicKey = ${REMOTE_PUB}
AllowedIPs = 10.10.10.2/32, 10.20.0.0/24, 10.40.0.0/24
PersistentKeepalive = 25
EOF

cat > /etc/wireguard/remote.conf <<EOF
[Interface]
PrivateKey = ${REMOTE_PRIV}
ListenPort = 51821

[Peer]
PublicKey = ${FW_PUB}
Endpoint = 192.0.2.1:51820
AllowedIPs = 10.10.10.0/24, 10.20.0.0/24, 10.40.0.0/24
PersistentKeepalive = 25
EOF

# Setup fw wg0 manually
ip netns exec fw ip link add dev wg0 type wireguard
ip netns exec fw wg setconf wg0 /etc/wireguard/fw.conf
ip netns exec fw ip address add 10.10.10.1/24 dev wg0
ip netns exec fw ip link set up dev wg0

# Setup remote wg0 manually
ip netns exec remote ip link add dev wg0 type wireguard
ip netns exec remote wg setconf wg0 /etc/wireguard/remote.conf
ip netns exec remote ip address add 10.10.10.2/24 dev wg0
ip netns exec remote ip link set up dev wg0

# Add remote routes manually
ip netns exec remote ip route add 10.20.0.0/24 dev wg0
ip netns exec remote ip route add 10.40.0.0/24 dev wg0

# Firewall rules for VPN
ip netns exec fw iptables -A FORWARD -i wg0 -s 10.10.10.2/32 -o veth-fw-office -d 10.20.0.0/24 -j ACCEPT
ip netns exec fw iptables -A FORWARD -i wg0 -s 10.10.10.2/32 -o veth-fw-dmz -d 10.40.0.0/24 -p tcp --dport 8080 -j ACCEPT
ip netns exec fw iptables -A FORWARD -i wg0 -s 10.10.10.2/32 -o veth-fw-dmz -d 10.40.0.0/24 -p tcp --dport 22 -j LOG --log-prefix "FW-DENY-VPN-SSH: "
ip netns exec fw iptables -A FORWARD -i wg0 -s 10.10.10.2/32 -o veth-fw-dmz -d 10.40.0.0/24 -p tcp --dport 22 -j REJECT
ip netns exec fw iptables -A FORWARD -i wg0 -s 10.10.10.2/32 -o veth-fw-guest -d 10.30.0.0/24 -j LOG --log-prefix "FW-DENY-VPN-GUEST: "
ip netns exec fw iptables -A FORWARD -i wg0 -s 10.10.10.2/32 -o veth-fw-guest -d 10.30.0.0/24 -j REJECT

echo "=== VPN setup complete ==="
ip netns exec fw wg show
