## Homelab Journal Entry: Rediscovering LXC and Proxmox Helper Scripts

**Date:** May 7, 2025

**Current State & Past Experiences:**
Up to this point, my Proxmox VE usage has been fairly limited, typically running no more than two or three Virtual Machines (VMs) concurrently. These VMs have generally served a few key purposes:
*   **Miscellaneous Docker Installs:** Hosting various Docker containers that, in hindsight, would be better suited for a dedicated "Lab VM" or a more lightweight solution.
*   **Plex Media Server:** A dedicated VM for managing and serving media.
*   **Original PFSense VM:** My initial router/firewall setup, which ran alongside other VMs on the same Proxmox host.

My experience with LXC (Linux Containers) has been minimal. I recall a brief attempt to create an LXC container some time ago. However, I hit a roadblock when I couldn't find any templates listed under the "local" storage in the Proxmox GUI wizard. After about five minutes of searching for a solution without success, I abandoned the effort and reverted to creating another full VM.

**Today's Breakthrough - A Renewed Attempt at LXC for Docker:**
Today, I decided to revisit LXC containers, specifically with the goal of setting up Docker. Initially, I faced the familiar challenge of figuring out where to begin with installing dependencies and getting Docker operational within a fresh LXC.

My search for a bash script to automate the dependency installation led me to an incredibly valuable resource I hadn't encountered before:

*   **Proxmox VE Helper Scripts:** `https://community-scripts.github.io/ProxmoxVE/`

**The "Holy Crap" Moment:**
This website is a game-changer. Browsing through the available scripts, I found one specifically for setting up Docker in an LXC container:
*   **Docker LXC Script (dated 5/1/2024)**

I executed this script, and within a remarkably short period, I had a fully functioning Docker environment, complete with Portainer for management, running inside an LXC container.

**Initial Thoughts & Future Outlook:**
This is a significant improvement over my previous methods of running Docker within full VMs. The resource efficiency and speed of deployment using this LXC script are immediately apparent.

While I'm sure there are even more optimized or refined ways to achieve my goals (and I'll continue to explore those), this discovery represents a substantial step forward in how I manage containerized applications in my homelab. The ease of use provided by these community scripts has opened up new possibilities and significantly lowered the barrier to entry for leveraging LXC more effectively.

**Key Takeaway:**
Community-maintained scripts and resources can be incredibly powerful tools for simplifying complex setups and accelerating learning in a homelab environment. Sometimes, the right tool or guide is just a web search away, and revisiting previously challenging technologies with new resources can lead to breakthroughs.

---
