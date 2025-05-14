# the.wtf.center - Home Lab Documentation

```
 ______  __ __    ___      __    __  ______  _____         __    ___  ____   ______    ___  ____
|      ||  |  |  /  _]    |  |__|  ||      ||     |       /  ]  /  _]|    \ |      |  /  _]|    \
|      ||  |  | /  [_     |  |  |  ||      ||   __|      /  /  /  [_ |  _  ||      | /  [_ |  D  )
|_|  |_||  _  ||    _]    |  |  |  ||_|  |_||  |_       /  /  |    _]|  |  ||_|  |_||    _]|    /
  |  |  |  |  ||   [_     |  `  '  |  |  |  |   _]     /   \_ |   [_ |  |  |  |  |  |   [_ |    \
  |  |  |  |  ||     |     \      /   |  |  |  |       \     ||     ||  |  |  |  |  |     ||  .  \
  |__|  |__|__||_____|      \_/\_/    |__|  |__|        \____||_____||__|__|  |__|  |_____||__|\_|
```

## The Journey So Far: 91 Days

A lot can happen when you are autistic and find a new hyperfocus. This is the story of mine.

On **February 12, 2025**, I didn't really know what a NAS (Network Attached Storage) was. I was juggling about 5TB of data with Google, a couple of terabytes with Dropbox, and probably another 5TB scattered across various other cloud platforms, all incurring monthly fees. My initial thought was simple: consolidate and cut costs by choosing just one cloud provider.

Instead, I took a different path. I invested approximately **$1400** into a UGREEN DXP4800+ NAS and populated it with four 12TB Seagate Ironwolf NAS drives. By **March 1, 2025**, I had 36TB of raw storage configured in something called RAID5 and was just beginning to become vaguely aware of a technology named Docker.

Today is **May 7, 2025**. My setup has evolved significantly:

---

### Current Lab Infrastructure:

#### 1. OPNsense Firewall Box
*   **Chassis:** SuperMicro X10SLH-N6-ST031 1U Server
*   **Memory:** 16GB DDR3 SDRAM (Chipkill ECC)
*   **CPU:** 3.5GHz Quad Core
*   **Networking:**
    *   6x 10GbE RJ45 Copper Onboard NICs
    *   Dual 1GbE RJ45 Ports (one shared with IPMI)

#### 2. UGREEN DXP4800+ NAS
*   **Storage:** 4x Seagate Ironwolf 12TB HDDs in a RAID5 array (approx. 36TB usable)
*   **Primary Functions:**
    *   Network File Storage
    *   Docker Containerization Host, running services such as:
        *   The \*Arr suite (Sonarr, Radarr, etc.)
        *   Manyfold (details TBD)
        *   Nginx Reverse Proxy
*   **Operating System Note:** Currently running UGOS Pro (UGREEN's native OS). Considering a switch to either TrueNAS or Unraid in the near future for more advanced features or flexibility.

#### 3. Dell EMC PowerEdge R640 - Proxmox VE Host
*   **Chassis:** 8 Bay SFF 1U Rack Server
*   **CPU:** 2x Intel Platinum 8164 @ 2.0 GHz (26 Cores / 52 Threads each, total 52C/104T)
*   **Memory:**
    *   128GB (4x32GB) DDR4 @ 2133MHz
    *   64GB (2x32GB) DDR4 @ 2400MHz
    *   *(Total: 192GB RAM)*
*   **RAID Controller:** Dell PERC H730
*   **Networking:** Mellanox ConnectX-4 with 2x 25GbE SFP28 NIC
*   **Storage:**
    *   **Boot/OS Drive (RAID1):** 2x Dell 960GB SATA SSDs
    *   **VM/Container Storage (RAID0):** 6x Samsung 870 EVO 500GB SATA SSDs
*   **Power Supply:** 2x Dell 750W Redundant PSUs
*   **Previous Role:** Hosted a PFSense VM before the dedicated SuperMicro box was implemented. Now serves as the primary hypervisor.

#### 4. Remote Seedbox
*   **Storage:** 18TB
*   **Connectivity:** 10Gbps connection
*   **Location:** Hosted externally

---

And there's more to document later!

Things have progressed rapidly, and I've performed so many system wipes, re-installs, and configuration restarts that it's finally time to start rigorously documenting my processes and creating shortcuts for myself. This repository is the beginning of that effort.

---
