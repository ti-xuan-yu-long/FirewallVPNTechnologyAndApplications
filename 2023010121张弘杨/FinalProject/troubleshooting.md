# 故障排查记录

## 场景 1：DNAT 配置了，但外部无法访问内网服务

**现象**：在 `PREROUTING` 链添加了 DNAT 规则，但 internet 访问 203.0.113.1:80 失败。

**原因**：DNAT 只修改目标地址，还需要在 `FORWARD` 链允许转发后的流量。

**解决**：添加 FORWARD 规则允许 `veth-fw-inet -> veth-fw-dmz` 到 10.40.0.2:8080 的流量。

---

## 场景 2：WireGuard 隧道无法建立

**现象**：remote 无法 ping 通 10.10.10.1。

**原因 1**：`wg-quick` 自动添加路由与已有物理路由冲突。

**解决**：改用 `Table = off` 或手动创建 `wg0` 接口和路由。

**原因 2**：防火墙 `INPUT` 链默认 DROP，没有放行 UDP 51820。

**解决**：添加 `iptables -A INPUT -p udp --dport 51820 -j ACCEPT`。

---

## 场景 3：内网访问外网时断时续

**现象**：office/guest 能 ping 通 internet，但 TCP 访问失败。

**原因**：缺少 `ESTABLISHED,RELATED` 状态放行，导致回程包被 DROP。

**解决**：在 FORWARD 链最前面添加：
```bash
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
