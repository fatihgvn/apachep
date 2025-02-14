#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "This script must be run as root/sudo." >&2
  exit 1
fi

if [ -f /etc/os-release ]; then
  . /etc/os-release
  echo "Distribution: $NAME, Version: $VERSION"
else
  echo "Your Linux distribution does not support /etc/os-release. Cannot determine distro." >&2
  exit 1
fi

# Process parameters: parse --with-lxc and --domain options.
with_lxc=false
container_domain="hdn"  # Default domain is "hdn"
other_params=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --with-lxc)
      with_lxc=true
      shift
      ;;
    --domain)
      if [ -n "$2" ]; then
        container_domain="$2"
        # Add both --domain and its value to other_params
        other_params+=("$1" "$2")
        shift 2
      else
        echo "Error: --domain option requires a value." >&2
        exit 1
      fi
      ;;
    *)
      other_params+=("$1")
      shift
      ;;
  esac
done

params="${other_params[@]}"

echo "Specified domain: $container_domain"
echo "Other parameters: $params"

case "$ID" in
  ubuntu|debian)
    echo "Ubuntu/Debian based distribution detected."

    if [ "$with_lxc" = true ]; then
        echo "--with-lxc option detected. Additional LXC installation steps can be executed."
        wget -q https://raw.githubusercontent.com/fatihgvn/apachep/main/install/ubuntu/install-lxc.sh -O /tmp/install-lxc.sh
        bash /tmp/install-lxc.sh $params
    else
        echo "--with-lxc option not detected."
        wget -q /tmp/install-ubuntu.sh https://raw.githubusercontent.com/fatihgvn/apachep/main/install/install-ubuntu.sh -O /tmp/install-ubuntu.sh
        bash /tmp/install-ubuntu.sh $params
    fi
    ;;
  centos|fedora|rhel)
    echo "CentOS/Fedora/RHEL based distribution detected."
    # todo: create install bash script for centos/fedora/rhel
    ;;
  *)
    echo "Unknown or unsupported distribution: $ID" >&2
    exit 1
    ;;
esac
