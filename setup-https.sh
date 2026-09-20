#!/usr/bin/env bash
set -euo pipefail

DEFAULT_KOMARI_PORT="25774"
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

detect_komari_port() {
    local exec_start=""
    local port=""

    if command -v systemctl >/dev/null 2>&1; then
        exec_start="$(systemctl show -p ExecStart --value komari.service 2>/dev/null || true)"
    fi

    if [[ -z "${exec_start}" && -f /etc/systemd/system/komari.service ]]; then
        exec_start="$(grep -E '^ExecStart=' /etc/systemd/system/komari.service | tail -n1 | cut -d= -f2- || true)"
    fi

    port="$(printf '%s\n' "${exec_start}" | sed -nE 's/.*-l[[:space:]]+[^[:space:]]*:([0-9]{1,5}).*/\1/p' | tail -n1)"

    if [[ "${port}" =~ ^[0-9]+$ ]] && (( port >= 1 && port <= 65535 )); then
        printf '%s\n' "${port}"
    else
        printf '%s\n' "${DEFAULT_KOMARI_PORT}"
    fi
}

KOMARI_PORT="$(detect_komari_port)"

if [[ "${KOMARI_PORT}" == "${DEFAULT_KOMARI_PORT}" ]]; then
    echo "检测到 Komari 端口：${KOMARI_PORT}（如未能读取服务配置则使用默认值）"
else
    echo "自动检测到 Komari 监听端口：${KOMARI_PORT}"
fi

if ! curl -fsS --max-time 5 "http://127.0.0.1:${KOMARI_PORT}/" >/dev/null 2>&1; then
    echo "警告：暂时无法通过 127.0.0.1:${KOMARI_PORT} 访问 Komari。"
    echo "请确认 Komari 已启动且监听端口正确。脚本仍可继续配置 Nginx。"
fi

read -rp "请输入 Komari 域名（例如 monitor.example.com）: " DOMAIN
read -rp "请输入用于申请 SSL 证书的邮箱: " EMAIL

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

echo
echo "请选择 SSL 证书验证方式："
echo "1. HTTP 验证（需要公网 80 端口可访问）"
echo "2. Cloudflare DNS 验证（不需要开放 80 端口）"
read -rp "请选择 [1-2]：" VERIFY_METHOD

case "${VERIFY_METHOD}" in
    1) VERIFY_NAME="HTTP" ;;
    2) VERIFY_NAME="Cloudflare DNS" ;;
    *)
        echo "错误：请选择 1 或 2。"
        exit 1
        ;;
esac

if [[ -f "${NGINX_CONF}" ]]; then
    BACKUP_FILE="${NGINX_CONF}.bak.$(date +%Y%m%d%H%M%S)"
    cp -a "${NGINX_CONF}" "${BACKUP_FILE}"
    echo "已备份原 Nginx 配置：${BACKUP_FILE}"
fi

echo
echo "[1/5] 配置 Komari HTTP 反向代理..."
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
echo "[2/5] 安装或检查 acme.sh..."
if [[ ! -x "${ACME_SH}" ]]; then
    curl -fsSL https://get.acme.sh | sh -s email="${EMAIL}"
fi

if [[ ! -x "${ACME_SH}" ]]; then
    echo "错误：acme.sh 安装失败。"
    exit 1
fi

"${ACME_SH}" --set-default-ca --server letsencrypt

echo
echo "[3/5] 使用 ${VERIFY_NAME} 验证申请证书..."

if [[ "${VERIFY_METHOD}" == "1" ]]; then
    echo "请确认 ${DOMAIN} 已解析到本机公网 IP，并且公网 80 端口可以访问。"

    set +e
    "${ACME_SH}" --issue --nginx -d "${DOMAIN}"
    ACME_RC=$?
    set -e
else
    echo
    echo "Cloudflare 凭据方式："
    echo "1. API Token（推荐）"
    echo "2. Global API Key"
    read -rp "请选择 [1-2]：" CF_METHOD

    case "${CF_METHOD}" in
        1)
            read -rsp "请输入 Cloudflare API Token：" CF_TOKEN_INPUT
            echo

            if [[ -z "${CF_TOKEN_INPUT}" ]]; then
                echo "错误：Cloudflare API Token 不能为空。"
                exit 1
            fi

            export CF_Token="${CF_TOKEN_INPUT}"
            unset CF_Account_ID CF_Zone_ID CF_Key CF_Email 2>/dev/null || true
            ;;
        2)
            read -rp "请输入 Cloudflare 登录邮箱：" CF_EMAIL_INPUT
            read -rsp "请输入 Cloudflare Global API Key：" CF_KEY_INPUT
            echo

            if [[ ! "${CF_EMAIL_INPUT}" =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]] || [[ -z "${CF_KEY_INPUT}" ]]; then
                echo "错误：Cloudflare 登录邮箱或 Global API Key 无效。"
                exit 1
            fi

            export CF_Email="${CF_EMAIL_INPUT}"
            export CF_Key="${CF_KEY_INPUT}"
            unset CF_Token CF_Account_ID CF_Zone_ID 2>/dev/null || true
            ;;
        *)
            echo "错误：请选择 1 或 2。"
            exit 1
            ;;
    esac

    set +e
    "${ACME_SH}" --issue --dns dns_cf -d "${DOMAIN}"
    ACME_RC=$?
    set -e
fi

if [[ "${ACME_RC}" -ne 0 && "${ACME_RC}" -ne 2 ]]; then
    echo "错误：SSL 证书申请失败。"
    if [[ "${VERIFY_METHOD}" == "1" ]]; then
        echo "请检查域名解析以及公网 80 端口。"
    else
        echo "请检查域名是否托管在 Cloudflare，以及 API Token / Global API Key 权限是否正确。"
    fi
    exit "${ACME_RC}"
fi

echo
echo "[4/5] 安装 SSL 证书..."
mkdir -p "${SSL_DIR}"
"${ACME_SH}" --install-cert -d "${DOMAIN}" \
    --key-file "${SSL_DIR}/private.key" \
    --fullchain-file "${SSL_DIR}/fullchain.cer" \
    --reloadcmd "systemctl reload nginx"

chmod 600 "${SSL_DIR}/private.key"

echo
echo "[5/5] 开启 HTTPS..."
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
echo "Komari 端口：${KOMARI_PORT}"
echo "验证方式：${VERIFY_NAME}"
echo "访问地址：https://${DOMAIN}"
echo "SSL 证书将由 acme.sh 自动续期"
echo "=============================================="
