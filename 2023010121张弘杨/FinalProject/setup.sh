#!/usr/bin/env bash
# setup.sh - 网络拓扑搭建 + HTTP服务启动 + WireGuard VPN配置 + 环境清理
# 用法:
#   sudo bash setup.sh          # 搭建完整环境（拓扑+服务+VPN）
#   sudo bash setup.sh cleanup  # 清理环境

set -e

# ==================== 清理函数 ====================
cleanup() {
    set +e
    echo "=== Cleaning up old environment ==="
    for ns in fw office guest dmz internet remote; do
        ip netns exec "$ns" ip link delete wg0 2>/dev/null
        ip netns del "$ns" 2>/dev/null
    done
    rm -rf /tmp/wgkeys
    echo "Cleanup complete"
    exit 0
}

# 如果参数是 cleanup，执行清理
if [ "$1" = "cleanup" ]; then
    cleanup
fi

# ==================== Step 1: 清理旧环境 ====================
echo "=== Step 1: cleanup old environment ==="
for ns in fw office guest dmz internet remote; do
    ip netns exec "$ns" ip link delete wg0 2>/dev/null || true
    ip netns del "$ns" 2>/dev/null || true
done
rm -rf /tmp/wgkeys

# ==================== Step 2: 创建命名空间 ====================
echo "=== Step 2: create namespaces ==="
for ns in fw office guest dmz internet remote; do
    ip netns add "$ns"
    ip netns exec "$ns" ip link set lo up
done

# ==================== Step 3: 创建 veth 对并配置 IP ====================
echo "=== Step 3: create veth pairs and configure IPs ==="

# office <--> fw
ip link add veth-fw-office type veth peer name veth-office-fw
ip link set veth-fw-office netns fw
ip link set veth-office-fw netns office
ip netns exec fw ip addr add 10.20.0.1/24 dev veth-fw-office
ip netns exec fw ip link set veth-fw-office up
ip netns exec office ip addr add 10.20.0.2/24 dev veth-office-fw
ip netns exec office ip link set veth-office-fw up
ip netns exec office ip route add default via 10.20.0.1

# guest <--> fw
ip link add veth-fw-guest type veth peer name veth-guest-fw
ip link set veth-fw-guest netns fw
ip link set veth-guest-fw netns guest
ip netns exec fw ip addr add 10.30.0.1/24 dev veth-fw-guest
ip netns exec fw ip link set veth-fw-guest up
ip netns exec guest ip addr add 10.30.0.2/24 dev veth-guest-fw
ip netns exec guest ip link set veth-guest-fw up
ip netns exec guest ip route add default via 10.30.0.1

# dmz <--> fw
ip link add veth-fw-dmz type veth peer name veth-dmz-fw
ip link set veth-fw-dmz netns fw
ip link set veth-dmz-fw netns dmz
ip netns exec fw ip addr add 10.40.0.1/24 dev veth-fw-dmz
ip netns exec fw ip link set veth-fw-dmz up
ip netns exec dmz ip addr add 10.40.0.2/24 dev veth-dmz-fw
ip netns exec dmz ip link set veth-dmz-fw up
ip netns exec dmz ip route add default via 10.40.0.1

# internet <--> fw
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

# ==================== Step 4: 启用 IP 转发 ====================
echo "=== Step 4: enable IP forwarding on fw ==="
ip netns exec fw sysctl -w net.ipv4.ip_forward=1

# ==================== Step 5: 基础连通性测试 ====================
echo "=== Step 5: basic connectivity test ==="
ip netns exec office ping -c 1 10.20.0.1
ip netns exec guest ping -c 1 10.30.0.1
ip netns exec dmz ping -c 1 10.40.0.1
ip netns exec internet ping -c 1 203.0.113.1

# ==================== Step 6: 启动 HTTP 服务 ====================
echo "=== Step 6: start HTTP services ==="
ip netns exec dmz bash -c 'python3 -m http.server 8080 >/dev/null 2>&1 &'
echo "dmz:8080 started"

ip netns exec office bash -c 'python3 -m http.server 8000 >/dev/null 2>&1 &'
echo "office:8000 started"

ip netns exec internet bash -c 'python3 -m http.server 80 >/dev/null 2>&1 &'
echo "internet:80 started"

sleep 1

# ==================== Step 7: 配置 WireGuard VPN ====================
echo "=== Step 7: setup WireGuard VPN ==="

mkdir -p /etc/wireguard
mkdir -p /tmp/wgkeys

# 生成密钥对
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

# 生成配置文件
cat > /etc/wireguard/fw.conf <<EOF
[Interface]
PrivateKey = ${FW_PRIV}
ListenPort = 51820

[Peer]
PublicKey = ${REMOTE_PUB}
AllowedIPs = 10.10.10.2/32
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

# 创建 fw 端 wg0 接口
ip netns exec fw ip link add dev wg0 type wireguard
ip netns exec fw wg setconf wg0 /etc/wireguard/fw.conf
ip netns exec fw ip address add 10.10.10.1/24 dev wg0
ip netns exec fw ip link set up dev wg0

# 创建 remote 端 wg0 接口
ip netns exec remote ip link add dev wg0 type wireguard
ip netns exec remote wg setconf wg0 /etc/wireguard/remote.conf
ip netns exec remote ip address add 10.10.10.2/24 dev wg0
ip netns exec remote ip link set up dev wg0

# 添加 remote 端路由
ip netns exec remote ip route add 10.20.0.0/24 dev wg0
ip netns exec remote ip route add 10.40.0.0/24 dev wg0

echo "=== VPN setup complete ==="
ip netns exec fw wg show

echo ""
echo "============================================"
echo "=== Setup complete! ==="
echo "=== Next: run 'sudo bash firewall.sh'  ==="
echo "============================================"
