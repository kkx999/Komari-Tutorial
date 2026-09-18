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

只需要准备：

```text
Cloudflare API Token
```

不需要手动填写 Account ID。acme.sh 会通过 API Token 自动查找域名对应的 Cloudflare Zone。

建议给 Token 只开放以下权限：

```text
Zone → DNS → Edit
Zone → Zone → Read
```

Zone Resources 建议限制为：

```text
Include → Specific zone → 你的域名
```

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

---

# 从 Komari 迁移到 KomariX

如果已经在使用 Komari，可以直接把现有数据迁移到 KomariX。原来的机器、UUID、Token、面板配置以及历史监控数据都可以一起保留。

> 迁移完成并确认 KomariX 正常之前，不要删除原来的 `/opt/komari`。

## 第一步：备份并停止 Komari

执行：

```bash
systemctl stop komari
systemctl disable komari
tar -C /opt/komari -czf /root/komari-data-before-komarix.tar.gz data
```

备份文件：

```text
/root/komari-data-before-komarix.tar.gz
```

建议同时下载到本地保存一份。

---

## 第二步：安装 KomariX

执行：

```bash
cd /root && curl -fsSL https://raw.githubusercontent.com/kkx999/KomariX/main/install-komarix.sh -o install-komarix.sh && chmod +x install-komarix.sh && ./install-komarix.sh
```

选择：

```text
1. 安装 KomariX
```

如果原 Komari 使用默认端口，KomariX 也继续使用：

```text
25774
```

安装完成后停止 KomariX：

```bash
systemctl stop komarix
```

---

## 第三步：迁移数据

执行：

```bash
rm -rf /opt/komarix/data
cp -a /opt/komari/data /opt/komarix/
mv /opt/komarix/data/komari.db /opt/komarix/data/komarix.db
chmod 644 /opt/komarix/data/komarix.db
systemctl start komarix
```

这样会同时迁移：

```text
机器
UUID
Token
面板配置
metrics.db 历史监控数据
```

KomariX 启动后会自动处理兼容迁移。

如果浏览器出现数据库迁移页面，按照页面提示完成即可。

---

## 第四步：检查迁移结果

检查服务：

```bash
systemctl status komarix --no-pager
```

然后打开原来的监控域名。

如果域名和端口没有改变，原来的 Agent 通常不需要重新安装。

确认机器和历史监控数据正常后，迁移就完成了。

---

## 如果需要切回 Komari

执行：

```bash
systemctl stop komarix
systemctl disable komarix
systemctl enable komari
systemctl start komari
```

因为原来的 `/opt/komari` 没有删除，所以可以直接恢复使用。

---

## 第五步：确认无误后删除旧 Komari

确认 KomariX 已经正常运行、所有机器都在线、历史监控数据也正常后，就可以删除旧 Komari。

执行：

```bash
systemctl stop komari 2>/dev/null || true
systemctl disable komari 2>/dev/null || true
rm -f /etc/systemd/system/komari.service
systemctl daemon-reload
systemctl reset-failed
rm -rf /opt/komari
rm -f /root/install-komari.sh
```

如果迁移前的备份已经下载到本地并确认不再需要服务器上的副本，也可以删除：

```bash
rm -f /root/komari-data-before-komarix.tar.gz
```

> 不要删除原来的 Nginx 配置和 SSL 证书。只要迁移后仍然使用相同域名和 `25774` 端口，它们仍然负责把域名转发到 KomariX。

执行完成后，服务器上就只保留 KomariX。

---

# KomariX 全新安装流程

如果是全新的 VPS，直接按照下面 4 步安装即可。

## 第一步：一键安装 KomariX

执行：

```bash
cd /root && curl -fsSL https://raw.githubusercontent.com/kkx999/KomariX/main/install-komarix.sh -o install-komarix.sh && chmod +x install-komarix.sh && ./install-komarix.sh
```

菜单选择：

```text
1. 安装 KomariX
```

发布通道推荐：

```text
stable
```

端口没有特殊需求就使用默认：

```text
25774
```

---

## 第二步：安装 Nginx

执行：

```bash
apt update && apt install -y nginx curl cron && systemctl enable --now nginx cron
```

---

## 第三步：一键配置域名 + HTTPS

先把自己的域名解析到当前 VPS 公网 IP。

然后执行：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/kkx999/Komari-Tutorial/main/setup-komarix-https.sh)
```

按照脚本提示输入：

```text
KomariX 域名
申请 SSL 证书的邮箱
```

证书验证方式可以选择：

```text
1. HTTP 验证
2. Cloudflare DNS 验证
```

如果选择 Cloudflare DNS 验证，还可以继续选择：

```text
1. API Token（推荐）
2. Global API Key
```

脚本会自动完成：

```text
Nginx 反向代理
SSL 证书申请
HTTPS 配置
HTTP 自动跳转 HTTPS
WebSocket 配置
证书自动续期
```

---

## 第四步：访问 KomariX

打开：

```text
https://你的KomariX域名
```

首次访问按照页面提示创建管理员账号即可。

KomariX 常用命令：

```bash
systemctl status komarix
systemctl restart komarix
journalctl -u komarix -f
```

默认目录：

```text
程序目录：/opt/komarix
主数据库：/opt/komarix/data/komarix.db
历史监控数据库：/opt/komarix/data/metrics.db
```

至此，KomariX 全新安装完成。

---

# KomariX 数据备份与恢复

KomariX 建议直接备份整个数据目录：

```text
/opt/komarix/data
```

这样可以同时保留机器、UUID、Token、面板配置以及历史监控数据。

## 备份 KomariX

执行：

```bash
systemctl stop komarix && tar -C /opt/komarix -czf /root/komarix-data-backup.tar.gz data && systemctl start komarix
```

备份文件：

```text
/root/komarix-data-backup.tar.gz
```

把这个文件下载到自己的电脑保存即可。

> 如果准备 DD 重装 VPS，一定要先把备份文件下载到服务器之外。

---

## 恢复 KomariX

先按照上面的 **KomariX 全新安装流程** 安装好 KomariX。

然后把备份文件上传到：

```text
/root/komarix-data-backup.tar.gz
```

执行：

```bash
systemctl stop komarix
rm -rf /opt/komarix/data
tar -C /opt/komarix -xzf /root/komarix-data-backup.tar.gz
chmod 644 /opt/komarix/data/komarix.db
systemctl start komarix
```

检查：

```bash
systemctl status komarix --no-pager
```

恢复完成后，原来的机器、UUID、Token、面板配置以及历史监控数据都会一起恢复。

如果域名和端口没有改变，原来的 Agent 通常不需要重新安装。

