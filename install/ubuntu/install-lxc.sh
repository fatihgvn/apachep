#!/bin/bash
# install-lxc.sh
# This script is designed for Ubuntu and Debian-based systems to install LXC, create an "apachep" container,
# retrieve its dynamically assigned IP address, set it as static, and then download a bash script from GitHub.
# The downloaded script will have its placeholders replaced with actual values.

# 1. Check for root/sudo privileges
if [ "$EUID" -ne 0 ]; then
  echo "This script must be run as root/sudo." >&2
  exit 1
fi

# 2. Check if LXC is installed; if not, install it.
if ! command -v lxc-ls >/dev/null 2>&1; then
  echo "LXC is not installed. Starting LXC installation..."
  apt-get update
  apt-get install -y lxc
  if [ $? -ne 0 ]; then
    echo "LXC installation failed." >&2
    exit 1
  fi
else
  echo "LXC is already installed."
fi

# 3. Check if a container named "apachep" already exists.
if lxc-ls --fancy | awk '{print $1}' | grep -wq "^apachep$"; then
  echo "Error: A container named 'apachep' already exists." >&2
  exit 1
fi

# 4. Create the "apachep" container.
echo "Creating the 'apachep' container..."
lxc-create -n apachep -t download -- -d ubuntu -r focal -a amd64
if [ $? -ne 0 ]; then
  echo "Failed to create the container." >&2
  exit 1
fi

# 5. Start the container and wait for its dynamically assigned IP address.
echo "Starting the 'apachep' container..."
lxc-start -n apachep -d

echo "Attempting to retrieve the container's IP address..."
ip_address=""
# Try for up to 10 attempts, waiting 2 seconds between attempts.
for i in {1..10}; do
  ip_address=$(lxc-info -n apachep | grep -m 1 "IP:" | awk '{print $2}')
  if [ -n "$ip_address" ] && [ "$ip_address" != "-" ]; then
    break
  fi
  sleep 2
done

if [ -z "$ip_address" ] || [ "$ip_address" = "-" ]; then
  echo "Error: Failed to retrieve the container's IP address." >&2
  exit 1
fi

echo "The container has obtained the dynamic IP address: $ip_address"

# 6. Stop the container to apply static IP configuration.
lxc-stop -n apachep

# 7. Add static IP settings to the container's configuration file.
config_file="/var/lib/lxc/apachep/config"
if [ ! -f "$config_file" ]; then
  echo "Error: Container config file not found: $config_file" >&2
  exit 1
fi

{
  echo ""
  echo "# Static IP configuration added by install-lxc.sh"
  echo "lxc.net.0.ipv4.address = ${ip_address}/24"
  echo "lxc.net.0.ipv4.gateway = 10.0.3.1"
} >> "$config_file"

echo "The container's IP address ($ip_address) has been configured as static."

# 8. Download a bash script from GitHub to the active user's home directory,
#    replace placeholders with actual values, and set it as executable.
if [ -n "$SUDO_USER" ]; then
  user_home=$(eval echo "~$SUDO_USER")
  user_name="$SUDO_USER"
else
  user_home="$HOME"
  user_name="$(whoami)"
fi

# Set container domain (default value, adjust as needed)
container_domain="hdn"

# Update the URL below with the actual GitHub script URL.
script_url="https://raw.githubusercontent.com/fatihgvn/apachep/main/install/ubuntu/start-apachep"
destination="$user_home/$(basename "$script_url")"

echo "Downloading bash script from: $script_url to $destination"
wget -qO "$destination" "$script_url"
if [ $? -ne 0 ]; then
  echo "Error: Failed to download the script from: $script_url" >&2
  exit 1
fi

# Replace placeholders in the downloaded script with actual values
sed -i "s|{{container_ip}}|$ip_address|g" "$destination"
sed -i "s|{{container_domain}}|$container_domain|g" "$destination"
sed -i "s|{{user}}|$user_name|g" "$destination"

chmod +x "$destination"
echo "Script downloaded, placeholders replaced, and set as executable: $destination"

# 9. Start the container again.
lxc-start -n apachep

# 10. Wait for the container to start running.
echo "Waiting for container to start..."
while [ "$(lxc-info -n apachep -s | awk '{print $2}')" != "RUNNING" ]; do
    sleep 1
done

# 11. Attach to the container and execute installation commands.
echo "Attaching to the container and executing installation commands..."
lxc-attach -n apachep -- bash -c "\
  apt update && \
  apt install -y git wget software-properties-common && \
  wget -qO /tmp/install-ubuntu.sh https://raw.githubusercontent.com/fatihgvn/apachep/main/install/install-ubuntu.sh && \
  bash /tmp/install-ubuntu.sh $params
"

echo "Installation commands executed inside the container."