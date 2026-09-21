#!/usr/bin/env bash
# ==============================================================================
# 佳贝艾特会员诊断驾驶舱 - 镜像构建脚本
#
# 功能：
#   1. 校验必填构建参数（REPORT_VERSION / DATA_UPDATED_AT），缺失即明确报错并停止
#   2. 带超时拉取基础镜像，拉取失败/超时即明确报错并停止
#   3. 基于 buildx 构建 linux/amd64 + linux/arm64 镜像，相同参数可重复构建
#
# 用法：
#   # 本地单架构构建（自动识别当前机器架构，--load 到本地）
#   REPORT_VERSION=1.0.0 DATA_UPDATED_AT=2026-09-21 ./scripts/build.sh
#
#   # 多架构构建并推送到镜像仓库（ARM + X86）
#   REPORT_VERSION=1.0.0 DATA_UPDATED_AT=2026-09-21 \
#       PUSH=true REGISTRY=registry.example.com/apps ./scripts/build.sh
#
# 环境变量：
#   REPORT_VERSION   报告版本（必填），如 1.0.0
#   DATA_UPDATED_AT  数据更新时间（必填），格式 YYYY-MM-DD
#   IMAGE_NAME       镜像名，默认 jiabei-dashboard
#   PLATFORMS        目标平台，默认：PUSH=true 时为 linux/amd64,linux/arm64，
#                    本地构建时为当前机器架构
#   REGISTRY         镜像仓库前缀（PUSH=true 时建议设置）
#   PUSH             是否推送，默认 false（本地构建需单一平台）
#   PULL_TIMEOUT     基础镜像拉取超时秒数，默认 300
# ==============================================================================
set -euo pipefail

cd "$(dirname "$0")/.."

IMAGE_NAME="${IMAGE_NAME:-jiabei-dashboard}"
PULL_TIMEOUT="${PULL_TIMEOUT:-300}"
PUSH="${PUSH:-false}"
REGISTRY="${REGISTRY:-}"
DOCKERFILE="frontend-user/Dockerfile"
CONTEXT_DIR="frontend-user"

err() { echo "ERROR: $*" >&2; exit 1; }

# 目标平台：推送模式默认 ARM + X86 多架构；本地构建默认当前机器架构
if [ -z "${PLATFORMS:-}" ]; then
    if [ "$PUSH" = "true" ]; then
        PLATFORMS="linux/amd64,linux/arm64"
    else
        case "$(uname -m)" in
            x86_64)         PLATFORMS="linux/amd64" ;;
            aarch64|arm64)  PLATFORMS="linux/arm64" ;;
            *) err "无法识别当前机器架构 $(uname -m)，请显式设置 PLATFORMS=linux/amd64 或 linux/arm64" ;;
        esac
    fi
fi

# ---- 1. 构建参数校验：缺失或格式错误即明确报错并停止 ----
[ -n "${REPORT_VERSION:-}" ]  || err "缺少构建参数 REPORT_VERSION（报告版本），示例: REPORT_VERSION=1.0.0"
[ -n "${DATA_UPDATED_AT:-}" ] || err "缺少构建参数 DATA_UPDATED_AT（数据更新时间），示例: DATA_UPDATED_AT=2026-09-21"
echo "$DATA_UPDATED_AT" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' \
    || err "DATA_UPDATED_AT 格式应为 YYYY-MM-DD，当前值: $DATA_UPDATED_AT"

# ---- 2. 环境检查 ----
command -v docker >/dev/null 2>&1 || err "未找到 docker，请先安装 Docker"
docker buildx version >/dev/null 2>&1 || err "未找到 docker buildx，请安装/启用 buildx 插件以支持跨平台构建"
[ -f "$DOCKERFILE" ] || err "未找到 $DOCKERFILE"

# 基础镜像引用以 Dockerfile 为唯一来源，保证脚本与 Dockerfile 不脱节
BASE_IMAGE=$(awk '/^FROM /{print $2; exit}' "$DOCKERFILE")
[ -n "$BASE_IMAGE" ] || err "无法从 $DOCKERFILE 解析基础镜像"

# ---- 3. 依赖拉取：超时或失败即明确报错并停止 ----
echo "==> 拉取基础镜像 $BASE_IMAGE（超时 ${PULL_TIMEOUT}s）"
if ! timeout "$PULL_TIMEOUT" docker pull "$BASE_IMAGE"; then
    err "基础镜像拉取失败或超时（${PULL_TIMEOUT}s）: $BASE_IMAGE，请检查网络或镜像仓库可用性后重试"
fi

# ---- 4. 组装镜像标签 ----
if [ -n "$REGISTRY" ]; then
    IMAGE_REF="${REGISTRY%/}/${IMAGE_NAME}:${REPORT_VERSION}"
else
    IMAGE_REF="${IMAGE_NAME}:${REPORT_VERSION}"
fi

# ---- 5. 构建 ----
if [ "$PUSH" = "true" ]; then
    echo "==> 构建多架构镜像并推送: $IMAGE_REF ($PLATFORMS)"
    docker buildx build \
        --platform "$PLATFORMS" \
        --build-arg "REPORT_VERSION=$REPORT_VERSION" \
        --build-arg "DATA_UPDATED_AT=$DATA_UPDATED_AT" \
        --tag "$IMAGE_REF" \
        --file "$DOCKERFILE" \
        --push \
        "$CONTEXT_DIR"
else
    case "$PLATFORMS" in
        *,*)
            err "本地构建（PUSH=false）仅支持单一平台，请设置 PLATFORMS=linux/amd64（或 linux/arm64），或使用 PUSH=true 构建并推送多架构镜像"
            ;;
    esac
    echo "==> 构建本地镜像: $IMAGE_REF ($PLATFORMS)"
    docker buildx build \
        --platform "$PLATFORMS" \
        --build-arg "REPORT_VERSION=$REPORT_VERSION" \
        --build-arg "DATA_UPDATED_AT=$DATA_UPDATED_AT" \
        --tag "$IMAGE_REF" \
        --file "$DOCKERFILE" \
        --load \
        "$CONTEXT_DIR"
fi

echo "==> 构建完成: $IMAGE_REF"
echo "    报告版本: $REPORT_VERSION | 数据更新时间: $DATA_UPDATED_AT | 平台: $PLATFORMS"
