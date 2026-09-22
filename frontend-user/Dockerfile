# 佳贝艾特会员诊断驾驶舱 - 前端展示镜像
# 支持 linux/amd64 与 linux/arm64 跨平台构建，同一构建参数产出一致镜像：
#   docker buildx build --platform linux/amd64,linux/arm64 \
#     --build-arg REPORT_VERSION=1.0.0 --build-arg DATA_UPDATED_AT=2026-02-05 \
#     -t jiabei-dashboard:latest ./frontend-user

# ============================================================
# 阶段 1 (deps): 拉取并校验前端依赖（ECharts）
# 使用构建机平台执行，产物为平台无关的静态文件，ARM/X86 结果一致；
# 版本固定 + SHA-256 校验，保证重复构建产物完全相同
# ============================================================
FROM --platform=$BUILDPLATFORM alpine:3.21 AS deps

ARG ECHARTS_VERSION=5.4.3
ARG ECHARTS_SHA256=1156429a16a38cb8604dcc6518c19406d4226142d908f8edd2e3531443c54d19

WORKDIR /deps

# 下载 ECharts（单次超时 30s、每个镜像源重试 3 次、双镜像源兜底），并做 SHA-256 完整性校验；
# 拉取超时或校验失败时明确报错并终止构建
RUN set -eu; \
    urls="https://cdn.jsdelivr.net/npm/echarts@${ECHARTS_VERSION}/dist/echarts.min.js \
https://unpkg.com/echarts@${ECHARTS_VERSION}/dist/echarts.min.js"; \
    ok=0; \
    for url in ${urls}; do \
        attempt=1; \
        while [ "${attempt}" -le 3 ]; do \
            echo ">> [deps] 拉取 echarts@${ECHARTS_VERSION} (第 ${attempt}/3 次): ${url}"; \
            if wget -q -T 30 -O echarts.min.js "${url}"; then \
                ok=1; \
                break; \
            fi; \
            echo "!! [deps] 拉取失败，2s 后重试"; \
            sleep 2; \
            attempt=$((attempt + 1)); \
        done; \
        [ "${ok}" -eq 1 ] && break; \
    done; \
    if [ "${ok}" -ne 1 ]; then \
        echo "ERROR: 依赖拉取失败 echarts@${ECHARTS_VERSION}（网络超时或不可达），请检查网络后重新构建" >&2; \
        exit 1; \
    fi; \
    if ! echo "${ECHARTS_SHA256}  echarts.min.js" | sha256sum -c - > /dev/null 2>&1; then \
        echo "ERROR: 依赖完整性校验失败（SHA-256 不匹配），已终止构建" >&2; \
        exit 1; \
    fi; \
    echo ">> [deps] echarts@${ECHARTS_VERSION} 完整性校验通过"

# ============================================================
# 阶段 2 (runtime): 运行时镜像（默认目标平台，ARM/X86 内容一致）
# ============================================================
FROM nginx:1.27.5-alpine AS runtime

# 清理默认静态文件与默认站点配置，保证镜像内容可重复
RUN rm -rf /usr/share/nginx/html/* /etc/nginx/conf.d/default.conf

# Nginx 站点配置（与本地直接打开的行为保持一致）
COPY nginx/default.conf /etc/nginx/conf.d/default.conf

# 静态文件（与仓库中的文件完全一致，本地直接打开即用）
COPY index.html /usr/share/nginx/html/index.html
COPY css/ /usr/share/nginx/html/css/
COPY js/ /usr/share/nginx/html/js/

# 前端依赖（来自 deps 阶段，已通过完整性校验）
COPY --from=deps /deps/echarts.min.js /usr/share/nginx/html/vendor/echarts.min.js

# 构建期注入：报告版本与数据更新时间（缺失或非法时明确报错并终止构建）
ARG REPORT_VERSION
ARG DATA_UPDATED_AT
RUN set -eu; \
    if [ -z "${REPORT_VERSION:-}" ]; then \
        echo "ERROR: 缺少构建参数 REPORT_VERSION（报告版本）" >&2; \
        echo "  用法: docker build --build-arg REPORT_VERSION=1.0.0 --build-arg DATA_UPDATED_AT=2026-02-05 ..." >&2; \
        exit 1; \
    fi; \
    if [ -z "${DATA_UPDATED_AT:-}" ]; then \
        echo "ERROR: 缺少构建参数 DATA_UPDATED_AT（数据更新时间）" >&2; \
        echo "  用法: docker build --build-arg REPORT_VERSION=1.0.0 --build-arg DATA_UPDATED_AT=2026-02-05 ..." >&2; \
        exit 1; \
    fi; \
    case "${REPORT_VERSION}${DATA_UPDATED_AT}" in \
        *\"*|*\\*|*\'*) \
            echo "ERROR: 构建参数包含非法字符（引号或反斜杠）" >&2; \
            exit 1 ;; \
    esac; \
    printf '// 由 Docker 构建期生成，请勿手动修改\nwindow.BUILD_INFO = {\n    reportVersion: "%s",\n    dataUpdatedAt: "%s"\n};\n' \
        "${REPORT_VERSION}" "${DATA_UPDATED_AT}" > /usr/share/nginx/html/js/build-info.js; \
    echo ">> 构建信息已注入: reportVersion=${REPORT_VERSION}, dataUpdatedAt=${DATA_UPDATED_AT}"

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD wget -q --spider http://localhost:80 || exit 1

CMD ["nginx", "-g", "daemon off;"]
