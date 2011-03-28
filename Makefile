IMAGE = ./image.iso

MKISOFS = genisomage

CONTENTS = ./contents/
DOWNLOAD = ./download/
CONFIGS = ./configs/

MOUNTPOINT = /mnt
MOUNT = mount
UMOUNT = umount

SYSTEMS = pmagic finnix sysrcd grub4dos debian dsl

.PHONY: all clean

# базовые вещи

all: base $(SYSTEMS) config

base:
	@echo '*** Checking for base directories'
	test -d $(CONTENTS) || mkdir -v $(CONTENTS)
	test -d $(DOWNLOAD) || mkdir -v $(DOWNLOAD)
	test -d $(CONTENTS)/isolinux || mkdir -v $(CONTENTS)/isolinux
	touch base

clean:
	@echo '*** Cleaning all'
	rm -rvf $(CONTENTS) $(DOWNLOAD)
	rm -rvf base syslinux syslinux-iso syslinux-usb $(SYSTEMS) $(foreach sys,$(SYSTEMS),$(sys)-latest) iso config

# загрузчик

syslinux: base
	@echo '*** Downloading & extracting: syslinux'
	URL=$$(wget -qO- 'http://www.kernel.org/pub/linux/utils/boot/syslinux/?C=M;O=D' | grep -m1 '.bz2"' | sed -r 's/.*"(.*)".*/\1/'); wget -cO$(DOWNLOAD)/$$URL http://www.kernel.org/pub/linux/utils/boot/syslinux/$$URL; tar -C $(DOWNLOAD) -xvf $(DOWNLOAD)/$$URL; mv -v $(DOWNLOAD)/$$(basename $$URL .tar.bz2) $(DOWNLOAD)/syslinux
	touch syslinux

syslinux-iso: syslinux base
	@echo '*** Installing: isolinux'
	cp $(DOWNLOAD)/syslinux/core/isolinux.bin $(CONTENTS)/isolinux/
	touch syslinux-iso

syslinux-usb: syslinux base
	@echo '*** Installing: syslinux'
	@if test -z $(TARGET); then echo '!!! You have to define TARGET!'; exit 1; fi
	blkid -t TYPE="vfat" $(TARGET)
	$(MOUNT) $(TARGET) $(MOUNTPOINT)
	test -d $(MOUNTPOINT)/isolinux || mkdir -v $(MOUNTPOINT)/isolinux
	$(UMOUNT) $(MOUNTPOINT)
	$(DOWNLOAD)/syslinux/linux/syslinux-nomtools -d isolinux -i $(TARGET)
	@echo '??? You may want to install mbr on you USB drive'

# различные ОС, отдельно скачивание и установка

pmagic-latest: base
	@echo '*** Downloading: pmagic'
	wget -cO$(DOWNLOAD)/pmagic.iso.zip $(shell wget -qO- 'http://partedmagic.com/doku.php?id=downloads' | egrep -om1 'href="http://sourceforge.net/projects/partedmagic/files/partedmagic/[^"]+"' | sed -r 's/href="(.*)"/\1/')
	@echo '*** Unpacking: pmagic'
	zcat $(DOWNLOAD)/pmagic.iso.zip > $(DOWNLOAD)/pmagic.iso
	rm $(DOWNLOAD)/pmagic.iso.zip
	touch pmagic-latest

pmagic: pmagic-latest
	@echo '*** Copying: pmagic'
	$(MOUNT) -o loop $(DOWNLOAD)/pmagic.iso $(MOUNTPOINT)
	cp -rv $(MOUNTPOINT)/pmagic $(CONTENTS)/
	for file in mhdd plpbt sgd syslinux/hdt.gz syslinux/memdisk syslinux/memtest syslinux/reboot.c32; do cp -rv $(MOUNTPOINT)/boot/$$file $(CONTENTS)/pmagic/; done
	$(UMOUNT) $(MOUNTPOINT)
	@echo '*** Copying configs'
	cp -v $(CONFIGS)/pmagic.cfg $(CONTENTS)/isolinux/pmagic.cfg
	cp -v $(CONFIGS)/pmagic*.txt $(CONTENTS)/isolinux/
	touch pmagic

finnix-latest: base
	@echo '*** Downloading: finnix'
	wget -cO$(DOWNLOAD)/finnix.iso http://finnix.org/releases/current/$(shell wget -qO- 'http://finnix.org/releases/current/' | grep '.iso"' | grep -v ppc | sed -r 's/.*href="(.*)".*/\1/' | head -1)
	touch finnix-latest

finnix: finnix-latest
	@echo '*** Copying: finnix'
	$(MOUNT) -o loop $(DOWNLOAD)/finnix.iso $(MOUNTPOINT)
	cp -rv $(MOUNTPOINT)/finnix/ $(CONTENTS)
	for file in *.imz hdt.c32 initrd.gz linux linux64 memdisk memtest pci.ids; do cp -v $(MOUNTPOINT)/isolinux/$$file $(CONTENTS)/finnix/; done
	$(UMOUNT) $(MOUNTPOINT)
	@echo '*** Copying configs'
	cp -v $(CONFIGS)/finnix.cfg $(CONTENTS)/isolinux/finnix.cfg
	touch finnix

