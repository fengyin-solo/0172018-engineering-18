#!/usr/bin/env bash
# ============================================================
# 拉取前端依赖（ECharts）到 vendor/，供本地直接打开页面使用
# 与 Dockerfile deps 阶段保持一致：固定版本 + SHA-256 完整性校验
# 拉取超时或校验失败时明确报错并以非零码退出
# ============================================================
set -euo pipefail

ECHARTS_VERSION="${ECHARTS_VERSION:-5.4.3}"
ECHARTS_SHA256="${ECHARTS_SHA256:-1156429a16a38cb8604dcc6518c19406d4226142d908f8edd2e3531443c54d19}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENDOR_DIR="${SCRIPT_DIR}/../vendor"
TARGET="${VENDOR_DIR}/echarts.min.js"
TMP_FILE="$(mktemp)"
trap 'rm -f "${TMP_FILE}"' EXIT

URLS=(
    "https://cdn.jsdelivr.net/npm/echarts@${ECHARTS_VERSION}/dist/echarts.min.js"
    "https://unpkg.com/echarts@${ECHARTS_VERSION}/dist/echarts.min.js"
)

fetch() { # $1=url $2=dest
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --connect-timeout 10 --max-time 60 -o "$2" "$1"
    elif command -v wget >/dev/null 2>&1; then
        wget -q -T 60 -O "$2" "$1"
    else
        echo "ERROR: 需要 curl 或 wget 才能拉取依赖" >&2
        return 1
    fi
}

verify_sha256() { # $1=file $2=expected
    if command -v sha256sum >/dev/null 2>&1; then
        echo "$2  $1" | sha256sum -c - >/dev/null 2>&1
    elif command -v shasum >/dev/null 2>&1; then
        echo "$2  $1" | shasum -a 256 -c - >/dev/null 2>&1
    else
        local actual
        actual="$(openssl dgst -sha256 -r "$1" | awk '{print $1}')"
        [ "${actual}" = "$2" ]
    fi
}

echo ">> 拉取 echarts@${ECHARTS_VERSION} ..."
ok=0
for url in "${URLS[@]}"; do
    for attempt in 1 2 3; do
        echo ">> 尝试 (${attempt}/3): ${url}"
        if fetch "${url}" "${TMP_FILE}"; then
            ok=1
            break
        fi
        echo "!! 拉取失败，2s 后重试" >&2
        sleep 2
    done
    [ "${ok}" -eq 1 ] && break
done

if [ "${ok}" -ne 1 ]; then
    echo "ERROR: 依赖拉取失败 echarts@${ECHARTS_VERSION}（网络超时或不可达），请检查网络后重试" >&2
    exit 1
fi

if ! verify_sha256 "${TMP_FILE}" "${ECHARTS_SHA256}"; then
    echo "ERROR: 依赖完整性校验失败（SHA-256 不匹配）" >&2
    exit 1
fi

mkdir -p "${VENDOR_DIR}"
mv "${TMP_FILE}" "${TARGET}"
echo ">> 完成: ${TARGET} (echarts@${ECHARTS_VERSION}, SHA-256 校验通过)"
