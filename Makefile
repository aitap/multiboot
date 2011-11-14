IMAGE = ./image.iso

MKISOFS = genisomage
CDRECORD = wodim
WGET = wget -N -c

CONTENTS = ./contents/
DOWNLOAD = ./download/
CONFIGS = ./configs/

MOUNTPOINT = /mnt
MOUNT = mount
UMOUNT = umount

SYSTEMS = pmagic finnix sysrcd grub4dos debian dsl tinycore

.PHONY: all clean syslinux-usb install-usb burn

# базовые вещи

all: base $(SYSTEMS) config

base:
	@echo -e '\e[1m*** Checking for base directories\e[0m'
	test -d $(CONTENTS) || mkdir -v $(CONTENTS)
	test -d $(DOWNLOAD) || mkdir -v $(DOWNLOAD)
	test -d $(CONTENTS)/isolinux || mkdir -v $(CONTENTS)/isolinux
	touch base

clean:
	@echo -e '\e[1m*** Cleaning all\e[0m'
	rm -rvf $(CONTENTS) $(DOWNLOAD)
	rm -rvf base syslinux syslinux-iso syslinux-usb $(SYSTEMS) $(foreach sys,$(SYSTEMS),$(sys)-latest) iso config

# загрузчик

syslinux: base
	@echo -e '\e[1m*** syslinux: downloading & extracting\e[0m'
	URL=$$(wget -qO- 'http://www.kernel.org/pub/linux/utils/boot/syslinux/?C=M;O=D' | sed -rn '/.bz2/{s/.*href="([^"]+)".*/\1/p;q}'); $(WGET) -O$(DOWNLOAD)/$$URL http://www.kernel.org/pub/linux/utils/boot/syslinux/$$URL; tar -C $(DOWNLOAD) -xvf $(DOWNLOAD)/$$URL; mv -v $(DOWNLOAD)/$$(basename $$URL .tar.bz2) $(DOWNLOAD)/syslinux
	touch syslinux

syslinux-iso: syslinux base
	@echo -e '\e[1m*** isolinux: installing\e[0m'
	cp $(DOWNLOAD)/syslinux/core/isolinux.bin $(CONTENTS)/isolinux/
	touch syslinux-iso

syslinux-usb: syslinux base
	@echo -e '\e[1m*** syslinux: installing\e[0m'
	@if test -z $(TARGET); then /bin/echo -e '\e[1m!!! You have to define TARGET!\e[0m'; exit 1; fi
	blkid -t TYPE="vfat" $(TARGET)
	$(MOUNT) $(TARGET) $(MOUNTPOINT)
	test -d $(MOUNTPOINT)/isolinux || mkdir -v $(MOUNTPOINT)/isolinux
	$(UMOUNT) $(MOUNTPOINT)
	$(DOWNLOAD)/syslinux/linux/syslinux-nomtools -d isolinux -i $(TARGET)
	@echo -e '\e[1m??? You may want to install mbr on you USB drive\e[0m'

# различные ОС, отдельно скачивание и установка

pmagic-latest: base
	@echo -e '\e[1m*** pmagic: downloading\e[0m'
	$(WGET) -O$(DOWNLOAD)/pmagic.iso.zip $(shell wget -qO- 'http://partedmagic.com/doku.php?id=downloads' | sed -rn '/href=".*pmagic-i686.*iso\.zip/{s/.*href="([^"]+)".*/\1/p;q}')
	@echo -e '\e[1m*** pmagic: extracting\e[0m'
	zcat $(DOWNLOAD)/pmagic.iso.zip > $(DOWNLOAD)/pmagic.iso
	rm $(DOWNLOAD)/pmagic.iso.zip
	touch pmagic-latest

pmagic: pmagic-latest
	@echo -e '\e[1m*** pmagic: installing\e[0m'
	$(MOUNT) -o loop $(DOWNLOAD)/pmagic.iso $(MOUNTPOINT)
	rm -rvf $(CONTENTS)/pmagic
	cp -rv $(MOUNTPOINT)/pmagic $(CONTENTS)/
	for file in mhdd plpbt sgd syslinux/hdt.gz syslinux/memdisk syslinux/memtest syslinux/reboot.c32; do cp -rv $(MOUNTPOINT)/boot/$$file $(CONTENTS)/pmagic/; done
	$(UMOUNT) $(MOUNTPOINT)
	@echo -e '\e[1m*** pmagic: copying configs\e[0m'
	cp -v $(CONFIGS)/pmagic.cfg $(CONTENTS)/isolinux/pmagic.cfg
	cp -v $(CONFIGS)/pmagic*.txt $(CONTENTS)/isolinux/
	touch pmagic

