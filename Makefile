#!/usr/bin/make -f

CONTENTS := contents
DOWNLOAD := download
SUDO := sudo

.PHONY: clean copy_over install_bootloader

# macros

# url, regexp, save_to
define LOAD_LINK
	@echo -e '\e[1m[ DOWNLOAD ]\e[0m $(1) -> $(2) -> $(3)'
	@perl "scripts/download.pl" "$(1)" "$(3)" $(2)
endef

# image boot_path config kernel_parameter target_config [title]
define GEN_CONFIG
	@echo -e '\e[1m[ GENERATE CONFIG ]\e[0m $(1) / $(2) / $(3) + $(4) -> $(5)'
	@7z e -so $(CONTENTS)/$(1) $(2)/$(3) | perl "scripts/syslinux2grub.pl" $(4)=/$(1) /$(2) /$(1) $(6) > $(5)
endef

# base

base := $(DOWNLOAD) $(CONTENTS) $(CONTENTS)/boot/grub
$(base):
	mkdir -pv $(base)
	touch $(base)
base: $(base)

# images themselves, download and extract separately

sysrcd_iso := $(CONTENTS)/boot/sysrcd.iso
$(sysrcd_iso): | $(base)
	$(call LOAD_LINK,http://www.sysresccd.org/Download,systemrescuecd-[\\d.]+\\.iso systemrescuecd-[\\d.]+\\.iso,$(sysrcd_iso))
	touch $(sysrcd_iso)
sysrcd_iso: $(sysrcd_iso)

sysrcd := $(CONTENTS)/boot/grub/sysrcd.cfg.in
$(sysrcd): $(sysrcd_iso)
	$(call GEN_CONFIG,boot/sysrcd.iso,sysresccd/boot/syslinux,sysresccd_sys.cfg,img_loop,$(sysrcd),"System Rescue CD")
sysrcd: $(sysrcd)

grub4dos_7z := $(DOWNLOAD)/grub4dos.7z
$(grub4dos_7z): | $(base)
	$(call LOAD_LINK,http://grub4dos.chenall.net/categories/downloads/,/downloads/grub4dos-[\\dabc.-]+/ grub4dos-[\\dabc.-]+\.7z,$(grub4dos_7z))
	touch $(grub4dos_7z)
grub4dos_7z: $(grub4dos_7z)

grub4dos := $(CONTENTS)/boot/grub.exe $(CONTENTS)/boot/grub/grub4dos.cfg.in
$(grub4dos): $(grub4dos_7z) configs/grub4dos.cfg
	7z e -y -i'!grub4dos-*/grub.exe' -o"$(CONTENTS)/boot" "$(DOWNLOAD)/grub4dos.7z"
	cp -v "configs/grub4dos.cfg" "$(CONTENTS)/boot/grub/grub4dos.cfg.in"
	touch $(grub4dos)
grub4dos: $(grub4dos)

porteus_desktop := XFCE

porteus_iso := $(CONTENTS)/boot/porteus.iso
$(porteus_iso): | $(base)
	@echo "Additional parameters: porteus_desktop=$(porteus_desktop)"
	$(call LOAD_LINK,http://dl.porteus.org/i586/current/,Porteus-$(porteus_desktop)-v[0-9.]+-i586\\.iso,$(porteus_iso))
	touch $(porteus_iso)
porteus_iso: $(porteus_iso)

porteus := $(CONTENTS)/boot/grub/porteus.cfg.in
$(porteus): $(porteus_iso)
	$(call GEN_CONFIG,boot/porteus.iso,boot/syslinux,porteus.cfg,from,$(porteus))
porteus: $(porteus)

# For now, update torrent URL manually. It's not like KNOPPIX is released every week.
knoppix_torrent := http://torrent.unix-ag.uni-kl.de/torrents/KNOPPIX_V8.2-2018-05-10-EN.torrent
knoppix_iso := $(DOWNLOAD)/KNOPPIX_V8.2-2018-05-10-EN/KNOPPIX_V8.2-2018-05-10-EN.iso
$(knoppix_iso): | $(base)
	aria2c --seed-time=0 --allow-overwrite=true -d $(DOWNLOAD) $(knoppix_torrent) # please seed separately
knoppix_iso: $(knoppix_iso)

# Knoppix has to be unpacked because it's more than 4G, but consists of less-than-4G files
knoppix := $(CONTENTS)/boot/KNOPPIX $(CONTENTS)/boot/grub/knoppix.cfg.in
$(knoppix): $(knoppix_iso) configs/knoppix.cfg
	7z x -o$(CONTENTS)/boot $(knoppix_iso) KNOPPIX/KNOPPIX KNOPPIX/KNOPPIX1 KNOPPIX/kversion
	7z e -o$(CONTENTS)/boot/KNOPPIX $(knoppix_iso) $(foreach f,linux linux64 minirt.gz,boot/isolinux/$(f))
	cp -v configs/knoppix.cfg $(CONTENTS)/boot/grub/knoppix.cfg.in
	touch $(knoppix)
knoppix: $(knoppix)

kav_iso := $(CONTENTS)/data/kav.iso
$(kav_iso): | $(base)
	mkdir -p $(CONTENTS)/data
	wget -c -O $(kav_iso) https://rescuedisk.s.kaspersky-labs.com/updatable/2018/krd.iso
	touch $(kav_iso)
kav_iso: $(kav_iso)

kav := $(CONTENTS)/boot/grub/kav.cfg.in $(CONTENTS)/liveusb
$(kav): $(kav_iso) scripts/kav_fixup.awk
	echo 'submenu "Kaspersky Rescue Disk" {' > $(CONTENTS)/boot/grub/kav.cfg.in
	echo set lang=ru >> $(CONTENTS)/boot/grub/kav.cfg.in
	7z e -so $(kav_iso) boot/grub/cfg/en.cfg >> $(CONTENTS)/boot/grub/kav.cfg.in
	echo >> $(CONTENTS)/boot/grub/kav.cfg.in
	7z e -so $(kav_iso) boot/grub/i386-pc/cfg/kav_menu.cfg \
		| awk -v path=/data/kav.iso -v addparams=isoloop=kav.iso -f scripts/grub2_fixup.awk \
		>> $(CONTENTS)/boot/grub/kav.cfg.in; \
	echo '}' >> $(CONTENTS)/boot/grub/kav.cfg.in
kav: $(kav)

drweb_iso := $(DOWNLOAD)/drweb.iso
$(drweb_iso): | $(base)
	wget -c -O $(drweb_iso) https://download.geo.drweb.com/pub/drweb/livedisk/drweb-livedisk-900-cd.iso
	touch $(drweb_iso)
drweb_iso: $(drweb_iso)

# DrWeb LiveDisk's casper doesn't support iso-scan/filename
drweb := $(CONTENTS)/boot/grub/drweb.cfg.in $(CONTENTS)/boot/drweb
$(drweb): $(drweb_iso)
	7z x -o$(CONTENTS) $(drweb_iso) .disk
	7z e -o$(CONTENTS)/boot/drweb $(drweb_iso) casper
	7z e -o$(CONTENTS)/boot/drweb $(drweb_iso) install/mt86plus
	7z e -so $(drweb_iso) isolinux/txt.cfg \
		| env FORCE_BOOT_PATH=1 perl "scripts/syslinux2grub.pl" live-media-path=boot/drweb /boot/drweb "" "DrWeb LiveDisk" \
		> $(CONTENTS)/boot/grub/drweb.cfg.in
drweb: $(drweb)

memtest_img := $(DOWNLOAD)/MemTest86.img
$(memtest_img): | $(base)
	wget -c -O $(DOWNLOAD)/memtest.zip http://memtest86.com/downloads/memtest86-usb.zip
	7z e -o$(DOWNLOAD) $(DOWNLOAD)/memtest.zip memtest86-usb.img
	7z e -o$(DOWNLOAD) $(DOWNLOAD)/memtest86-usb.img MemTest86.img

memtest_img: $(memtest_img)

memtest := $(CONTENTS)/boot/memtest86 $(CONTENTS)/boot/grub/memtest.cfg.in
$(memtest): $(memtest_img) configs/memtest.cfg
	7z e -o$(CONTENTS)/boot/memtest86 $(memtest_img) EFI/BOOT/
	cp configs/memtest.cfg $(CONTENTS)/boot/grub/memtest.cfg.in
memtest: $(memtest)

memtestplus_bin := $(DOWNLOAD)/memtest86+-5.01.bin.gz
$(memtestplus_bin): | $(base)
	wget -O $(memtestplus_bin) http://www.memtest.org/download/5.01/memtest86+-5.01.bin.gz

memtestplus := $(CONTENTS)/boot/memtest86+.bin $(CONTENTS)/boot/grub/memtestplus.cfg.in
$(memtestplus): $(memtestplus_bin) configs/memtestplus.cfg
	zcat $(memtestplus_bin) > $(CONTENTS)/boot/memtest86+.bin
	cp configs/memtestplus.cfg $(CONTENTS)/boot/grub/memtestplus.cfg.in
memtestplus: $(memtestplus)

debian_desktop := xfce

debian_iso := $(CONTENTS)/boot/debian.iso
$(debian_iso): | $(base)
	@echo "Additional parameters: debian_desktop=$(debian_desktop)"
	$(call LOAD_LINK,https://cdimage.debian.org/images/unofficial/non-free/images-including-firmware/current-live/i386/iso-hybrid/,debian-live-[0-9.]+-i386-$(debian_desktop)\\+nonfree\\.iso,$(debian_iso))
	touch $(debian_iso)
debian_iso: $(debian_iso)

debian := $(CONTENTS)/boot/grub/debian.cfg.in
$(debian): $(debian_iso)
	$(call GEN_CONFIG,boot/debian.iso,isolinux,menu.cfg,findiso,$(debian),"Debian Live")
debian: $(debian)

# build loader config

config := $(CONTENTS)/boot/grub/grub.cfg
$(config): $(CONTENTS)/boot/grub/*.cfg.in configs/grub.cfg | $(base)
	cp configs/grub.cfg $(config)
	for file in $(CONTENTS)/boot/grub/*.cfg.in; do echo ". \$$prefix/$$(basename $$file)" >> $(config); done
config: $(config)

copy_over: $(config)
	# TARGET_DIR=$(TARGET_DIR)
	test -d "$(TARGET_DIR)"
	rsync -urtvP --inplace --modify-window=2 "$(CONTENTS)/" "$(TARGET_DIR)/"

install_bootloader:
	# TARGET_DIR=$(TARGET_DIR) TARGET_DEV=$(TARGET_DEV)
	test -d "$(TARGET_DIR)" && test -b "$(TARGET_DEV)"
	$(SUDO) grub-install --boot-directory="$(TARGET_DIR)/boot" --target=i386-pc "$(TARGET_DEV)"
	$(foreach arch,i386 x86_64, \
		$(SUDO) grub-install --boot-directory="$(TARGET_DIR)/boot" --target=$(arch)-efi \
			--efi-directory="$(TARGET_DIR)" --removable --no-nvram; \
	)

# now that we've defined all the variables, time to define the "all" rules

IMAGES = $(sysrcd) $(grub4dos)
EXTRA_IMAGES = $(IMAGES) $(knoppix) $(porteus) $(kav) $(drweb) $(memtest) $(memtestplus) $(debian)

all: $(base) $(IMAGES) $(config)
all_images: $(EXTRA_IMAGES) all

clean:
	rm -rvf $(IMAGES) $(EXTRA_IMAGES) $(CONTENTS) $(DOWNLOAD)
