# DAN2on3 Build Makefile
# Thorsten Brehm, 2022

ASM_FILE := DAN2on3.s

O65_FILE := $(addprefix bin/,$(ASM_FILE:.s=.o65))

A3DU_PATH := tools/A3Driverutil
TEMP_DISK := bin/_Apple3SOS.SysUtils.dsk

SOURCE_DISK := source/disk/Apple3SOS1.3SysUtils.dsk
OUTPUT_DISK := bin/Apple3SOS.SysUtils.DAN2o3.dsk

AppleCommander := java -jar tools/AppleCommander/AppleCommander-1.3.5.13-ac.jar
A3DriverUtil := python $(A3DU_PATH)/a3driverutil.py

LOG_PREFIX := "--\> "
ECHO := @echo -e

.SILENT: all $(O65_FILE) $(O65_FILE:.o65=.o) bin/SOS.DRIVER $(OUTPUT_DISK)

all: bin $(OUTPUT_DISK)

clean:
	rm -f bin/*

bin:
	- mkdir $@

bin/%.o: source/driver/%.s Makefile
	$(ECHO) "$(LOG_PREFIX) Compiling $<"
	ca65 -l $(@:.o=.lst) $< -o $@

bin/%.o65: bin/%.o
	$(ECHO) "$(LOG_PREFIX) Linking $@"
	ld65 $< -o $@ -C $(A3DU_PATH)/Apple3_o65.cfg

bin/DAN2on3.driver: $(O65_FILE)
	$(A3DriverUtil) sos $< $@

bin/SOS.DRIVER: $(O65_FILE) $(SOURCE_DISK)
	rm -f bin/SOS.DRIVER
	$(ECHO) "$(LOG_PREFIX) Extracting original SOS.DRIVER"
	$(AppleCommander) -g $(SOURCE_DISK) SOS.DRIVER $@.original
	cp $@.original $@.temp
	$(ECHO) "$(LOG_PREFIX) Adding new $< to new SOS.DRIVER"
	$(A3DriverUtil) add $(O65_FILE) $@.temp
	mv $@.temp $@

$(OUTPUT_DISK): bin/SOS.DRIVER bin/DAN2on3.driver $(SOURCE_DISK)
	$(ECHO) "$(LOG_PREFIX) Copying SysUtils disk..."
	cp $(SOURCE_DISK) $(TEMP_DISK)
	$(ECHO) "$(LOG_PREFIX) Removing old SOS.DRIVER from SysUtils disk..."
	$(AppleCommander) -d $(TEMP_DISK) SOS.DRIVER
	$(ECHO) "$(LOG_PREFIX) Adding new SOS.DRIVER to SysUtils disk..."
	cat bin/SOS.DRIVER | $(AppleCommander) -p $(TEMP_DISK) SOS.DRIVER SOS
#	$(ECHO) "$(LOG_PREFIX) Adding separate driver file to SysUtils disk..."
#	cat bin/DAN2on3.driver | $(AppleCommander) -p $(TEMP_DISK) DAN2on3.driver SOS
	mv $(TEMP_DISK) $@

show:
	$(ECHO) "$(LOG_PREFIX) Disk contents:"
	$(AppleCommander) -l $(OUTPUT_DISK)

SD: $(OUTPUT_DISK)
	cp $(OUTPUT_DISK) /run/media/brehm/5C28-5CDC/APPLEIII/Thorsten/.