sysrcd-latest: base
	@echo '*** Downloading: sysrcd'
	wget -cO$(DOWNLOAD)/sysrcd.iso $(shell wget -qO- http://sysresccd.org/Download | egrep -om1 'href="https://sourceforge.net/projects/systemrescuecd/files/sysresccd-x86/[^"]+"' | sed -r 's/href="(.*)"/\1/')
	touch sysrcd-latest

sysrcd: sysrcd-latest
	@echo '*** Copying: sysrcd'
	rm -rvf $(CONTENTS)/sysrcd
	mkdir $(CONTENTS)/sysrcd
	$(MOUNT) -o loop $(DOWNLOAD)/sysrcd.iso $(MOUNTPOINT)
	for file in bootdisk bootprog ntpasswd sysrcd.dat sysrcd.md5 version; do cp -rv $(MOUNTPOINT)/$$file $(CONTENTS); done
	for file in rescue* altker* initram.igz memdisk; do cp -v $(MOUNTPOINT)/isolinux/$$file $(CONTENTS)/sysrcd; done
	$(UMOUNT) $(MOUNTPOINT)
	@echo '*** Copying configs'
	cp -v $(CONFIGS)/sysrcd.cfg $(CONTENTS)/isolinux/sysrcd.cfg
	cp -v $(CONFIGS)/sysrcd*.msg $(CONFIGS)/ntpass*.msg $(CONTENTS)/isolinux/
	touch sysrcd

grub4dos-latest: base
	@echo '*** Downloading & extracting: grub4dos'
	URL=http://grub4dos-chenall.googlecode.com/files/$$(wget -qO- http://code.google.com/p/grub4dos-chenall/downloads/list | egrep -om1 'grub4dos-[a-z0-9.\-]+.7z' | head -1); wget -cO$(DOWNLOAD)/$$(basename $$URL) $$URL; 7z e -y -xr'!*chinese*' -o$(DOWNLOAD)/grub4dos $(DOWNLOAD)/$$(basename $$URL);
	touch grub4dos-latest

grub4dos: grub4dos-latest
	@echo '*** Installing: grub4dos'
	cp -v $(DOWNLOAD)/grub4dos/grub.exe $(CONTENTS)/isolinux/
	@echo '*** Copying configs'
	cp -v $(CONFIGS)/grub4dos.cfg $(CONTENTS)/isolinux/
	touch grub4dos

love:
	@echo not war

debian-latest: base
	@echo '*** Downloading: debian'
	wget -cO$(DOWNLOAD)/debian.bzi http://ftp.ru.debian.org/debian/dists/testing/main/installer-i386/current/images/netboot/debian-installer/i386/linux
	wget -cO$(DOWNLOAD)/debian.ifs http://ftp.ru.debian.org/debian/dists/testing/main/installer-i386/current/images/netboot/debian-installer/i386/initrd.gz
	touch debian-latest

debian: debian-latest
	@echo '*** Installing: debian'
	rm -rvf $(CONTENTS)/debian/
	mkdir -v $(CONTENTS)/debian/
	cp -v $(DOWNLOAD)/debian.bzi $(DOWNLOAD)/debian.ifs $(CONTENTS)/debian/
	@echo '*** Copying configs'
	cp -v $(CONFIGS)/debian.cfg $(CONTENTS)/isolinux/debian.cfg
	touch debian

dsl-latest: base
	@echo '*** Downloading: dsl'
	wget -cO$(DOWNLOAD)/dsl.iso http://ftp.belnet.be/packages/damnsmalllinux/current/current.iso
	touch dsl-latest

dsl: dsl-latest
	@echo '*** Installing: dsl'
	$(MOUNT) -o loop $(DOWNLOAD)/dsl.iso $(MOUNTPOINT)
	cp -rv $(MOUNTPOINT)/KNOPPIX/ $(CONTENTS)
	cp -v $(MOUNTPOINT)/boot/isolinux/linux24 $(MOUNTPOINT)/boot/isolinux/minirt24.gz $(CONTENTS)/KNOPPIX/
	$(UMOUNT) $(MOUNTPOINT)
	@echo '*** Copying configs'
	cp -v $(CONFIGS)/dsl.cfg $(CONTENTS)/isolinux/
	touch dsl

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
	@echo '*** Installing $(CONTENTS) on usb-drive'
	@if test -z $(TARGET); then echo "!!! You have to define TARGET to make install-usb!"; exit 1; fi
	$(MOUNT) $(TARGET) $(MOUNTPOINT)
	cp -rv $(CONTENTS)/* $(MOUNTPOINT)
	rm -fv $(MOUNTPOINT)/isolinux/isolinux.bin
	mv -v $(MOUNTPOINT)/isolinux/isolinux.cfg $(MOUNTPOINT)/isolinux/syslinux.cfg
	$(UMOUNT) $(MOUNTPOINT)

# сборка isolinux.cfg

config: base syslinux
	@echo '*** Building isolinux.cfg'
	rm -vf $(CONTENTS)/isolinux/config.cfg $(CONTENTS)/isolinux/isolinux.cfg
	echo "INCLUDE config.cfg" > $(CONTENTS)/isolinux/isolinux.cfg.1
	for file in $(CONTENTS)/isolinux/*cfg; do echo "INCLUDE $$(basename $$file)" >> $(CONTENTS)/isolinux/isolinux.cfg.1; done
	mv $(CONTENTS)/isolinux/isolinux.cfg.1 $(CONTENTS)/isolinux/isolinux.cfg
	cp $(CONFIGS)/rus.psf $(CONFIGS)/back.png $(CONFIGS)/config.cfg $(CONTENTS)/isolinux/
	cp $(wildcard $(DOWNLOAD)/syslinux/com32/menu/*menu.c32) $(CONTENTS)/isolinux
	touch config
