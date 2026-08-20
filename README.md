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

## 第三步：绑定 Komari 域名

把：

```text
你的Komari域名
```

修改成自己的域名，然后整段执行：

```bash
DOMAIN="你的Komari域名"

cat > /etc/nginx/conf.d/komari.conf <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:25774;
    }
}
EOF

nginx -t && systemctl reload nginx
```

---

## 第四步：申请 SSL 证书

把域名和邮箱修改成自己的，然后整段执行：

```bash
DOMAIN="你的Komari域名"
EMAIL="你的邮箱"

curl https://get.acme.sh | sh -s email="$EMAIL" && \
mkdir -p /etc/nginx/ssl/komari && \
/root/.acme.sh/acme.sh --set-default-ca --server letsencrypt && \
/root/.acme.sh/acme.sh --issue --nginx -d "$DOMAIN" && \
/root/.acme.sh/acme.sh --install-cert -d "$DOMAIN" \
  --key-file /etc/nginx/ssl/komari/private.key \
  --fullchain-file /etc/nginx/ssl/komari/fullchain.cer \
  --reloadcmd "systemctl reload nginx"
```

证书会自动续期。

---

## 第五步：开启 HTTPS

把域名修改成自己的，然后整段执行：

```bash
DOMAIN="你的Komari域名"

cat > /etc/nginx/conf.d/komari.conf <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name $DOMAIN;

    ssl_certificate /etc/nginx/ssl/komari/fullchain.cer;
    ssl_certificate_key /etc/nginx/ssl/komari/private.key;

    location / {
        proxy_pass http://127.0.0.1:25774;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "Upgrade";

        proxy_buffering off;
    }
}
EOF

nginx -t && systemctl reload nginx
```

---

## 第六步：访问 Komari

打开：

```text
https://你的Komari域名
```

完成。

Komari 的独立 Nginx 配置：

```text
/etc/nginx/conf.d/komari.conf
```

不会修改：

```text
/etc/nginx/nginx.conf
```
