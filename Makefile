#!/usr/bin/make -f

IMAGE := image.iso

MKISOFS := genisomage

CONTENTS := contents
DOWNLOAD := download
CONFIGS := configs
SCRIPTS := scripts

MOUNTPOINT := /mnt
MOUNT := mount
UMOUNT := umount

SYSTEMS := porteus finnix sysrcd grub4dos debian

.PHONY: all clean syslinux-usb install-usb burn

# макросы

# url, regexp, save_to
define LOAD_LINK
	@echo -e '\e[1m[ DOWNLOAD ]\e[0m $(1) -> $(2) -> $(3)'
	@perl "$(SCRIPTS)/download.pl" "$(1)" "$(2)" "$(DOWNLOAD)/$(3)"
endef

# iso
define AUTOMOUNT
	@echo -e '\e[1m[ MOUNT ]\e[0m $(1)'
	@$(MOUNT) -o loop "$(DOWNLOAD)/$(1)" "$(MOUNTPOINT)"
endef

# fullname, target_config, (src_config)
define AUTOCOPY
	@echo -e '\e[1m[ AUTOCOPY ]\e[0m -> "$(1)"'
	@perl "$(SCRIPTS)/syslinux-autocopy.pm" -s "$(MOUNTPOINT)" -t "$(CONTENTS)" -c "$(3)" -a "$(CONTENTS)/isolinux/$(2)" -n "$(1)"
endef

define AUTOUNMOUNT
	@echo -e '\e[1m[ UNMOUNT ]\e[0m'
	@$(UMOUNT) $(MOUNTPOINT)
endef

# базовые вещи

all: base $(SYSTEMS) config

base:
	mkdir -pv "$(CONTENTS)" "$(DOWNLOAD)" "$(CONTENTS)/isolinux"
	touch base

clean:
	rm -rvf "$(CONTENTS)" "$(DOWNLOAD)"
	rm -rvf base syslinux syslinux-iso syslinux-usb $(SYSTEMS) $(foreach sys,$(SYSTEMS),$(sys)-latest) iso config

# загрузчик

