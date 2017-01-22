#!/usr/bin/make -f

CONTENTS := contents
DOWNLOAD := download
CONFIGS := configs
SCRIPTS := scripts

MOUNTPOINT := /mnt
MOUNT := mount -o loop
UMOUNT := umount

IMAGES := sysrcd $(debian_cfg) $(grub4dos_krn)
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
	rm -rvf base syslinux $(ALL_IMAGES) config

# loader

syslinux: base
	mkdir -pv "$(DOWNLOAD)/syslinux"
	$(call LOAD_LINK,http://www.kernel.org/pub/linux/utils/boot/syslinux/?C=M;O=D,syslinux-4\\.[0-9]+\\.tar\\.xz,syslinux.tar.xz)
	set -e; for file in core/isolinux.bin linux/syslinux-nomtools com32/menu/menu.c32 com32/menu/vesamenu.c32; do tar --wildcards -xvOf "$(DOWNLOAD)/syslinux.tar.xz" "syslinux-*/$$file" > "$(DOWNLOAD)/syslinux/$$(basename $$file)"; done
	chmod +x "$(DOWNLOAD)/syslinux/syslinux-nomtools"
	touch syslinux

# images themselves, download and extract separately

sysrcd_iso := $(DOWNLOAD)/sysrcd.iso
$(sysrcd_iso): base
	$(call LOAD_LINK,http://www.sysresccd.org/Download,systemrescuecd-x86-[\\d.]+\\.iso/download,sysrcd.iso)
	touch $(sysrcd_iso)
sysrcd_iso: $(sysrcd_iso)

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
$(grub4dos_7z): base
	$(call LOAD_LINK,http://grub4dos.chenall.net/categories/downloads/,/downloads/grub4dos-[\\dabc.-]+/ grub4dos-[\\dabc.-]+\.7z,grub4dos.7z)
	touch $(grub4dos_7z)
grub4dos_7z: $(grub4dos_7z)

grub4dos_krn := $(CONTENTS)/isolinux/grub.exe
$(grub4dos_krn): $(grub4dos_7z)
	7z e -y -i'!grub4dos-*/grub.exe' -o"$(CONTENTS)/isolinux" "$(DOWNLOAD)/grub4dos.7z"
	cp -v "$(CONFIGS)/grub4dos.cfg" "$(CONTENTS)/isolinux/"
	touch $(grub4dos_krn)
grub4dos_krn: $(grub4dos_krn)

debian_images := $(CONTENTS)/debian/linux $(CONTENTS)/debian/initrd.gz
$(debian_images): base
	mkdir -pv $(CONTENTS)/debian/
	wget -N -P $(CONTENTS)/debian http://cdimage.debian.org/debian/dists/stable/main/installer-i386/current/images/netboot/debian-installer/i386/linux http://cdimage.debian.org/debian/dists/stable/main/installer-i386/current/images/netboot/debian-installer/i386/initrd.gz
	touch $(debian_images)
debian_images: $(debian_images)

debian_firmware := $(DOWNLOAD)/debian_firmware.tgz
# http://cdimage.debian.org/cdimage/unofficial/non-free/firmware/stable/current/firmware.tar.gz

debian_cfg := $(CONTENTS)/isolinux/debian.cfg
$(debian_cfg): $(debian_images)
	cp -v $(CONFIGS)/debian.cfg $(CONTENTS)/isolinux/debian.cfg
	touch $(debian_cfg)
debian_cfg: $(debian_cfg)

porteus_desktop := XFCE

porteus_iso := $(DOWNLOAD)/porteus.iso
$(porteus_iso): base
	@echo "Additional parameters: porteus_desktop=$(porteus_desktop)"
	$(call LOAD_LINK,http://dl.porteus.org/i586/current/,Porteus-$(porteus_desktop)-v[0-9.]+-i586\\.iso,porteus.iso)
	touch $(porteus_iso)
porteus_iso: $(porteus_iso)

porteus: $(porteus_iso)
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
