# Rclone NAS Mounts in Proxmox & LXCs: The "It Just Works" (Eventually) Guide

So, you want your glorious NAS media/data accessible inside a Proxmox LXC container. `rsync` is great, but `rclone` can mount things like a champ, and sometimes that's exactly what we need. This guide will walk through setting up an `rclone` mount on your Proxmox VE (PVE) host and then making it available to an LXC.

**Our Mission:** Mount a NAS share (using FTP in this example) persistently on the PVE host, then bind-mount it into an LXC.

---

## Phase 1: Getting Rclone Talking to Your NAS on the PVE Host

First things first, let's get `rclone` installed and configured on the PVE host itself.

### 1. SSH into your PVE Host

You know the drill.
```bash
ssh your_pve_user@192.168.X.X
```

### 2. Install Rclone

The official script is your friend:
```bash
curl https://rclone.org/install.sh | sudo bash
```

### 3. Configure Your Rclone Remote (The NAS)

This is where you tell `rclone` how to connect to your NAS.
```bash
rclone config
```
Follow the prompts. For this example, we're connecting to a NAS via **FTP on port 22 (which is usually SFTP, but let's roll with the user's note; if it's true FTP on 22, that's unusual but rclone can handle it!) with no explicit or implicit SSL.**

*   When `rclone config` asks for a name, let's call it `nas`.
*   Choose the appropriate type (e.g., `ftp`, `sftp`).
*   Enter host, port (22), user, password, etc.

### 4. Quick Sanity Check: Can Rclone See Your Files?

```bash
rclone ls nas:
```
If you see a list of files/folders from your NAS, you're golden! **Hit `CTRL-C` to stop it**, as it'll try to list *everything*. If not, revisit `rclone config`.

### 5. FUSE: The Magic Behind the Mount

`rclone mount` uses FUSE (Filesystem in Userspace) to work. Let's make sure it's ready.

*   **Install FUSE (if not already there):**
    ```bash
    sudo apt update
    sudo apt install fuse3 # fuse3 is generally preferred
    # You might also need/have 'fuse'
    # sudo apt install fuse
    # sudo modprobe fuse # Usually handled by install
    ```

*   **Allow Non-Root Users to Mount (Crucial!):**
    Edit `/etc/fuse.conf` (e.g., `sudo nano /etc/fuse.conf`) and uncomment (remove the `#`) from the line:
    ```
    user_allow_other
    ```
    Or, the quick and dirty way:
    ```bash
    echo "user_allow_other" | sudo tee -a /etc/fuse.conf
    ```

### 6. Create a Mount Point on PVE

This is where the NAS share will appear on your Proxmox host.
```bash
sudo mkdir -p /mnt/nas-media
```

### 7. Test the Mount Manually

Let's see if it works before automating.
```bash
sudo /usr/bin/rclone mount nas:media /mnt/nas-media \
  --allow-other \
  --uid 1000 \
  --gid 1000 \
  --umask 002 \
  --vfs-cache-mode writes
```
*   `nas:media`: This assumes your media is in a top-level folder named `media` on your `nas` remote. Adjust if your path is different (e.g., `nas:some/other/path`).
*   Open **another terminal session** to your PVE host and run:
    ```bash
    ls /mnt/nas-media
    ```
You should see the contents of your NAS `media` folder! If so, great. Go back to the terminal running `rclone mount` and hit `CTRL-C` to stop it.

### 8. (Optional) Test as a Daemon (Background Process)

Same command, but add `--daemon`:
```bash
sudo /usr/bin/rclone mount nas:media /mnt/nas-media \
  --allow-other \
  --uid 1000 \
  --gid 1000 \
  --umask 002 \
  --vfs-cache-mode writes \
  --daemon
```
This runs it in the background. To unmount this test daemon:
```bash
sudo umount /mnt/nas-media
# or sudo fusermount3 -u /mnt/nas-media
```

---

## Phase 2: Making the Mount Persistent with Systemd

Manually mounting is fine for testing, but we want this available after reboots. `fstab` isn't the best fit for `rclone` mounts; `systemd` is the way.

### 1. Ensure No Lingering Mounts

Double-check it's unmounted:
```bash
sudo umount /mnt/nas-media || sudo fusermount3 -u /mnt/nas-media || sudo fusermount -u /mnt/nas-media
# One of these should work if it was mounted. No error is fine too.
```

### 2. Create the Rclone Mount Script

This script will contain our `rclone mount` command with all the bells and whistles.
```bash
sudo nano /usr/local/bin/rclone-mount-nas.sh
```
Paste the following into the script:

```bash
#!/bin/bash

# Variables - makes it easier to change later if needed
REMOTE_PATH="nas:media" # Your rclone remote and path
MOUNT_POINT="/mnt/nas-media"
LOG_FILE="/var/log/rclone-nas.log"
RCLONE_BIN="/usr/bin/rclone" # Usually correct, check with 'which rclone'

# Ensure mount point exists
mkdir -p "$MOUNT_POINT"

# The Rclone Mount Command
"$RCLONE_BIN" mount "$REMOTE_PATH" "$MOUNT_POINT" \
  --allow-other \
  --uid 1000 \
  --gid 1000 \
  --umask 002 \
  --vfs-cache-mode writes \
  --dir-cache-time 12h \
  --poll-interval 15s \
  --log-file "$LOG_FILE" \
  --log-level INFO

exit 0
```

**Make it executable:**
```bash
sudo chmod +x /usr/local/bin/rclone-mount-nas.sh
```

**Understanding those Script Arguments:**

