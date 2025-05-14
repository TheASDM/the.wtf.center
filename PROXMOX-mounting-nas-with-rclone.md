# Using Rclone to Mount a NAS Drive on Proxmox for LXC Use

This guide outlines the steps to mount a NAS drive on a Proxmox VE (PVE) host using Rclone and make it accessible within an LXC container.

## I. PVE Host: Rclone Setup & Initial Mount

### 1. Access PVE Shell
```bash
ssh xxx@192.168.x.x
```

### 2. Install Rclone
```bash
curl https://rclone.org/install.sh | sudo bash
```

### 3. Configure Rclone Remote
```bash
rclone config
```
*   Follow prompts to set up your NAS remote.
*   For this example: The NAS uses FTP on port 22, with no explicit or implicit SSL. Name the remote `nas`.

### 4. Verify Remote Connection
```bash
rclone ls nas:
```
*   This lists all files on the remote. Use `CTRL-C` to exit after confirming it works.

### 5. FUSE Dependencies
*   **Install FUSE:**
    ```bash
    sudo apt install fuse
    sudo modprobe fuse
    ```
*   **Install fuse3 (if needed/preferred):**
    ```bash
    sudo apt update
    sudo apt install fuse3
    ```
*   **Enable `user_allow_other` in `/etc/fuse.conf`:**
    Uncomment the line `user_allow_other` using `sudo nano /etc/fuse.conf`, or run:
    ```bash
    echo "user_allow_other" | sudo tee -a /etc/fuse.conf
    ```

### 6. Create Mount Directory on PVE
```bash
sudo mkdir -p /mnt/nas-media
```

### 7. Test Rclone Mount
```bash
sudo rclone mount nas:media /mnt/nas-media \
  --allow-other \
  --uid 1000 \
  --gid 1000 \
  --umask 002 \
  --vfs-cache-mode writes
```
*   In another terminal, verify:
    ```bash
    ls /mnt/nas-media
    ```
    You should see your NAS file structure. `CTRL-C` the `rclone mount` command.

### 8. Test Rclone Mount as Daemon (Optional)
```bash
sudo rclone mount nas:media /mnt/nas-media \
  --allow-other \
  --uid 1000 \
  --gid 1000 \
  --umask 002 \
  --vfs-cache-mode writes \
  --daemon
```

## II. PVE Host: Persistent Mount via Systemd

### 1. Unmount (If Still Mounted)
Ensure any test mounts are unmounted:
```bash
sudo fusermount3 -u /mnt/nas-media
# or
sudo fusermount -u /mnt/nas-media
# or
sudo umount /mnt/nas-media
```

### 2. Create Rclone Mount Script
```bash
sudo nano /usr/local/bin/rclone-mount-nas.sh
```
Paste the following script:
```bash
#!/bin/bash

/usr/bin/rclone mount nas:media /mnt/nas-media \
  --allow-other \
  --uid 1000 \
  --gid 1000 \
  --umask 002 \
  --vfs-cache-mode writes \
  --dir-cache-time 12h \
  --poll-interval 15s \
  --log-file /var/log/rclone-nas.log \
  --log-level INFO
```

