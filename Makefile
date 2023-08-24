# DAN2on3 Build Makefile
# Thorsten Brehm, 2022

include version.mk

ZIP_FILE := DAN2on3_v$(CONFIG_VERSION).zip

DISKS  := Apple3SOS.DAN2on3.Config.dsk  Apple3SOS.DAN2on3.SysUtils.dsk
DRIVER := DAN2ON3.DRIVER

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
	- rm $(ZIP_FILE)
	@zip $(ZIP_FILE) $(addprefix bin/,$(DISKS) $(DISKS:.dsk=.po) $(DRIVER))

