#!/bin/bash
set -e 

# Load Configuration
CONFIG_FILE="/etc/vmware-rebuild/vmware-rebuild.conf"

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "ERROR: Config file not found at $CONFIG_FILE"
    exit 1
fi

# Set Dynamic Variables
KERN_VER=$(uname -r)
VMWARE_MODULE_DIR="$VMWARE_MOD_BASE/$KERN_VER/misc"
SIGN_SCRIPT="/usr/src/linux-headers-$KERN_VER/scripts/sign-file"
PRIV_KEY="$KEY_DIR/$PRIV_KEY_NAME"
DER_KEY="$KEY_DIR/$DER_KEY_NAME"

echo "Starting VMware module rebuild for kernel $KERN_VER..."

# Check requirements
if [ ! -f "$SIGN_SCRIPT" ]; then
    echo "ERROR: Signing script not found at $SIGN_SCRIPT. Ensure linux-headers-generic is installed."
    exit 1
fi

if [ ! -f "$PRIV_KEY" ]; then
    echo "ERROR: Private key not found at $PRIV_KEY. Run setup.sh again."
    exit 1
fi

# 1. Recompile modules
# We ignore the error code because service start will fail due to unsigned modules
/usr/bin/vmware-modconfig --console --install-all || true

# 2. Sign the modules
if [ ! -f "$VMWARE_MODULE_DIR/vmmon.ko" ]; then
    echo "ERROR: vmmon.ko was not found. Compilation failed."
    exit 1
fi

echo "Signing vmmon..."
"$SIGN_SCRIPT" sha256 "$PRIV_KEY" "$DER_KEY" "$VMWARE_MODULE_DIR/vmmon.ko"

echo "Signing vmnet..."
"$SIGN_SCRIPT" sha256 "$PRIV_KEY" "$DER_KEY" "$VMWARE_MODULE_DIR/vmnet.ko"

# 3. Load the modules explicitly
echo "Loading modules..."
modprobe vmmon
modprobe vmnet

echo "VMware module rebuild and sign complete."