*   `--allow-other`: Allows non-root users (like your LXC user) to access the mount. Requires `user_allow_other` in `/etc/fuse.conf`.
*   `--uid 1000` / `--gid 1000`: Makes files appear owned by UID 1000 and GID 1000 *within the mount on the PVE host*. This often aligns with the first non-root user in an LXC, simplifying permissions.
*   `--umask 002`: Sets permissions to `rw-rw-r--` (664) for files and `rwxrwxr-x` (775) for directories. User and group get read/write, others get read.
*   `--vfs-cache-mode writes`: Caches files being written. Good for compatibility and performance, especially with FTP/SFTP.
*   `--dir-cache-time 12h`: How long `rclone` remembers the directory structure before re-checking. Reduces remote calls.
*   `--poll-interval 15s`: How often `rclone` checks the remote for changes made outside this mount.
*   `--log-file /var/log/rclone-nas.log` & `--log-level INFO`: Essential for debugging.

### 3. Create the Systemd Service File

This tells `systemd` how to manage our script.
```bash
sudo nano /etc/systemd/system/rclone-nas.service
```
Paste this in:

```ini
[Unit]
Description=rclone Mount for NAS Media (/mnt/nas-media)
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=root
Group=root
ExecStart=/usr/local/bin/rclone-mount-nas.sh
ExecStop=/bin/fusermount3 -u /mnt/nas-media
# If fusermount3 isn't your primary, you might use /bin/fusermount or /bin/umount
Restart=on-failure
RestartSec=5s # Optional: wait 5 seconds before restarting on failure

[Install]
WantedBy=multi-user.target
```

### 4. Enable and Start the Service

```bash
sudo systemctl daemon-reload  # Tell systemd to re-read its configs
sudo systemctl enable rclone-nas.service # Make it start on boot
sudo systemctl start rclone-nas.service  # Start it now
```

### 5. Check the Status

```bash
sudo systemctl status rclone-nas.service
```
You should see `active (running)`. If not, check the logs: `sudo journalctl -u rclone-nas.service` and `sudo cat /var/log/rclone-nas.log`.

Also, verify the mount:
```bash
ls /mnt/nas-media
```

### 6. The Ultimate Test: Reboot PVE
```bash
sudo reboot
```
After it comes back up, SSH in and check `ls /mnt/nas-media`. If your files are there, Phase 2 is a success!

---

## Phase 3: Giving Your LXC Access

Now that `/mnt/nas-media` is reliably mounted on the PVE host, let's make it available inside your LXC container (e.g., LXC ID `101`).

### 1. Create a Mount Target *Inside* the LXC's Filesystem (on the PVE Host)

This is a bit meta. You're creating a directory on the PVE host *that will become* the mount point inside the LXC.
Replace `101` with your LXC ID and `/mnt/plex-media` with your desired path *inside* the LXC.
```bash
sudo mkdir -p /var/lib/lxc/101/rootfs/mnt/plex-media
```

### 2. Configure the LXC (Bind Mount)

Edit your LXC's configuration file on the PVE host.
```bash
sudo nano /etc/pve/lxc/101.conf
```
Add this line to the end of the file:
```
mp0: /mnt/nas-media,mp=/mnt/plex-media
```
*   `mp0`: Mount point zero (if you have others, use `mp1`, `mp2`, etc.).
*   `/mnt/nas-media`: The source path on the PVE host (where rclone mounted the NAS).
*   `mp=/mnt/plex-media`: The destination path *inside* the LXC.

**A Note on Privileged vs. Unprivileged LXCs:**

*   **The example above (and UID/GID 1000 in the rclone script) generally works well for PRIVILEGED LXCs**, or unprivileged LXCs where the primary user inside the container also happens to be UID/GID 1000.
*   **For UNPRIVILEGED LXCs with different UID/GID mappings:** This gets more complex. You might need to adjust the `--uid` and `--gid` in your `rclone-mount-nas.sh` script to match the *host-side* UID/GID that corresponds to the desired user *inside* the LXC. You may also need to configure `lxc.idmap` entries in the LXC's `.conf` file. The provided `ChatGPT` example is a starting point for `idmap`, but requires careful understanding of your specific unprivileged container's mapping.
    ```
    # Example for unprivileged (VERIFY AND TEST THOROUGHLY):
    # echo "root:1000:1" | sudo tee -a /etc/subuid
    # echo "root:1000:1" | sudo tee -a /etc/subgid
    #
    # In /etc/pve/lxc/101.conf:
    # lxc.idmap: u 0 100000 1000
    # lxc.idmap: u 1000 1000 1      <-- This maps host UID 1000 to container UID 1000
    # lxc.idmap: u 1001 101001 64536
    # lxc.idmap: g 0 100000 1000
    # lxc.idmap: g 1000 1000 1      <-- This maps host GID 1000 to container GID 1000
    # lxc.idmap: g 1001 101001 64536
    ```
    **For now, we're assuming a privileged LXC or a simple unprivileged setup where UID/GID 1000 aligns.**

### 3. Restart Your LXC Container

Apply the changes:
```bash
sudo pct stop 101
sudo pct start 101
```

### 4. Verify Access Inside the LXC

Access your LXC's console (from the PVE web UI) or SSH into it.
```bash
ls -l /mnt/plex-media
```
You should see your NAS files! Permissions should also allow the relevant user inside the LXC (often UID 1000) to read/write based on the `--uid`, `--gid`, and `--umask` we set.

---

## Victory Lap (and a Teaser)

If all went well, you now have a robust, auto-mounting `rclone` share from your NAS available directly within your LXC container. High five!

**Next time on the.wtf.center:** We might explore ensuring PVE's `rclone-nas.service` is fully up and running *before* the LXC attempts to use its bind mount, to prevent occasional startup race conditions. But for now, this should get you 99% of the way there!
```
