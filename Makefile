#!/usr/bin/make -f

CONTENTS := contents
DOWNLOAD := download
CONFIGS := configs
SCRIPTS := scripts
SUDO := sudo

IMAGES := $(sysrcd_cfg) $(grub4dos_files)
ALL_IMAGES := $(IMAGES) $(knoppix_files) $(porteus_cfg) $(kav_files) $(drweb_cfg)

.PHONY: all clean copy_over install_bootloader

# macros

# url, regexp, save_to
define LOAD_LINK
	@echo -e '\e[1m[ DOWNLOAD ]\e[0m $(1) -> $(2) -> $(3)'
	@perl "$(SCRIPTS)/download.pl" "$(1)" "$(3)" $(2)
endef

# image boot_path config kernel_parameter target_config [title]
define GEN_CONFIG
	@echo -e '\e[1m[ GENERATE CONFIG ]\e[0m $(1) / $(2) / $(3) + $(4) -> $(5)'
	@7z e -so $(CONTENTS)/$(1) $(2)/$(3) | perl "$(SCRIPTS)/syslinux2grub.pl" $(4)=/$(1) /$(2) /$(1) $(6) > $(5)
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

sysrcd_cfg := $(CONTENTS)/boot/grub/sysrcd.cfg.in
$(sysrcd_cfg): $(sysrcd_iso)
	$(call GEN_CONFIG,boot/sysrcd.iso,isolinux,isolinux.cfg,isoloop,$(sysrcd_cfg))
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

porteus_cfg := $(CONTENTS)/boot/grub/porteus.cfg.in
$(porteus_cfg): $(porteus_iso)
	$(call GEN_CONFIG,boot/porteus.iso,boot/syslinux,porteus.cfg,from,$(porteus_cfg))
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

kav_files := $(CONTENTS)/boot/grub/kav.cfg.in $(CONTENTS)/liveusb
$(kav_files): $(kav_iso) scripts/kav_fixup.awk
	echo 'submenu "Kaspersky Rescue Disk" {' > $(CONTENTS)/boot/grub/kav.cfg.in
	echo set kav_lang=ru >> $(CONTENTS)/boot/grub/kav.cfg.in
	7z e -so $(kav_iso) boot/grub/i386-pc/cfg/en.cfg >> $(CONTENTS)/boot/grub/kav.cfg.in
	echo >> $(CONTENTS)/boot/grub/kav.cfg.in
	$(foreach platform,efi pc, \
		7z e -so $(kav_iso) boot/grub/i386-$(platform)/cfg/kav_menu.cfg \
			| awk -v platform=$(platform) -f $(SCRIPTS)/kav_fixup.awk \
			>> $(CONTENTS)/boot/grub/kav.cfg.in; \
	)
	echo '}' >> $(CONTENTS)/boot/grub/kav.cfg.in
	touch $(CONTENTS)/liveusb
kav_files: $(kav_files)

drweb_iso := $(DOWNLOAD)/drweb.iso
$(drweb_iso): | $(base)
	wget -c -O $(drweb_iso) https://download.geo.drweb.com/pub/drweb/livedisk/drweb-livedisk-900-cd.iso
	touch $(drweb_iso)
drweb_iso: $(drweb_iso)

# DrWeb LiveDisk's casper doesn't support iso-scan/filename
drweb_files := $(CONTENTS)/boot/grub/drweb.cfg.in $(CONTENTS)/boot/drweb
$(drweb_files): $(drweb_iso)
	7z x -o$(CONTENTS) $(drweb_iso) .disk
	7z e -o$(CONTENTS)/boot/drweb $(drweb_iso) casper
	7z e -o$(CONTENTS)/boot/drweb $(drweb_iso) install/mt86plus
	7z e -so $(drweb_iso) isolinux/txt.cfg \
		| env FORCE_BOOT_PATH=1 perl "$(SCRIPTS)/syslinux2grub.pl" live-media-path=boot/drweb /boot/drweb "" "DrWeb LiveDisk" \
		> $(CONTENTS)/boot/grub/drweb.cfg.in
drweb_files: $(drweb_files)

memtest_iso := $(DOWNLOAD)/memtest.iso
$(memtest_iso): | $(base)
	wget -c -O $(DOWNLOAD)/memtest.tgz http://memtest86.com/downloads/memtest86-iso.tar.gz
	tar xvOf $(DOWNLOAD)/memtest.tgz --wildcards "*.iso" > $(memtest_iso)
memtest_iso: $(memtest_iso)

memtest_files := $(CONTENTS)/boot/memtest86 $(CONTENTS)/boot/grub/memtest.cfg.in
$(memtest_files): $(memtest_iso) $(CONFIGS)/memtest.cfg
	7z e -o$(CONTENTS)/boot/memtest86 $(memtest_iso) EFI/BOOT/ ISOLINUX/MEMTEST
	cp $(CONFIGS)/memtest.cfg $(CONTENTS)/boot/grub/memtest.cfg.in
memtest_files: $(memtest_files)

# build loader config

config := $(CONTENTS)/boot/grub/grub.cfg
$(config): $(CONTENTS)/boot/grub/*.cfg.in $(CONFIGS)/grub.cfg | $(base)
	cp $(CONFIGS)/grub.cfg $(config)
	for file in $(CONTENTS)/boot/grub/*.cfg.in; do echo ". \$$prefix/$$(basename $$file)" >> $(config); done
config: $(config)

copy_over: $(config)
	test -d "$(TARGET_DIR)"
	rsync -urvP --inplace --modify-window=2 "$(CONTENTS)/" "$(TARGET_DIR)/"

install_bootloader:
	test -d "$(TARGET_DIR)" && test -b "$(TARGET_DEV)"
	$(SUDO) grub-install --boot-directory="$(TARGET_DIR)/boot" --target=i386-pc "$(TARGET_DEV)"
	$(foreach arch,i386 x86_64, \
		$(SUDO) grub-install --boot-directory="$(TARGET_DIR)/boot" --target=$(arch)-efi \
			--efi-directory="$(TARGET_DIR)" --removable --no-nvram; \
	)
