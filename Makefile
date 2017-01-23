#!/usr/bin/make -f

CONTENTS := contents
DOWNLOAD := download
CONFIGS := configs
SCRIPTS := scripts

MOUNTPOINT := /mnt
MOUNT := mount -o loop
UMOUNT := umount

IMAGES := sysrcd $(grub4dos_krn)
ALL_IMAGES := $(IMAGES) porteus $(knoppix_files)

.PHONY: all clean syslinux-usb install-usb

# macros

# url, regexp, save_to
define LOAD_LINK
	@echo -e '\e[1m[ DOWNLOAD ]\e[0m $(1) -> $(2) -> $(3)'
	@perl "$(SCRIPTS)/download.pl" "$(1)" "$(3)" $(2)
endef

# iso
define AUTOMOUNT
	@echo -e '\e[1m[ MOUNT ]\e[0m $(1)'
	@$(MOUNT) "$(DOWNLOAD)/$(1)" "$(MOUNTPOINT)"
endef

# fullname, target_config, (src_config)
define AUTOCOPY
	@echo -e '\e[1m[ AUTOCOPY ]\e[0m -> "$(1)"'
	@perl "$(SCRIPTS)/syslinux.pm" -s "$(MOUNTPOINT)" -t "$(CONTENTS)" -c "$(3)" -a "$(CONTENTS)/isolinux/$(2)" -n "$(1)"
endef

define AUTOUNMOUNT
	@echo -e '\e[1m[ UNMOUNT ]\e[0m'
	@$(UMOUNT) $(MOUNTPOINT)
endef

# base

all: $(base) $(IMAGES) $(config)

base := $(DOWNLOAD) $(CONTENTS) $(CONTENTS)/isolinux $(CONTENTS)/boot
$(base):
	mkdir -pv $(base)
	touch $(base)
base: $(base)

clean:
	rm -rvf $(ALL_IMAGES) $(CONTENTS) $(DOWNLOAD)

# loader

