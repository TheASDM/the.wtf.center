## Homelab Journal Entry: NVIDIA GPU Passthrough to an LXC Container for Docker

**Date:** May 7-8, 2025

**Objective:** Configure an NVIDIA GPU for use within a Proxmox VE LXC container, specifically to enable GPU acceleration for Docker workloads (e.g., Plex transcoding, AI/ML tasks).

**Context & Challenges:**
While AI tools like ChatGPT are useful for general guidance, their package and repository suggestions can sometimes be outdated or not directly applicable to specific, rapidly evolving environments like NVIDIA drivers and toolkits. This guide consolidates information from AI suggestions with current official NVIDIA documentation and practical experience as of May 2025.

---

### Step 1: Install NVIDIA Drivers on the Proxmox VE Host

The host system needs the correct NVIDIA drivers installed first.

1.  **Prepare the Host for Driver Installation:**
    Ensure kernel headers and build tools are installed.
    ```bash
    # On PVE Host (as root)
    apt update && apt install -y pve-headers-$(uname -r) build-essential
    ```

2.  **Download the Latest NVIDIA Driver:**
    Visit the official NVIDIA UNIX driver page to get the link for the most recent driver:
    *   URL: `https://www.nvidia.com/en-us/drivers/unix/`
    *   Download the appropriate driver file (e.g., `NVIDIA-Linux-x86_64-XXX.YY.run`).
    ```bash
    # On PVE Host (as root)
    # Replace with the actual downloaded filename
    wget https://us.download.nvidia.com/XFree86/Linux-x86_64/YOUR_DRIVER_VERSION/NVIDIA-Linux-x86_64-YOUR_DRIVER_VERSION.run
    ```

3.  **Make the Driver Installer Executable and Run It:**
    ```bash
    # On PVE Host (as root)
    chmod +x ./NVIDIA-Linux-x86_64-YOUR_DRIVER_VERSION.run
    ./NVIDIA-Linux-x86_64-YOUR_DRIVER_VERSION.run --dkms
    ```
    *   `--dkms`: This flag ensures the NVIDIA kernel modules are automatically rebuilt if the PVE kernel is updated.

4.  **During the NVIDIA Driver Installation:**
    *   **DKMS Registration:** Say YES.
    *   **32-bit Compatibility Libraries:** Say YES if you might need them (generally safe to include).
    *   **X configuration file:** I allowed it to write/update the X configuration file (e.g., `/etc/X11/xorg.conf`), even though a headless PVE server doesn't typically use a graphical X session. This is generally harmless.

5.  **Reboot the Proxmox VE Host:**
    ```bash
    # On PVE Host (as root)
    reboot
    ```

6.  **Verify Driver Installation on Host:**
    After reboot, check if the NVIDIA driver is loaded and the GPU is recognized:
    ```bash
    # On PVE Host (as root)
    nvidia-smi
    ```
    You should see output detailing your NVIDIA GPU(s) and driver version.

---

### Step 2: Prepare the LXC Container Configuration on the Host

Modify the LXC container's configuration file to allow access to the NVIDIA devices.

1.  **Edit the Container Configuration File:**
    Replace `<CTID>` with the actual ID of your LXC container.
    ```bash
    # On PVE Host (as root)
    nano /etc/pve/lxc/<CTID>.conf
    ```

2.  **Add GPU Passthrough and Nesting Lines:**
    Append the following lines to the configuration file:
    ```conf
    # Enable nesting, often required for Docker inside LXC
    features: nesting=1

    # Allow access to NVIDIA character devices
    # Note: cgroup v1 syntax. For cgroup v2, syntax is different (lxc.cgroup2.devices.allow)
    # PVE 7.x typically uses cgroup2 by default for new containers, PVE 6.x used cgroup v1.
    # Assuming PVE 7.x with cgroup2, the following would be more appropriate:
    # lxc.cgroup2.devices.allow: c 195:* rwm
    # lxc.cgroup2.devices.allow: c 243:* rwm
    # However, the provided config uses cgroup v1 syntax. If issues arise, check PVE cgroup version.
    # For this example, sticking to the provided:
    lxc.cgroup.devices.allow: c 195:* rwm  # NVIDIA devices
    lxc.cgroup.devices.allow: c 243:* rwm  # NVIDIA NVSwitch devices (may not be present/needed for all GPUs)

    # Mount NVIDIA device nodes into the container
    lxc.mount.entry: /dev/nvidia0 dev/nvidia0 none bind,optional,create=file
    lxc.mount.entry: /dev/nvidiactl dev/nvidiactl none bind,optional,create=file
    lxc.mount.entry: /dev/nvidia-uvm dev/nvidia-uvm none bind,optional,create=file
    lxc.mount.entry: /dev/nvidia-uvm-tools dev/nvidia-uvm-tools none bind,optional,create=file
    # If you have more GPUs, add entries for /dev/nvidia1, /dev/nvidia2, etc.
    ```
    *   *Self-correction/Note for future:* The provided `lxc.cgroup.devices.allow` lines are for `cgroup v1`. If Proxmox VE is using `cgroup v2` (common in newer versions), the syntax would be `lxc.cgroup2.devices.allow: ...`. The duplication of `c 195:* rwm` was likely a typo and one is sufficient. `c 243:* rwm` might be for NVSwitch, which isn't present on consumer GPUs. If problems occur, review device major numbers (`ls -l /dev/nvidia*` on host).

3.  **Restart the LXC Container:**
    Apply the configuration changes by restarting the container.
    ```bash
    # On PVE Host (as root)
    pct reboot <CTID>
    # Or pct stop <CTID> followed by pct start <CTID>
    ```

---

### Step 3: Install NVIDIA Drivers (User-Space Components) Inside the LXC Container

The container needs the user-space components of the NVIDIA driver that match the version installed on the PVE host. **Do not install the kernel module inside the container.**

1.  **Log into the LXC Container:**
    ```bash
    # On PVE Host
    pct enter <CTID>
    # (Performed as root within the container for this setup)
    ```

2.  **Update Package Lists and Upgrade:**
    ```bash
    # Inside LXC Container (as root)
    apt update &&
