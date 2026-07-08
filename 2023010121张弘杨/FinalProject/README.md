# 企业级网络安全架构搭建与攻防演练

## 一、实验环境

- 操作系统：Ubuntu 24.04 LTS（WSL2 on Windows 11）
- 内核版本：Linux 5.15.x（WSL2 默认内核）
- WireGuard 版本：wireguard-tools 1.0.20210914
- iptables 版本：iptables v1.8.10（nf_tables 后端）
- Python 版本：Python 3.12（用于 HTTP 测试服务）
- 实验工具：iproute2、iptables、wireguard-tools、curl、nmap、tcpdump

## 二、拓扑图和地址规划

### 拓扑图

```
                    +------------------+
                    |    internet      |  203.0.113.10/24
                    |  (模拟外网客户端)|
                    +--------+---------+
                             |
                       veth-inet
                             |
+-----------+    veth-fw-inet     +-------+    veth-fw-dmz      +-----------+
|   guest   |<------------------->|  fw   |<------------------->|    dmz    |
| 访客区    |   10.30.0.0/24       |防火墙 |    10.40.0.0/24      | DMZ服务器 |
|10.30.0.0/24                     +---+---+                      |10.40.0.0/24|
+-----------+                         |   |                      +-----------+
                                      |   |
                                      |   |   veth-fw-office    +-----------+
                                      |   +<------------------>|  office   |
                                      |       10.20.0.0/24     | 办公区    |
                                      |                         |10.20.0.0/24|
                                      |                         +-----------+
                                      |
                                      |   wg0 (WireGuard VPN)
                                      |   10.10.10.0/24
                                      |
                                      |   veth-fw-remote (192.0.2.0/24)
                                      |
                                +-----v----+
                                |  remote  |
                                | VPN 客户端|
                                +----------+
                                10.10.10.2
```

### 地址规划表

| 区域 | 命名空间 | 网段 | 接口 | IP 地址 |
|------|---------|------|------|---------|
| 互联网 | internet | 203.0.113.0/24 | veth-inet | 203.0.113.10 |
| 防火墙-互联网口 | fw | 203.0.113.0/24 | veth-fw-inet | 203.0.113.1 |
| 防火墙-办公口 | fw | 10.20.0.0/24 | veth-fw-office | 10.20.0.1 |
| 防火墙-DMZ口 | fw | 10.40.0.0/24 | veth-fw-dmz | 10.40.0.1 |
| 防火墙-访客口 | fw | 10.30.0.0/24 | veth-fw-guest | 10.30.0.1 |
| 防火墙-VPN物理口 | fw | 192.0.2.0/24 | veth-fw-remote | 192.0.2.1 |
| 防火墙-VPN隧道 | fw | 10.10.10.0/24 | wg0 | 10.10.10.1 |
| 办公区 | office | 10.20.0.0/24 | veth-office | 10.20.0.2 |
| DMZ 区 | dmz | 10.40.0.0/24 | veth-dmz | 10.40.0.2 |
| 访客区 | guest | 10.30.0.0/24 | veth-guest | 10.30.0.2 |
| VPN 物理层 | remote | 192.0.2.0/24 | veth-remote | 192.0.2.2 |
| VPN 隧道 | remote | 10.10.10.0/24 | wg0 | 10.10.10.2 |

## 三、第一部分：网络规划与基础搭建

### 3.1 setup.sh 说明

`setup.sh` 完成以下工作：

1. 创建 6 个网络命名空间：fw、office、dmz、guest、internet、remote
2. 创建 5 对 veth 虚拟网卡，分别分配到对应命名空间
3. 为每个命名空间内的接口配置 IP 地址
4. 在 fw 命名空间启用 IP 转发（`net.ipv4.ip_forward=1`）
5. 为每个非 fw 命名空间配置默认路由，指向 fw 侧的网关地址
6. 关闭各命名空间的 rp_filter，避免隧道流量被反向路径过滤丢弃

