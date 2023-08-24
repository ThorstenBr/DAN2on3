# DAN2on3: A/// ROM Makefile
# Thorsten Brehm, 2023

# assembler source
ASM_FILES  := diskio.s saratests.s monitor.s

# assembler output
OBJ_FILES  := $(addprefix bin/,$(ASM_FILES:.s=.o))
# output file
ROM_FILE := bin/A3ROM_DANII.bin

# Logging stuff
LOG_PREFIX := "--\> "
ECHO := @echo -e

.SILENT: all clean bin list $(OBJ_FILES) $(ROM_FILE)

all: bin $(ROM_FILE)

clean:
	rm -f bin/*

bin:
	- mkdir $@

bin/%.o: %.s Makefile
	$(ECHO) "$(LOG_PREFIX) Assembling $<"
	ca65 $(VERSION_INFO) -l $(@:.o=.lst) $< -o $@

$(ROM_FILE): $(OBJ_FILES)
	ld65 -tnone $(OBJ_FILES) -o $@

