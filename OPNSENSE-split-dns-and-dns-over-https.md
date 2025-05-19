# OPNsense Split-DNS & DNS over HTTPS (DoH) Guide

This guide details setting up Split-DNS on OPNsense using Unbound DNS to resolve local domains internally, and addresses conflicts caused by DNS over HTTPS (DoH).

## The Problem: Split-DNS vs. DNS over HTTPS (DoH)

**Split-DNS** resolves internal services (e.g., `service.yourdomain.com`) to local IP addresses for clients on your LAN, and to public IP addresses for external clients. This avoids NAT reflection.

**DNS over HTTPS (DoH)** encrypts DNS queries and sends them over HTTPS (port 443) to public DoH servers. Browsers and OSes enabling DoH **bypass your local OPNsense Unbound DNS**, breaking Split-DNS by resolving local hostnames to their public IPs.

### TL;DR: If Split-DNS Fails

*   **Disable DoH in client browsers/OS** (e.g., Firefox: Settings > Privacy & Security > DNS over HTTPS > Off; Chrome/Edge: Settings > Privacy > Security > Use secure DNS > Off/With current provider).
*   Or, **add exceptions for your local domains** in client DoH settings if supported.
*   Consider blocking public DoH server IPs via OPNsense firewall rules (e.g., using pfBlockerNG).

## Guide to Split-DNS with OPNsense Unbound DNS

**Assumptions:**
*   OPNsense is your router/firewall.
*   LAN clients use OPNsense for DNS (via DHCP).
*   You have a domain (e.g., `yourdomain.com` or `internal.lan`).

### 1. Configure Unbound DNS

1.  Navigate to **Services > Unbound DNS > General**.
2.  Ensure **Enable Unbound DNS** is checked.
3.  **Listen Port:** `53`.
4.  **Network Interfaces:** Select `LAN` (and other internal interfaces). Do NOT select `WAN`.
5.  **Outgoing Network Interfaces:** Select `WAN`.
6.  **DNSSEC:** Enable (recommended).
7.  Click **Apply**.

### 2. Add Host Overrides

1.  Navigate to **Services > Unbound DNS > Overrides**.
2.  Under **Host Overrides**, click **+ Add**.
3.  For each internal service:
    *   **Host:** Hostname part (e.g., `nas`).
    *   **Domain:** Your domain (e.g., `yourdomain.com`).
    *   **Type:** `A` (IPv4) or `AAAA` (IPv6).
    *   **IP Address / Target:** Internal IP of the service (e.g., `192.168.1.50`).
    *   **Description:** (Optional) e.g., "Local NAS IP".
    *   Click **Save**.
4.  After adding all overrides, click **Apply changes**.

### 3. Configure Client DNS (via DHCP)

1.  Navigate to **Services > DHCPv4 > [Your LAN Interface]**.
2.  **DNS servers:** Leave blank (OPNsense uses its own IP) or enter OPNsense's LAN IP. Do not list public DNS servers here.
3.  Click **Save**.
4.  Configure similarly for DHCPv6 if used.
5.  Manually configure static clients to use OPNsense's LAN IP for DNS.

### 4. Test Split-DNS

1.  On a LAN client (renew DHCP lease if needed):
    ```bash
    dig @[your firewallip] yourdomain.com
    ```

    ```bash
    dig @8.8.8.8 yourdomain.com
    ```
2.  Verify the first resolves to your local IP and the secone resolves to your public IP.
3.  Access the service via its FQDN in a browser (ensure DoH is off in that browser for testing).

### 5. (Optional) Firewall Rules to Enforce Local DNS

Prevent clients from using external DNS servers on port 53.

1.  Go to **Firewall > Rules > LAN**.
2.  **Rule 1 (Allow DNS to OPNsense):**
    *   Action: `Pass`, Interface: `LAN`, Protocol: `TCP/UDP`, Source: `LAN net`, Destination: `This Firewall`, Destination Port: `DNS`.
3.  **Rule 2 (Block External DNS):**
    *   Action: `Block`, Interface: `LAN`, Protocol: `TCP/UDP`, Source: `LAN net`, Destination: `any`, Destination Port: `DNS`.
    *   This rule must be *below* Rule 1.
4.  **Apply changes**.
    *Note: This does not block DoH traffic on port 443. Use pfBlockerNG with IP lists for more robust DoH blocking.*

## Troubleshooting

*   **Clear Client DNS Cache:** (e.g., `ipconfig /flushdns` on Windows).
*   **Check OPNsense Unbound Logs:** **Services > Unbound DNS > Log File**.
*   **Packet Capture (OPNsense):** **Interfaces > Diagnostics > Packet Capture** (filter port 53) to verify queries reach OPNsense.
*   **Verify DoH is Disabled:** If `nslookup` works but browsers fail, DoH is the likely culprit.

Split-DNS provides efficient local name resolution. Managing client-side DoH settings is crucial for its correct operation.
