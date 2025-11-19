#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status

# 1. Set working directory to where your keys are located
cd /root

# 2. define variables
KERN_VER=$(uname -r)
VMWARE_MODULE_DIR="/lib/modules/$KERN_VER/misc"
SIGN_SCRIPT="/usr/src/linux-headers-$KERN_VER/scripts/sign-file"

echo "Starting vmmon and vmnet modules rebuild for kernel $KERN_VER..."

# 3. Recompile modules
# --install-all compiles and installs the modules to the directory defined above
# We append '|| true' because this command attempts to start services immediately
# after compilation. Since modules aren't signed yet, service launch fails.
# We ignore this specific error to proceed to signing.
/usr/bin/vmware-modconfig --console --install-all || true

# 4. Sign the modules
# We verify the signing script exists first to avoid vague errors if headers are missing
if [ -f "$SIGN_SCRIPT" ]; then
    # SAFETY CHECK: verify compilation actually created the file before signing
    if [ ! -f "$VMWARE_MODULE_DIR/vmmon.ko" ]; then
        echo "ERROR: vmmon.ko was not found at $VMWARE_MODULE_DIR. Compilation likely failed completely."
        exit 1
    fi
    if [ ! -f "$VMWARE_MODULE_DIR/vmnet.ko" ]; then
        echo "ERROR: vmnet.ko was not found at $VMWARE_MODULE_DIR. Compilation likely failed completely."
        exit 1
    fi

    echo "Signing vmmon..."
    "$SIGN_SCRIPT" sha256 MOK.priv MOK.der "$VMWARE_MODULE_DIR/vmmon.ko"
    
    echo "Signing vmnet..."
    "$SIGN_SCRIPT" sha256 MOK.priv MOK.der "$VMWARE_MODULE_DIR/vmnet.ko"
else
    echo "ERROR: Signing script not found at $SIGN_SCRIPT. Are linux-headers installed?"
    exit 1
fi

# 5. Load the modules explicitly
echo "Loading modules..."
modprobe vmmon
modprobe vmnet

echo "vmmon and vmnet modules rebuild and sign complete."
