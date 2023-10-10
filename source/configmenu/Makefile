# DAN2on3 ConfigMenu Build Makefile
# Thorsten Brehm, 2022

# include file with version
include ../../version.mk

VER_MAJOR      := $(word 1,$(subst ., ,$(CONFIG_VERSION)))
VER_MINOR      := $(word 2,$(subst ., ,$(CONFIG_VERSION)))
VER_MAINT      := $(word 3,$(subst ., ,$(CONFIG_VERSION)))

VERSION_INFO   := -DVER_MAJOR=$(VER_MAJOR) -DVER_MINOR=$(VER_MINOR) -DVER_MAINT=$(VER_MAINT)

# assembler source
ASM_FILE       := bootpg.s

# linked output
DISK_BIN_FILE  := $(addprefix bin/,$(addprefix disk_,$(ASM_FILE:.s=.bin)))
DAN_BIN_FILE   := $(addprefix bin/,$(addprefix VOLA3_,$(ASM_FILE:.s=.bin)))
BIN_FILES      := $(DISK_BIN_FILE) $(DAN_BIN_FILE)

# Output disk file
OUTPUT_DISK    := bin/Apple3Disk.DAN2on3.Boot.po

# Temporary disk file
TEMP_DISK      := bin/temp.po

# Build Utilities
DSK2PO         := python3 ../../tools/dsk2po/dsk2po.py
PO2DSK         := python3 ../../tools/dsk2po/dsk2po.py --reversed
APPLE_BOOT     := python3 ../../tools/AppleBoot/makeAppleBootDisk.py
AppleCommander := java -jar ../../tools/AppleCommander/AppleCommander-ac-1.8.0.jar

# Logging stuff
LOG_PREFIX     := "--\> "
ECHO           := @echo -e

.SILENT: all clean bin list $(BIN_FILES) $(DISK_BIN_FILE:.bin=.o) $(OUTPUT_DISK)

all: bin $(DISK_BIN_FILE) $(OUTPUT_DISK) bin/VOLA3_APPLEIII_BOOT_MENU.po

clean:
	rm -f bin/*

bin:
	- mkdir $@

# Rules to build an Apple III disk bootloader for the DANII card
bin/disk_%.o: %.s Makefile
	$(ECHO) "$(LOG_PREFIX) Compiling $<"
	ca65 $(VERSION_INFO) -DDISK_BOOTLOADER=1 -l $(@:.o=.lst) $< -o $@

bin/disk_%.bin: bin/disk_%.o
	$(ECHO) "$(LOG_PREFIX) Linking $@"
	ld65 -tnone $< -o $@

$(OUTPUT_DISK): $(DISK_BIN_FILE)
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
	$(APPLE_BOOT) --po --extrablocks 0x1400 $< $(TEMP_DISK) $(OUTPUT_DISK)
	rm $(TEMP_DISK)
	cp $@ ../../disks/.
	$(PO2DSK) ../../disks/$(notdir $@)

# Rules to build an Apple III boot menu for the DANII card (boot program stored on the DANII card)
bin/VOLA3_%.o: %.s Makefile
	$(ECHO) "$(LOG_PREFIX) Compiling $<"
	ca65 $(VERSION_INFO) -DDANII_BOOTLOADER=1 -l $(@:.o=.lst) $< -o $@

bin/VOLA3_APPLEIII_BOOT_MENU.po: bin/VOLA3_$(ASM_FILE:.s=.o)
	$(ECHO) "$(LOG_PREFIX) Linking $@"
	ld65 -tnone $< -o $@
	cp $@ ../../bin/.

# show disk contents
list:
	$(ECHO) "$(LOG_PREFIX) Disk contents:"
	$(AppleCommander) -ll $(OUTPUT_DISK)