**Script Argument Explanations:**
*   `--allow-other`: Allows users other than the one running rclone (usually root) to access the mount. Required for LXCs, containers, or non-root users to read/write the mount. Must be enabled in `/etc/fuse.conf` with `user_allow_other` uncommented.
*   `--uid 1000`: Makes all files appear owned by UID 1000 (in the mount). Ensures the container user (your nasuser) sees the files as owned by them. Critical if your container runs as unprivileged and you want access from inside.
*   `--gid 1000`: Makes all files appear owned by group ID 1000 (typically nasgroup). This allows the group to also have write/read access if the user permissions don’t cover it. Complements `--uid 1000` to match LXC internal group ownership.
*   `--umask 002`: Removes write permissions for "others" but keeps them for user and group. Results in: Files: `664` (rw-rw-r--), Dirs: `775` (rwxrwxr-x). Ensures your container user (UID 1000, GID 1000) has read-write, but no global write risk.
*   `--vfs-cache-mode writes`: Caches writes in memory or disk before writing to the remote (VFS = Virtual File System). Needed if the remote doesn’t support operations like random writes or concurrent file changes (typical with SFTP/WebDAV). Enables compatibility with more software. `writes` = only cache when writing (not when reading).
*   `--dir-cache-time 12h`: Keeps the directory/file list in memory for 12 hours. Reduces the need to keep rechecking file structure from the remote. Boosts performance by avoiding repetitive directory lookups.
*   `--poll-interval 15s`: Tells rclone to check for external file changes every 15 seconds. Useful if the remote folder is modified externally (e.g., via another client). Works best with remotes that support polling (SFTP, some cloud providers). Without it, the cache may become stale.
*   `--log-file /var/log/rclone-nas.log`: Sends all logging output to a specific file. Helps with debugging. Important if running as a systemd service where real-time CLI logs aren't visible.
*   `--log-level INFO`: Sets the verbosity of logs. `INFO` = balanced, shows file events, mounts, disconnects, errors. Other options: `DEBUG`, `ERROR`, `NOTICE`, `WARNING`.

Make the script executable:
```bash
sudo chmod +x /usr/local/bin/rclone-mount-nas.sh
```

### 3. Create Systemd Service File
```bash
sudo nano /etc/systemd/system/rclone-nas.service
```
Paste the following:
```ini
[Unit]
Description=Mount rclone NAS remote to /mnt/nas-media
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/rclone-mount-nas.sh
ExecStop=/bin/fusermount3 -u /mnt/nas-media
Restart=on-failure
User=root
Group=root

[Install]
WantedBy=multi-user.target
```

### 4. Enable and Start the Service
Ensure `/mnt/nas-media` is unmounted before starting.
```bash
sudo systemctl daemon-reexec # Use if modifying existing systemd files extensively
sudo systemctl daemon-reload
sudo systemctl enable rclone-nas.service
sudo systemctl start rclone-nas.service
```

### 5. Verify Service Status
```bash
sudo systemctl status rclone-nas.service
```
Should show `active (running)`. Confirm with `ls /mnt/nas-media`.

### 6. Test Persistence
```bash
sudo reboot
```
After reboot, verify `ls /mnt/nas-media` shows your files.

## III. LXC Container: Accessing the Mount

### 1. Create Mount Target in LXC (on PVE host)
Replace `101` with your LXC ID and `/mnt/plex-media` with the desired path *inside* the LXC.
```bash
sudo mkdir -p /var/lib/lxc/101/rootfs/mnt/plex-media
```

### 2. Configure LXC Bind Mount
Edit the LXC's configuration file (e.g., `/etc/pve/lxc/101.conf`):
```bash
sudo nano /etc/pve/lxc/101.conf
```
Add this line (adjust `mp0` if other mount points exist):
```
mp0: /mnt/nas-media,mp=/mnt/plex-media
```

**Note on Unprivileged LXCs & UID/GID Mapping:**
*   This setup assumes a **privileged LXC** or an unprivileged LXC where UID/GID 1000 on the host maps correctly to the desired user inside the container.
*   For other unprivileged LXC scenarios, UID/GID mapping is required. The following is an **UNVERIFIED** example:
    On PVE host:
    ```bash
    # echo "root:1000:1" | sudo tee -a /etc/subuid
    # echo "root:1000:1" | sudo tee -a /etc/subgid
    ```
    In `/etc/pve/lxc/101.conf`:
    ```
    # lxc.idmap = u 0 100000 1000
    # lxc.idmap = u 1000 1000 1
    # lxc.idmap = u 1001 101001 64536
    # lxc.idmap = g 0 100000 1000
    # lxc.idmap = g 1000 1000 1
    # lxc.idmap = g 1001 101001 64536
    ```

### 3. Restart LXC Container
```bash
sudo pct stop 101
sudo pct start 101
```

### 4. Verify Access Inside LXC
Access the LXC (console or SSH) and check:
```bash
ls -l /mnt/plex-media
```
The NAS files should be listed.