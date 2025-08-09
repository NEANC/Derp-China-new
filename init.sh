#!/usr/bin/env sh

# 1. 在后台启动 tailscaled 守护进程
echo "Starting tailscaled..."
/usr/sbin/tailscaled --state=/var/lib/tailscale/tailscaled.state --socket=/var/run/tailscale/tailscaled.sock &> /var/lib/tailscale/tailscaled_initial.log &

# 2. 等待 tailscaled 的 socket 文件创建成功
echo "Waiting for tailscaled socket..."
while [ ! -e /var/run/tailscale/tailscaled.sock ]; do
    sleep 1
done
echo "Tailscaled socket is ready."

# 3. 执行 tailscale up，将其加入网络
echo "Bringing tailscale up..."
/usr/bin/tailscale --socket=/var/run/tailscale/tailscaled.sock up \
    --accept-routes=true \
    --accept-dns=true \
    --auth-key "${TAILSCALE_AUTH_KEY}" \
    &> /var/lib/tailscale/tailscale_onboard.log

# 检查 'tailscale up' 是否成功
if [ $? -ne 0 ]; then
    echo "!!! 'tailscale up' command failed. See log below for details."
    cat /var/lib/tailscale/tailscale_onboard.log
    exit 1
fi
echo "'tailscale up' command succeeded."

# 4. 只有在以上步骤全部成功后，才启动 derper 服务器
echo "Starting derper server..."
/usr/local/bin/derper \
    --hostname="$TAILSCALE_DERP_HOSTNAME" \
    --a="$TAILSCALE_DERP_ADDR" \
    --stun-port="$TAILSCALE_DERP_STUN_PORT" \
    --verify-clients="$TAILSCALE_DERP_VERIFY_CLIENTS"
