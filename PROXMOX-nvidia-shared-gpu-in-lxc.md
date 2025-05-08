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

2.  **Update Package Lists and Upgrade and Install gcc, make for Dependencies**
    ```bash
    # Inside LXC Container (as root)
    apt update && apt upgrade -y
    apt install gcc
    apt install make
    ```

3.  **Download the Same NVIDIA Driver Version as on the Host:**
    Ensure you download the *exact same* driver version that was installed on the PVE host.
    ```bash
    # Inside LXC Container (as root)
    # Replace with the actual downloaded filename matching the host's driver
    wget https://us.download.nvidia.com/XFree86/Linux-x86_64/YOUR_DRIVER_VERSION/NVIDIA-Linux-x86_64-YOUR_DRIVER_VERSION.run
    ```

4.  **Make the Installer Executable and Run It (User-Space Only):**
    ```bash
    # Inside LXC Container (as root)
    chmod +x ./NVIDIA-Linux-x86_64-YOUR_DRIVER_VERSION.run
    ./NVIDIA-Linux-x86_64-YOUR_DRIVER_VERSION.run --no-kernel-module
    ```
    *   `--no-kernel-module`: This is **critical**. It tells the installer to only install the user-space libraries and tools, not to attempt to build or install kernel modules (which are already provided by the host).
    *   During installation, answer YES to installing 32-bit compatibility libraries if prompted and desired.

5.  **Verify Driver Access Inside the Container:**
    ```bash
    # Inside LXC Container (as root)
    nvidia-smi
    ```
    If successful, you should see the same `nvidia-smi` output as on the host, indicating the container can communicate with the GPU.

---

### Step 4: Install NVIDIA Container Toolkit for Docker

To allow Docker containers to utilize the NVIDIA GPU, the NVIDIA Container Toolkit is required. Older methods (`nvidia-docker2`) are deprecated.

1.  **Deprecated Methods (For Reference - Do Not Use):**
    ```
    ## Deprecated ##
    # distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
    # curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | apt-key add -
    # curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | tee /etc/apt/sources.list.d/nvidia-docker.list
    # apt update && apt install -y nvidia-docker2
    # systemctl restart docker
    #
    # ALSO DEPRECATED PACKAGES:
    # libnvidia-container1
    # libnvidia-container-tools
    ## DEPRECATED ##
    ```

2.  **Install NVIDIA Container Toolkit (Current Method as of May 2025):**
    Source: `https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html`
    ```bash
    # Inside LXC Container (as root)
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
    && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

    # The official docs might include enabling experimental packages if needed.
    # The original notes included this, uncomment if stable doesn't work or if a feature is needed:
    # sed -i -e '/experimental/ s/^#//g' /etc/apt/sources.list.d/nvidia-container-toolkit.list
    
    sudo apt-get update
    sudo apt-get install -y nvidia-container-toolkit
    ```

3.  **Configure Docker to Use NVIDIA Runtime (Often automatic with `nvidia-container-toolkit`):**
    The toolkit typically configures Docker automatically. If not, you might need to edit `/etc/docker/daemon.json` and ensure the NVIDIA runtime is set as default or available, then restart Docker:
    ```json
    // Example /etc/docker/daemon.json
    // {
    //     "default-runtime": "nvidia",
    //     "runtimes": {
    //         "nvidia": {
    //             "path": "nvidia-container-runtime",
    //             "runtimeArgs": []
    //         }
    //     }
    // }
    ```
    Then `sudo systemctl restart docker`.

---

### Step 5: Final Verification

After all installations and configurations:

1.  **Check `nvidia-smi` inside the LXC container again:**
    ```bash
    # Inside LXC Container
    nvidia-smi
    ```
    Output should be similar to:
    ```
    dustin@plex:~$ nvidia-smi
    Thu May  8 00:09:49 2025       
    +-----------------------------------------------------------------------------------------+
    | NVIDIA-SMI 570.144                Driver Version: 570.144        CUDA Version: 12.8     |
    |-----------------------------------------+------------------------+----------------------+
    | GPU  Name                 Persistence-M | Bus-Id          Disp.A | Volatile Uncorr. ECC |
    | Fan  Temp   Perf          Pwr:Usage/Cap |           Memory-Usage | GPU-Util  Compute M. |
    |                                         |                        |               MIG M. |
    |=========================================+========================+======================|
    |   0  NVIDIA GeForce RTX 3060        Off |   00000000:D8:00.0 Off |                  N/A |
    |  0%   59C    P0             33W /  170W |       0MiB /  12288MiB |      3%      Default |
    |                                         |                        |                  N/A |
    +-----------------------------------------+------------------------+----------------------+
                                                                                           
    +-----------------------------------------------------------------------------------------+
    | Processes:                                                                              |
    |  GPU   GI   CI              PID   Type   Process name                        GPU Memory |
    |        ID   ID                                                               Usage      |
    |=========================================================================================|
    |  No running processes found                                                             |
    +-----------------------------------------------------------------------------------------+
    dustin@plex:~$ 
    ```

2.  **Test a Docker container with GPU access:**
    ```bash
    # Inside LXC Container
    docker run --rm --gpus all nvidia/cuda:12.5.0-base-ubuntu22.04 nvidia-smi
    # Replace 12.5.0-base-ubuntu22.04 with a relevant CUDA image.
    ```
    This command should pull a CUDA-enabled Docker image and run `nvidia-smi` inside it, demonstrating that Docker containers can now access the GPU.

**Conclusion:**
With these steps, the NVIDIA GPU is successfully passed through from the Proxmox VE host to an LXC container, and the NVIDIA Container Toolkit is installed, enabling Docker containers within the LXC to leverage GPU acceleration. This setup is significantly more resource-efficient than using a full VM for GPU-accelerated Docker workloads.

---
