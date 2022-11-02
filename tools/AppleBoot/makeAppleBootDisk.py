# Patch the bootloader to an Apple III disk image. Thorsten Brehm, 2022.
#
# Apple II(I) forever!
#
import sys

DISK_SIZE = 140*1024         # size of an AppleII(I) disk in bytes: 140K

if len(sys.argv)!=4:
	print("ERROR: incorrect number of parameters.")
	print("Usage: python3 makeAppleBootDisk.py <bootloader.o65> <input.dsk> <output.dsk>")
	print("       input.dsk may be omitted by using '-' (patches bootloader into an otherwise empty disk)")
	sys.exit(1)

InputFileName  = sys.argv[1] # input: the bootloader binary (.bin)
InputDisk      = sys.argv[2] # input: the original disk file (.dsk)
OutputFileName = sys.argv[3] # output: the disk file (.dsk)

# read bootloader
with open(InputFileName, "rb") as InputFile:
	Bootloader = InputFile.read()
	
# check size
if len(Bootloader)>1024:
	print("ERROR: Bootloader is exceeds 1024 bytes (two blocks). That's not going to work!")
	sys.exit(1)

# fill bootloader to a multiple of 512, so it occupies full blocks
if len(Bootloader) % 512 != 0:
	Bootloader += b"\x00"*(512-(len(Bootloader) % 512))

Disk = b"\x00" * DISK_SIZE
if InputDisk != "-":
	with open(InputDisk, "rb") as InputFile:
		Disk = InputFile.read()
if len(Disk) != DISK_SIZE:
	print("ERROR: Disk has an unexpected size. That's not going to work!")
	sys.exit(1)

# patch Apple III boot loader into block 0 (DSK has a non-linear sector format)
Disk = Bootloader[0:0x0100]+Disk[0x0100:0x0E00]+Bootloader[0x100:0x200]+Disk[0xF00:]

# patch larger boot loaders also into block 1 (DSK has a non-linear sector format)
# This overwrites the Apple II bootloader!
if len(Bootloader)>512:
	print("Note: Bootloader exceeds 512 bytes, so overwrites the Apple II bootloader in block 1.")
	Disk = Disk[0x0000:0x0c00]+Bootloader[0x300:0x400]+Bootloader[0x200:0x300]+Disk[0xE00:]

# write disk image
with open(OutputFileName, "wb") as OutputFile:
	OutputFile.write(Disk)

