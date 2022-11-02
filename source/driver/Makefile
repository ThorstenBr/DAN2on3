# DAN2on3 Driver Build Makefile
# Thorsten Brehm, 2022

# assembler source
ASM_FILE    := DAN2on3.s
# linked output
O65_FILE    := $(addprefix bin/,$(ASM_FILE:.s=.o65))
# SOS driver file
DAN2_DRIVER := bin/DAN2ON3.DRIVER
# SOS System Utilities disk (input)
SOURCE_DISK := ../disk/Apple3SOS1.3SysUtils.dsk
# temporary disk file
TEMP_DISK   := bin/_Apple3SOS.SysUtils.dsk
# Final System Utilities disk with new driver (output)
OUTPUT_DISK := bin/Apple3SOS.SysUtils.DAN2o3.dsk

# Build Utilities
A3DU_PATH := ../../tools/A3Driverutil
A3DriverUtil := python $(A3DU_PATH)/a3driverutil.py
AppleCommander := java -jar ../../tools/AppleCommander/AppleCommander-1.3.5.13-ac.jar

# Logging stuff
LOG_PREFIX := "--\> "
ECHO := @echo -e

.SILENT: all $(O65_FILE) $(O65_FILE:.o65=.o) $(DAN2_DRIVER)

all: bin $(OUTPUT_DISK) $(DAN2_DRIVER)

clean:
	rm -f bin/*

bin:
	- mkdir $@

bin/%.o: %.s Makefile
	$(ECHO) "$(LOG_PREFIX) Compiling $<"
	ca65 -l $(@:.o=.lst) $< -o $@

bin/%.o65: bin/%.o
	$(ECHO) "$(LOG_PREFIX) Linking $@"
	ld65 $< -o $@ -C $(A3DU_PATH)/Apple3_o65.cfg

$(DAN2_DRIVER): $(O65_FILE)
	$(A3DriverUtil) sos $< $@
	cp $@ ../../bin/.

bin/SOS.DRIVER: bin/DAN2on3.o65 $(SOURCE_DISK)
	rm -f bin/SOS.DRIVER
	$(ECHO) "$(LOG_PREFIX) Extracting original SOS.DRIVER"
	$(AppleCommander) -g $(SOURCE_DISK) SOS.DRIVER $@.original
	cp $@.original $@.temp
	$(ECHO) "$(LOG_PREFIX) Adding new $< to new SOS.DRIVER"
	$(A3DriverUtil) add bin/DAN2on3.o65 $@.temp
	mv $@.temp $@

$(OUTPUT_DISK): bin/SOS.DRIVER $(DAN2ON3_DRIVER) $(SOURCE_DISK)
	$(ECHO) "$(LOG_PREFIX) Copying SysUtils disk..."
	cp $(SOURCE_DISK) $(TEMP_DISK)
	$(ECHO) "$(LOG_PREFIX) Removing old SOS.DRIVER from SysUtils disk..."
	$(AppleCommander) -d $(TEMP_DISK) SOS.DRIVER
	$(ECHO) "$(LOG_PREFIX) Adding new SOS.DRIVER to SysUtils disk..."
	cat bin/SOS.DRIVER | $(AppleCommander) -p $(TEMP_DISK) SOS.DRIVER SOS
	mv $(TEMP_DISK) $@
	cp $@ ../../bin/.

# show disk contents
list:
	$(ECHO) "$(LOG_PREFIX) Disk contents:"
	$(AppleCommander) -l $(OUTPUT_DISK)

# extract kernel file
bin/SOS.KERNEL:
	$(ECHO) "$(LOG_PREFIX) Extracting original SOS.KERNEL"
	$(AppleCommander) -g $(SOURCE_DISK) SOS.KERNEL $@

