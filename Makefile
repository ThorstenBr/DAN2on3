# DAN2on3 Build Makefile
# Thorsten Brehm, 2022

include version.mk

ZIP_FILE    := Releases/DAN2on3_v$(CONFIG_VERSION).zip
DISKS       := Apple3Disk.DAN2on3.Boot.dsk \
               Apple3Disk.DAN2on3.SOSSysUtils.dsk
A3_BOOTMENU := VOLA3_APPLEIII_BOOT_MENU.po
DRIVER      := DAN2ON3.DRIVER
A3_ROMS     := A3ROM_DANII_4KB.bin A3ROM_DANII_8KB.bin

.SILENT: all clean bin disks

all: bin disks
	make -C source/driver $@
	make -C source/configmenu $@
	make -C source/rom $@

clean:
	make -C source/driver $@
	make -C source/configmenu $@
	make -C source/rom $@
	rm -f bin/* disks/*

bin disks:
	- mkdir $@

release:
	- rm -f $(ZIP_FILE)
	@mkdir -p Releases
	@zip $(ZIP_FILE) readme.txt $(addprefix disks/,$(DISKS) $(DISKS:.dsk=.po)) $(addprefix bin/,$(A3_BOOTMENU) $(DRIVER) $(A3_ROMS))

