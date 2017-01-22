#!/usr/bin/make -f

CONTENTS := contents
DOWNLOAD := download
CONFIGS := configs
SCRIPTS := scripts

MOUNTPOINT := /mnt
MOUNT := mount -o loop
UMOUNT := umount

IMAGES := sysrcd grub4dos debian
ALL_IMAGES := $(IMAGES) porteus

.PHONY: all clean syslinux-usb install-usb burn

# macros

# url, regexp, save_to
define LOAD_LINK
	@echo -e '\e[1m[ DOWNLOAD ]\e[0m $(1) -> $(2) -> $(3)'
	@perl "$(SCRIPTS)/download.pl" "$(1)" "$(DOWNLOAD)/$(3)" $(2)
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

all: base $(IMAGES) config

base:
	mkdir -pv "$(CONTENTS)" "$(DOWNLOAD)" "$(CONTENTS)/isolinux"
	touch base

clean:
	rm -rvf "$(CONTENTS)" "$(DOWNLOAD)"
	rm -rvf base syslinux syslinux-usb $(ALL_IMAGES) $(foreach sys,$(ALL_IMAGES),$(sys)-latest) config

# loader

syslinux: base
	mkdir -pv "$(DOWNLOAD)/syslinux"
	$(call LOAD_LINK,http://www.kernel.org/pub/linux/utils/boot/syslinux/?C=M;O=D,syslinux-4\\.[0-9]+\\.tar\\.xz,syslinux.tar.xz)
	set -e; for file in core/isolinux.bin linux/syslinux-nomtools com32/menu/menu.c32 com32/menu/vesamenu.c32; do tar --wildcards -xvOf "$(DOWNLOAD)/syslinux.tar.xz" "syslinux-*/$$file" > "$(DOWNLOAD)/syslinux/$$(basename $$file)"; done
	chmod +x "$(DOWNLOAD)/syslinux/syslinux-nomtools"
	touch syslinux

# images themselves, download and extract separately

sysrcd-latest: base
	$(call LOAD_LINK,http://www.sysresccd.org/Download,systemrescuecd-x86-[\\d.]+\\.iso/download,sysrcd.iso)
	touch sysrcd-latest

sysrcd: sysrcd-latest
	$(call AUTOMOUNT,sysrcd.iso)
	$(call AUTOCOPY,SystemRescueCD,sysrcd.cfg)
	mkdir -p "$(CONTENTS)/sysrcd"
	set -e;\
	for file in sysrcd.dat sysrcd.md5 version;\
		do cp -rv "$(MOUNTPOINT)/$$file" "$(CONTENTS)";\
	done
	$(call AUTOUNMOUNT)
	touch sysrcd

grub4dos-latest: base
	$(call LOAD_LINK,http://grub4dos.chenall.net/categories/downloads/,/downloads/grub4dos-[\\dabc.-]+/ grub4dos-[\\dabc.-]+\.7z,grub4dos.7z)
	7z e -y -i'!grub4dos-*/grub.exe' -o"$(DOWNLOAD)" "$(DOWNLOAD)/grub4dos.7z"
	touch grub4dos-latest

grub4dos: grub4dos-latest
	cp -v "$(DOWNLOAD)/grub.exe" "$(CONTENTS)/isolinux/"
	cp -v "$(CONFIGS)/grub4dos.cfg" "$(CONTENTS)/isolinux/"
	touch grub4dos

debian-latest: base
	mkdir -p "$(DOWNLOAD)/debian"
	wget -O"$(DOWNLOAD)/debian/linux" http://cdimage.debian.org/debian/dists/stable/main/installer-i386/current/images/netboot/debian-installer/i386/linux
	wget -O"$(DOWNLOAD)/debian/initrd.gz" http://cdimage.debian.org/debian/dists/stable/main/installer-i386/current/images/netboot/debian-installer/i386/initrd.gz
	touch debian-latest

debian: debian-latest
	mkdir -pv $(CONTENTS)/debian/
	cp -v $(DOWNLOAD)/debian/linux $(DOWNLOAD)/debian/initrd.gz $(CONTENTS)/debian/
	cp -v $(CONFIGS)/debian.cfg $(CONTENTS)/isolinux/debian.cfg
	touch debian

porteus_desktop := XFCE

porteus-latest: base
	@echo "Additional parameters: porteus_desktop=$(porteus_desktop)"
	$(call LOAD_LINK,http://dl.porteus.org/i486/current/,Porteus-$(porteus_desktop)-v[0-9.]+-i486\\.iso,porteus.iso)
	touch porteus-latest

porteus: porteus-latest
	$(call AUTOMOUNT,porteus.iso)
	$(call AUTOCOPY,Porteus,porteus.cfg,$(MOUNTPOINT)/boot/syslinux/porteus.cfg)
	mkdir -p "$(MOUNTPOINT)/porteus"
	cp -rv "$(MOUNTPOINT)/porteus/base" "$(MOUNTPOINT)/porteus/"*.sgn "$(CONTENTS)/porteus"
	$(call AUTOUNMOUNT)
	touch porteus

# build loader config

config: base syslinux
	rm -vf "$(CONTENTS)/isolinux/config.cfg" "$(CONTENTS)/isolinux/isolinux.cfg"
	echo "INCLUDE config.cfg" > "$(CONTENTS)/isolinux/isolinux.cfg.1"
	for file in "$(CONTENTS)/isolinux/"*.cfg; do echo "INCLUDE $$(basename $$file)" >> "$(CONTENTS)/isolinux/isolinux.cfg.1"; done
	mv "$(CONTENTS)/isolinux/isolinux.cfg.1" "$(CONTENTS)/isolinux/isolinux.cfg"
	cp -v "$(DOWNLOAD)/syslinux/menu.c32" "$(CONFIGS)/config.cfg" "$(CONTENTS)/isolinux/"
	touch config

# install to thumbdrive

syslinux-usb: syslinux base
	@if test -z "$(TARGET)"; then /bin/echo -e 'You have to define TARGET.'; exit 1; fi
	mount "$(TARGET)" "$(MOUNTPOINT)"
	mkdir -pv "$(MOUNTPOINT)/isolinux"
	umount "$(MOUNTPOINT)"
	"$(DOWNLOAD)/syslinux/syslinux-nomtools" -d isolinux -i "$(TARGET)"

install-usb: all syslinux-usb
	@if test -z "$(TARGET)"; then echo "You have to define TARGET to make install-usb."; exit 1; fi
	mount "$(TARGET)" "$(MOUNTPOINT)"
	cp -Lrv "$(CONTENTS)/"* "$(MOUNTPOINT)"
	rm -fv "$(MOUNTPOINT)/isolinux/isolinux.bin"
	mv -v "$(MOUNTPOINT)/isolinux/isolinux.cfg" "$(MOUNTPOINT)/isolinux/syslinux.cfg"
	umount "$(MOUNTPOINT)"
