# =========================================================================
#  第一阶段: 构建器 (Builder)
#  我们使用一个完整的 Go 开发环境镜像 (golang:latest) 来编译程序。
# =========================================================================
FROM golang:latest AS builder

# 设置 Go 代理以加速国内的模块下载。
ENV GOPROXY="https://goproxy.cn"

# 设置工作目录。
WORKDIR /src

# 初始化 Go 模块并下载 derper 源代码。
# `go get` 会将源代码和依赖项下载到模块缓存中。
RUN go mod init builder && \
    go get tailscale.com/cmd/derper@main

# --- 核心编译步骤 ---
# 使用 `CGO_ENABLED=0` 来构建一个完全静态链接的二进制文件。
# 这至关重要，因为它确保编译出的程序不依赖任何外部系统库 (如 glibc)。
# 这样，程序就能在任何 Linux 环境（包括使用 musl 库的 Alpine）中独立运行。
# 我们使用 `-o /derper` 参数，明确地将编译结果输出到根目录下的 `derper` 文件。
RUN CGO_ENABLED=0 go build -o /derper tailscale.com/cmd/derper


# =========================================================================
#  第二阶段: 最终运行镜像 (Final Image)
#  我们使用一个极致轻量的 Alpine 镜像作为最终运行环境。
#  这大大减小了最终镜像的体积，并提高了安全性。
# =========================================================================
FROM alpine:latest

# 更新 Alpine 的软件包仓库地址为阿里云镜像，以提高下载速度。
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories

# 安装运行 derper 和 tailscale 所必需的软件包。
# - iptables: tailscale 需要它来管理网络规则。
# - ca-certificates: derper 作为 HTTPS 服务器，需要系统的根证书来验证客户端证书。
# - tailscale: 从 Alpine 的 edge 仓库安装最新的 tailscale 客户端。
RUN apk add --no-cache iptables ca-certificates \
    tailscale --repository=https://mirrors.aliyun.com/alpine/edge/community

# 从第一阶段 (builder) 中，将我们编译好的、可独立运行的 derper 程序复制过来。
# 我们将它放在 `/usr/local/bin` 目录下，这是存放自定义程序的标准位置。
COPY --from=builder /derper /usr/local/bin/derper

# 复制自定义的初始化脚本到容器中。
COPY init.sh /init.sh
# 赋予该脚本执行权限。
RUN chmod +x /init.sh

# 暴露 derper 服务需要的端口。
# - 444/tcp: 用于 DERP 的 HTTPS 流量。
# - 3478/udp: 用于 STUN 服务，帮助客户端进行 NAT 穿透。
EXPOSE 444/tcp
EXPOSE 3478/udp

# 设置容器的入口点。当容器启动时，会自动执行这个脚本。
ENTRYPOINT ["/init.sh"]
