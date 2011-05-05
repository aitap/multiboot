Tiny Core accepts the following additional boot time options:

 tinycore {cron|syslog}              Start various daemons at boot
 tinycore host=xxxx                  Set hostname to xxxx
 tinycore secure                     Set password
 tinycore protect                    Password Encrypted Backup
 tinycore noautologin                Skip automatic login
 tinycore tz=GMT+8                   Timezone tz=PST+8PDT,M3.2.0/2,M11.1.0/2
 tinycore user=abc                   Specify alternate user
 tinycore desktop=yyy                Specify alternate window manager
 tinycore laptop                     Force load laptop related modules
 tinycore embed                      Stay on initramfs
 tinycore nozswap                    Skip compressed swap in ram
 tinycore xvesa=800x600x32           Set Xvesa default screen resolution
 tinycore mydata=yyyy                Specify alternate name for backup file
 tinycore blacklist=ssb              Blacklist a single module
 tinycore multivt                    Allows for multiple virtual terminals
 
