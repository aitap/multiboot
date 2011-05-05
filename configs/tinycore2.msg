Tiny Core accepts the following persistence options:

 tinycore tce={hda1|sda1}            Specify Restore TCE apps directory
 tinycore restore={hda1|sda1|floppy} Specify saved configuration location
 tinycore waitusb=X                  Wait X seconds for slow USB devices
 tinycore swapfile{=hda1}            Scan or Specify swapfile
 tinycore home={hda1|sda1}           Specify persistent home directory
 tinycore opt={hda1|sda1}            Specify persistent opt directory
 tinycore local={hda1|sda1}          Specify PPI directory or loopback file
 tinycore lst=yyy.lst                Load alternate static yyy.lst on boot
 tinycore base                       Skip TCE load only the base system
 tinycore norestore                  Turn off the automatic restore
 tinycore safebackup                 Saves a backup copy (mydatabk.tgz)
 tinycore showapps                   Display application names when booting
 
