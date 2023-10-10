;
; Apple 3 registers
;
KBD_KEY       = $C000 ; keyboard value
KBD_MOD       = $C008 ; keyboard modifiers
KBD_STROBE    = $C010 ; clear keypress
BEEPER        = $C040 ; beep!
CHRRAM_DISABLE= $C04E ; character RAM disable
CHRRAM_ENABLE = $C04F ; character RAM enable
CLRSCR        = $FB7D ; screen init routine in ROM
BLOCKIO       = $F479 ; BLOCK I/O routine in ROM
DISKBOOT      = $F6A1 ; DISK BOOT routine in ROM
ENVREG        = $FFDF ; Environment Register
                      ; flags: 0x80: disable 2MHz (enable 1MHz)
                      ;        0x40: enable I/O bank
                      ;        0x20: screen enable
                      ;        0x10: enable reset/NMI
                      ;        0x08: disable RAM write
                      ;        0x04: primary stack
                      ;        0x02: select ROM page 1/page 0 (page 1=default)
                      ;        0x01: enable ROM space

SOUND_DAC     = $FFE0 ; SOUND DAC: 6 bit
BANKREG       = $FFEF ; flags:
                      ;        0x80: /IRQ input
                      ;        0x40: /AIISW output
                      ;        0x20: /IRQ3 input
                      ;        0x10: /IRQ4 input
                      ;        0x08: reserved/NC
                      ;        0x04: bank switch bit 2
                      ;        0x02: bank switch bit 1
                      ;        0x01: bank switch bit 0

SCRNLOC    =    $58
LMARGIN    =    SCRNLOC      ; left window border for text display (X position after new line)
RMARGIN    =    SCRNLOC+1    ; right window border for line wrap
WINTOP     =    SCRNLOC+2    ; first display line
WINBTM     =    SCRNLOC+3    ; last display line
CH         =    SCRNLOC+4
CV         =    SCRNLOC+5
BAS4L      =    SCRNLOC+6
BAS4H      =    SCRNLOC+7
BAS8L      =    SCRNLOC+8
BAS8H      =    SCRNLOC+9
TBAS4L     =    SCRNLOC+$0A
TBAS4H     =    SCRNLOC+$0B
TBAS8L     =    SCRNLOC+$0C
TBAS8H     =    SCRNLOC+$0D
FORGND     =    SCRNLOC+$0E
BKGND      =    SCRNLOC+$0F
MODES      =    SCRNLOC+$10  ; bit 0x80 for inverse (1=normal, 0=inverse), 0x40 for 40 vs 80char mode (1=80 chars)
CURSOR     =    SCRNLOC+$11
TEMPX      =    SCRNLOC+$14
TEMPY      =    SCRNLOC+$15
CSWL       =    SCRNLOC+$16
CSWH       =    SCRNLOC+$17
KSWL       =    SCRNLOC+$18
KSWH       =    SCRNLOC+$19

; Apple II to III mapping
BASL       =    BAS4L
INVFLG     =    MODES

; Apple III ROM routines
HOME       = $FB7D ; Apple III screen init routine
VTAB       = $FBC7 ; Apple III BASCALC routine to calculate line's base address
SETCV      = $FBC5
RDKEY      = $FD0C
COUT2      = $FC06
COUT       = $FC39
PRBYTE     = $F9AE
PRHEX      = $F9B7
BELL       = $FC4E
DEBUG_MONITOR = $F901

; Apple III Color Constants
COL_BLACK      = 0
COL_MAGENTA    = 1
COL_DARKBLUE   = 2
COL_VIOLETT    = 3
COL_DARKGREEN  = 4
COL_GRAY1      = 5
COL_MIDDLEBLUE = 6
COL_BLUE       = 7
COL_BROWN      = 8
COL_ORANGE     = 9
COL_GRAY2      = 10
COL_PINK       = 11
COL_GREEN      = 12
COL_YELLOW     = 13
COL_LIGHTBLUE  = 14
COL_WHITE      = 15

; generate Apple-ASCII string (with MSB set)
.MACRO   ASCHI STR
.REPEAT  .STRLEN (STR), C
.BYTE    .STRAT (STR, C) | NORMAL
.ENDREP
.ENDMACRO

; generated string with inverted characters
.MACRO   ASCINV STR
.REPEAT  .STRLEN (STR), C
.BYTE    .STRAT (STR, C)
.ENDREP
.ENDMACRO

