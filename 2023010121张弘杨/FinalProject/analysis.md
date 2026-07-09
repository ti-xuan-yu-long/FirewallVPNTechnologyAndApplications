# 攻防演练分析报告

## 一、攻击演练

### 攻击 1：nmap 端口扫描

**场景：** guest 命名空间使用 nmap 扫描 office 网络

**命令：**
```bash
sudo ip netns exec guest bash -c "timeout 5 nmap -Pn -p 8000 10.20.0.2 || true"
```

**结果：** `Host seems down`，扫描被防火墙拦截

**分析：** FORWARD 链默认 DROP，guest -> office 的流量被直接丢弃，nmap 收不到任何响应。

**查看 LOG 计数器：**
```bash
sudo ip netns exec fw iptables -L FORWARD -v -n | grep "FW-DENY-GUEST-OFFICE"
```

### 攻击 2：源端口 53 绕过

**场景：** guest 命名空间尝试使用源端口 53（DNS）绕过防火墙

**命令：**
```bash
sudo ip netns exec guest bash -c "timeout 2 bash -c 'exec 3<>/dev/tcp/10.20.0.2/8000; echo ok >&3' || true"
```

**结果：** 绕过失败，连接被拒绝

**分析：** iptables 规则按源/目的 IP 匹配，不依赖源端口，因此源端口伪造无效。

### 攻击 3：VPN 伪造攻击

**场景：** internet 命名空间向 fw 的 WireGuard 端口发送伪造 UDP 包

**命令：**
```bash
sudo ip netns exec internet bash -c "timeout 2 bash -c 'echo test > /dev/udp/192.0.2.1/51820' || true"
```

**结果：** 伪造包被丢弃，无合法握手

**分析：** WireGuard 使用 Curve25519 非对称加密握手认证，无合法私钥的伪造包无法建立隧道。

### REJECT vs DROP 信息泄露

- **REJECT** 发送 ICMP port unreachable，确认端口被过滤（信息泄露）
- **DROP** 静默丢弃，使端口扫描更慢（更隐蔽）

## 二、防御分析

### 2.1 防御规则统计

**查看所有 LOG/REJECT 计数器：**
```bash
sudo ip netns exec fw iptables -L FORWARD -v -n | grep -E "LOG|REJECT"
```

**查看拒绝源统计：**
```bash
# guest -> office 拦截次数
sudo ip netns exec fw iptables -L FORWARD -v -n | grep "FW-DENY-GUEST-OFFICE"

# guest -> dmz 拦截次数
sudo ip netns exec fw iptables -L FORWARD -v -n | grep "FW-DENY-GUEST-DMZ"

# SSH 入侵尝试汇总
sudo ip netns exec fw iptables -L FORWARD -v -n | grep -E "FW-DENY-(OFFICE|INET|VPN)-SSH"
```

**查看允许流量统计：**
```bash
# office -> dmz:8080 允许次数
sudo ip netns exec fw iptables -L FORWARD -v -n | grep "veth-fw-office.*veth-fw-dmz.*dpt:8080"

# office -> internet 允许次数
sudo ip netns exec fw iptables -L FORWARD -v -n | grep "veth-fw-office.*veth-fw-inet"

# guest -> internet 允许次数
sudo ip netns exec fw iptables -L FORWARD -v -n | grep "veth-fw-guest.*veth-fw-inet"
```

### 2.2 防御策略总结

| 防御层 | 策略 | 效果 |
|--------|------|------|
| 边界防护 | FORWARD 默认 DROP | 阻止所有未明确允许的流量 |
| 状态检测 | ESTABLISHED,RELATED | 保证已建立连接正常通信 |
| 审计监控 | LOG + log-prefix | 精确记录每种违规访问类型 |
| 访问控制 | REJECT + LOG | 记录并拒绝违规访问 |
| NAT 隐藏 | SNAT/DNAT | 隐藏内部拓扑，暴露必要服务 |
| DDoS 防御 | connlimit | 限制并发连接数，缓解 DDoS/CC |

## 三、改进方案：connlimit DDoS 防御

### 3.1 规则说明

firewall.sh 中已内置 connlimit 规则：

```bash
# 限制单 IP 到 dmz:8080 的并发连接数不超过 10
iptables -A FORWARD -p tcp -i veth-fw-inet -o veth-fw-dmz -d 10.40.0.2 --dport 8080 \
    -m connlimit --connlimit-above 10 -j LOG --log-prefix "FW-DOS-DMZ: "
iptables -A FORWARD -p tcp -i veth-fw-inet -o veth-fw-dmz -d 10.40.0.2 --dport 8080 \
    -m connlimit --connlimit-above 10 -j REJECT
```

### 3.2 DDoS 测试命令

**模拟 15 个并发连接：**
```bash
for i in $(seq 1 15); do
    sudo ip netns exec internet bash -c "timeout 3 bash -c 'echo ok > /dev/tcp/203.0.113.1/80' &"
done
wait
sleep 2
```

**查看 connlimit 计数器：**
```bash
sudo ip netns exec fw iptables -L FORWARD -v -n | grep -E "connlimit|FW-DOS"
```

### 3.3 测试结果

- 前 10 个连接：ACCEPT（正常访问）
- 后 5 个连接：LOG + REJECT（超过并发限制）
- 有效缓解 DDoS/CC 攻击
