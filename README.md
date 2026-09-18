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

如果当前已经部署了 Komari，并且希望迁移到 KomariX，同时保留已经添加的监控机器、机器名称、UUID、Token、站点配置以及历史监控数据，可以按照下面的方法迁移。

KomariX 对 Komari 的现有数据库结构保留了兼容迁移逻辑。

默认情况下：

Komari 主数据库：

```text
/opt/komari/data/komari.db
```

KomariX 主数据库：

```text
/opt/komarix/data/komarix.db
```

历史监控指标数据库默认都是：

```text
data/metrics.db
```

因此迁移时除了需要把 Komari 的 `komari.db` 改为 KomariX 使用的 `komarix.db`，还建议把整个 Komari `data` 目录一起保留下来。

> 建议迁移完成并确认所有机器正常上线之前，不要删除原来的 `/opt/komari` 目录。这样如果迁移出现问题，可以随时切回原 Komari。

## 第一步：停止 Komari 并完整备份数据

先停止 Komari：

```bash
systemctl stop komari
systemctl disable komari
```

确认旧主数据库存在：

```bash
ls -lh /opt/komari/data/komari.db
```

然后完整备份 Komari 的数据目录：

```bash
tar -C /opt/komari -czf /root/komari-data-before-komarix.tar.gz data
```

备份文件位于：

```text
/root/komari-data-before-komarix.tar.gz
```

建议在继续操作之前，把这个压缩包另外下载到本地电脑保存一份。

---

## 第二步：安装 KomariX

执行 KomariX 官方安装脚本：

```bash
cd /root && curl -fsSL https://raw.githubusercontent.com/kkx999/KomariX/main/install-komarix.sh -o install-komarix.sh && chmod +x install-komarix.sh && ./install-komarix.sh
```

选择：

```text
1. 安装 KomariX
```

如果原来的 Komari 使用默认端口：

```text
25774
```

KomariX 也继续使用：

```text
25774
```

这样原来的 Nginx 反向代理和域名通常不需要修改。

安装完成后先停止 KomariX：

```bash
systemctl stop komarix
```

---

## 第三步：把 Komari 数据迁移到 KomariX

先确认原来的 Komari 主数据库仍然存在：

```bash
test -f /opt/komari/data/komari.db && echo "Komari 数据库存在"
```

然后执行：

```bash
systemctl stop komarix

mkdir -p /opt/komarix/data

rm -rf /opt/komarix/data/*

cp -a /opt/komari/data/. /opt/komarix/data/

mv /opt/komarix/data/komari.db /opt/komarix/data/komarix.db

chmod 644 /opt/komarix/data/komarix.db

systemctl start komarix
```

这里会把原 Komari 的整个 `data` 目录复制到 KomariX。

其中：

```text
komari.db
```

会改名为：

```text
komarix.db
```

如果原 Komari 使用默认 SQLite 指标数据库：

```text
metrics.db
```

它会一起被复制到 KomariX，因此历史 CPU、内存、流量、Ping 等监控数据也可以继续保留。

如果原 Komari 的指标数据库使用的是 MySQL 或 PostgreSQL，而不是本地 `metrics.db`，主数据库中的连接配置也会一并迁移，但需要确保 KomariX 服务器仍然可以连接原来的远程数据库。

---

## 第四步：让 KomariX 自动执行兼容迁移

启动 KomariX 后检查服务状态：

```bash
systemctl status komarix --no-pager
```

查看最近日志：

```bash
journalctl -u komarix -n 100 --no-pager
```

KomariX 启动时会自动检查旧数据库结构，并执行兼容迁移。

如果浏览器中出现数据库迁移页面，请按照页面提示完成迁移。

迁移过程中不要强制关闭 KomariX，也不要删除旧 Komari 数据。

---

## 第五步：检查迁移结果

打开原来的监控域名：

```text
https://你的Komari域名
```

重点检查：

```text
管理员账号是否可以正常登录
原来的监控机器是否全部存在
机器名称是否正确
UUID / Token 是否保留
机器是否重新上线
分组、备注等信息是否正常
Ping 任务是否正常
历史监控曲线是否存在
通知配置是否正常
```

如果原来的域名和端口都没有改变，并且 UUID、Token 已经成功迁移，原来的 Agent 通常不需要重新安装，也不需要重新添加机器。

---

## 第六步：确认 Nginx 和 HTTPS

如果迁移前后继续使用相同域名和相同端口：

```text
25774
```

原来的 Nginx 配置：

```text
/etc/nginx/conf.d/komari.conf
```

以及原来的 SSL 证书：

```text
/etc/nginx/ssl/komari
```

通常都可以继续使用，不需要重新申请证书。

可以检查：

