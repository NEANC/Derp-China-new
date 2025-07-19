# ---- STAGE 1: The Builder ----
FROM golang:latest AS builder

ENV GOPROXY="https://goproxy.cn"
WORKDIR /src

# 下载 derper 的源代码
RUN go mod init builder && \
    go get tailscale.com/cmd/derper@latest

# 使用 CGO_ENABLED=0 来构建一个完全静态链接的二进制文件
# 这个文件不依赖任何外部库，可以在任何 Linux 内核上运行，包括 Alpine
RUN CGO_ENABLED=0 go build -o /derper tailscale.com/cmd/derper


# ---- STAGE 2: The Final Image ----
FROM alpine:latest

# 更新 Alpine 包仓库为阿里云镜像
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories

# 安装运行时依赖
# ca-certificates 对于 derper 进行 TLS 通信至关重要
RUN apk add --no-cache iptables ca-certificates \
    tailscale --repository=https://mirrors.aliyun.com/alpine/edge/community

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
