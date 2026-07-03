# Linux 网络安全期末大作业

## 实验环境

- Windows 11 + WSL2 + Ubuntu
- VS Code + WSL 扩展
- 工具：iproute2、iptables、wireguard-tools

## 网络拓扑

- fw：防火墙命名空间
- office：10.20.0.0/24
- guest：10.30.0.0/24
- dmz：10.40.0.0/24
- internet：203.0.113.0/24
- remote：通过 WireGuard VPN 接入

## 脚本说明

| 脚本 | 功能 |
|------|------|
| setup.sh | 创建网络拓扑 |
| firewall.sh | 配置 iptables 防火墙 |
| vpn_setup.sh | 配置 WireGuard VPN |
| start_services.sh | 启动测试服务 |
| test_firewall.sh | 防火墙连通性测试 |
| test_vpn.sh | VPN 连通性测试 |
| log_audit.sh | 安全审计与日志统计 |
| attack_test.sh | 攻击模拟 |
| defense_analysis.sh | 防御分析 |
| improvement.sh | 改进方案（connlimit） |
| cleanup.sh | 清理环境 |

## 运行步骤

```bash
sudo bash cleanup.sh
sudo bash setup.sh
sudo bash firewall.sh
sudo bash vpn_setup.sh
sudo bash start_services.sh
sudo bash test_firewall.sh
sudo bash test_vpn.sh
sudo bash log_audit.sh
sudo bash attack_test.sh
sudo bash defense_analysis.sh
sudo bash improvement.sh
