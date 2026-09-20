#!/usr/bin/env bash
set -euo pipefail

REPO="komari-monitor/komari"
INSTALL_DIR="/opt/komari"
BINARY_PATH="${INSTALL_DIR}/komari"
SERVICE_FILE="/etc/systemd/system/komari.service"
SERVICE_NAME="komari"
DEFAULT_PORT="25774"

if [[ "${EUID}" -ne 0 ]]; then
    echo "错误：请使用 root 用户运行此脚本。"
    exit 1
fi

ensure_dependencies() {
    if command -v curl >/dev/null 2>&1 && command -v systemctl >/dev/null 2>&1; then
        return
    fi

    if command -v apt >/dev/null 2>&1; then
        apt update
        apt install -y curl ca-certificates
    elif command -v yum >/dev/null 2>&1; then
        yum install -y curl ca-certificates
    elif command -v apk >/dev/null 2>&1; then
        apk add curl ca-certificates
    else
        echo "错误：缺少 curl/systemctl，且未识别到支持的包管理器。"
        exit 1
    fi

    if ! command -v curl >/dev/null 2>&1 || ! command -v systemctl >/dev/null 2>&1; then
        echo "错误：当前系统缺少 curl 或 systemd。"
        exit 1
    fi
}

detect_arch() {
    case "$(uname -m)" in
        x86_64) echo "amd64" ;;
        aarch64|arm64) echo "arm64" ;;
        i386|i686) echo "386" ;;
        riscv64) echo "riscv64" ;;
        loongarch64|loong64) echo "loong64" ;;
        *)
            echo "错误：不支持的 CPU 架构：$(uname -m)" >&2
            exit 1
            ;;
    esac
}

detect_existing_port() {
    local exec_start=""
    local port=""

    exec_start="$(systemctl show -p ExecStart --value "${SERVICE_NAME}.service" 2>/dev/null || true)"
    if [[ -z "${exec_start}" && -f "${SERVICE_FILE}" ]]; then
        exec_start="$(grep -E '^ExecStart=' "${SERVICE_FILE}" | tail -n1 | cut -d= -f2- || true)"
    fi

    port="$(printf '%s\n' "${exec_start}" | sed -nE 's/.*-l[[:space:]]+[^[:space:]]*:([0-9]{1,5}).*/\1/p' | tail -n1)"
    if [[ "${port}" =~ ^[0-9]+$ ]] && (( port >= 1 && port <= 65535 )); then
        echo "${port}"
    else
        echo "${DEFAULT_PORT}"
    fi
}

ensure_dependencies

ARCH="$(detect_arch)"
EXISTING_PORT="$(detect_existing_port)"
VERSION="${1:-}"
PORT="${2:-}"

if [[ -z "${VERSION}" ]]; then
    read -rp "请输入要安装的 Komari Release 版本（例如 1.5.0-fix1 或 1.4.3）: " VERSION
fi

VERSION="${VERSION#refs/tags/}"
VERSION="${VERSION#tags/}"

if [[ -z "${VERSION}" || ! "${VERSION}" =~ ^[A-Za-z0-9._-]+$ ]]; then
    echo "错误：版本格式不正确。请输入 GitHub Release 的 Tag，例如 1.5.0-fix1。"
    exit 1
fi

if [[ -z "${PORT}" ]]; then
    read -rp "请输入 Komari 监听端口 [默认 ${EXISTING_PORT}]: " PORT
    PORT="${PORT:-${EXISTING_PORT}}"
fi

if [[ ! "${PORT}" =~ ^[0-9]+$ ]] || (( PORT < 1 || PORT > 65535 )); then
    echo "错误：端口必须是 1-65535 之间的数字。"
    exit 1
fi

RELEASE_API="https://api.github.com/repos/${REPO}/releases/tags/${VERSION}"
DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${VERSION}/komari-linux-${ARCH}"

echo
echo "准备安装："
echo "  版本：${VERSION}"
echo "  架构：${ARCH}"
echo "  端口：${PORT}"
echo "  目录：${INSTALL_DIR}"
echo

if ! curl -fsSL --connect-timeout 10 --max-time 30 "${RELEASE_API}" -o /dev/null; then
    echo "错误：未找到 Release Tag：${VERSION}"
    echo "请确认版本号与 GitHub Release 中的 Tag 完全一致。"
    exit 1
