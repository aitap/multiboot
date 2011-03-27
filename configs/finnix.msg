


09Finnix07 version 0f93.0                07                    http://www.finnix.org/
Copyright (C) 1999-2000, 2005-2009 Ryan Finnie         http://www.finnie.org/
Compiled: Sat Aug  8 23:00:36 PDT 2009 (Build 2318)

The following is a partial list of boot options available in Finnix.  For a
full list of boot options, see http://www.finnix.org/Cheat_Codes.  
  toram - Copy disc to RAM, then eject the disc.  Requires 192MiB RAM.
  testcd - Verify checksums on all files on the CD.
  noeject - Do not eject the CD upon shutdown or toram.
  nodma - Use a generic ATA driver, and do not enable DMA support.
  nohwsetup, noboothwsetup - Do not automatically probe for hardware.
  noswap - Do not automatically mount found swap devices.
  nofstab - Do not let Finnix maintain its own automatic fstab mappings.
  nodhcp - Do not attempt DHCP addressing from any found interfaces.
  sshd - Scramble the root/finnix passwords, then start an SSH daemon.
  keyboard=de-latin1 - Use an alternative keyboard layout.
  tz=PST8PDT - Use a local timezone (UTC by default).
  nolvm, noraid, nocrypt - Do not autodetect LVM/MD-RAID/DM-Crypt devices.
  usbhid - Load USB HID drivers as soon as possible.
  rw - Attempt to mount the Finnix "disc" R/W (useful for USB flash drives).
  nfsroot=... - Boot from NFS.  See web site for full usage.

Press ESC to return to the main menu.
