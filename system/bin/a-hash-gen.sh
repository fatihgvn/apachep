# Usage: ./sha1gen.sh <folder to scan>
find "$1" -type f -exec sha1sum {} \; > "$1" SHA1checksums.sha1
