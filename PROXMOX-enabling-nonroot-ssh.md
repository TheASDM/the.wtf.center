Here's how to make a new user and enable SSH for them in OpenSSH

**1. Ensure a Login Shell is Set (You likely did this)**

When you created the user with `sudo useradd ... -s /bin/bash nasuser`, you assigned `/bin/bash` as the login shell. This is necessary for an interactive SSH session.

To verify:
```bash
getent passwd nasuser
```
The output should end with `/bin/bash` (or another valid shell like `/bin/sh`, `/usr/bin/zsh`, etc.). If it's `/sbin/nologin` or `/bin/false`, the user cannot log in.
If needed, change it:
```bash
sudo usermod -s /bin/bash nasuser
```

**2. Set a Password for the User (You likely did this)**

SSH needs a way to authenticate the user. The simplest is a password.
```bash
sudo passwd nasuser
```
Follow the prompts to set a strong password.

**3. SSH Server Configuration on Proxmox VE (`sshd_config`)**

Proxmox VE runs an OpenSSH server. Its main configuration file is `/etc/ssh/sshd_config`.
Key settings to check (though defaults are usually fine for non-root users):

*   **`PasswordAuthentication yes`**: This must be set to `yes` for password-based SSH logins. It's often the default.
*   **`ChallengeResponseAuthentication yes`**: Also related to password/interactive logins.
*   **`UsePAM yes`**: This is standard on Debian-based systems like PVE and allows Pluggable Authentication Modules to handle authentication, which includes local user passwords.
*   **`AllowUsers` / `DenyUsers` / `AllowGroups` / `DenyGroups`**: Check if these directives exist in your `/etc/ssh/sshd_config`. If `nasuser` (or a group it belongs to) is explicitly denied, or not explicitly allowed when an `AllowUsers` list exists, login will fail. Usually, these are not set by default, meaning all valid users are allowed.

If you make any changes to `/etc/ssh/sshd_config`, restart the SSH service:
```bash
sudo systemctl restart sshd
```
or
```bash
sudo systemctl restart ssh
```

**4. SSH Client (From Your Workstation)**

Now, from another machine (your laptop/desktop), you can try to SSH in:
```bash
ssh nasuser@<PVE_HOST_IP_ADDRESS>
```
Replace `<PVE_HOST_IP_ADDRESS>` with the actual IP of your Proxmox VE server. You should be prompted for the password you set for `nasuser`.

**6. SSH Key-Based Authentication (Recommended for Better Security)**

Instead of or in addition to passwords, using SSH keys is much more secure.

*   **On your client machine (e.g., your laptop):**
    If you don't have an SSH key pair yet, generate one:
    ```bash
    ssh-keygen -t ed25519 # Modern and secure
    # or
    # ssh-keygen -t rsa -b 4096 # Still very common and strong
    ```
    This will create `~/.ssh/id_ed25519` (private key) and `~/.ssh/id_ed25519.pub` (public key), or similar for RSA.

*   **Copy the public key to `nasuser` on the PVE host:**
    The easiest way (if password SSH is temporarily working for `nasuser`):
    ```bash
    ssh-copy-id nasuser@<PVE_HOST_IP_ADDRESS>
    ```
    This command appends your public key to `/home/nasuser/.ssh/authorized_keys` on the PVE server and sets the correct permissions.

    **Manual method (if `ssh-copy-id` isn't available or if you prefer):**
    1.  Get the content of your public key (e.g., `cat ~/.ssh/id_ed25519.pub` on your client).
    2.  Log into PVE as `root` (or another user with `sudo` access).
    3.  Create the `.ssh` directory for `nasuser` if it doesn't exist and set permissions:
        ```bash
        sudo mkdir -p /home/nasuser/.ssh
        sudo chmod 700 /home/nasuser/.ssh
        sudo chown nasuser:nasuser /home/nasuser/.ssh # Or nasuser:nasgroup
        ```
    4.  Create/edit the `authorized_keys` file, paste your public key into it, and set permissions:
        ```bash
        sudo nano /home/nasuser/.ssh/authorized_keys
        # (Paste your public key here)
        sudo chmod 600 /home/nasuser/.ssh/authorized_keys
        sudo chown nasuser:nasuser /home/nasuser/.ssh/authorized_keys # Or nasuser:nasgroup
        ```

*   Now try SSHing in again from your client:
    ```bash
    ssh nasuser@<PVE_HOST_IP_ADDRESS>
    ```
    It should log you in without a password prompt (it might ask for your SSH key passphrase if you set one).

*   **Optional: Disable Password Authentication (Higher Security):**
    Once key-based auth is working, you can disable password authentication in `/etc/ssh/sshd_config` on PVE for even better security:
    ```
    PasswordAuthentication no
    ```
    And restart `sshd`: `sudo systemctl restart sshd`.
    **Be careful:** Ensure key-based login works reliably for all users who need SSH access (including `root`, if you SSH as root) before disabling passwords, or you could lock yourself out.

**Summary for `nasuser` SSH:**

1.  Ensure `nasuser` has a password (`sudo passwd nasuser`).
2.  Ensure `nasuser` has a login shell (`/bin/bash`).
3.  SSH to `nasuser@<PVE_IP>`.
4.  (Recommended) Set up SSH key-based authentication for `nasuser`.

The user `nasuser` primarily exists on PVE to ensure correct ownership mapping for files accessed via NFS from your VMs/containers. It generally shouldn't need to "install things" system-wide. If it needs to run specific commands or scripts, those would typically be placed in its home directory or a location it has execute permissions for.