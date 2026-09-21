# ==============================================================================
# 佳贝艾特会员诊断驾驶舱 - 前端展示镜像
#
# 设计说明：
#   - 基础镜像固定版本（多架构 manifest，按目标平台自动匹配 ARM/X86），
#     静态文件原样复制，镜像内容仅取决于构建参数 => 相同参数可重复构建出一致镜像
#   - 构建期注入报告版本 (REPORT_VERSION) 与数据更新时间 (DATA_UPDATED_AT)，
#     注入结果写入 js/build-info.js，容器重启后页面行为与本机一致
#   - 构建参数缺失或格式错误时明确报错并停止
#
# 构建示例：
#   docker buildx build --platform linux/amd64,linux/arm64 \
#       --build-arg REPORT_VERSION=1.0.0 \
#       --build-arg DATA_UPDATED_AT=2026-09-21 \
#       -t jiabei-dashboard:1.0.0 ./frontend-user
# ==============================================================================

# 固定基础镜像版本，保证可重复构建（不要使用浮动 tag，如 nginx:alpine）
FROM nginx:1.27.4-alpine

# nginx 配置（变更频率低，前置以复用构建缓存）
COPY nginx.conf /etc/nginx/conf.d/default.conf

# 静态文件：与本地直接打开保持同一目录结构（index.html + css/ + js/）
COPY index.html /usr/share/nginx/html/index.html
COPY css /usr/share/nginx/html/css
COPY js /usr/share/nginx/html/js

# ---- 构建参数（必填）：报告版本与数据更新时间 ----
ARG REPORT_VERSION
ARG DATA_UPDATED_AT

# 参数校验 + 构建期注入：生成 js/build-info.js 覆盖仓库中的本地开发默认值
RUN set -eu; \
    if [ -z "$REPORT_VERSION" ]; then \
        echo "ERROR: 缺少构建参数 REPORT_VERSION，请使用 --build-arg REPORT_VERSION=<版本号>" >&2; \
        exit 1; \
    fi; \
    if [ -z "$DATA_UPDATED_AT" ]; then \
        echo "ERROR: 缺少构建参数 DATA_UPDATED_AT，请使用 --build-arg DATA_UPDATED_AT=<YYYY-MM-DD>" >&2; \
        exit 1; \
    fi; \
    if ! echo "$DATA_UPDATED_AT" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then \
        echo "ERROR: DATA_UPDATED_AT 格式应为 YYYY-MM-DD，当前值: $DATA_UPDATED_AT" >&2; \
        exit 1; \
    fi; \
    printf '// 由镜像构建生成，请勿手工修改\nwindow.__BUILD_INFO__ = {\n    reportVersion: "%s",\n    dataUpdatedAt: "%s"\n};\n' \
        "$REPORT_VERSION" "$DATA_UPDATED_AT" \
        > /usr/share/nginx/html/js/build-info.js

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
