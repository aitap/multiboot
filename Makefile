#!/usr/bin/make -f

CONTENTS := contents
DOWNLOAD := download
CONFIGS := configs
SCRIPTS := scripts

MOUNTPOINT := /mnt
MOUNT := mount -o loop
UMOUNT := umount

IMAGES := $(sysrcd_cfg) $(grub4dos_files)
ALL_IMAGES := $(IMAGES) porteus $(knoppix_files)

.PHONY: all clean

# macros

# url, regexp, save_to
define LOAD_LINK
	@echo -e '\e[1m[ DOWNLOAD ]\e[0m $(1) -> $(2) -> $(3)'
	@perl "$(SCRIPTS)/download.pl" "$(1)" "$(3)" $(2)
endef

# base

all: $(base) $(IMAGES) $(config)

base := $(DOWNLOAD) $(CONTENTS) $(CONTENTS)/boot/grub
$(base):
	mkdir -pv $(base)
	touch $(base)
base: $(base)

clean:
	rm -rvf $(ALL_IMAGES) $(CONTENTS) $(DOWNLOAD)

# images themselves, download and extract separately

sysrcd_iso := $(CONTENTS)/boot/sysrcd.iso
$(sysrcd_iso): | $(base)
	$(call LOAD_LINK,http://www.sysresccd.org/Download,systemrescuecd-x86-[\\d.]+\\.iso/download,$(sysrcd_iso))
	touch $(sysrcd_iso)
sysrcd_iso: $(sysrcd_iso)

# TODO: isoloop=/path/to/file.iso
sysrcd_cfg := $(CONTENTS)/boot/grub/sysrcd.cfg.in
$(sysrcd_cfg): $(sysrcd_iso) $(CONFIGS)/sysrcd.cfg
	cp $(CONFIGS)/sysrcd.cfg $(sysrcd_cfg)
	touch $(sysrcd_cfg)
sysrcd_cfg: $(sysrcd_cfg)

grub4dos_7z := $(DOWNLOAD)/grub4dos.7z
$(grub4dos_7z): | $(base)
	$(call LOAD_LINK,http://grub4dos.chenall.net/categories/downloads/,/downloads/grub4dos-[\\dabc.-]+/ grub4dos-[\\dabc.-]+\.7z,$(grub4dos_7z))
	touch $(grub4dos_7z)
grub4dos_7z: $(grub4dos_7z)

grub4dos_files := $(CONTENTS)/boot/grub.exe $(CONTENTS)/boot/grub/grub4dos.cfg.in
$(grub4dos_files): $(grub4dos_7z) $(CONFIGS)/grub4dos.cfg
	7z e -y -i'!grub4dos-*/grub.exe' -o"$(CONTENTS)/boot" "$(DOWNLOAD)/grub4dos.7z"
	cp -v "$(CONFIGS)/grub4dos.cfg" "$(CONTENTS)/boot/grub/grub4dos.cfg.in"
	touch $(grub4dos_files)
grub4dos_files: $(grub4dos_files)

porteus_desktop := XFCE

porteus_iso := $(CONTENTS)/boot/porteus.iso
$(porteus_iso): | $(base)
	@echo "Additional parameters: porteus_desktop=$(porteus_desktop)"
	$(call LOAD_LINK,http://dl.porteus.org/i586/current/,Porteus-$(porteus_desktop)-v[0-9.]+-i586\\.iso,$(porteus_iso))
	touch $(porteus_iso)
porteus_iso: $(porteus_iso)

# TODO: from=/path/to/file.iso
porteus_cfg := $(CONTENTS)/boot/grub/porteus.cfg.in
$(porteus_cfg): $(porteus_iso) $(CONFIGS)/porteus.cfg
	cp $(CONFIGS)/porteus.cfg $(porteus_cfg)
porteus_cfg: $(porteus_cfg)

# For now, update torrent URL manually. It's not like KNOPPIX is released every week.
knoppix_torrent := http://torrent.unix-ag.uni-kl.de/torrents/KNOPPIX_V7.7.1DVD-2016-10-22-EN.torrent
knoppix_iso := $(DOWNLOAD)/KNOPPIX_V7.7.1DVD-2016-10-22-EN/KNOPPIX_V7.7.1DVD-2016-10-22-EN.iso
$(knoppix_iso): | $(base)
	aria2c --seed-time=0 --allow-overwrite=true -d $(DOWNLOAD) $(knoppix_torrent) # please seed separately
knoppix_iso: $(knoppix_iso)

# Knoppix has to be unpacked because it's more than 4G, but consists of less-than-4G files
knoppix_files := $(CONTENTS)/boot/KNOPPIX $(CONTENTS)/boot/grub/knoppix.cfg.in
$(knoppix_files): $(knoppix_iso) $(CONFIGS)/knoppix.cfg
	7z x -o$(CONTENTS)/boot $(knoppix_iso) KNOPPIX/KNOPPIX KNOPPIX/KNOPPIX1 KNOPPIX/kversion
	7z e -o$(CONTENTS)/boot/KNOPPIX $(knoppix_iso) $(foreach f,linux linux64 minirt.gz,boot/isolinux/$(f))
	cp -v $(CONFIGS)/knoppix.cfg $(CONTENTS)/boot/grub/knoppix.cfg.in
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

config := $(CONTENTS)/boot/grub/grub.cfg
$(config): $(CONTENTS)/boot/grub/*.cfg.in | $(base)
	: > $(config)
	for file in $^; do echo ". $$(basename $$file)" >> $(config); done
	# grub variables: grub_platform=efi/pc; grub_cpu=x86_64/i386
config: $(config)

# TODO: install loader on the thumbdrive, both BIOS boot sector and EFI files

# TODO: copy the boot files to the bootable thumbdrive
