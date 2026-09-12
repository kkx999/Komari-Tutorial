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

先把自己的 Komari 域名解析到当前 VPS 公网 IP。

然后执行：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/kkx999/Komari-Tutorial/main/setup-https.sh)
```

脚本首先需要输入：

```text
Komari 域名
用于申请 SSL 证书的邮箱
```

然后可以选择两种证书验证方式：

```text
1. HTTP 验证
2. Cloudflare DNS 验证
```

### 方式一：HTTP 验证

适合 VPS 的公网 80 端口可以正常访问的情况。

选择：

```text
1. HTTP 验证（需要公网 80 端口可访问）
```

脚本会使用 acme.sh 的 Nginx HTTP 验证方式自动申请 Let's Encrypt 证书。

要求：

```text
域名已经解析到当前 VPS
TCP 80 可以从公网访问
TCP 443 用于最终 HTTPS 访问
```

### 方式二：Cloudflare DNS 验证

如果域名 DNS 托管在 Cloudflare，可以选择：

```text
2. Cloudflare DNS 验证（不需要开放 80 端口）
```

这种方式通过 Cloudflare DNS API 自动创建 `_acme-challenge` TXT 记录完成验证，申请证书时不需要公网开放 80 端口。

Cloudflare 凭据支持两种方式：

```text
1. API Token（推荐）
2. Global API Key
```

#### Cloudflare API Token（推荐）

需要准备：

```text
Cloudflare Account ID
Cloudflare API Token
```

建议创建只用于 DNS 验证的受限 API Token，不要直接使用权限过大的 Token。

脚本输入 API Token 时不会在终端显示 Token 内容。

#### Cloudflare Global API Key

也兼容传统 Global API Key，需要准备：

```text
Cloudflare 登录邮箱
Cloudflare Global API Key
```

Global API Key 权限较大，优先推荐使用 API Token。

Cloudflare 凭据会由 acme.sh 保存，用于后续自动续期证书，请注意保护 `/root/.acme.sh/` 目录。

### 脚本会自动完成

1. 创建 Komari 的 Nginx 反向代理配置
2. 安装或检查 acme.sh
3. 根据选择使用 HTTP 或 Cloudflare DNS 验证
4. 使用 Let's Encrypt 申请 SSL 证书
5. 安装 SSL 证书
6. 自动开启 HTTPS
7. 配置 HTTP 自动跳转 HTTPS
8. 配置 WebSocket 反向代理
9. 重载 Nginx

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
