Tiny Core accepts the following additional boot time options:

 Color            640x480     800x600      1024x768     1280x1024
   256    8 bit     769         771           773          775
 32000   15 bit     784         787           790          793
 65000   16 bit     785         788           791          794
 16.7M   24 bit     786         789           792          795

 tinycore vga=7xx                    7xx from table above
 tinycore xsetup                     Prompt user for Xvesa setup
 tinycore lang=en                    C only unless getlocale.tcz is installed
 tinycore kmap=us                    US only unless kmaps.tcz is installed
 tinycore text                       Textmode
 tinycore superuser                  Textmode as user root
 tinycore noicons                    Do not use icons
 tinycore noswap                     Do not use swap partition
 tinycore nodhcp                     Skip the dhcp request at boot
 tinycore noutc                      BIOS is using localtime
 tinycore pause                      Pause at completion of boot messages
 
