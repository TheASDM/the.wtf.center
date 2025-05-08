I have 36tbs on my NAS and only around 4tbs on my R640. So the NAS must be used to store local media, but I want the server (and its GPU) to handle the serving and transcoding. I have mounted and unmounted drives using CIFS, NFS, and SSHFS multiple times each so far through my various iterations of VMs. CIFS seems to have the best compatability, NFS seems to work the best (but is Linux exclusive I believe?), and SSHFS is actually really cool and fairly easy (and let's you mount to a remote seedbox), BUT it is a pain in the ass to get to start on boot and is kind of finnicky.

For some reason I havne't thought to (and ChatGPT hasn't recommended) that I actually host-mount the NAS to my ProxMox host so that I can volume bind that binding to my LXC container. That should make it to where I can get the NAS mounted BEFORE the VM/LXC starts and it is treated as native. 

ChatGPT instructions really suck for mounting drives as it mixes up CIFS, NFS, and some other things sometimes. So I won't be using any of the commands it gives me. However, it looks like I have previously gotten some help on this from Google Gemini. Here's my starting point from Gemini:


Let's define some placeholders (replace these with your actual values):

    <NAS_IP_ADDRESS>: The IP address of your NAS (e.g., 192.168.20.2).

    <PATH_ON_NAS>: The full path being shared by the NAS (e.g., /volume2/media). Check your NAS settings for this exact path.

    <LOCAL_MOUNT_POINT>: The directory on your server where you want the NAS share to appear (e.g., /mnt/media/nas). This directory must exist and should ideally be empty.

Steps on the Client Server:

1. Install NFS Client Utilities:
    sudo apt update
    sudo apt install nfs-common
 
2. Create the Local Mount Point:

Choose a location on your server where you want to access the NAS files. /mnt is a common place.

    sudo mkdir -p <LOCAL_MOUNT_POINT>
    # Example:
    # sudo mkdir -p /mnt/nas

(The -p flag ensures parent directories are created if they don't exist and doesn't throw an error if the directory already exists.)

3. Mount the NFS Share Manually (Temporary Mount):

This command mounts the share immediately. It will not persist after a reboot. This is good for testing.
    sudo mount -t nfs <NAS_IP_ADDRESS>:<PATH_ON_NAS> <LOCAL_MOUNT_POINT>
    # Example:
    # sudo mount -t nfs 192.168.1.100:/volume1/data /mnt/nas

Optional: Mount Options: You can add other options using -o, separated by commas (e.g., rw for read-write, ro for read-only, hard, soft, intr). Defaults are usually okay to start.

4. Verify the Mount: 
    mount | grep nfs
    or specifically check your mount point:
        
    mount | grep <LOCAL_MOUNT_POINT>
    # Example: mount | grep /mnt/nas

    
Check disk usage, which should now include the NAS share:
    df -h

Try listing files:
   
ls -l <LOCAL_MOUNT_POINT>
# Example: ls -l /mnt/nas
    (You might encounter permission errors here if UID/GID mapping isn't correct between the NAS and server - this is a common NFS issue).

5. Make the Mount Persistent (Automatic on Boot):
To have the share mounted automatically every time the server boots, you need to add an entry to the /etc/fstab file. Be careful editing this file, as errors can prevent your server from booting correctly.

Backup fstab first:
    sudo cp /etc/fstab /etc/fstab.bak

Edit fstab: Use a text editor like nano or vim.   
    sudo nano /etc/fstab

Add a line like this at the end of the file:
     
    # <Device>                                <Mount Point>         <Type> <Options>                         <Dump> <Pass>
    <NAS_IP_ADDRESS>:<PATH_ON_NAS>            <LOCAL_MOUNT_POINT>   nfs    defaults,_netdev,nofail           0      0

Example:  
    192.168.1.100:/volume1/data            /mnt/nas              nfs    defaults,_netdev,nofail           0      0

Explanation of Options:
nfs: Specifies the filesystem type.

defaults: A standard set of options (includes rw, suid, dev, exec, auto, nouser, async).

_netdev: Important! Tells the system this is a network device and it shouldn't try mounting it until the network is up.
nofail: Recommended! Prevents the system from halting the boot process if the NAS is unavailable. The mount will simply fail silently.

You might want to add specific NFS version options here too, like vers=4. Example: defaults,_netdev,nofail,vers=4
<Dump> and <Pass> should generally be 0 for NFS mounts.

Save and close the editor (Ctrl+X, then Y, then Enter in nano).

6. Test the fstab Entry:
If you manually mounted the share earlier, unmount it first:      
    sudo umount <LOCAL_MOUNT_POINT>
    # Example: sudo umount /mnt/nas

Now, tell the system to mount everything listed in /etc/fstab that isn't already mounted:
     
    sudo mount -a

Verify the mount again using 
    mount | grep nfs or df -h 

If it mounts without errors, it should work correctly on the next reboot.

Unmounting:

To manually unmount the share:
    sudo umount <LOCAL_MOUNT_POINT>
    # Example: sudo umount /mnt/nas

    
(Make sure no processes are using the mount point when you try to unmount it, otherwise you'll get a "device is busy" error. Use lsof | grep <LOCAL_MOUNT_POINT> to find processes using it).

Important Considerations & Troubleshooting:

Firewall: Ensure your server's firewall (e.g., ufw, firewalld) allows outgoing connections to the NAS IP on the NFS ports (typically TCP/UDP 2049 and potentially others for related services like portmapper/rpcbind on port 111 if using NFSv3 or older). Also ensure the NAS firewall allows incoming connections from the server's IP.

Permissions (UID/GID): NFS often uses User IDs (UID) and Group IDs (GID) for permissions. If the user accessing the mount point on the server doesn't have a matching UID/GID on the NAS, you might get permission denied errors. You may need to:

Ensure users have matching UIDs/GIDs on both systems.

Use NFSv4 with ID mapping (e.g., nfsidmap).

Configure the NAS export to "squash" all connecting users to a specific user/group on the NAS (e.g., all_squash, anonuid, anongid options in the NAS export settings). Check your NAS documentation.

NFS Versions: Mismatched NFS versions between client and server can cause issues. Stick to v4 if possible, or explicitly set the version on the client (vers=X option) to match the server.

NAS Configuration: Double-check the export path and allowed client IPs on the NAS itself. This is the most common source of initial connection problems.

Logs: Check system logs on both the server (/var/log/syslog or journalctl) and the NAS for more detailed error messages if things aren't working.