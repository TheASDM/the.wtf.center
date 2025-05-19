# Split-DNS with OPNsense: Taming Local Resolution (and Dodging DoH Traps)

One of the common goals when setting up a more advanced home or lab network is to resolve internal services using their "real" domain names (e.g., `nas.yourdomain.com`) to their local IP addresses, without relying on NAT reflection (hairpin NAT). This is called **Split-DNS**. It's cleaner, often faster, and avoids potential complexities with NAT reflection.

However, a modern "feature" can unexpectedly sabotage your carefully crafted Split-DNS setup: **DNS over HTTPS (DoH)**. Many of us (myself included!) have spent hours troubleshooting DNS issues, only to discover DoH was the culprit, bypassing our local DNS resolver.

This guide will walk you through setting up Split-DNS on OPNsense using Unbound DNS and, crucially, how to handle the DoH challenge.

## What is Split-DNS?

Split-DNS (also known as split-horizon DNS or split-view DNS) is a DNS configuration where internal clients and external clients receive different DNS responses for the same FQDN (Fully Qualified Domain Name).

*   **Internal Clients (on your LAN):** When they query `service.yourdomain.com`, they get back a private IP address (e.g., `192.168.1.50`).
*   **External Clients (on the Internet):** When they query `service.yourdomain.com`, they get back your public IP address (which then usually hits a NAT rule on your OPNsense firewall to forward to the internal service).

**Why use it?**
*   **Avoid NAT Reflection:** NAT reflection allows internal clients to access internal services using the public IP. While OPNsense handles it, it can sometimes be finicky or add slight overhead. Split-DNS is often a more robust solution.
*   **Simpler Client Configuration:** Clients always use the same FQDN, regardless of whether they are internal or external (though the resolution path differs).
*   **Direct Local Access:** Internal traffic to local services stays entirely local, which can be faster.

## The Unexpected Villain: DNS over HTTPS (DoH)

### What is DNS over HTTPS (DoH)?

DNS over HTTPS (DoH) is a protocol for performing DNS resolution via the HTTPS protocol. Instead of sending DNS queries as plain text over UDP or TCP port 53, DoH encrypts them and sends them over TCP port 443 (the standard HTTPS port).

**Why does it exist?**
*   **Privacy:** Prevents eavesdropping on DNS queries by anyone on the network path (e.g., ISPs, public Wi-Fi operators).
*   **Security:** Helps prevent DNS spoofing or manipulation.
*   **Circumvention:** Can bypass DNS-based censorship or filtering.

**Why is it a problem for Split-DNS?**
Many modern web browsers (Chrome, Firefox, Edge) and even some operating systems are starting to enable DoH by default or offer it as an easy-to-enable option. When DoH is active *within an application or OS*, that application/OS **bypasses your local DNS resolver (OPNsense/Unbound)**. Instead, it sends its DNS queries directly to a public DoH provider (like Cloudflare, Google, Quad9).

