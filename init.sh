#!/usr/bin/env sh

# 开启 shell 的调试模式，如果任何命令失败，脚本会立即退出。
set -e

# 在后台启动 tailscaled 守护进程。
# --state=/var/lib/tailscale/tailscaled.state 指定了状态文件的存储位置。
# `&>` 将标准输出和错误输出都重定向到日志文件，以便排错。
# `&` 使命令在后台运行。
echo "Starting tailscaled..."
/usr/sbin/tailscaled --state=/var/lib/tailscale/tailscaled.state &> /var/lib/tailscale/tailscaled_initial.log &

# 等待几秒钟，确保 tailscaled 已经完全启动并准备就绪。
sleep 5

# 使用 tailscale up 命令将此容器加入到您的 Tailscale 网络。
# --accept-routes=true: 接受其他节点推送的路由。
# --accept-dns=true: 使用 Tailscale 的 MagicDNS。
# --auth-key=$TAILSCALE_AUTH_KEY: 使用从环境变量传入的授权密钥进行自动认证。
# `&>` 将输出重定向到日志文件。
# `&` 使命令在后台运行。
echo "Running tailscale up..."
/usr/bin/tailscale up --accept-routes=true --accept-dns=true --auth-key=$TAILSCALE_AUTH_KEY &> /var/lib/tailscale/tailscale_onboard.log &

# 再次等待，确保已经成功加入网络。
sleep 5

# --- 启动 Tailscale DERP 服务器 ---
# 这是脚本的最后一个命令，它会在前台运行，保持容器不退出。
# 我们使用 `/usr/local/bin/derper` 这个绝对路径来调用程序，这是最可靠的方式。
# 所有参数都从环境变量中获取，这使得配置非常灵活。
# --hostname: 您为 DERP 服务器指定的域名。
# --a: （可选）指定 DERP 服务器监听的地址，留空则监听在所有接口的 443 端口（但在 Docker 中通常由 EXPOSE 和端口映射处理）。
# --stun-port: 指定 STUN 服务的监听端口。
# --verify-clients: 开启客户端验证，这是一个重要的安全功能，确保只有您网络内的设备才能使用此 DERP 服务器。
echo "Starting DERP server..."
/usr/local/bin/derper \
    --hostname="$TAILSCALE_DERP_HOSTNAME" \
    --a="$TAILSCALE_DERP_ADDR" \
    --stun-port="$TAILSCALE_DERP_STUN_PORT" \
    --verify-clients="$TAILSCALE_DERP_VERIFY_CLIENTS"