fi

TMP_BINARY="$(mktemp)"
trap 'rm -f "${TMP_BINARY}"' EXIT

echo "[1/4] 下载 Komari ${VERSION}..."
if ! curl -fL --retry 2 --connect-timeout 10 --max-time 300 "${DOWNLOAD_URL}" -o "${TMP_BINARY}"; then
    echo "错误：下载失败。该版本可能没有 ${ARCH} 架构的 Linux 文件。"
    exit 1
fi

if [[ ! -s "${TMP_BINARY}" ]]; then
    echo "错误：下载到的文件为空。"
    exit 1
fi
chmod +x "${TMP_BINARY}"

TIMESTAMP="$(date +%Y%m%d%H%M%S)"
BINARY_BACKUP=""
SERVICE_BACKUP=""
WAS_ACTIVE=0

if systemctl is-active --quiet "${SERVICE_NAME}.service" 2>/dev/null; then
    WAS_ACTIVE=1
    echo "[2/4] 停止当前 Komari 服务..."
    systemctl stop "${SERVICE_NAME}.service"
else
    echo "[2/4] 当前 Komari 服务未运行，继续安装..."
fi

mkdir -p "${INSTALL_DIR}"

if [[ -f "${BINARY_PATH}" ]]; then
    BINARY_BACKUP="${BINARY_PATH}.backup.${TIMESTAMP}"
    cp -a "${BINARY_PATH}" "${BINARY_BACKUP}"
    echo "已备份当前程序：${BINARY_BACKUP}"
fi

if [[ -f "${SERVICE_FILE}" ]]; then
    SERVICE_BACKUP="${SERVICE_FILE}.backup.${TIMESTAMP}"
    cp -a "${SERVICE_FILE}" "${SERVICE_BACKUP}"
    echo "已备份当前服务配置：${SERVICE_BACKUP}"
fi

rollback() {
    echo
    echo "安装未成功，正在恢复原版本..."

    if [[ -n "${BINARY_BACKUP}" && -f "${BINARY_BACKUP}" ]]; then
        cp -a "${BINARY_BACKUP}" "${BINARY_PATH}"
    else
        rm -f "${BINARY_PATH}"
    fi

    if [[ -n "${SERVICE_BACKUP}" && -f "${SERVICE_BACKUP}" ]]; then
        cp -a "${SERVICE_BACKUP}" "${SERVICE_FILE}"
    else
        rm -f "${SERVICE_FILE}"
    fi

    systemctl daemon-reload || true
    if [[ "${WAS_ACTIVE}" -eq 1 ]]; then
        systemctl start "${SERVICE_NAME}.service" || true
    fi
}

echo "[3/4] 安装程序并配置 systemd..."
if ! install -m 0755 "${TMP_BINARY}" "${BINARY_PATH}"; then
    rollback
    exit 1
fi

cat > "${SERVICE_FILE}" <<EOF
[Unit]
Description=Komari Monitor Service
After=network.target

[Service]
Type=simple
ExecStart=${BINARY_PATH} server -l 0.0.0.0:${PORT}
WorkingDirectory=${INSTALL_DIR}
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "${SERVICE_NAME}.service" >/dev/null

echo "[4/4] 启动 Komari..."
if ! systemctl restart "${SERVICE_NAME}.service"; then
    rollback
    echo "错误：Komari 启动失败。"
    exit 1
fi

sleep 1
if ! systemctl is-active --quiet "${SERVICE_NAME}.service"; then
    journalctl -u "${SERVICE_NAME}.service" -n 30 --no-pager || true
    rollback
    echo "错误：Komari 未能保持运行，已恢复原版本。"
    exit 1
fi

echo
echo "=============================================="
echo "Komari 指定版本安装完成"
echo "版本：${VERSION}"
echo "架构：${ARCH}"
echo "端口：${PORT}"
echo "本机访问：http://127.0.0.1:${PORT}"
echo "服务状态：systemctl status komari"
echo "实时日志：journalctl -u komari -f"
if [[ -n "${BINARY_BACKUP}" ]]; then
    echo "旧程序备份：${BINARY_BACKUP}"
fi
echo "=============================================="