finnix-latest: base
	@echo -e '\e[1m*** finnix: downloading\e[0m'
	$(WGET) -O$(DOWNLOAD)/finnix.iso $(shell wget -qO- http://finnix.org/releases/current/ | sed -rn '/"finnix-[0-9]+.iso"/{s#.*"(finnix-[0-9]+.iso)".*#http://finnix.org/releases/current/\1#;p}')
	touch finnix-latest

finnix: finnix-latest
	@echo -e '\e[1m*** finnix: installing\e[0m'
	$(MOUNT) -o loop $(DOWNLOAD)/finnix.iso $(MOUNTPOINT)
	cp -rv $(MOUNTPOINT)/finnix/ $(CONTENTS)
	for file in *.imz hdt.c32 initrd.xz linux linux64 memdisk memtest pci.ids; do cp -v $(MOUNTPOINT)/isolinux/$$file $(CONTENTS)/finnix/; done
	$(UMOUNT) $(MOUNTPOINT)
	@echo -e '\e[1m*** finnix: copying configs\e[0m'
	cp -v $(CONFIGS)/finnix.cfg $(CONTENTS)/isolinux/finnix.cfg
	touch finnix

sysrcd-latest: base
	@echo -e '\e[1m*** sysrcd: downloading\e[0m'
	$(WGET) -O$(DOWNLOAD)/sysrcd.iso $(shell wget -qO- http://sysresccd.org/Download | egrep -om1 'href="https://sourceforge.net/projects/systemrescuecd/files/sysresccd-x86/[^"]+"' | sed -r 's/href="(.*)"/\1/')
	touch sysrcd-latest

sysrcd: sysrcd-latest
	@echo -e '\e[1m*** sysrcd: installing\e[0m'
	rm -rvf $(CONTENTS)/sysrcd
	mkdir $(CONTENTS)/sysrcd
	$(MOUNT) -o loop $(DOWNLOAD)/sysrcd.iso $(MOUNTPOINT)
	for file in bootdisk bootprog ntpasswd sysrcd.dat sysrcd.md5 version; do cp -rv $(MOUNTPOINT)/$$file $(CONTENTS); done
	for file in rescue* altker* initram.igz memdisk netboot; do cp -v $(MOUNTPOINT)/isolinux/$$file $(CONTENTS)/sysrcd; done
	$(UMOUNT) $(MOUNTPOINT)
	@echo -e '\e[1m*** sysrcd: copying configs\e[0m'
	cp -v $(CONFIGS)/sysrcd.cfg $(CONTENTS)/isolinux/sysrcd.cfg
	cp -v $(CONFIGS)/sysrcd*.msg $(CONFIGS)/ntpass*.msg $(CONTENTS)/isolinux/
	touch sysrcd

grub4dos-latest: base
	@echo -e '\e[1m*** grub4dos: downloading & extracting\e[0m'
	URL=http://grub4dos-chenall.googlecode.com/files/$$(wget -qO- http://code.google.com/p/grub4dos-chenall/downloads/list | sed -rn "/href=.*'Featured'/{s/.*href=\"([^\"]+)\".*/http:\1/p;q}"); $(WGET) -O$(DOWNLOAD)/$$(basename $$URL) $$URL; 7z e -y -xr'!*chinese*' -o$(DOWNLOAD)/grub4dos $(DOWNLOAD)/$$(basename $$URL);
	touch grub4dos-latest

grub4dos: grub4dos-latest
	@echo -e '\e[1m*** grub4dos: installing\e[0m'
	cp -v $(DOWNLOAD)/grub4dos/grub.exe $(CONTENTS)/isolinux/
	@echo -e '\e[1m*** grub4dos: copying configs\e[0m'
	cp -v $(CONFIGS)/grub4dos.cfg $(CONTENTS)/isolinux/
	touch grub4dos

love:
	@echo not war

debian-latest: base
	@echo -e '\e[1m*** debian: downloading\e[0m'
	$(WGET) -O$(DOWNLOAD)/debian.bzi http://ftp.ru.debian.org/debian/dists/testing/main/installer-i386/current/images/netboot/debian-installer/i386/linux
	$(WGET) -O$(DOWNLOAD)/debian.ifs http://ftp.ru.debian.org/debian/dists/testing/main/installer-i386/current/images/netboot/debian-installer/i386/initrd.gz
	touch debian-latest

debian: debian-latest
	@echo -e '\e[1m*** debian: installing\e[0m'
	rm -rvf $(CONTENTS)/debian/
	mkdir -v $(CONTENTS)/debian/
	cp -v $(DOWNLOAD)/debian.bzi $(DOWNLOAD)/debian.ifs $(CONTENTS)/debian/
	@echo -e '\e[1m*** debian: copying configs\e[0m'
	cp -v $(CONFIGS)/debian.cfg $(CONTENTS)/isolinux/debian.cfg
	touch debian

dsl-latest: base
	@echo -e '\e[1m*** dsl: downloading\e[0m'
	$(WGET) -O$(DOWNLOAD)/dsl.iso http://ftp.belnet.be/packages/damnsmalllinux/current/current.iso
	touch dsl-latest

dsl: dsl-latest
	@echo -e '\e[1m*** dsl: installing\e[0m'
	$(MOUNT) -o loop $(DOWNLOAD)/dsl.iso $(MOUNTPOINT)
	cp -rv $(MOUNTPOINT)/KNOPPIX/ $(CONTENTS)
	cp -v $(MOUNTPOINT)/boot/isolinux/linux24 $(MOUNTPOINT)/boot/isolinux/minirt24.gz $(CONTENTS)/KNOPPIX/
	$(UMOUNT) $(MOUNTPOINT)
	@echo -e '\e[1m*** dsl: copying configs\e[0m'
	cp -v $(CONFIGS)/dsl.cfg $(CONTENTS)/isolinux/
	touch dsl

tinycore-latest: base
	@echo -e '\e[1m*** tinycore: downloading\e[0m'
	$(WGET) -O$(DOWNLOAD)/tinycore.iso http://distro.ibiblio.org/tinycorelinux/4.x/x86/release/tinycore-current.iso
	touch tinycore-latest

tinycore: tinycore-latest
	@echo -e '\e[1m*** tinycore: installing\e[0m'
	$(MOUNT) -o loop $(DOWNLOAD)/tinycore.iso $(MOUNTPOINT)
	rm -rvf $(CONTENTS)/tinycore
	mkdir -v $(CONTENTS)/tinycore
	for file in vmlinuz tinycore.gz; do cp -v $(MOUNTPOINT)/boot/$$file $(CONTENTS)/tinycore; done
	@echo -e '\e[1m*** tinycore: copying configs\e[0m'
	cp -v $(CONFIGS)/tinycore* $(CONTENTS)/isolinux/
	$(UMOUNT) $(MOUNTPOINT)
	touch tinycore

# сборка образа, установка на флешку

iso: base $(SYSTEMS) syslinux-iso config
	genisoimage -o $(IMAGE) \
	-l -J -R \
	-b isolinux/isolinux.bin -c isolinux/boot.cat \
	-no-emul-boot -boot-load-size 4 -boot-info-table \
	-V 'AITap Boot CD' \
	$(CONTENTS)
	touch iso

install-usb: base $(SYSTEMS) syslinux-usb config
	@echo -e '\e[1m*** Installing $(CONTENTS) on usb-drive\e[0m'
	@if test -z $(TARGET); then echo "!!! You have to define TARGET to make install-usb!"; exit 1; fi
	$(MOUNT) $(TARGET) $(MOUNTPOINT)
	cp -rv $(CONTENTS)/* $(MOUNTPOINT)
	rm -fv $(MOUNTPOINT)/isolinux/isolinux.bin
	mv -v $(MOUNTPOINT)/isolinux/isolinux.cfg $(MOUNTPOINT)/isolinux/syslinux.cfg
	$(UMOUNT) $(MOUNTPOINT)

# сборка isolinux.cfg

config: base syslinux
	@echo -e '\e[1m*** Building isolinux.cfg\e[0m'
	rm -vf $(CONTENTS)/isolinux/config.cfg $(CONTENTS)/isolinux/isolinux.cfg
	echo "INCLUDE config.cfg" > $(CONTENTS)/isolinux/isolinux.cfg.1
	for file in $(CONTENTS)/isolinux/*cfg; do echo "INCLUDE $$(basename $$file)" >> $(CONTENTS)/isolinux/isolinux.cfg.1; done
	mv $(CONTENTS)/isolinux/isolinux.cfg.1 $(CONTENTS)/isolinux/isolinux.cfg
	cp $(CONFIGS)/rus.psf $(CONFIGS)/back.png $(CONFIGS)/config.cfg $(CONTENTS)/isolinux/
	cp $(wildcard $(DOWNLOAD)/syslinux/com32/menu/*menu.c32) $(CONTENTS)/isolinux
	touch config

# выжигание
burn: iso
	@echo -e '\e[1m*** Burning iso\e[0m'
	$(CDRECORD) -v $(IMAGE)

format-usb:
	@echo -e '\e[1m*** Formatting usb thumbdrive...\e[0m'
	@if [ -z $(TARGET) ]; then /bin/echo -e '\e[1m!!! You have to define TARGET!\e[0m'; exit 1; fi
	case $(TARGET) in /dev/sd[a-z][0-9]*)	mkfs.vfat -v $(TARGET);	install-mbr $$(echo $(TARGET) | grep -o '/dev/sd[a-z]')	;; /dev/sd[a-z]) mkfs.vfat -v $(TARGET)	;; *) /bin/echo -e "\e[1m!!! Don't know what to do with $(TARGET)\e[0m" ;; esac
