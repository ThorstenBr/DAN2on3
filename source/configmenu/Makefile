# DAN2on3 ConfigMenu Build Makefile
# Thorsten Brehm, 2022

# assembler source
ASM_FILE := configmenu.s
# linked output
O65_FILE := $(addprefix bin/,$(ASM_FILE:.s=.o65))
# Input disk file
INPUT_DISK  := ../disk/Apple3SOS1.3SysUtils.dsk
# Output disk file
OUTPUT_DISK := bin/Apple3SOS_DAN2o3_Config.dsk

# Build Utilities
APPLE_BOOT := python3 ../../tools/AppleBoot/makeAppleBootDisk.py

# Logging stuff
LOG_PREFIX := "--\> "
ECHO := @echo -e

.SILENT: all $(O65_FILE) $(O65_FILE:.o65=.o)

all: bin $(O65_FILE) $(OUTPUT_DISK)

clean:
	rm -f bin/*

bin:
	- mkdir $@

bin/%.o: %.s Makefile
	$(ECHO) "$(LOG_PREFIX) Compiling $<"
	ca65 -l $(@:.o=.lst) $< -o $@

bin/%.o65: bin/%.o
	$(ECHO) "$(LOG_PREFIX) Linking $@"
	ld65 -tnone $< -o $@

$(OUTPUT_DISK): $(O65_FILE)
	$(ECHO) "$(LOG_PREFIX) Patching bootloader to disk image $@"
	$(APPLE_BOOT) $< $(INPUT_DISK) $(OUTPUT_DISK)
	cp $@ ../../bin/.