syslinux: base
	mkdir -pv "$(DOWNLOAD)/syslinux"
	$(call LOAD_LINK,http://www.kernel.org/pub/linux/utils/boot/syslinux/?C=M;O=D,syslinux-4\.[0-9]+\.tar\.xz,syslinux.tar.xz)
	set -e; for file in core/isolinux.bin linux/syslinux-nomtools com32/menu/menu.c32 com32/menu/vesamenu.c32; do tar --wildcards -xvOf "$(DOWNLOAD)/syslinux.tar.xz" "syslinux-*/$$file" > "$(DOWNLOAD)/syslinux/$$(basename $$file)"; done
	chmod +x "$(DOWNLOAD)/syslinux/syslinux-nomtools"
	touch syslinux

syslinux-iso: syslinux base
	cp "$(DOWNLOAD)/syslinux/isolinux.bin" "$(CONTENTS)/isolinux/"
	touch syslinux-iso

syslinux-usb: syslinux base
	@if test -z "$(TARGET)"; then /bin/echo -e 'You have to define TARGET.'; exit 1; fi
	$(MOUNT) "$(TARGET)" "$(MOUNTPOINT)"
	mkdir -pv "$(MOUNTPOINT)/isolinux"
	$(UMOUNT) "$(MOUNTPOINT)"
	"$(DOWNLOAD)/syslinux/syslinux-nomtools" -d isolinux -i "$(TARGET)"

# различные ОС, отдельно скачивание и установка

finnix-latest: base
	$(call LOAD_LINK,http://finnix.org/releases/current/,finnix-[0-9]+.iso,finnix.iso)
	touch finnix-latest

finnix: finnix-latest
	$(call AUTOMOUNT,finnix.iso)
	$(call AUTOCOPY,Finnix,finnix.cfg)
	cp -rv "$(MOUNTPOINT)/finnix/" "$(CONTENTS)"
	cp -v "$(MOUNTPOINT)/boot/x86/pci.ids" "$(CONTENTS)/finnix/"
	$(call AUTOUNMOUNT)
	touch finnix

sysrcd-latest: base
	$(call LOAD_LINK,http://www.sysresccd.org/Download,systemrescuecd-x86-[\d.]+\.iso/download,sysrcd.iso)
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
	$(call LOAD_LINK,http://code.google.com/p/grub4dos-chenall/downloads/list,grub4dos-[\dabc.-]+\.7z,grub4dos.7z)
	7z e -y -i'!grub4dos-*/grub.exe' -o"$(DOWNLOAD)" "$(DOWNLOAD)/grub4dos.7z"
	touch grub4dos-latest

grub4dos: grub4dos-latest
	cp -v "$(DOWNLOAD)/grub.exe" "$(CONTENTS)/isolinux/"
	cp -v "$(CONFIGS)/grub4dos.cfg" "$(CONTENTS)/isolinux/"
	touch grub4dos

love:
	@echo not war

debian-latest: base
	mkdir -p "$(DOWNLOAD)/debian"
	wget -O"$(DOWNLOAD)/debian/linux" http://cdimage.debian.org/debian/dists/squeeze/main/installer-i386/current/images/netboot/debian-installer/i386/linux
	wget -O"$(DOWNLOAD)/debian/initrd.gz" http://cdimage.debian.org/debian/dists/squeeze/main/installer-i386/current/images/netboot/debian-installer/i386/initrd.gz
	touch debian-latest

debian: debian-latest
	mkdir -pv $(CONTENTS)/debian/
	cp -v $(DOWNLOAD)/debian/linux $(DOWNLOAD)/debian/initrd.gz $(CONTENTS)/debian/
	cp -v $(CONFIGS)/debian.cfg $(CONTENTS)/isolinux/debian.cfg
	touch debian

porteus-latest: base
	$(call LOAD_LINK,http://www.ponce.cc/porteus/i486/current/,Porteus-v[0-9.]+-i486\.iso,porteus.iso)
	touch porteus-latest

porteus: porteus-latest
	$(call AUTOMOUNT,porteus.iso)
	$(call AUTOCOPY,Porteus,porteus.cfg,$(MOUNTPOINT)/boot/syslinux/porteus.cfg)
	cp -rv "$(MOUNTPOINT)/porteus" "$(CONTENTS)"
	$(call AUTOUNMOUNT)
	touch porteus

# сборка образа, установка на флешку

iso: base $(SYSTEMS) syslinux-iso config
	genisoimage -o "$(IMAGE)" \
	-l -J -R \
	-b isolinux/isolinux.bin -c isolinux/boot.cat \
	-no-emul-boot -boot-load-size 4 -boot-info-table \
	-V 'AITap Boot CD' \
	"$(CONTENTS)"
	touch iso
$(IMAGE): iso

install-usb: base $(SYSTEMS) syslinux-usb config
	@if test -z "$(TARGET)"; then echo "You have to define TARGET to make install-usb."; exit 1; fi
	$(MOUNT) "$(TARGET)" "$(MOUNTPOINT)"
	cp -Lrv "$(CONTENTS)/"* "$(MOUNTPOINT)"
	rm -fv "$(MOUNTPOINT)/isolinux/isolinux.bin"
	mv -v "$(MOUNTPOINT)/isolinux/isolinux.cfg" "$(MOUNTPOINT)/isolinux/syslinux.cfg"
	"$(UMOUNT)" "$(MOUNTPOINT)"

# сборка isolinux.cfg

config: base syslinux
	rm -vf "$(CONTENTS)/isolinux/config.cfg" "$(CONTENTS)/isolinux/isolinux.cfg"
	echo "INCLUDE config.cfg" > "$(CONTENTS)/isolinux/isolinux.cfg.1"
	for file in "$(CONTENTS)/isolinux/"*.cfg; do echo "INCLUDE $$(basename $$file)" >> "$(CONTENTS)/isolinux/isolinux.cfg.1"; done
	mv "$(CONTENTS)/isolinux/isolinux.cfg.1" "$(CONTENTS)/isolinux/isolinux.cfg"
	cp -v "$(DOWNLOAD)/syslinux/menu.c32" "$(CONFIGS)/config.cfg" "$(CONTENTS)/isolinux/"
	touch config
