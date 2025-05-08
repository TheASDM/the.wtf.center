## Homelab NFS Setup: NAS to Proxmox VE Host & LXC Container

This document outlines the steps taken to share a directory from a NAS via NFS, mount it on a Proxmox VE (PVE) host, and then make it accessible within a privileged LXC container, ensuring consistent user/group ID (UID/GID) permissions.

**Goal:** Provide an LXC container with direct, permission-consistent access to media files stored on a NAS.

**Key Components & IDs:**
*   **NAS:** Serves files via NFS. Files primarily owned by UID `1000` and GID `1000`.
*   **Proxmox VE (PVE) Host:** Mounts the NFS share. A local user `nasuser` with UID `1000` and GID `1000` exists on PVE for clarity and potential direct interaction with the mount.
*   **LXC Container (Privileged):** Runs applications that need access to the NAS files. A user with UID `1000` and GID `1000` is created inside the container to match file ownership.

---

### Step 1: NAS - NFS Export Configuration

1.  **Identify/Create Data Directory:**
    *   On the NAS, determine or create the directory to be shared (e.g., `/export/media` or `/volume1/media`).
2.  **Ensure File Ownership:**
    *   Ensure the files and directories within this shared folder are owned by the desired UID/GID, which is `1000:1000` in this case.
    ```bash
    # On the NAS (example commands, actual syntax may vary by NAS OS)
    # Assuming 'nas_admin_user' is the user with UID 1000 on the NAS
    sudo chown -R 1000:1000 /export/media
    sudo chmod -R u=rwX,g=rX,o=rX /export/media # Example permissions
    ```
3.  **Configure NFS Export:**
    *   Access your NAS's NFS server settings (e.g., via Web GUI or `/etc/exports` if a standard Linux NFS server).
    *   Create an export for the directory (e.g., `/export/media`).
    *   **Client IP/Hostname:** Specify the IP address of your Proxmox VE host (e.g., `192.168.1.50`).
    *   **Permissions:** `rw` (read-write).
    *   **Squash Options (Crucial for PVE `root` interaction):**
        *   Initially, `root_squash` (default) was likely active, mapping PVE `root` to `nobody` or an anonymous UID. This caused issues with LXC bind mount setup.
        *   **Solution Implemented:** Changed to map all users to admin, or effectively `no_root_squash`. This gives PVE `root` (which performs the bind mount operation) sufficient privileges on the NFS share.
            *   *Alternative (more secure if PVE root squash is kept):* Ensure the anonymous user (`anonuid`/`anongid` defined on NAS) has at least `rx` (read and execute) permissions on the *exported directory itself* on the NAS.
    *   **Other Options:** `sync` (safer for data integrity) or `async` (better performance).
4.  **Apply NFS Export Settings:**
    *   Save changes and restart the NFS service on the NAS if required.
    ```bash
    # On a standard Linux NFS server (example)
    # sudo exportfs -ra
    # sudo systemctl restart nfs-kernel-server
    ```

---

### Step 2: Proxmox VE (PVE) Host - User & NFS Client Setup

1.  **Create Matching User/Group on PVE (for clarity & NFSv4 ID mapping):**
    *   Even though PVE `root` handles the mount, having a user with matching IDs to the NAS owner can be beneficial, especially with NFSv4 ID mapping or if other PVE processes need to interact as that user.
    ```bash
    # On PVE Host (as root or with sudo)
    # Check if UID/GID 1000 are free
    getent passwd 1000
    getent group 1000

    # Create group (e.g., 'nasgroup' or same as username)
    sudo groupadd -g 1000 nasgroup # Or 'nasuser' if group name matches username

    # Create user
    sudo useradd -u 1000 -g 1000 -m -s /bin/bash nasuser
    # Optionally set a password
    sudo passwd nasuser
    ```
2.  **Install NFS Client Utilities:**
    ```bash
    # On PVE Host
    sudo apt update
    sudo apt install nfs-common -y
    ```
3.  **Create Mount Point Directory on PVE:**
    ```bash
    # On PVE Host
    sudo mkdir -p /mnt/nas/media
    ```
4.  **Mount NFS Share Manually (for testing):**
    ```bash
    # On PVE Host
    # Replace <NAS_IP> and /path/to/nas/export with actual values
    sudo mount -t nfs <NAS_IP>:/path/to/nas/export /mnt/nas/media
    ls -l /mnt/nas/media # Verify contents and permissions (should show UID/GID 1000)
    sudo umount /mnt/nas/media # Unmount after testing
    ```
5.  **Configure Automatic Mounting via `/etc/fstab`:**
    *   Edit `/etc/fstab` on the PVE host:
    ```bash
    # On PVE Host
    sudo nano /etc/fstab
    ```
    *   Add the following line (adjust NAS IP, export path, and local mount point):
    ```fstab
    <NAS_IP>:/path/to/nas/export  /mnt/nas/media  nfs  defaults,auto,nofail,_netdev,rw  0  0
    ```
    *   **Key options:**
        *   `auto`: Mount at boot.
        *   `nofail`: Prevents PVE boot from hanging if NAS is unavailable.
        *   `_netdev`: Waits for network to be up before attempting mount.
        *   `rw`: Read-write.