```bash
nginx -t && systemctl reload nginx
```

---

# 迁移失败时回退到 Komari

因为整个迁移过程没有删除原来的 `/opt/komari`，所以如果 KomariX 迁移后出现异常，可以快速切回原来的 Komari。

执行：

```bash
systemctl stop komarix
systemctl disable komarix

systemctl enable komari
systemctl start komari
```

然后检查：

```bash
systemctl status komari --no-pager
```

如果原来的 Nginx 仍然代理到相同的 `25774` 端口，域名会重新访问原来的 Komari。

确认 KomariX 长时间运行正常之后，再决定是否删除旧的 Komari 文件。

---

# 迁移完成后的目录

原 Komari 建议暂时保留：

```text
/opt/komari
```

新的 KomariX：

```text
/opt/komarix
```

KomariX 主数据库：

```text
/opt/komarix/data/komarix.db
```

KomariX 默认历史监控数据库：

```text
/opt/komarix/data/metrics.db
```

迁移前的完整备份：

```text
/root/komari-data-before-komarix.tar.gz
```

建议确认 KomariX 中所有机器、历史数据和通知功能均正常后，再清理旧 Komari 数据。

---

# KomariX 全新安装流程

如果是全新的 VPS，不需要从 Komari 迁移数据，可以直接按照下面的流程部署 KomariX。

## 第一步：一键安装 KomariX

执行：

```bash
cd /root && curl -fsSL https://raw.githubusercontent.com/kkx999/KomariX/main/install-komarix.sh -o install-komarix.sh && chmod +x install-komarix.sh && ./install-komarix.sh
```

进入菜单后选择：

```text
1. 安装 KomariX
```

发布通道推荐选择：

```text
stable
```

KomariX 默认端口：

```text
25774
```

如果没有特殊需求，直接使用默认端口即可。

安装完成后可以检查：

```bash
systemctl status komarix --no-pager
```

如果显示：

```text
active (running)
```

说明 KomariX 已正常运行。

---

## 第二步：安装 Nginx

执行：

```bash
apt update && apt install -y nginx curl cron && systemctl enable --now nginx cron
```

---

## 第三步：一键配置域名 + SSL + HTTPS

先把自己的 KomariX 域名解析到当前 VPS 公网 IP。

然后执行：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/kkx999/Komari-Tutorial/main/setup-komarix-https.sh)
```

脚本首先需要输入：

```text
KomariX 域名
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

Cloudflare 凭据支持：

```text
1. API Token（推荐）
2. Global API Key
```

#### Cloudflare API Token

只需要输入：

```text
Cloudflare API Token
```

不需要手动填写 Account ID。

建议 Token 权限：

```text
Zone → DNS → Edit
Zone → Zone → Read
```

Zone Resources 建议限制为：

```text
Include → Specific zone → 你的域名
```

输入 Token 时终端不会显示内容。

#### Cloudflare Global API Key

也支持传统 Global API Key。

需要输入：

```text
Cloudflare 登录邮箱
Cloudflare Global API Key
```

Global API Key 权限较大，普通情况下优先推荐 API Token。

Cloudflare 凭据会由 acme.sh 保存，用于以后自动续期证书，请注意保护：

```text
/root/.acme.sh/
```

### 一键脚本会自动完成

```text
创建 KomariX Nginx 反向代理
安装或检查 acme.sh
选择 HTTP 或 Cloudflare DNS 验证
支持 Cloudflare API Token
支持 Cloudflare Global API Key
申请 Let's Encrypt SSL 证书
安装 SSL 证书
开启 HTTPS
HTTP 自动跳转 HTTPS
配置 WebSocket 反向代理
重新加载 Nginx
配置 acme.sh 自动续期
```

KomariX Nginx 配置：

```text
/etc/nginx/conf.d/komarix.conf
```

SSL 证书目录：

```text
/etc/nginx/ssl/komarix
```

脚本不会修改：

```text
/etc/nginx/nginx.conf
```

---

## 第四步：访问 KomariX

打开：

```text
https://你的KomariX域名
```

首次访问按照页面提示完成管理员初始化即可。

---

## KomariX 常用服务管理命令

查看状态：

```bash
systemctl status komarix
```

启动：

```bash
systemctl start komarix
```

停止：

```bash
systemctl stop komarix
```

重启：

```bash
systemctl restart komarix
```

实时日志：

```bash
journalctl -u komarix -f
```

默认程序目录：

```text
/opt/komarix
```

默认主数据库：

```text
/opt/komarix/data/komarix.db
```

默认历史监控数据库：

```text
/opt/komarix/data/metrics.db
```

至此，KomariX 全新安装完成。

---

# KomariX 数据备份与恢复

