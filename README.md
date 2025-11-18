# VMware Workstation Auto-Signer for Linux Secure Boot

This tool solves the issue where VMware Workstation modules (`vmmon`, `vmnet`) fail to load on Linux systems with Secure Boot enabled, particularly after Kernel updates.

It creates a systemd service that runs **once at boot**, checks if the modules for the current kernel are compiled/signed, and if not, recompiles them, signs them with your MOK (Machine Owner Key), and loads them before the VMware service starts.

## Prerequisites

* Ubuntu/Debian based system (Scripts use `apt`).
* VMware Workstation Pro/Player installed.
* Secure Boot enabled (otherwise you don't need this).

## Installation

1.  Clone this repository:

    ```bash
    git clone [https://github.com/chriv/vmws_module_rebuilder](https://github.com/chriv/vmws_module_rebuilder)
    cd vmws_module_rebuilder
    ```

2.  Run the setup script as root:

    ```bash
    sudo ./setup.sh
    ```

3.  **Follow the on-screen prompts.**

    * If you do not have MOK keys, the script will generate them and ask you to set a password for enrollment.
    * **IMPORTANT:** If keys were generated, you must **REBOOT**.
    * Upon reboot, you will see a blue "MOK Management" screen. Select **Enroll MOK**, view the key, continue, and enter the password you just set.

## How it works

1.  **Configuration:** Stores settings in `/etc/vmware-rebuild/vmware-rebuild.conf`.
2.  **Keys:** Stores keys in `/etc/vmware-rebuild/` (restricted to root).
3.  **Service:** A systemd unit `vmware-modules-rebuild.service` runs before `vmware.service`.
4.  **Script:** `/usr/local/bin/vmware-rebuild-sign.sh` compiles the modules using `vmware-modconfig`, signs them using the kernel headers script, and loads them.

## Updating Dependencies

The setup script installs `linux-headers-generic`, which is a metapackage. This ensures that when you run `apt upgrade` and get a new kernel, you also automatically get the matching headers required for signing.
