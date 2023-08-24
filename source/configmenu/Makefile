# DAN2on3 ConfigMenu Build Makefile
# Thorsten Brehm, 2022

# include file with version
include ../../version.mk

VER_MAJOR := $(word 1,$(subst ., ,$(CONFIG_VERSION)))
VER_MINOR := $(word 2,$(subst ., ,$(CONFIG_VERSION)))
VER_MAINT := $(word 3,$(subst ., ,$(CONFIG_VERSION)))

VERSION_INFO := -DVER_MAJOR=$(VER_MAJOR) -DVER_MINOR=$(VER_MINOR) -DVER_MAINT=$(VER_MAINT)

# assembler source
ASM_FILE := bootpg_v6.s
# linked output
O65_FILE := $(addprefix bin/,$(ASM_FILE:.s=.o65))
# Output disk file
OUTPUT_DISK := bin/Apple3SOS.DAN2on3.Config.po
# Temporary disk file
TEMP_DISK := bin/temp.po
# Build Utilities
DSK2PO     := python3 ../../tools/dsk2po/dsk2po.py
PO2DSK     := python3 ../../tools/dsk2po/dsk2po.py --reversed
APPLE_BOOT := python3 ../../tools/AppleBoot/makeAppleBootDisk.py
AppleCommander := java -jar ../../tools/AppleCommander/AppleCommander-ac-1.8.0.jar

# Logging stuff
LOG_PREFIX := "--\> "
ECHO := @echo -e

.SILENT: all clean bin list $(O65_FILE) $(O65_FILE:.o65=.o) $(OUTPUT_DISK)

all: bin $(O65_FILE) $(OUTPUT_DISK)

clean:
	rm -f bin/*

bin:
	- mkdir $@

bin/%.o: %.s Makefile
	$(ECHO) "$(LOG_PREFIX) Compiling $<"
	ca65 $(VERSION_INFO) -l $(@:.o=.lst) $< -o $@

bin/%.o65: bin/%.o
	$(ECHO) "$(LOG_PREFIX) Linking $@"
	ld65 -tnone $< -o $@

$(OUTPUT_DISK): $(O65_FILE)
	$(ECHO) "$(LOG_PREFIX) Creating disk image..."
	$(AppleCommander) -pro140 $(TEMP_DISK) DAN2ON3.BOOT
	# we use a little trick to squeeze a larger bootloader on the disk,
	# but still keep it in a valid SOS/PRODOS format: we add a dummy file to
	# occupy some space - but then reuse the file content space for the extra
	# blocks of the bootloader
	$(ECHO) "$(LOG_PREFIX) Adding dummy placeholder for bootloader to disk..."
	cat dummydata.txt | $(AppleCommander) -p $(TEMP_DISK) RESERVED BIN
	$(ECHO) "$(LOG_PREFIX) Adding separate driver file to disk..."
	cat ../driver/bin/DAN2ON3.DRIVER | $(AppleCommander) -p $(TEMP_DISK) DAN2ON3.DRIVER SOS
	$(ECHO) "$(LOG_PREFIX) Patching bootloader to disk $@"
	$(APPLE_BOOT) --po --extrablocks 0x1200 $< $(TEMP_DISK) $(OUTPUT_DISK)
	rm $(TEMP_DISK)
	cp $@ ../../bin/.
	$(PO2DSK) ../../bin/$(notdir $@)

# show disk contents
list:
	$(ECHO) "$(LOG_PREFIX) Disk contents:"
	$(AppleCommander) -ll $(OUTPUT_DISK)