### 3.2 连通性测试结果

搭建完成后，基础连通性如下（未加防火墙规则前）：

- office -> fw：通
- office -> dmz：通
- office -> internet：通（需配合 SNAT）
- guest -> internet：通
- guest -> office：通（防火墙策略生效后将被拒绝）
- internet -> dmz：通（需配合 DNAT）
- remote -> fw（VPN 隧道）：通

### 3.3 脚本清单

| 脚本 | 功能 |
|------|------|
| setup.sh | 创建网络拓扑（6 个命名空间 + 5 对 veth） |
| firewall.sh | 配置 iptables 防火墙规则 |
| vpn_setup.sh | 配置 WireGuard VPN 隧道 |
| start_services.sh | 启动 HTTP 测试服务 |
| test_firewall.sh | 防火墙连通性测试（8 项） |
| test_vpn.sh | VPN 连通性测试（4 项） |
| log_audit.sh | 安全审计与日志统计 |
| attack_test.sh | 攻击模拟（3 个场景） |
| defense_analysis.sh | 防御分析（规则命中统计） |
| improvement.sh | 改进方案（connlimit DDoS 防御） |
| cleanup.sh | 清理环境（删除命名空间和 wg0） |

### 3.4 运行步骤

```bash
sudo bash cleanup.sh        # 先清理旧环境
sudo bash setup.sh           # 创建网络拓扑
sudo bash firewall.sh        # 配置防火墙规则
sudo bash vpn_setup.sh       # 配置 WireGuard VPN
sudo bash start_services.sh  # 启动测试服务
sudo bash test_firewall.sh   # 防火墙测试
sudo bash test_vpn.sh        # VPN 测试
sudo bash log_audit.sh       # 安全审计
sudo bash attack_test.sh     # 攻击模拟
sudo bash defense_analysis.sh # 防御分析
sudo bash improvement.sh     # DDoS 防御改进
```

## 四、第二部分：防火墙策略实现

### 4.1 firewall.sh 说明

`firewall.sh` 在 fw 命名空间内配置 iptables 规则，采用"默认拒绝"（Default Deny）原则：

**默认策略：**
- INPUT 链：DROP
- FORWARD 链：DROP

**INPUT 链规则：**
- 允许 lo 回环接口
- 允许 `RELATED,ESTABLISHED` 状态包（状态检测）
- 允许 ICMP echo-request（ping）
- 允许 UDP 51820 端口（WireGuard 监听端口）

**FORWARD 链规则：**
- 允许 `RELATED,ESTABLISHED` 状态包
- 允许 office -> dmz:8080（业务访问）
- 拒绝 office -> dmz:22（SSH），先 LOG 再 REJECT
- 允许 internet -> dmz:8080（通过 DNAT 后访问）
- 拒绝 internet -> dmz:22，先 LOG 再 REJECT
- 拒绝 guest -> office，先 LOG 再 REJECT
- 拒绝 guest -> dmz，先 LOG 再 REJECT
- 允许 VPN(wg0) -> office
- 允许 VPN(wg0) -> dmz:8080
- 拒绝 VPN -> dmz:22，先 LOG 再 REJECT
- 拒绝 VPN -> guest，先 LOG 再 REJECT

**NAT 规则：**
- DNAT：将 `203.0.113.1:80` 映射到 `10.40.0.2:8080`（公网访问 DMZ 服务）
- SNAT/MASQUERADE：office、guest、VPN 访问 internet 时做源地址转换

### 4.2 访问控制矩阵

| 源 \ 目标 | office | dmz:8080 | dmz:22 | internet |
|---------|--------|----------|--------|----------|
| office  | -      | 允许     | 拒绝   | 允许(SNAT) |
| guest   | 拒绝   | 拒绝     | 拒绝   | 允许(SNAT) |
| internet| 拒绝   | 允许(DNAT)| 拒绝  | -        |
| VPN(remote) | 允许 | 允许   | 拒绝   | 允许(SNAT) |

