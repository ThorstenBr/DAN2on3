# DAN2on3 Build Makefile
# Thorsten Brehm, 2022

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