syslinux := $(DOWNLOAD)/syslinux-nomtools $(CONTENTS)/isolinux/menu.c32
$(syslinux): | $(base)
	$(call LOAD_LINK,http://www.kernel.org/pub/linux/utils/boot/syslinux/?C=M;O=D,syslinux-4\\.[0-9]+\\.tar\\.xz,syslinux.tar.xz)
	tar --wildcards -xvOf "$(DOWNLOAD)/syslinux.tar.xz" "syslinux-*/linux/syslinux-nomtools" > "$(DOWNLOAD)/syslinux-nomtools"
	tar --wildcards -xvOf "$(DOWNLOAD)/syslinux.tar.xz" "syslinux-*/com32/menu/menu.c32" > "$(CONTENTS)/isolinux/menu.c32"
	chmod +x "$(DOWNLOAD)/syslinux-nomtools"
	touch $(syslinux)
syslinux: $(syslinux)

# images themselves, download and extract separately

sysrcd_iso := $(CONTENTS)/boot/sysrcd.iso
$(sysrcd_iso): | $(base)
	$(call LOAD_LINK,http://www.sysresccd.org/Download,systemrescuecd-x86-[\\d.]+\\.iso/download,$(sysrcd_iso))
	touch $(sysrcd_iso)
sysrcd_iso: $(sysrcd_iso)
# TODO: use the isoloop=/path/to/file.iso kernel parameter
sysrcd: $(sysrcd_iso)
	$(call AUTOMOUNT,sysrcd.iso)
	$(call AUTOCOPY,SystemRescueCD,sysrcd.cfg)
	mkdir -p "$(CONTENTS)/sysrcd"
	set -e;\
	for file in sysrcd.dat sysrcd.md5 version;\
		do cp -rv "$(MOUNTPOINT)/$$file" "$(CONTENTS)";\
	done
	$(call AUTOUNMOUNT)
	touch sysrcd

grub4dos_7z := $(DOWNLOAD)/grub4dos.7z
$(grub4dos_7z): | $(base)
	$(call LOAD_LINK,http://grub4dos.chenall.net/categories/downloads/,/downloads/grub4dos-[\\dabc.-]+/ grub4dos-[\\dabc.-]+\.7z,$(grub4dos_7z))
	touch $(grub4dos_7z)
grub4dos_7z: $(grub4dos_7z)

grub4dos_krn := $(CONTENTS)/boot/grub.exe
$(grub4dos_krn): $(grub4dos_7z)
	7z e -y -i'!grub4dos-*/grub.exe' -o"$(CONTENTS)/boot" "$(DOWNLOAD)/grub4dos.7z"
	cp -v "$(CONFIGS)/grub4dos.cfg" "$(CONTENTS)/isolinux/"
	touch $(grub4dos_krn)
grub4dos_krn: $(grub4dos_krn)

porteus_desktop := XFCE

porteus_iso := $(CONTENTS)/boot/porteus.iso
$(porteus_iso): | $(base)
	@echo "Additional parameters: porteus_desktop=$(porteus_desktop)"
	$(call LOAD_LINK,http://dl.porteus.org/i586/current/,Porteus-$(porteus_desktop)-v[0-9.]+-i586\\.iso,$(porteus_iso))
	touch $(porteus_iso)
porteus_iso: $(porteus_iso)
# TODO: use from=/path/to/file.iso kernel parameter
porteus: $(porteus_iso)
	$(call AUTOMOUNT,porteus.iso)
	$(call AUTOCOPY,Porteus,porteus.cfg,$(MOUNTPOINT)/boot/syslinux/porteus.cfg)
	mkdir -p "$(MOUNTPOINT)/porteus"
	cp -rv "$(MOUNTPOINT)/porteus/base" "$(MOUNTPOINT)/porteus/"*.sgn "$(CONTENTS)/porteus"
	$(call AUTOUNMOUNT)
	touch porteus

# For now, update torrent URL manually. It's not like KNOPPIX is released every week.
knoppix_torrent := http://torrent.unix-ag.uni-kl.de/torrents/KNOPPIX_V7.7.1DVD-2016-10-22-EN.torrent
knoppix_iso := $(DOWNLOAD)/KNOPPIX_V7.7.1DVD-2016-10-22-EN/KNOPPIX_V7.7.1DVD-2016-10-22-EN.iso
$(knoppix_iso): | $(base)
	aria2c --seed-time=0 --allow-overwrite=true -d $(DOWNLOAD) $(knoppix_torrent) # please seed separately
knoppix_iso: $(knoppix_iso)

# Knoppix has to be unpacked because it's more than 4G, but consists of less-than-4G files
knoppix_files := $(CONTENTS)/boot/KNOPPIX $(CONTENTS)/isolinux/knoppix.cfg
$(knoppix_files): $(knoppix_iso) $(CONFIGS)/knoppix.cfg
	7z x -o$(CONTENTS)/boot $(knoppix_iso) KNOPPIX/KNOPPIX KNOPPIX/KNOPPIX1 KNOPPIX/kversion
	7z e -o$(CONTENTS)/boot/KNOPPIX $(knoppix_iso) $(foreach f,linux linux64 minirt.gz,boot/isolinux/$(f))
	cp -v $(CONFIGS)/knoppix.cfg $(CONTENTS)/isolinux/knoppix.cfg
	touch $(knoppix_files)
knoppix_files: $(knoppix_files)

kav_iso := $(CONTENTS)/rescue/rescue.iso
$(kav_iso): | $(base)
	mkdir -pv $(CONTENTS)/rescue
	wget -c -O $(kav_iso) http://rescuedisk.kaspersky-labs.com/rescuedisk/updatable/kav_rescue_10.iso
	touch $(kav_iso)
kav_iso: $(kav_iso)

drweb_iso := $(CONTENTS)/boot/drweb.iso
$(drweb_iso): | $(base)
	wget -c -O $(drweb_iso) https://download.geo.drweb.com/pub/drweb/livedisk/drweb-livedisk-900-cd.iso
	touch $(drweb_iso)
drweb_iso: $(drweb_iso)

# build loader config

config := $(CONTENTS)/isolinux/isolinux.cfg
$(config): $(syslinux) | $(base)
	rm -vf "$(CONTENTS)/isolinux/config.cfg" "$(CONTENTS)/isolinux/isolinux.cfg"
	echo "INCLUDE config.cfg" > "$(CONTENTS)/isolinux/isolinux.cfg.1"
	for file in "$(CONTENTS)/isolinux/"*.cfg; do echo "INCLUDE $$(basename $$file)" >> "$(CONTENTS)/isolinux/isolinux.cfg.1"; done
	mv "$(CONTENTS)/isolinux/isolinux.cfg.1" "$(CONTENTS)/isolinux/isolinux.cfg"
	cp -v "$(CONFIGS)/config.cfg" "$(CONTENTS)/isolinux/"
	touch $(config)
config: $(config)

# install to thumbdrive

syslinux-usb: $(syslinux) | $(base)
	@if test -z "$(TARGET)"; then /bin/echo -e 'You have to define TARGET.'; exit 1; fi
	mount "$(TARGET)" "$(MOUNTPOINT)"
	mkdir -pv "$(MOUNTPOINT)/isolinux"
	umount "$(MOUNTPOINT)"
	"$(DOWNLOAD)/syslinux-nomtools" -d isolinux -i "$(TARGET)"

install-usb: all syslinux-usb
	@if test -z "$(TARGET)"; then echo "You have to define TARGET to make install-usb."; exit 1; fi
	mount "$(TARGET)" "$(MOUNTPOINT)"
	cp -Lrv "$(CONTENTS)/"* "$(MOUNTPOINT)"
	rm -fv "$(MOUNTPOINT)/isolinux/isolinux.bin"
	mv -v "$(MOUNTPOINT)/isolinux/isolinux.cfg" "$(MOUNTPOINT)/isolinux/syslinux.cfg"
	umount "$(MOUNTPOINT)"