### 4.3 防火墙测试结果（test_firewall.sh）

8 项测试全部 PASS：

| 测试项 | 源 -> 目标 | 预期 | 结果 |
|--------|-----------|------|------|
| Test 1 | office -> dmz:8080 | 成功 | PASS |
| Test 2 | office -> dmz:22 | 拒绝 | PASS |
| Test 3 | guest -> office | 拒绝 | PASS |
| Test 4 | guest -> dmz | 拒绝 | PASS |
| Test 5 | guest -> internet | 成功 | PASS |
| Test 6 | internet -> dmz(DNAT) | 成功 | PASS |
| Test 7 | internet -> dmz:22 | 拒绝 | PASS |
| Test 8 | office -> internet(SNAT) | 成功 | PASS |

## 五、第三部分：VPN远程接入

### 5.1 WireGuard 配置说明

**密钥生成：**
- 使用 `wg genkey` 生成 fw 端和 remote 端各自的私钥
- 使用 `wg pubkey` 从私钥导出对应公钥

**接口配置：**
- fw 端 wg0：地址 `10.10.10.1/24`，监听 UDP 51820
- remote 端 wg0：地址 `10.10.10.2/24`，监听 UDP 51821

**AllowedIPs 设计：**
- fw 端 AllowedIPs = `10.10.10.2/32`（仅接受 remote 隧道地址，避免路由劫持）
- remote 端 AllowedIPs = `10.20.0.0/24, 10.40.0.0/24, 10.10.10.0/24`（能访问办公区、DMZ、隧道网段）

**Table=off 策略：**
- 手动创建 wg0 接口并设置 `Table=off`，避免 wg-quick 自动添加路由与现有物理路由冲突

**配置文件：**
- `vpn-fw.conf`：fw 端（服务端）WireGuard 配置
- `vpn-remote.conf`：remote 端（客户端）WireGuard 配置

### 5.2 测试结果（test_vpn.sh）

VPN 4 项测试全部 PASS：

| 测试项 | 源 -> 目标 | 预期 | 结果 |
|--------|-----------|------|------|
| Test 1 | remote -> office:8000 | 成功 | PASS |
| Test 2 | remote -> dmz:8080 | 成功 | PASS |
| Test 3 | remote -> dmz:22 | 拒绝 | PASS |
| Test 4 | remote -> guest | 拒绝 | PASS |

## 六、第四部分：安全审计与日志分析

### 6.1 LOG 规则说明

在每条 REJECT 规则前添加对应的 LOG 规则，使用不同的 `log-prefix` 标识违规类型：

| LOG 前缀 | 含义 |
|----------|------|
| FW-DENY-GUEST-OFFICE | 访客访问办公区 |
| FW-DENY-GUEST-DMZ | 访客访问 DMZ |
| FW-DENY-INET-SSH | 外部访问 SSH |
| FW-DENY-OFFICE-SSH | 办公区访问 DMZ SSH |
| FW-DENY-VPN-SSH | VPN 访问 DMZ SSH |
| FW-DENY-VPN-GUEST | VPN 访问访客区 |

**WSL2 限制说明：** WSL2 内核不会将 iptables LOG 消息写入 dmesg/journalctl，因此通过 `iptables -L -v -n` 的包计数器来观察规则命中情况。

### 6.2 日志分析报告（log_audit.sh）

模拟 5 种违规访问，观察 LOG/REJECT 计数器变化：

| 违规类型 | 触发方式 | LOG 计数 | REJECT 计数 |
|---------|---------|---------|------------|
| guest -> office | TCP 连接 | +1 | +1 |
| guest -> dmz:22 | TCP 连接 | +1 | +1 |
| internet -> dmz:22 | TCP 连接 | +1 | +1 |
| office -> dmz:22 | TCP 连接 | +1 | +1 |
| VPN -> dmz:22 | TCP 连接 | +1 | +1 |

