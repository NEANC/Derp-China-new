# ---- STAGE 1: The Builder ----
FROM golang:latest AS builder

WORKDIR /src

# 下载 derper 的源代码
RUN go mod init builder && \
    go get tailscale.com/cmd/derper@main

# 使用 CGO_ENABLED=0 来构建一个完全静态链接的二进制文件
# 这个文件不依赖任何外部库，可以在任何 Linux 内核上运行，包括 Alpine
RUN CGO_ENABLED=0 go build -o /derper tailscale.com/cmd/derper


# ---- STAGE 2: The Final Image ----
FROM debian:bookworm-slim

# 安装运行时依赖
# ca-certificates 对于 derper 进行 TLS 通信至关重要
RUN apt-get update && apt-get install -y --no-install-recommends \
    iptables ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

# 安装最新版本的 Tailscale
RUN curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.noarmor.gpg | tee /usr/share/keyrings/tailscale-archive-keyring.gpg > /dev/null && \
    curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.tailscale-keyring.list | tee /etc/apt/sources.list.d/tailscale.list && \
    apt-get update && apt-get install -y --no-install-recommends tailscale \
    && rm -rf /var/lib/apt/lists/*

# 从 builder 阶段复制我们编译好的、可独立运行的静态二进制文件
COPY --from=builder /derper /usr/local/bin/derper

# 复制初始化脚本并设置执行权限
COPY init.sh /init.sh
RUN chmod +x /init.sh

# 暴露端口
EXPOSE 444/tcp
EXPOSE 3478/udp

# 设置入口点
ENTRYPOINT ["/init.sh"]