如果以后需要重装 VPS、迁移服务器，或者在升级前做完整备份，建议直接备份整个 KomariX `data` 目录，而不是只备份单个数据库文件。

KomariX 默认数据目录：

```text
/opt/komarix/data
```

其中主要包括：

```text
komarix.db
metrics.db
```

`komarix.db` 主要保存：

```text
管理员账号
已添加的监控机器
机器名称
UUID
Token
分组
备注
站点配置
Ping 任务
通知配置
主题和插件相关配置
```

`metrics.db` 主要保存：

```text
CPU 历史监控数据
内存历史监控数据
磁盘历史监控数据
流量历史监控数据
Ping 历史监控数据
其他历史指标数据
```

因此推荐直接完整备份：

```text
/opt/komarix/data
```

这样恢复后可以最大程度保留原来的 KomariX 状态。

## 重装 VPS 或迁移前：完整备份 KomariX

先停止 KomariX：

```bash
systemctl stop komarix
```

确认数据目录存在：

```bash
ls -lah /opt/komarix/data
```

然后完整打包：

```bash
tar -C /opt/komarix -czf /root/komarix-data-backup.tar.gz data
```

备份完成后重新启动 KomariX：

```bash
systemctl start komarix
```

备份文件位于：

```text
/root/komarix-data-backup.tar.gz
```

可以检查：

```bash
ls -lh /root/komarix-data-backup.tar.gz
```

建议在重装系统之前，把：

```text
/root/komarix-data-backup.tar.gz
```

下载到自己的电脑或其他安全位置保存。

> 如果准备执行 DD 重装系统，必须先把备份文件下载到服务器之外。系统重装后，原 VPS 上的文件通常都会被清空。

---

## 重装 VPS 后：恢复 KomariX

先按照上面的 **KomariX 全新安装流程** 安装好 KomariX。

安装完成后先停止服务：

```bash
systemctl stop komarix
```

把之前保存的：

```text
komarix-data-backup.tar.gz
```

上传到：

```text
/root/komarix-data-backup.tar.gz
```

然后执行：

```bash
systemctl stop komarix

mkdir -p /opt/komarix

rm -rf /opt/komarix/data

tar -C /opt/komarix -xzf /root/komarix-data-backup.tar.gz

chmod 644 /opt/komarix/data/komarix.db

systemctl start komarix
```

恢复完成后检查服务：

```bash
systemctl status komarix --no-pager
```

查看最近日志：

```bash
journalctl -u komarix -n 100 --no-pager
```

如果服务正常启动，打开原来的 KomariX 域名检查：

```text
管理员账号是否可以正常登录
原来的监控机器是否全部存在
机器名称是否正常
UUID / Token 是否保留
Agent 是否重新上线
历史 CPU / 内存 / 流量 / Ping 曲线是否存在
Ping 任务是否正常
通知配置是否正常
主题及其他配置是否正常
```

如果域名、端口和 Agent 配置没有改变，并且 UUID、Token 已成功恢复，原来的 Agent 通常不需要重新安装。

---

## 只恢复主数据库

如果只想恢复机器、UUID、Token 和面板配置，不需要历史监控曲线，也可以只备份：

```text
/opt/komarix/data/komarix.db
```

备份：

```bash
systemctl stop komarix

cp /opt/komarix/data/komarix.db /root/komarix.db

systemctl start komarix
```

恢复：

```bash
systemctl stop komarix

cp /root/komarix.db /opt/komarix/data/komarix.db

chmod 644 /opt/komarix/data/komarix.db

systemctl start komarix
```

这种方式不会恢复：

```text
metrics.db 中的历史监控曲线
```

因此普通情况下更推荐使用完整 `data` 目录备份。

---

## 恢复后如果 KomariX 无法启动

先查看日志：

```bash
journalctl -u komarix -n 200 --no-pager
```

检查文件：

```bash
ls -lah /opt/komarix/data
```

确认至少存在：

```text
/opt/komarix/data/komarix.db
```

然后重新设置主数据库权限：

```bash
chmod 644 /opt/komarix/data/komarix.db
```

再尝试：

```bash
systemctl restart komarix
```

如果备份来自较旧版本的 KomariX，首次启动时可能会自动执行数据库结构迁移。

迁移过程中不要强制关闭服务。

---

## 建议的备份方式

日常使用时，最推荐保存：

```text
/root/komarix-data-backup.tar.gz
```

它包含完整的：

```text
/opt/komarix/data
```

需要重装系统或迁移服务器时，只需要：

```text
安装 KomariX
↓
停止 KomariX
↓
恢复 data 目录
↓
启动 KomariX
↓
检查机器和历史监控数据
```

即可完成恢复。

