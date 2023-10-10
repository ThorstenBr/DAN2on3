# Patch the bootloader to an Apple III disk image. Thorsten Brehm, 2022.
#
# Apple II(I) forever!
#
import sys

DISK_SIZE = 140*1024         # size of an AppleII(I) disk in bytes: 140K
ForceFlag = False
PoMode    = False
ExtraBlockAddress = None
AnyDiskSize = False

def readFile(InputFileName):
	with open(InputFileName, "rb") as InputFile:
		Data = InputFile.read()
	return Data

def writeFile(OutputFileName, Data):
	with open(OutputFileName, "wb") as OutputFile:
		OutputFile.write(Data)

def checkDummyArea(DummyData):
	while len(DummyData)!=0:
		# make sure each 512 block contains consistent dummy data
		for i in range(512):
			if DummyData[i]!=DummyData[0]:
				print("ERROR: Patch area for bootloader does not contain expected placeholder data!")
				sys.exit(1)
		# make sure each 512 block expected dummy data ('0'..'9')
		if (DummyData[0]<ord('0'))or(DummyData[0]>ord('9')):
			print("ERROR: Patch area for bootloader does not contain expected placeholder data!")
			sys.exit(1)
		# next block
		DummyData = DummyData[512:]
	print("  Patch area for bootloader is OK!")

def patchBootloader(Disk, Bootloader):
	OriginalSize = len(Bootloader)

	# check size
	if (OriginalSize > 1024)and(not ForceFlag)and(ExtraBlockAddress==None):
		print("ERROR: Bootloader is exceeds 1024 bytes (two blocks). That's not going to work!")
		sys.exit(1)

	# fill bootloader to a multiple of 512, so it occupies full blocks
	if OriginalSize % 512 != 0:
		Bootloader += b"\x00"*(512-(len(Bootloader) % 512))

	# patch Apple III boot loader into block 0
	if PoMode:
		Disk = Bootloader[0:0x0200]+Disk[0x0200:]
	else:
		# .dsk format has a non-linear sector format
		Disk = Bootloader[0:0x0100]+Disk[0x0100:0x0E00]+Bootloader[0x100:0x200]+Disk[0xF00:]

	RemainingSize = len(Bootloader)-512

	if RemainingSize==0:
		return Disk

	# patch remaining blocks
	if ExtraBlockAddress != None:
		if not PoMode:
			print("ERROR: ExtraBlocks only implemented for .po format disks!")
			sys.exit(1)
		DummyData = Disk[ExtraBlockAddress:ExtraBlockAddress+RemainingSize]
		checkDummyArea(DummyData)
		Disk = Disk[:ExtraBlockAddress]+Bootloader[512:512+RemainingSize]+Disk[ExtraBlockAddress+RemainingSize:]
	elif PoMode:
		Disk = Bootloader + Disk[len(Bootloader):]
	else:
		# patch Apple III boot loader into block 0 (DSK has a non-linear sector format)
		Disk = Bootloader[0:0x0100]+Disk[0x0100:0x0E00]+Bootloader[0x100:0x200]+Disk[0xF00:]

		# patch larger boot loaders also into block 1 (DSK has a non-linear sector format)
		# This overwrites the Apple II bootloader!
		if len(Bootloader)>512:
			print("Note: Bootloader (%i bytes) exceeds 512 bytes, so overwrites the Apple II bootloader in block 1." %(OriginalSize,))
			Disk = Disk[0x0000:0x0c00]+Bootloader[0x300:0x400]+Bootloader[0x200:0x300]+Disk[0xE00:]

	print("  Successfully patched",len(Bootloader),"byte bootloader!")
	return Disk

def getParameters():
	global DISK_SIZE, ForceFlag, PoMode, ExtraBlockAddress, AnyDiskSize

	Parameters = sys.argv[1:]
	while Parameters!=[]:
		if Parameters[0]=="--force":
			ForceFlag = True
		elif Parameters[0]=="--anydisksize":
			AnyDiskSize = True
		elif Parameters[0]=="--po":
			PoMode = True
		elif Parameters[0]=="--extrablocks":
			ExtraBlockAddress = int(Parameters[1],16)
			Parameters = Parameters[1:]
			print("  ExtraBlockAddress",hex(ExtraBlockAddress))
		else:
			break
		Parameters = Parameters[1:]

	if len(Parameters)!=3:
		print("ERROR: incorrect number of parameters.")
		print("Usage: python3 makeAppleBootDisk.py [--force] <bootloader.o65> <input.dsk> <output.dsk>")
		print("       input.dsk may be omitted by using '-' (patches bootloader into an otherwise empty disk)")
		sys.exit(1)

	return Parameters

def main():
	Parameters     = getParameters()
	InputFileName  = Parameters[0] # input: the bootloader binary (.bin)
	InputDisk      = Parameters[1] # input: the original disk file (.dsk)
	OutputFileName = Parameters[2] # output: the disk file (.dsk)

	# read bootloader
	Bootloader = readFile(InputFileName)

	# read disk
	if InputDisk != "-":
		Disk = readFile(InputDisk)
	else:
		Disk = b"\x00" * DISK_SIZE

	if (not AnyDiskSize)and(len(Disk) != DISK_SIZE):
		print("ERROR: Disk has an unexpected size. That's not going to work!")
		sys.exit(1)

	# patch bootloader
	Disk = patchBootloader(Disk, Bootloader)

	# write disk image
	writeFile(OutputFileName, Disk)

main()

