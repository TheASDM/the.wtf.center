ChatGPT is useful for a lot of things with the home lab, but the packages and repos it has you install are (of course) all over the place. The below combines the good parts of what ChatGPT 04-mini suggested with current versions and sources from NVidia as of 5/7/2025.

First install drivers on ProxMox host as root:
  apt update && apt install pve-headers-$(uname -r) build-essential
  wget MOST RECENT FROM: https://www.nvidia.com/en-us/drivers/unix/
  chmod +x ./NVIDIA-Linux-x86_64-****ACTUAL VERSION#
  ./NVIDIA-Linux-x86_64-****ACTUAL VERSION# --dkms

During the install I allowed it to write the config for X, even though we don't use it. 
  reboot

Verify on host with:
  nvidia-smi

Next prepare the container in the host shell:
  nano /etc/pve/lxc/<CTID>.conf

Add the following:
  features: nesting=1
  lxc.cgroup.devices.allow: c 195:* rwm
  lxc.cgroup.devices.allow: c 195:* rwm
  lxc.cgroup.devices.allow: c 243:* rwm
  lxc.mount.entry: /dev/nvidia0 dev/nvidia0 none bind,optional,create=file
  lxc.mount.entry: /dev/nvidiactl dev/nvidiactl none bind,optional,create=file
  lxc.mount.entry: /dev/nvidia-uvm dev/nvidia-uvm none bind,optional,create=file
  lxc.mount.entry: /dev/nvidia-uvm-tools dev/nvidia-uvm-tools none bind,optional,create=file

Clean everyting up:
  reboot <CID>

Next log on to the LXC container (I did as root)
  apt update && apt upgrade
  wget MOST RECENT FROM: https://www.nvidia.com/en-us/drivers/unix/
  chmod +x ./NVIDIA-Linux-x86_64-****ACTUAL VERSION#
  ./NVIDIA-Linux-x86_64-****ACTUAL VERSION#.run --no-kernel-module

Test our work:
  nvidia-smi


Sweet. Now we have the drivers working. Let's get the Docker toolkit. All this shit is deprecated:
## Deprecated ##
#distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
#curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | apt-key add -
#curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | tee /etc/apt/sources.list.d/nvidia-docker.list
#apt update && apt install -y nvidia-docker2
#systemctl restart docker
####
#BOTH DEPRECATED 	
#libnvidia-container1
#libnvidia-container-tools
## DEPRECATED ##

So do this instead (source: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)
  curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
  && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
  sed -i -e '/experimental/ s/^#//g' /etc/apt/sources.list.d/nvidia-container-toolkit.list
  
  sudo apt-get update
  
  sudo apt-get install -y nvidia-container-toolkit

And this should leave you with:

  dustin@plex:~$ nvidia-smi
  Thu May  8 00:09:49 2025       
  +-----------------------------------------------------------------------------------------+
  | NVIDIA-SMI 570.144                Driver Version: 570.144        CUDA Version: 12.8     |
  |-----------------------------------------+------------------------+----------------------+
  | GPU  Name                 Persistence-M | Bus-Id          Disp.A | Volatile Uncorr. ECC |
  | Fan  Temp   Perf          Pwr:Usage/Cap |           Memory-Usage | GPU-Util  Compute M. |
  |                                         |                        |               MIG M. |
  |=========================================+========================+======================|
  |   0  NVIDIA GeForce RTX 3060        Off |   00000000:D8:00.0 Off |                  N/A |
  |  0%   59C    P0             33W /  170W |       0MiB /  12288MiB |      3%      Default |
  |                                         |                        |                  N/A |
  +-----------------------------------------+------------------------+----------------------+
                                                                                           
  +-----------------------------------------------------------------------------------------+
  | Processes:                                                                              |
  |  GPU   GI   CI              PID   Type   Process name                        GPU Memory |
  |        ID   ID                                                               Usage      |
  |=========================================================================================|
  |  No running processes found                                                             |
  +-----------------------------------------------------------------------------------------+
  dustin@plex:~$ 
