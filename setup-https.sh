#!/usr/bin/env bash
set -euo pipefail

KOMARI_PORT="25774"
NGINX_CONF="/etc/nginx/conf.d/komari.conf"
SSL_DIR="/etc/nginx/ssl/komari"
ACME_SH="/root/.acme.sh/acme.sh"

if [[ "${EUID}" -ne 0 ]]; then
    echo "错误：请使用 root 用户运行此脚本。"
    exit 1
fi

if ! command -v nginx >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
    echo "错误：未检测到 Nginx 或 curl。"
    echo "请先执行教程第二步安装 Nginx、curl 和 cron。"
    exit 1
fi

read -rp "请输入 Komari 域名（例如 monitor.example.com）: " DOMAIN
read -rp "请输入用于申请 SSL 证书的邮箱: " EMAIL

# 自动去掉用户误输入的协议、路径和末尾斜杠。
DOMAIN="${DOMAIN#http://}"
DOMAIN="${DOMAIN#https://}"
DOMAIN="${DOMAIN%%/*}"
DOMAIN="${DOMAIN%.}"

if [[ -z "${DOMAIN}" ]] || [[ ! "${DOMAIN}" =~ ^([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}$ ]]; then
    echo "错误：域名格式不正确：${DOMAIN:-<空>}"
    exit 1
fi

if [[ ! "${EMAIL}" =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]]; then
    echo "错误：邮箱格式不正确：${EMAIL}"
    exit 1
fi

if [[ -f "${NGINX_CONF}" ]]; then
    BACKUP_FILE="${NGINX_CONF}.bak.$(date +%Y%m%d%H%M%S)"
    cp -a "${NGINX_CONF}" "${BACKUP_FILE}"
    echo "已备份原 Nginx 配置：${BACKUP_FILE}"
fi

echo
 echo "[1/4] 配置 Komari HTTP 反向代理..."
cat > "${NGINX_CONF}" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};

    location / {
        proxy_pass http://127.0.0.1:${KOMARI_PORT};

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

nginx -t
systemctl reload nginx

echo
 echo "[2/4] 安装或检查 acme.sh..."
if [[ ! -x "${ACME_SH}" ]]; then
    curl -fsSL https://get.acme.sh | sh -s email="${EMAIL}"
fi

if [[ ! -x "${ACME_SH}" ]]; then
    echo "错误：acme.sh 安装失败。"
    exit 1
fi

"${ACME_SH}" --set-default-ca --server letsencrypt

echo
 echo "[3/4] 为 ${DOMAIN} 申请 SSL 证书..."
set +e
"${ACME_SH}" --issue --nginx -d "${DOMAIN}"
ACME_RC=$?
set -e

# acme.sh 在已有有效证书、无需重新签发时可能返回 2，可继续安装证书。
if [[ "${ACME_RC}" -ne 0 && "${ACME_RC}" -ne 2 ]]; then
    echo "错误：SSL 证书申请失败。"
    echo "请确认域名已经解析到本机公网 IP，并且 80 端口可以从公网访问。"
    exit "${ACME_RC}"
fi

mkdir -p "${SSL_DIR}"
"${ACME_SH}" --install-cert -d "${DOMAIN}" \
    --key-file "${SSL_DIR}/private.key" \
    --fullchain-file "${SSL_DIR}/fullchain.cer" \
    --reloadcmd "systemctl reload nginx"

chmod 600 "${SSL_DIR}/private.key"

echo
 echo "[4/4] 开启 HTTPS..."
cat > "${NGINX_CONF}" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};

    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name ${DOMAIN};

    ssl_certificate ${SSL_DIR}/fullchain.cer;
    ssl_certificate_key ${SSL_DIR}/private.key;

    location / {
        proxy_pass http://127.0.0.1:${KOMARI_PORT};

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

nginx -t
systemctl reload nginx

echo
echo "=============================================="
echo "Komari 域名和 HTTPS 配置完成"
echo "访问地址：https://${DOMAIN}"
echo "SSL 证书将由 acme.sh 自动续期"
echo "=============================================="
