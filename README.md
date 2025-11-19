# ImageServer

## SUMMARY
Provide a script to configure an Image Server to propagate Operating System images to desktop PCs using Linux Mint and PXE.

### BASED ON...
The script from Spip, 2023
https://gist.github.com/spipm/aef2db9b28d085b0c162d0b21afbe0f1

### DESCRIPTION
This is a bash shell script to configure a Linux Mint 22.1 Xia to act as an Image Server to deploy desktop 
images (Windows or else) to desktop computers using the network, PXE boot, Rescuezilla, dnsmasq, tftpboot, 
nginx and Samba. Also, you will need to install Linux Mint 22.1 Xia on your own. I used a setup with a switch 
conected to the Linux Mint server and to the desktop computers you want to deploy the image, with no 
connection to my actual network. 

### ATTENTION!
As we are going to setup a very special configuration for dhcp, may be is better for you to setup a 
separate network for that. Or you may have problems on your actual network.

## FUNCTIONALITY

### ON DEBUGGING
The script has a lot for debugging. First, you have a switch variable to enable/disable debugging:   
  debug=0; (debug disabled)  
  debug=1; (debug enabled)

The messagens will go to the screen and to a file:  
  debug_file="/tmp/pxe-config-1.3.log";

You can rename this file as you wish. But the login you are using to run the code must have writing access to the file.

### ON NETWORK
You also have variables for networking that you must adapt to the environment of your server computer:  

  \# For network (change this)  
  net_interf="enp0s31f6";  
  net_prefix="192.168.100";  
  net_broadc="255.255.255.0";  

### ON RESCUEZILLA IMAGE
This script may grab the Rescuezilla image from internet in:

  \# For iso link and image  
  iso_link="https://github.com/rescuezilla/rescuezilla/releases/download/2.6/rescuezilla-2.6-64bit.oracular.iso";  
  iso_name="rescuezilla";  
  iso_file="${iso_name}.iso";  

But, if already downloaded, the rescuezilla image must be put/copied into /tmp, using the name ${iso_file}. In that case, the script will skip downloading the iso image.  

### ON MAIN FUNCTION
The MAIN is not a function, it is a label to the main functionality of the script. In this case, it create the directories (if nonexistent), 
then install needed .deb packages into Linux Mint (dnsmasq, tftp-hpa, nginx, pxelinux, grub-efi-amd64-signed, shim-signed and samba. After 
installing the packages, it proceeds to get the Rescuezilla image, mounts it and copies some files to specific directories. 
Then unmount the image. 

After that, there is a function to configure the net boot. That means the configuration for pxelinus files, tftpboot and uefi files.

Next are the functions for configuration of dnsmasq and samba.

The function for dnsmasq configuration receives one parameter (UEFI|BIOS) that changes the file used for pxeboot. So, in the call of the function, be sure to use:  
  ConfigDNSmasq "UEFI";  
or  
  ConfigDNSmasq "BIOS";

What is the catch? Well, if the desktop computers you are going to apply the image are not UEFI-configured, use "BIOS". If they are UEFI-configured, use "UEFI". 
Also, do not put UEFI-configured and UEFI-non-configured desktops to receive the image at the same time. Just do a batch with UEFI-configured desktops and 
another with UEFI-non-configured desktops, changing the "ConfigDNSmasq" call to be "UEFI" or "BIOS".

## IN THE END...
You shoud remember to put the image/s you want to apply to the desktops into the samba share /srv/samba/imagens, so you can direct Rescuezilla 
to get the image from the network in the samba share. If you do not know how to use Rescuezilla to get the image from the samba service, look 
into information about Rescuezilla, ok? Also, the images **must** be created using Rescuezilla OR Clonezilla.

Next thing to do after running the script is to connect the Linux Mint server and the batch of desktop computers together via network switch and turn on every one of the desktop computers.
