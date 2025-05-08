Okay, here's a tightly written Markdown guide combining the Docker Compose setup for Plex (using `linuxserver/plex`) and the OPNsense NAT/Firewall configuration for remote access.

---

## Plex Media Server on Docker (LXC) with OPNsense Remote Access

This guide details setting up Plex Media Server using the `linuxserver/plex` Docker image within an LXC container on Proxmox VE, and configuring OPNsense for local and remote access.

**Assumptions:**
*   Docker and NVIDIA Container Toolkit are installed and working on the LXC container (Docker Host).
*   NVIDIA GPU is available and intended for hardware transcoding. (Adjust if using Intel QSV or no HW acceleration).
*   LXC Docker Host IP: `192.168.1.150` (Replace with your actual static IP).
*   NAS media paths on Docker Host: `/mnt/media/movies`, `/mnt/media/shows`.
*   Plex config path on Docker Host: `/opt/plex/config`.
*   User/Group ID for Plex permissions: `1000:1000` (`PUID`/`PGID`).

---

### Step 1: Prepare Docker Host (LXC Container)

1.  **Create Directories for Plex Data:**
    ```bash
    # On your Docker Host (LXC)
    sudo mkdir -p /opt/plex/config
    # Media directories (/mnt/media/*) should already be mounted from NAS
    ```

2.  **Set Permissions for Config Directory:**
    The `PUID`/`PGID` user needs write access to the config directory.
    ```bash
    # On your Docker Host (LXC)
    sudo chown -R 1000:1000 /opt/plex/config
    sudo chmod -R u+rw /opt/plex/config
    ```
    *(Ensure UID/GID 1000 also has read access to `/mnt/media/*`)*

---

### Step 2: Plex Docker Compose (Portainer Stack)

Use the following Docker Compose YAML in Portainer (Stacks > Add Stack > Web editor).

```yaml
version: '3.8'

services:
  plex:
    image: lscr.io/linuxserver/plex:latest
    container_name: plex
    network_mode: host # Simplifies network discovery and port access
    environment:
      - PUID=1000                     # User ID for Plex permissions
      - PGID=1000                     # Group ID for Plex permissions
      - TZ=America/Chicago            # **SET YOUR TIMEZONE** (e.g., Europe/London)
      - VERSION=docker                # 'docker' for stable, 'latest' for Plex Pass beta
      - PLEX_CLAIM=claim-PWTp6tqWy8VmTiWzPrsx # **REPLACE WITH YOUR FRESH CLAIM TOKEN** (https://plex.tv/claim)
    volumes:
      - /opt/plex/config:/config       # Plex configuration, database, metadata
      - /mnt/media/movies:/data/movies:ro # Movies library (read-only)
      - /mnt/media/shows:/data/tvshows:ro # TV Shows library (read-only)
      # - /mnt/media/music:/data/music:ro # Optional: Music library
    restart: unless-stopped
    # --- NVIDIA GPU Hardware Acceleration ---
    # Remove/comment 'deploy' if not using NVIDIA GPU or toolkit not configured.
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1 # Or 'all'
              capabilities: [gpu]
    # --- Intel QSV Hardware Acceleration (Alternative) ---
    # Uncomment 'devices' below and remove NVIDIA 'deploy' section if using Intel QSV.
    # devices:
    #   - /dev/dri:/dev/dri
```

**Before Deploying:**
*   **Update `TZ`** to your correct timezone.
*   **Get a fresh `PLEX_CLAIM` token** from `https://www.plex.tv/claim` and replace the placeholder. The token is for initial setup only.
*   **Review Hardware Acceleration:** Ensure the correct section (NVIDIA or Intel QSV) is active or both are removed if no hardware acceleration is used.

**Deploy the stack in Portainer.**

---

### Step 3: OPNsense Port Forwarding for Remote Access

Configure OPNsense to forward external requests on port `32400` to your Plex server.

1.  **Log into OPNsense.**
2.  Navigate to **Firewall** -> **NAT** -> **Port Forward**.
3.  Click **`+ Add`** to create a new rule.

4.  **Configure the Port Forward Rule:**
    *   **Interface:** `WAN` (your internet-facing interface)
    *   **TCP/IP Version:** `IPv4`
    *   **Protocol:** `TCP`
    *   **Source:** `any`
    *   **Destination:** `WAN address`
    *   **Destination port range:** From: `32400`, To: `32400`
    *   **Redirect target IP:** `192.168.1.150` (Your Plex Docker Host's static IP)
    *   **Redirect target port:** `32400`
    *   **Description:** `Plex Remote Access`
    *   **NAT reflection:** `Use system default` (adjust to `Enable (Pure NAT)` if local access via public IP/domain fails)
    *   **Filter rule association:** `Add associated filter rule` (This automatically creates the necessary WAN firewall rule to allow the traffic)

5.  **Click `Save`, then `Apply changes`.**

---

### Step 4: Plex Server Setup & Verification

1.  **Access Plex Web UI:** Open `http://<Plex_Docker_Host_IP>:32400/web` (e.g., `http://192.168.1.150:32400/web`).
2.  **Initial Setup:**
    *   Log in with your Plex account (it should be claimed automatically if the token was valid).
    *   Give your server a name.
    *   **Add Libraries:**
        *   Movies: Point to `/data/movies` inside Plex.
        *   TV Shows: Point to `/data/tvshows` inside Plex.
    *   Complete the setup wizard.
3.  **Verify Remote Access:**
    *   In Plex: **Settings** > **Remote Access**.
    *   It should indicate "Fully accessible outside your network."
    *   Test access from an external network (e.g., phone on cellular data via the Plex app or `app.plex.tv`).

---

### Troubleshooting Notes:

*   **Static IP for Plex Host:** Ensure the Docker host (`192.168.1.150`) has a static IP or DHCP reservation.
*   **Firewall on Docker Host:** If a firewall (like `ufw`) is active on the LXC container, ensure it allows incoming traffic on port `32400`. (Docker's `network_mode: host` means the container shares the host's network stack).
*   **CGNAT/Double NAT:** If remote access fails, check if your ISP uses CGNAT or if you have a double NAT setup. These require different solutions (e.g., VPN, ISP bridge mode).
*   **NAT Reflection for Local Access via Public IP:** If accessing Plex using your public IP/domain *from within your LAN* fails, set "NAT reflection" to `Enable (Pure NAT)` in the OPNsense port forward rule or use split-DNS.

This setup provides a robust Plex installation with persistent data, read-only media access from the container, optional hardware acceleration, and properly configured remote access through OPNsense.

---