每条违规访问都准确触发了对应的 LOG 和 REJECT 规则，计数器递增，证明审计策略生效。

## 七、第五部分：攻防演练

### 7.1 攻击演练（attack_test.sh）

**攻击 1：nmap 端口扫描**

- 攻击方：guest 命名空间
- 目标：office (10.20.0.2)
- 命令：`nmap -p 8000 10.20.0.2`
- 结果：`Host seems down`，扫描被防火墙拦截
- 分析：FORWARD 链默认 DROP，guest -> office 的流量被直接丢弃，nmap 收不到任何响应

**攻击 2：源端口 53 绕过**

- 攻击方：guest 命名空间
- 目标：office (10.20.0.2:8000)
- 方法：尝试使用源端口 53（DNS）绕过防火墙
- 结果：绕过失败，连接被拒绝
- 分析：iptables 规则按源/目的 IP 匹配，不依赖源端口，因此源端口伪造无效

**攻击 3：VPN 伪造攻击**

- 攻击方：internet 命名空间
- 目标：fw 的 WireGuard 端口 (192.0.2.1:51820)
- 方法：发送伪造的 WireGuard UDP 包
- 结果：伪造包被丢弃，无合法握手
- 分析：WireGuard 使用加密握手认证，无合法私钥的伪造包无法建立隧道

### 7.2 防御分析（defense_analysis.sh）

通过 `iptables -L -v -n` 统计各规则的包命中数：

- **拒绝源统计**：guest 被拒次数最多（访问 office 和 dmz 均被拒）
- **SSH 入侵尝试汇总**：office -> dmz:22、internet -> dmz:22、VPN -> dmz:22 的 REJECT 计数
- **允许流量统计**：office -> dmz:8080、internet -> dmz(DNAT) 的 ACCEPT 计数

### 7.3 边界测试（improvement.sh）

**connlimit DDoS 防御：**

- 规则：`-m connlimit --connlimit-above 10 -j REJECT`
- 限制单个 IP 到 dmz:8080 的并发连接数不超过 10
- 测试：发起 15 个并发连接
- 结果：前 10 个 ACCEPT，后 5 个 REJECT

## 八、故障排查

详见 `troubleshooting.md`，主要故障场景：

### 8.1 DNAT 后 FORWARD 规则不匹配

- **现象**：internet 访问 203.0.113.1:80 时连接超时
- **原因**：FORWARD 规则匹配的是 DNAT 前的目的地址（203.0.113.1:80），但 DNAT 后目的地址已变为 10.40.0.2:8080，规则无法匹配
- **解决**：将 FORWARD 规则改为匹配 DNAT 后的目的地址 `10.40.0.2:8080`

### 8.2 WireGuard 隧道握手成功但 ping 100% 丢包

- **现象**：`wg show` 显示握手成功，但 remote ping office 100% 丢包
- **原因**：`vpn_setup.sh` 检测到 wg0 接口已存在时跳过了 iptables 规则的添加，导致 FORWARD 链中没有 VPN 相关的允许规则
- **解决**：手动添加 VPN 的 FORWARD 规则（wg0 -> office/dmz/guest）

### 8.3 rp_filter 干扰隧道流量

- **现象**：即使 FORWARD 规则正确，VPN 流量仍被丢弃
- **原因**：内核的反向路径过滤（rp_filter）将隧道流量判定为可疑包并丢弃
- **解决**：关闭所有命名空间的 rp_filter：`echo 0 > /proc/sys/net/ipv4/conf/*/rp_filter`

## 九、遇到的问题和解决方法

### 9.1 WSL2 下 iptables LOG 不写 dmesg

