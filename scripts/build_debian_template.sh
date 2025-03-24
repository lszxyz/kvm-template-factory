#!/bin/bash
set -e

# 定义变量
VM_NAME="debian-template"
IMAGE_NAME="debian-template.qcow2"
IMAGE_SIZE="64G"
OS_VARIANT="debian12.0"
PACKAGES="openssh-server vim curl wget net-tools sudo"
#时区
TIME_ZONE="Asia/Shanghai"

# 静态 IP 地址配置 (可选)
STATIC_IP="${STATIC_IP:-}"
STATIC_NETMASK="${STATIC_NETMASK:-}"
STATIC_GATEWAY="${STATIC_GATEWAY:-}"
STATIC_DNS="${STATIC_DNS:-}"
INTERFACE="eth0"

# 输出构建信息
echo "开始构建 Debian KVM 虚拟机模板..."
echo "虚拟机名称: $VM_NAME"
echo "镜像名称: $IMAGE_NAME"
echo "镜像大小: $IMAGE_SIZE"
echo "Debian 版本: $OS_VARIANT"
echo "安装软件包: $PACKAGES"
echo "时区: $TIME_ZONE"

if [ -n "$STATIC_IP" ]; then
  echo "静态 IP 地址配置:"
  echo "  IP 地址: $STATIC_IP"
  echo "  子网掩码: $STATIC_NETMASK"
  echo "  网关: $STATIC_GATEWAY"
  echo "  DNS 服务器: $STATIC_DNS"
else
  echo "使用 DHCP 获取 IP 地址"
fi

# 创建临时目录
TMP_DIR=$(mktemp -d)
cd "$TMP_DIR"

# 使用 virt-builder 创建镜像
virt-builder "$OS_VARIANT" \
  --size "$IMAGE_SIZE" \
  --format qcow2 \
  --output "$IMAGE_NAME" \
  --hostname "$VM_NAME" \
  --root-password password:your_default_password \
  --install "$PACKAGES" \
  --timezone "$TIME_ZONE" \
  --update

# 配置网络 (如果提供了静态 IP 地址)
if [ -n "$STATIC_IP" ] && [ -n "$STATIC_NETMASK" ] && [ -n "$STATIC_GATEWAY" ] && [ -n "$STATIC_DNS" ]; then
  echo "配置静态 IP 地址..."
  cat > /tmp/network_config <<EOF
auto $INTERFACE
iface $INTERFACE inet static
  address $STATIC_IP
  netmask $STATIC_NETMASK
  gateway $STATIC_GATEWAY
  dns-nameservers $STATIC_DNS
EOF

  # 将配置写入 /etc/network/interfaces (需要 root 权限)
  virt-customize -a "$IMAGE_NAME" --mkdir /mnt/root
  virt-customize -a "$IMAGE_NAME" --upload /tmp/network_config:/mnt/root/network_config
  virt-customize -a "$IMAGE_NAME" --run-command "mv /mnt/root/network_config /etc/network/interfaces"
  virt-customize -a "$IMAGE_NAME" --run-command "rm -rf /mnt/root"
  # 解决network manager的问题
  virt-customize -a "$IMAGE_NAME" --run-command "sed -i 's/#network/network/g' /etc/NetworkManager/NetworkManager.conf"
fi

# 显示镜像信息
qemu-img info "$IMAGE_NAME"

# 上传镜像到存储 (可以选择上传到云存储，例如 S3)
# 此处示例是将镜像复制到指定目录，你需要根据你的实际情况修改
# 例如使用 scp 上传到 KVM 主机
echo "正在上传镜像..."
# 确保有权限
scp -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no "$IMAGE_NAME" ${SSH_USER}@${KVM_HOST}:/var/lib/libvirt/images/
echo "镜像上传完成。"

# 清理临时目录
cd ..
rm -rf "$TMP_DIR"

echo "Debian KVM 虚拟机模板构建完成！"