# DAN2on3 Build Makefile
# Thorsten Brehm, 2022

include version.mk

ZIP_FILE    := DAN2on3_v$(CONFIG_VERSION).zip
DISKS       := Apple3Disk.DAN2on3.Boot.dsk \
               Apple3Disk.DAN2on3.SOSSysUtils.dsk
A3_BOOTMENU := VOLA3_APPLEIII_BOOT_MENU.po
DRIVER      := DAN2ON3.DRIVER
A3_ROMS     := A3ROM_DANII_4KB.bin A3ROM_DANII_8KB.bin

.SILENT: all clean bin

all: bin
	make -C source/driver $@
	make -C source/configmenu $@
	make -C source/rom $@

clean:
	make -C source/driver $@
	make -C source/configmenu $@
	make -C source/rom $@
	rm -f bin/*

bin:
	- mkdir $@

release:
	- rm -f $(ZIP_FILE)
	@zip $(ZIP_FILE) readme.txt $(addprefix bin/,$(DISKS) $(DISKS:.dsk=.po) $(A3_BOOTMENU) $(DRIVER) $(A3_ROMS))