- **问题**：iptables LOG 规则触发后，dmesg 和 journalctl 中没有日志
- **原因**：WSL2 内核的日志子系统与标准 Linux 不同，iptables LOG 消息不会写入内核日志
- **解决**：使用 `iptables -L -v -n` 的包计数器替代日志，通过计数器变化判断规则是否命中

### 9.2 wg-quick 路由冲突

- **问题**：使用 wg-quick 启动 WireGuard 时报路由冲突错误
- **原因**：wg-quick 会自动添加 AllowedIPs 对应的路由，但这些路由与现有的物理接口路由冲突
- **解决**：放弃 wg-quick，手动使用 `ip link add wg0 type wireguard` 创建接口，设置 `Table=off` 禁止自动路由

### 9.3 vpn_setup.sh 幂等性问题

- **问题**：重复运行 vpn_setup.sh 时，wg0 接口已存在导致脚本提前退出，iptables 规则未添加
- **原因**：脚本在检测到 wg0 存在后直接 return，跳过了后续的 iptables 规则配置
- **解决**：手动补充 VPN FORWARD 规则；建议后续改进脚本逻辑，在 wg0 已存在时只补充规则

### 9.4 HTTP 服务未启动导致测试失败

- **问题**：运行 test_firewall.sh 时，部分测试显示 Connection refused
- **原因**：忘记运行 start_services.sh，dmz/office/internet 的 HTTP 服务未启动
- **解决**：在测试前先运行 `sudo bash start_services.sh`

## 十、总结与思考

通过本次期末大作业，我对 Linux 网络安全架构有了全面而深入的理解。企业级网络安全不是单点防御，而是多层纵深防御体系。

**网络隔离是安全的基础。** 通过 Linux 网络命名空间（network namespace）和 veth 虚拟网卡，我们在单机上模拟了企业网络的典型分区：办公区（office）、DMZ 服务器区、访客区（guest）、互联网（internet）和远程 VPN 接入区。这种隔离方式让不同安全等级的网络在逻辑上完全独立，即使某个区域被攻破，攻击者也无法直接访问其他区域。

**默认拒绝是防火墙的核心原则。** 本次实验中 INPUT 和 FORWARD 链均设为 DROP 默认策略，再按最小权限原则逐条添加 ALLOW 规则。这种方式确保了只有明确允许的流量才能通过，任何未预期的访问都会被丢弃。状态检测（`-m state --state RELATED,ESTABLISHED`）的加入，使得防火墙能区分新建连接和已建立连接的回包，既安全又不影响正常通信。

**VPN 是远程接入的安全通道。** WireGuard 相比传统 OpenVPN 更轻量、配置更简洁、加密更强。本次实验中 AllowedIPs 的设计体现了最小权限原则：fw 端只接受 remote 的隧道地址，remote 端只允许访问必要的内网网段。Table=off 策略解决了 wg-quick 与现有路由冲突的问题，体现了实际部署中需要灵活变通的能力。

**安全审计让防御可观测。** LOG 规则配合不同的 log-prefix，能精确定位每种违规访问的类型和来源。虽然 WSL2 的限制导致日志无法写入 dmesg，但通过 iptables 包计数器同样实现了审计目标。这启示我们：工具的选择要因地制宜，核心目标是可观测性，而非特定工具。

**攻防演练验证了防御有效性。** nmap 扫描被默认 DROP 策略拦截；源端口 53 绕过因 iptables 按 IP 匹配而失败；VPN 伪造因缺少合法密钥而被丢弃。connlimit 模块补充了应用层的并发连接限制，有效缓解 DDoS 攻击。这些测试证明：合理的防火墙策略能抵御大多数常见攻击。

最后，本次实验让我深刻理解了"纵深防御"的理念：边界防护（FORWARD DROP）、内部隔离（命名空间）、接入安全（WireGuard VPN）、审计监控（LOG+计数器）、应用防护（connlimit）多层协同，单点失守不会导致整体崩溃。这正是企业级网络安全架构的核心思想。
