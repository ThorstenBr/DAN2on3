# DAN2on3 Build Makefile
# Thorsten Brehm, 2022

include version.mk

ZIP_FILE    := DAN2on3_v$(CONFIG_VERSION).zip
DISKS       := Apple3Disk.DAN2on3.Config.dsk \
               Apple3Disk.DAN2on3.SOSSysUtils.dsk
A3_BOOTMENU := VOLA3_APPLEIII_BOOT_MENU.po
DRIVER      := DAN2ON3.DRIVER

.SILENT: all clean bin

all: bin
	make -C source/driver $@
	make -C source/configmenu $@

clean:
	make -C source/driver $@
	make -C source/configmenu $@
	rm -f bin/*

bin:
	- mkdir $@

release:
	- rm -f $(ZIP_FILE)
	@zip $(ZIP_FILE) readme.txt $(addprefix bin/,$(DISKS) $(DISKS:.dsk=.po) $(A3_BOOTMENU) $(DRIVER))

