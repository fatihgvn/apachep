#!/bin/bash
set -e

# Usage: ./script.sh [domain_extension]
# If no domain extension parameter is provided, the default "hdn" is used.
DOMAIN_EXT="${1:-hdn}"

get_system_ip() {
    hostname -I | awk '{print $1}'
}

# Retrieve the system's IP address
SYSTEM_IP=$(get_system_ip)
if [ -z "$SYSTEM_IP" ]; then
    echo "Failed to retrieve system IP. Exiting."
    exit 1
fi

echo "System IP: $SYSTEM_IP"
echo "Domain extension: .$DOMAIN_EXT"

# 1. Update package lists and install dnsmasq
echo "Updating packages and installing dnsmasq..."
apt-get update
apt-get install -y dnsmasq

# 2. If systemd-resolved is active, stop and disable it
if systemctl is-active --quiet systemd-resolved; then
    echo "systemd-resolved service is active. Stopping and disabling it..."
    systemctl stop systemd-resolved
    systemctl disable systemd-resolved
    # The /etc/resolv.conf file affects the system's DNS settings.
    # If it's a symbolic link, remove it and recreate the file.
    if [ -L /etc/resolv.conf ]; then
        rm /etc/resolv.conf
    fi
    echo "nameserver 8.8.8.8" > /etc/resolv.conf
fi

# 3. Configure dnsmasq
# Set up wildcard redirection based on the specified domain extension (e.g., *.dev or *.local)
DNSMASQ_CONF="/etc/dnsmasq.d/domain.conf"
echo "Configuring dnsmasq: $DNSMASQ_CONF"

cat > "$DNSMASQ_CONF" <<EOF
# Wildcard redirection for all *.${DOMAIN_EXT} domains
local=/${DOMAIN_EXT}/

# Uncomment the following lines if you want to restrict dnsmasq to a specific interface (e.g., eth0):
listen-address=$SYSTEM_IP
interface=eth0
bind-interfaces
EOF

# (Optional) Review the default settings in /etc/dnsmasq.conf for any potential conflicts
# and comment out conflicting lines if necessary.

# 4. Restart the dnsmasq service
echo "Restarting the dnsmasq service..."
systemctl restart dnsmasq

echo "dnsmasq installation and configuration completed. All *.${DOMAIN_EXT} domains are now redirected to $SYSTEM_IP."
