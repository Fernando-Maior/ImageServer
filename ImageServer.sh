#!/bin/bash
#
# Fernando Maciel Souto Maior
# Script to setup a PXE boot server
# for installing imagens using the
# Rescuezilla imager.
#
# Based on script from Spip, 2023
# https://gist.github.com/spipm/aef2db9b28d085b0c162d0b21afbe0f1
#
# Versions
# v1.0, 2025-06-25
# -first version, based on heavily changed script from Spip, for
#  the sake of using Rescuezilla
#
# v1.1, 2025-06-26
# -includes debug features and complete redesign
#
# v1.2, 2025-06-30
# -includes pxe for uefi
# -debugging includes second parameter:
#  0=to file only
#  1=to file and stdout
#  2=to file and stdout plus separator
#
# v1.3, 2025-07-01
# -includes configuration for samba
#
# ------------------------------------------------------------------------

#
# DEBUGGING 
#
  # Debug?
    debug=1;
    debug_file="/tmp/pxe-config-1.3.log";
    sep="#------------------------------------------------";

  # Print to debug file
    function Debug {
      [ ${2} -ge 2 ] && echo ${sep};
      [ ${2} -ge 1 ] && echo ${1};
      echo ${1} >> ${debug_file};
    }

#
# VARIABLES (STATIC and DYNAMIC)
#
  # For network (change this)
  net_interf="enp0s31f6";
  net_prefix="192.168.100";
  net_broadc="255.255.255.0";

  # do not change this
  net_ipaddr="${net_prefix}.1";
  net_range1="${net_prefix}.100";
  net_range2="${net_prefix}.200";
  
  # For iso link and image
  iso_link="https://github.com/rescuezilla/rescuezilla/releases/download/2.6/rescuezilla-2.6-64bit.oracular.iso";
  iso_name="rescuezilla";
  iso_file="${iso_name}.iso";
  
  # For dhcp and tftp
  tftp_dir="/srv/tftp";
  dist_dir="${tftp_dir}/${iso_name}";
  dhcp_boot="dhcp_boot";
  
  # For grub and pxelinux
  grub_dir="${tftp_dir}/grub";

  # Debug?
  if [ ${debug} -eq 1 ]; then
    Debug "CONSTANTS" 2;
    Debug "net_interf = [${net_interf}]" 1;
    Debug "net_prefix = [${net_prefix}]" 1;
    Debug "net_broadc = [${net_broadc}]" 1;
    Debug "net_ipaddr = [${net_ipaddr}]" 1;
    Debug "net_range1 = [${net_range1}]" 1;
    Debug "net_range2 = [${net_range2}]" 1;
    Debug "iso_link   = [${iso_link}]"   1;
    Debug "iso_name   = [${iso_name}]"   1;
    Debug "iso_file   = [${iso_file}]"   1;
    Debug "tftp_dir   = [${tftp_dir}]"   1;
    Debug "dist_dir   = [${dist_dir}]"   1;
    Debug "dhcp_boot  = [${dhcp_boot}]"  1;
    Debug "grub_dir   = [${grub_dir}]"   1;
  fi

#
# FUNCTIONS
#

# Get needed packages from repository
function GetPackages {
  # Debug?
  [ ${debug} -eq 1 ] && Debug "Install packages..." 2;

  # Install needed packages
  apt -y install dnsmasq tftp-hpa nginx pxelinux grub-efi-amd64-signed shim-signed samba;
}

