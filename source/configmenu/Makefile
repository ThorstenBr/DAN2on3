# DAN2on3 ConfigMenu Build Makefile
# Thorsten Brehm, 2022

# include file with version
include ../../version.mk

VER_MAJOR := $(word 1,$(subst ., ,$(VERSION)))
VER_MINOR := $(word 2,$(subst ., ,$(VERSION)))
VER_MAINT := $(word 3,$(subst ., ,$(VERSION)))

VERSION_INFO := -DVER_MAJOR=$(VER_MAJOR) -DVER_MINOR=$(VER_MINOR) -DVER_MAINT=$(VER_MAINT)

# assembler source
ASM_FILE := configmenu.s
# linked output
O65_FILE := $(addprefix bin/,$(ASM_FILE:.s=.o65))
# Input disk file
INPUT_DISK  := ../disk/Apple3SOS1.3SysUtils.dsk
# Output disk file
OUTPUT_DISK := bin/Apple3SOS.DAN2on3.Config.dsk
# Temporary disk file
TEMP_DISK := bin/temp.dsk
# Build Utilities
DSK2PO     := python3 ../../tools/dsk2po/dsk2po.py
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
	$(ECHO) "$(LOG_PREFIX) Preparing empty Apple III SOS disk..."
	cp $(INPUT_DISK) $(TEMP_DISK)
	$(AppleCommander) -d $(TEMP_DISK) SOS.KERNEL
	$(AppleCommander) -d $(TEMP_DISK) SOS.DRIVER
	$(AppleCommander) -d $(TEMP_DISK) SOS.INTERP
	$(AppleCommander) -d $(TEMP_DISK) SYSTEM.PASCAL
	$(AppleCommander) -d $(TEMP_DISK) SYSTEM.MISCINFO
	$(AppleCommander) -d $(TEMP_DISK) SYSTEM.STARTUP
	$(ECHO) "$(LOG_PREFIX) Setting volume name..."
	$(AppleCommander) -n $(TEMP_DISK) DAN2ON3.CONFIG
	$(ECHO) "$(LOG_PREFIX) Adding separate driver file to disk..."
	cat ../../bin/DAN2ON3.DRIVER | $(AppleCommander) -p $(TEMP_DISK) DAN2ON3.DRIVER SOS
	$(ECHO) "$(LOG_PREFIX) Patching bootloader to disk $@"
	$(APPLE_BOOT) $< $(TEMP_DISK) $(OUTPUT_DISK)
	rm $(TEMP_DISK)
	cp $@ ../../bin/.
	$(DSK2PO) ../../bin/$(notdir $@)

# show disk contents
list:
	$(ECHO) "$(LOG_PREFIX) Disk contents:"
	$(AppleCommander) -ll $(OUTPUT_DISK)

