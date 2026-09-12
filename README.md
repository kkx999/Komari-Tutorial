# Komari监控面板搭建教程

[Komari 文档](https://komari-document.pages.dev/)

[全国ICMP Ping监控节点地址分享](https://www.nodeseek.com/post-82748-1)

# Komari 部署教程

## 第一步：安装 Komari

```bash
cd /root && curl -fsSL https://raw.githubusercontent.com/komari-monitor/komari/main/install-komari.sh -o install-komari.sh && chmod +x install-komari.sh && ./install-komari.sh
```

选择：

```text
1. 安装 Komari
```

Komari 默认端口：

```text
25774
```

---

## 第二步：安装 Nginx

```bash
apt update && apt install -y nginx curl cron && systemctl enable --now nginx cron
```

---

## 第三步：一键配置域名 + SSL + HTTPS

先把自己的 Komari 域名解析到当前 VPS 公网 IP，并确保公网可以访问 `80` 和 `443` 端口。

然后执行：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/kkx999/Komari-Tutorial/main/setup-https.sh)
```

脚本运行后只需要输入：

```text
Komari 域名
邮箱
```

例如：

```text
请输入 Komari 域名（例如 monitor.example.com）: monitor.example.com
请输入用于申请 SSL 证书的邮箱: example@example.com
```

脚本会自动完成：

1. 创建 Komari 的 Nginx 反向代理配置
2. 安装 acme.sh
3. 使用 Let's Encrypt 申请 SSL 证书
4. 安装 SSL 证书
5. 自动开启 HTTPS
6. 配置 HTTP 自动跳转 HTTPS
7. 配置 WebSocket 反向代理
8. 重载 Nginx

SSL 证书会由 acme.sh 自动续期。

Komari 的独立 Nginx 配置：

```text
/etc/nginx/conf.d/komari.conf
```

SSL 证书目录：

```text
/etc/nginx/ssl/komari
```

不会修改：

```text
/etc/nginx/nginx.conf
```

---

## 第四步：访问 Komari

打开：

```text
https://你的Komari域名
```

完成。

---

# Komari 数据备份与恢复

如果需要重装 VPS，但希望保留 Komari 当前已经添加的监控机器、机器名称、UUID、Token 等信息，可以备份 `komari.db`。

> 此方法主要保留 Komari 主数据库中的机器和配置数据，不包含 `metrics.db` 中的历史监控曲线数据。

## 重装 VPS 前：备份数据库

执行：

```bash
systemctl stop komari

cp /opt/komari/data/komari.db /root/komari.db

systemctl start komari
```

备份完成后，数据库文件位于：

```text
/root/komari.db
```

请务必在重装 VPS 前把 `komari.db` 下载到自己的电脑保存，否则重装系统后该文件也会被删除。

---

## 重装 VPS 后：恢复数据库

先按照本教程重新部署好 Komari，然后把之前备份的 `komari.db` 上传到：

```text
/root/komari.db
```

再执行：

```bash
systemctl stop komari

cp /root/komari.db /opt/komari/data/komari.db

chmod 644 /opt/komari/data/komari.db

systemctl start komari
```

恢复完成后，可以检查 Komari 服务状态：

```bash
systemctl status komari
```

如果服务正常启动，之前已经添加的监控机器会重新出现在 Komari 中，通常无需重新安装 Agent 或重新添加机器。