# Get iso image from rescuezilla and grab files
function GetImage {
  # Debug?
  [ ${debug} -eq 1 ] && Debug "Get image..." 2;

  # Get image
  cd /tmp;
  [   -f ${iso_file} ] && Debug "Image file ${iso_file} already there..." 1;
  [ ! -f ${iso_file} ] && wget ${iso_link} -O ${iso_name}.iso --no-check-certificate >/dev/null;

  # Mount it
  [ ${debug} -eq 1 ] && Debug "Mounting iso" 1;
  mnt_dir="/mnt/${iso_name}";
  mkdir -p ${mnt_dir};
  mount -o ro ./${iso_name}.iso ${mnt_dir};

  # Copy Linux init files and grub
  [ ${debug} -eq 1 ] && Debug "Copying files" 1;
  cp    ${mnt_dir}/casper/vmlinuz   ${dist_dir};
  cp    ${mnt_dir}/casper/initrd.lz ${dist_dir};
  cp -r ${mnt_dir}/boot/grub/*      ${grub_dir};

  # Unmount iso
  umount ${mnt_dir};

  # Copy image to final place
  [ ${debug} -eq 1 ] && Debug "Copying image" 1;
  cp ./${iso_name}.iso ${dist_dir};
}

# Configure grub
function ConfigureNETBoot {
  # Debug?
  [ ${debug} -eq 1 ] && Debug "Configure NETBoot" 2;

  # Copy things for boot from pxelinux and syslinux
  [ ${debug} -eq 1 ] && Debug "Copying files from pxelinux/syslinux" 1;
  mkdir -p ${tftp_dir}/syslinux;
  cp /usr/lib/PXELINUX/lpxelinux.0 ${tftp_dir};
  cp /usr/lib/syslinux/modules/bios/* ${tftp_dir}/syslinux;

  # get loaders from shim-signed and grub-efi-amd64-signed
  [ ${debug} -eq 1 ] && Debug "Copying loaders for uefi" 1;
  cp /usr/lib/shim/shimx64.efi.signed.latest ${tftp_dir}/bootx64.efi;
  cp /usr/lib/grub/x86_64-efi-signed/grubnetx64.efi.signed ${tftp_dir}/grubx64.efi;

  # Creates GRUB config file
  [ ${debug} -eq 1 ] && Debug "Creating GRUB config file" 1;
  cat >${grub_dir}/grub.cfg <<EOL
set timeout=10
set default="rescuezilla"
menuentry "Start Rescuezilla" --id rescuezilla {
  linux ${iso_name}/vmlinuz url=http://${net_ipaddr}/${iso_name}/${iso_name}.iso ip=dhcp boot=casper quiet noprompt noeject toram edd=on locale=pt_BR console-setup/layoutcode=br bootkbd=br fsck.mode=skip fastboot splash ---
  initrd ${iso_name}/initrd.lz
}
EOL

  # Creates UEFI config file
  [ ${debug} -eq 1 ] && Debug "Creating UEFI config file" 1;
  mkdir -p ${tftp_dir}/pxelinux.cfg;
  cat >${tftp_dir}/pxelinux.cfg/default <<EOL
DEFAULT rescuezilla
LABEL rescuezilla
MENU LABEL rescuezilla
KERNEL ${iso_name}/vmlinuz url=http://${net_ipaddr}/${iso_name}/${iso_name}.iso ip=dhcp boot=casper quiet noprompt noeject toram edd=on fsck.mode=skip fastboot splash 
INITRD ${iso_name}/initrd.lz
APPEND root=/dev/ram0 ramdisk_size=15000000 
EOL
}

# Configure dnsmasq
function ConfigDNSmasq {
  # Debug?
  [ ${debug} -eq 1 ] && Debug "Configure dnsmasq (${1})" 2;

  # UEFI or BIOS?
  [ ${1} == "UEFI" ] && dhcp_boot="bootx64.efi";
  [ ${1} == "BIOS" ] && dhcp_boot="lpxelinux.0";
  [ ${debug} -eq 1 ] && Debug "dhcp_boot = [${dhcp_boot}]" 1;
  
  # Cat to the dnsmasq config file  
  cat >/etc/dnsmasq.d/pxe.conf <<EOL
interface=${net_interf}
bind-interfaces
dhcp-range=${net_range1},${net_range2},${net_broadc}
dhcp-boot=${dhcp_boot}
enable-tftp
tftp-root=${tftp_dir}
port=0
EOL

  # Restart dnsmasq service
  [ ${debug} -eq 1 ] && Debug "Restarting dnsmasq service" 1;
  systemctl restart dnsmasq
}

# Configure samba
function ConfigSamba {
  # Debug?
  [ ${debug} -eq 1 ] && Debug "Configure samba" 2;

  cat >/etc/samba/smb.conf <<EOL
# Globals
[global]
  workgroup = WORKGROUP
  server string = %h server (Samba, Ubuntu)
  log file = /var/log/samba/log.%m
  max log size = 1000
  logging = file
  panic action = /usr/share/samba/panic-action %d
  server role = standalone server
  obey pam restrictions = yes
  unix password sync = yes
  passwd program = /usr/bin/passwd %u
  passwd chat = *Enter\snew\s*\spassword:* %n\n *Retype\snew\s*\spassword:* %n\n *password\supdated\ssuccessfully* .
  pam password change = yes
  map to guest = bad user
  usershare allow guests = yes

# Shares
[Imagens]
  command = Imagens de instalacao
  path = /srv/samba/imagens
  browseable = yes
  read only = yes
  guest ok = yes
  
# End
EOL
  
  # Restart samba services
  [ ${debug} -eq 1 ] && Debug "Restarting services (nmbd and smbd)" 1;
  systemctl restart nmbd;
  systemctl restart smbd;
}


#
# MAIN
#
  # Remove old directory
  #rm -rf ${tftp_dir};

  # Create directories, if they do not exist
  [ ${debug} -eq 1 ] && Debug "Creating directories" 1;
  mkdir -p ${tftp_dir};
  mkdir -p ${dist_dir};
  mkdir -p ${grub_dir};
 
  # Begin processing
  GetPackages;
  GetImage;
  ConfigureNETBoot;
  ConfigDNSmasq "UEFI";
  ConfigSamba;

  exit;
#
# EOF
#