This means your carefully configured Unbound overrides for `service.yourdomain.com` to resolve to `192.168.1.50` are completely ignored by DoH-enabled clients. They'll query the public DoH server, get your public IP, and then you're back to relying on NAT reflection (if it's even working as expected).

## TL;DR - The Quick Fix for DoH Interference

If your Split-DNS isn't working and you suspect DoH:

1.  **Disable DoH in your web browsers:**
    *   **Firefox:** `Settings` > `Privacy & Security` > (Scroll to bottom) `DNS over HTTPS` > `Off` or `Max Protection` (and configure exceptions for your local domains).
    *   **Chrome/Edge:** `Settings` > `Privacy and security` > `Security` > `Use secure DNS`. Turn it `Off` or select `With your current service provider` (if OPNsense is correctly configured as the system DNS). If you choose a specific DoH provider here, you'll need to add exceptions if the browser supports it, or disable it.
2.  **Check Operating System DoH settings:** Some OS versions are also integrating DoH.
3.  **(Advanced) Block DoH Servers:** You can use firewall rules or pfBlockerNG on OPNsense to block known public DoH server IPs, forcing clients to fall back to your local resolver. This is a more aggressive approach.

Now, let's set up Split-DNS properly.

## Guide to Split-DNS on OPNsense with Unbound DNS

This guide assumes:
*   You have OPNsense installed and configured as your router/firewall.
*   Your LAN clients are configured (likely via DHCP) to use OPNsense as their DNS server.
*   You have a domain name (e.g., `yourdomain.com`) that you use publicly, and you want to use it for internal services as well. (You can also use a fake internal-only domain like `home.arpa`).

### Step 1: Ensure Unbound DNS is Enabled and Configured

1.  Navigate to **Services > Unbound DNS > General**.
2.  Make sure **Enable Unbound DNS** is checked.
3.  **Listen Port:** Should be `53`.
4.  **Network Interfaces:** Select `LAN` (and any other internal interfaces you want Unbound to listen on). Do NOT select WAN unless you intend for OPNsense to be an open resolver (generally not recommended).
5.  **Outgoing Network Interfaces:** Select `WAN` (or your specific outgoing gateway interface).
6.  **DNSSEC:** Recommended to be enabled for security.
7.  Click **Apply**.

### Step 2: Configure Host Overrides for Your Internal Services

This is where you tell Unbound how to resolve specific hostnames to internal IP addresses.

1.  Navigate to **Services > Unbound DNS > Overrides**.
2.  Under the **Host Overrides** section, click the **+ Add** button.
3.  Fill in the details for your internal service:
    *   **Host:** The hostname part *without* the domain (e.g., `nas`, `webserver`, `plex`).
    *   **Domain:** Your domain name (e.g., `yourdomain.com` or `home.arpa`).
    *   **Type:**
        *   `A`: For an IPv4 address.
        *   `AAAA`: For an IPv6 address.
        *   `MX`: For mail exchange records (less common for simple internal services).
    *   **IP Address / Target:** The *internal* IP address of your service (e.g., `192.168.1.50`).
    *   **Description:** A helpful note (e.g., "NAS local IP").
4.  Click **Save**.
5.  Repeat step 3-4 for every internal service you want to resolve locally.
    *   Example 1: `nas.yourdomain.com` -> `192.168.1.50`
    *   Example 2: `opnsense.yourdomain.com` -> `192.168.1.1` (if your OPNsense is at this IP)
6.  After adding all overrides, click **Apply changes** at the top of the Overrides page.

*(Optional) Domain Override for the entire domain:*
If you want *all* queries for `yourdomain.com` (including ones not explicitly in Host Overrides) to be handled solely by your local Unbound and *not* be forwarded to upstream public DNS servers, you can add a Domain Override:
1.  Still in **Services > Unbound DNS > Overrides**.
2.  Under **Domain Overrides**, click **+ Add**.
3.  **Domain:** `yourdomain.com`
4.  **IP Address:** `127.0.0.1` (tells Unbound to resolve it using its own configuration, including Host Overrides).
5.  **Description:** "Handle mydomain.com locally".
6.  **Save** and **Apply changes**.
This can be useful if `yourdomain.com` is *only* used internally or if you want to be absolutely sure external resolvers are not queried for anything under this domain from your LAN.

### Step 3: Ensure Clients Use OPNsense for DNS

Your LAN clients must use OPNsense as their DNS server for Split-DNS to work.

1.  Navigate to **Services > DHCPv4 > [Your LAN Interface]** (e.g., `LAN`).
2.  In the **DNS servers** field:
    *   Leave it **blank**: OPNsense will then advertise its own IP address as the DNS server. This is usually the default and preferred.
    *   Or, explicitly enter the LAN IP address of your OPNsense box (e.g., `192.168.1.1`).
3.  Do NOT put public DNS servers (like `1.1.1.1` or `8.8.8.8`) here if you want Split-DNS to function reliably for all clients.
4.  Click **Save**.
5.  If you use IPv6, configure similarly under **Services > DHCPv6 > [Your LAN Interface]**.
6.  For clients with static IP configurations, ensure their DNS server is manually set to OPNsense's LAN IP.

### Step 4: Testing Your Split-DNS Setup

1.  From a client machine on your LAN:
    *   Renew its DHCP lease or reboot it to ensure it gets the latest DNS settings.
    *   Open a command prompt or terminal.
    *   Use `nslookup` (or `dig`) to test:
        ```
        nslookup nas.yourdomain.com
        ```
        
        The output should show the *internal* IP address you configured in the Host Override (e.g., `192.168.1.50`). It should also show your OPNsense box as the resolving server.

        ```
        # Example output
        Server:  opnsense.yourdomain.com  # or your OPNsense IP
        Address: 192.168.1.1

        Name:    nas.yourdomain.com
        Address: 192.168.1.50
        ```
2.  Try accessing the service in your browser using the FQDN (e.g., `http://nas.yourdomain.com`).

### Step 5: Firewall Rules to Enforce Local DNS (Optional but Recommended)

To prevent clients from bypassing OPNsense and using external DNS servers (including DoH servers, though DoH is harder to block by port alone), you can create firewall rules.

1.  Navigate to **Firewall > Rules > LAN**.
2.  **Rule 1: Allow DNS to OPNsense (if not already implicitly allowed by a general LAN to any rule)**
    *   Action: `Pass`
    *   Interface: `LAN`
    *   Direction: `in`
    *   TCP/IP Version: `IPv4` (and/or `IPv6`)
    *   Protocol: `TCP/UDP`
    *   Source: `LAN net`
    *   Destination: `This Firewall` (or OPNsense's LAN IP address)
    *   Destination port range: `DNS` (from) `DNS` (to)
    *   Description: `Allow LAN DNS to OPNsense`
    *   Save and Apply.
3.  **Rule 2: Block DNS to External Servers**
    *   Action: `Block` (or `Reject` - Reject is "noisier" but can help clients fail faster)
    *   Interface: `LAN`
    *   Direction: `in`
    *   TCP/IP Version: `IPv4` (and/or `IPv6`)
    *   Protocol: `TCP/UDP`
    *   Source: `LAN net`
    *   Destination: `any`
    *   Destination port range: `DNS` (from) `DNS` (to)
    *   Description: `Block LAN DNS to External`
    *   **Important:** This rule must be *below* the rule allowing DNS to OPNsense.
    *   Save and Apply.

**Note on Blocking DoH with Firewall Rules:**
Blocking DoH effectively with port-based firewall rules is difficult because it uses TCP port 443 (standard HTTPS traffic). A more effective approach is to use pfBlockerNG (an OPNsense package) with lists of known DoH/DoT (DNS over TLS) server IP addresses to block them.

## Troubleshooting

*   **Clear DNS Cache:** On your client machine, clear the DNS cache (e.g., `ipconfig /flushdns` on Windows, or restart `systemd-resolved` on Linux).
*   **Check Unbound Logs:** **Services > Unbound DNS > Log File**. Look for queries and responses.
*   **Packet Capture:** Use **Interfaces > Diagnostics > Packet Capture** on OPNsense (filter for port 53) to see if DNS queries are reaching OPNsense.
*   **DoH is the Prime Suspect:** If `nslookup` from the command line works (resolves to the internal IP) but your browser still goes to the public IP, DoH in the browser is almost certainly the cause. Double-check browser settings.
*   **NAT Reflection Check:** If you still need NAT reflection as a fallback or for specific cases, ensure it's configured correctly under **Firewall > NAT > Port Forward** (enable NAT reflection for the relevant rules) and **Firewall > Settings > Advanced** (Reflection for port forwards & Reflection for 1:1). However, the goal of split-DNS is often to *reduce* reliance on it.

## Conclusion

Setting up Split-DNS with Unbound on OPNsense provides a robust and efficient way to handle local domain resolution. The biggest hurdle in modern networks is often the silent intervention of DNS over HTTPS. By understanding how DoH works and how to manage it on your clients, you can ensure your local DNS setup performs as expected. Good luck, and hopefully, this saves you the 10+ hours of frustration many of us have faced!
