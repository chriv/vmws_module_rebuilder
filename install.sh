#!/bin/bash
set -e

# Configuration
CONFIG_DIR="/etc/vmware-rebuild"
BIN_DIR="/usr/local/bin"
SERVICE_DIR="/etc/systemd/system"

# Check for root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

echo "=== VMware Secure Boot Auto-Signer Setup ==="

# 1. Install Dependencies
echo "[+] Installing build dependencies..."
# 'linux-headers-generic' ensures we always get headers for the latest kernel update
apt-get update
apt-get install -y build-essential linux-headers-generic mokutil openssl

# 2. Create Directory Structure
echo "[+] Creating configuration directory at $CONFIG_DIR..."
mkdir -p "$CONFIG_DIR"

# 3. Handle MOK Keys
PRIV_KEY="$CONFIG_DIR/MOK.priv"
DER_KEY="$CONFIG_DIR/MOK.der"

if [ -f "$PRIV_KEY" ] && [ -f "$DER_KEY" ]; then
    echo "[*] Existing MOK keys found in $CONFIG_DIR. Skipping generation."
else
    echo "[+] Generating new MOK keys..."
    
    # specific configuration for module signing key
    cat <<EOF > "$CONFIG_DIR/openssl.cnf"
[ req ]
default_bits = 4096
distinguished_name = req_distinguished_name
prompt = no
string_mask = utf8only
x509_extensions = myexts

[ req_distinguished_name ]
O = VMware Rebuild Service
CN = VMware Rebuild MOK

[ myexts ]
basicConstraints=critical,CA:FALSE
keyUsage=digitalSignature
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid
EOF

    openssl req -x509 -new -nodes -utf8 -sha256 -days 36500 \
        -batch -config "$CONFIG_DIR/openssl.cnf" \
        -outform DER -out "$DER_KEY" \
        -keyout "$PRIV_KEY" 
    
    chmod 600 "$PRIV_KEY"
    rm "$CONFIG_DIR/openssl.cnf"
    
    echo "[!] IMPORTANT: You must import this key into your BIOS/Shim."
    echo "[!] The system will ask for a password. Remember it for the reboot."
    echo "    Running: mokutil --import $DER_KEY"
    mokutil --import "$DER_KEY"
fi

# 4. Install Configuration File
echo "[+] Installing configuration file..."
# We don't overwrite if it exists to preserve user settings
if [ ! -f "$CONFIG_DIR/vmware-rebuild.conf" ]; then
    cp vmware-rebuild.conf "$CONFIG_DIR/vmware-rebuild.conf"
else
    echo "[*] Config file exists. Skipping copy."
fi

# 5. Install Main Script
echo "[+] Installing rebuild script to $BIN_DIR..."
cp vmware-rebuild-sign.sh "$BIN_DIR/vmware-rebuild-sign.sh"
chmod +x "$BIN_DIR/vmware-rebuild-sign.sh"

# 6. Install Service
echo "[+] Installing Systemd service..."
cp vmware-modules-rebuild.service "$SERVICE_DIR/vmware-modules-rebuild.service"
systemctl daemon-reload
systemctl enable vmware-modules-rebuild.service

echo "=== Setup Complete ==="
echo "1. If you just generated a new key, REBOOT NOW."
echo "2. On boot, select 'Enroll MOK', 'Continue', 'Yes', and enter your password."
echo "3. If keys were already set up, you can test the service with:"
echo "   systemctl start vmware-modules-rebuild.service"
