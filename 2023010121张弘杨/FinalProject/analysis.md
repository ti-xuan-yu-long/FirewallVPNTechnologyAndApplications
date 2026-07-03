# 攻防分析

## 5.1 常见攻击路径

### 攻击 1：横向扫描
guest 区域的 nmap 扫描 office 被防火墙 `FW-DENY-GUEST-OFFICE` 规则拦截。

### 攻击 2：源端口伪造
试图用源端口 53 绕过防火墙失败，因为 iptables 策略基于源/目的网络，不依赖源端口。

### 攻击 3：VPN 伪造
WireGuard 使用 Curve25519 非对称加密，没有私钥无法完成握手，伪造 UDP 包直接被丢弃。

## 5.2 防御分析

- 默认 `FORWARD DROP` 阻止所有未明确允许的流量
- `LOG` + `REJECT` 记录并拒绝违规访问
- `ESTABLISHED,RELATED` 保证已建立连接正常通信
- SNAT/DNAT 隐藏内部拓扑并暴露必要服务

## 5.3 改进方案

使用 `connlimit` 模块限制单 IP 到 dmz:8080 的并发连接数（如 10 个），缓解 DDoS/CC 攻击。