6.  **Test `fstab` Entry and Reboot PVE:**
    ```bash
    # On PVE Host
    sudo mount -a # Attempts to mount all entries in fstab
    mount | grep /mnt/nas/media # Verify it's mounted
    # Perform a full PVE reboot to ensure it mounts automatically.
    ```

---

### Step 3: LXC Container Setup (Privileged)

1.  **Create a New Privileged LXC Container:**
    *   Use the PVE Web GUI or `pct create` command. Ensure it's "Privileged" (Uncheck "Unprivileged container" during creation or ensure `unprivileged: 0` in its config). For this example, assume container ID `101`.
    *   Select an OS template (e.g., Debian, Ubuntu).
2.  **Start the Container and Access its Console:**
    ```bash
    # On PVE Host
    pct start 101
    pct enter 101
    ```
3.  **Create Matching User/Group Inside the Container:**
    *   Since the container is privileged, UID/GID `1000` inside the container *is* UID/GID `1000` on the PVE host and thus corresponds to the NFS file ownership.
    ```bash
    # Inside the LXC Container (ID 101)
    # Check if UID/GID 1000 are free (should be on a fresh container)
    getent passwd 1000
    getent group 1000

    # Create group (match PVE group name for consistency if desired)
    groupadd -g 1000 nasgroup # Or 'nasuser'
    # Create user
    useradd -u 1000 -g 1000 -m -s /bin/bash nasuser
    passwd nasuser # Optional
    ```
4.  **Create the Target Mount Point Directory Inside the Container:**
    *   This directory *must exist in the container's root filesystem* before the bind mount is applied.
    ```bash
    # Inside the LXC Container (ID 101)
    mkdir -p /mnt/media # Or your chosen path, e.g., /media
    exit # Exit the container console
    ```
5.  **Configure Bind Mount from PVE to LXC:**
    *   This is done on the PVE host, modifying the container's configuration.
    ```bash
    # On PVE Host (ensure container 101 is stopped or changes may need a restart)
    pct stop 101 # Recommended before changing mount points
    # Add the bind mount (mp0 is the first mount point, use mp1, mp2, etc. if others exist)
    pct set 101 -mp0 /mnt/nas/media,mp=/mnt/media
    # Or edit /etc/pve/lxc/101.conf and add:
    # mp0: /mnt/nas/media,mp=/mnt/media
    pct start 101
    ```
    *   `/mnt/nas/media`: Source path on the PVE host (where NFS is mounted).
    *   `/mnt/media`: Target path inside the LXC container.

---

### Step 4: Verification and Usage

1.  **Check Mount Inside the Container:**
    ```bash
    # On PVE Host
    pct enter 101

    # Inside the LXC Container
    df -h /mnt/media
    ls -l /mnt/media
    ```
    *   `df -h` should show the filesystem from the NAS.
    *   `ls -l` should list the contents of the NAS share, and files/directories should be owned by `nasuser nasgroup` (or whatever names correspond to UID/GID 1000 inside the container).
2.  **Test Permissions:**
    *   As `nasuser` (UID 1000) inside the container, you should have appropriate read/write access based on the NAS permissions for UID 1000.
    ```bash
    # Inside the LXC Container
    su - nasuser
    cd /mnt/media
    touch test_from_container.txt # Test write access
    ls # Verify file creation
    rm test_from_container.txt
    exit # Exit from nasuser shell
    exit # Exit from container console
    ```

---

**Summary of Key Learnings & Troubleshooting Points:**

*   **`root_squash` on NAS:** This was the primary hurdle for LXC bind mounts. PVE `root` needs sufficient permission on the NFS *source* directory to set up the bind. Disabling `root_squash` (or carefully managing anonymous user permissions on the NAS) resolved this.
*   **Privileged vs. Unprivileged Containers:** UID/GID mapping is direct in privileged containers. For unprivileged containers, UID/GID re-mapping would be required, making this more complex.
*   **Target Directory for Bind Mounts:** The target directory *must exist inside the container's rootfs* before the bind mount is applied.
*   **`_netdev` and `nofail` in `/etc/fstab`:** Crucial for reliable mounting of network filesystems on PVE boot.
*   **UID/GID Consistency:** Maintaining the same UID/GID (`1000:1000`) across NAS, PVE (user `nasuser`), and LXC (user `nasuser`) simplifies permission management.
*   **Nesting:** While mentioned, nesting was not directly a factor in the NFS/bind-mount setup itself but is a feature of the container.

---

This setup now provides a robust way for applications within the privileged LXC container to directly and efficiently access data on the NAS with correct permissions.
