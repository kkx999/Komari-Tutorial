# Komari 监控面板搭建教程

> 本仓库用于快速部署 Komari、Nginx 反向代理、HTTPS，以及安装指定的 Komari Release 版本。

[Komari GitHub](https://github.com/komari-monitor/komari)

[Komari Releases](https://github.com/komari-monitor/komari/releases)

[全国 ICMP Ping 监控节点地址分享](https://www.nodeseek.com/post-82748-1)

---

# Komari 部署教程

## 第一步：安装 Komari

### 方式一：安装官方当前版本

执行官方安装脚本：

```bash
cd /root && curl -fsSL https://raw.githubusercontent.com/komari-monitor/komari/main/install-komari.sh -o install-komari.sh && chmod +x install-komari.sh && ./install-komari.sh
```

在全新机器上运行时，当前官方脚本会直接进入安装流程。

推荐选择：

```text
语言：简体中文
版本：标准版
通道：正式版
监听端口：25774（默认）
```

Komari 官方安装器现在支持自定义监听端口，因此不一定必须使用 `25774`。

本教程后面的 HTTPS 脚本会自动读取 Komari systemd 服务中的实际监听端口；如果读取不到，才会回退到默认端口 `25774`。

---

### 方式二：安装指定 Komari 版本

如果需要安装旧版本、固定版本，或者在不同 Release 之间切换，可以使用本仓库的指定版本安装脚本：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/kkx999/Komari-Tutorial/main/install-version.sh)
```

脚本会提示输入：

```text
Komari Release Tag
监听端口
```

例如安装：

```text
1.4.3
```

或者：

```text
1.5.0-fix1
```

也可以直接把版本和端口写在命令后面。

例如安装 Komari 1.4.3，并监听 25774：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/kkx999/Komari-Tutorial/main/install-version.sh) 1.4.3 25774
```

指定版本脚本会自动：

1. 检测 CPU 架构
2. 检查 Release Tag 是否存在
3. 下载对应 Linux 程序
4. 创建或更新 `komari.service`
5. 保留现有 `/opt/komari` 数据目录
6. 已存在旧程序时自动备份程序、systemd 配置和主数据库 `komari.db`
7. 启动失败时自动恢复旧程序、旧服务配置和主数据库
8. 保留现有 `/opt/komari/data` 数据目录

支持的架构：

```text
amd64
arm64
386
riscv64
loong64
```

> 输入的版本必须是 Komari GitHub Releases 中真实存在的 Tag。\n>\n> 如果从较新版本降级到较旧版本，建议在执行前另外完整备份 `/opt/komari/data`，因为不同版本之间的数据库结构不保证向下兼容。

---

## 第二步：安装 Nginx

Debian / Ubuntu：

```bash
apt update && apt install -y nginx curl cron && systemctl enable --now nginx cron
```

确认 Komari 正常运行：

```bash
systemctl status komari
```

---

## 第三步：一键配置域名 + SSL + HTTPS

先把自己的 Komari 域名解析到当前 VPS 公网 IP。

然后执行：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/kkx999/Komari-Tutorial/main/setup-https.sh)
```

脚本会自动检测 Komari 当前监听端口。

例如：

```text
25774
3000
8080
```

只要该端口写在当前 `komari.service` 的启动参数中，就不需要手动修改 Nginx 配置。

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

### HTTPS 脚本会自动完成

1. 自动读取 Komari 当前监听端口
2. 创建 Komari 的 Nginx 反向代理配置
3. 安装或检查 acme.sh
4. 根据选择使用 HTTP 或 Cloudflare DNS 验证
5. 使用 Let's Encrypt 申请 SSL 证书
6. 安装 SSL 证书
7. 自动开启 HTTPS
8. 配置 HTTP 自动跳转 HTTPS
9. 配置 WebSocket 反向代理
10. 检查并重载 Nginx

Komari 的独立 Nginx 配置：

```text
/etc/nginx/conf.d/komari.conf
```

SSL 证书目录：

```text
/etc/nginx/ssl/komari
```

不会直接修改：

```text
/etc/nginx/nginx.conf
```

SSL 证书会由 acme.sh 自动续期。

---

## 第四步：访问 Komari

打开：

```text
https://你的Komari域名
```

完成。

---

# 常用服务命令

查看状态：

```bash
systemctl status komari
```

重启：

```bash
systemctl restart komari
```

停止：

```bash
systemctl stop komari
```

启动：

```bash
systemctl start komari
```

查看实时日志：

```bash
journalctl -u komari -f
```

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
