Apple3Disk.DAN2on3.Boot.dsk:
  - Floppy Disk image. Contains the DAN][ boot menu.
  - Use as a boot disk to launch the DAN][ boot menu.
  - Also contains the DAN2ON3.DRIVER as a separate file (usable as an SOS data disk).

Apple3Disk.DAN2on3.SOSSysUtils.dsk:
  - Floppy Disk image with the SOS System Utilities.
  - Already has the DAN2ON3.DRIVER preinstalled (auto-detects the DANII slot).

Apple3Disk.DAN2on3.SOSSysUtils.po:
  - Same as floppy disk image - but in .PO format.

DAN2ON3.DRIVER:
  - Separate binary file with the DANII SOS driver.
  - Useful if you want to generate your own disk images (using CiderPress etc).

VOLA3_APPLEIII_BOOT_MENU.po:
  - Apple III boot menu for the DAN][ card.
  - Store this file on the first SD card of your DAN][ controller.

A3ROM_DANII_4KB.bin / A3ROM_DANII_8KB.bin:
  - Apple III ROM images to enable the autostart feature with the DAN][ controller.
  - These images can be used for either a 4KB or an 8KB ROM (The Apple /// mainboard accepts both types).
  - The use of the autostart ROM is optional. The autostart ROM allows to boot directly from the DAN][ controller,
    without requiring any disk at all (AlphaLock pressed: normal disk boot, AlphaLock not pressed: DAN][ boot strap).

