; DAN2on3config: Apple /// Configuration Menu for the DAN II Card. Thorsten Brehm, 2022.
;
; Based on DAN II Firmware by profc9 (https://github.com/profdc9/Apple2Card).
;
; Apple II(I) forever!
;

;          .TITLE "DAN2on3config - Apple /// Configuration Menu for the DAN II Card. Thorsten Brehm, 2022."

;DEBUG=1

.IFNDEF DEBUG
           .ORG $A000  ; this is where Apple III bootloaders live
.ELSE
           .ORG $A200
.ENDIF
           JMP boot

;
; Apple 3 registers
;
KBD_KEY       = $C000 ; keyboard value
KBD_STROBE    = $C010 ; clear keypress
BEEPER        = $C040 ; beep!
BANKREG       = $FFEF ; Bank selection register for $2000-$9FFF (lower 4 bits)
CLRSCR        = $FB7D ; screen init routine in ROM
BLOCKIO       = $F479 ; BLOCK I/O routine in ROM
ENVREG        = $FFDF ; Environment Register
                      ; flags: 0x80: disable 2MHz (enable 1MHz)
                      ;        0x40: enable I/O bank
                      ;        0x20: screen enable
                      ;        0x10: enable reset/NMI
                      ;        0x08: disable RAM write
                      ;        0x04: primary stack
                      ;        0x03: enable ROM space

SCRNLOC    =    $58
LMARGIN    =    SCRNLOC      ; left window border for text display (X position after new line)
RMARGIN    =    SCRNLOC+1    ; right window border for line wrap
WINTOP     =    SCRNLOC+2    ; first display line
WINBTM     =    SCRNLOC+3    ; last display line
CH         =    SCRNLOC+4
CV         =    SCRNLOC+5
MODES      =    SCRNLOC+$10  ; bit 0x80 for inverse (1=normal, 0=inverse), 0x40 for 40 vs 80char mode (1=80 chars)
TEMPX      =    SCRNLOC+$14
TEMPY      =    SCRNLOC+$15
CSWL       =    SCRNLOC+$16
CSWH       =    SCRNLOC+$17

;
; Apple 3 screen lines
;
; Apple II(I): text mode line addresses:
;  1- 5: $0400, $0480, $0500, $0580, $0600,
;  6-10: $0680, $0700, $0780, $0428, $04A8,
; 11-15: $0528, $05A8, $0628, $06A8, $0728,
; 16-20: $07A8, $0450, $04D0, $0550, $05D0,
; 21-24: $0650, $06D0, $0750, $07D0
TITLE_LINE  = $0400
FOOTER_LINE = $07D0

;
; Apple 3 ROM parameters
;
IBSLOT = $81                      ; disk drive slot (preset by ROM)
IBDRVN = $82                      ; disk drive (preset by ROM)
IBBUFP = $85                      ; buffer pointer for disk I/O (2 bytes)
IBCMD  = $87                      ; command byte for disk I/O (1 byte: read=1, write=2)

;
; DANII Command Constants
;
DAN2_DoStatus  = $00              ; get status of a unit
DAN2_DoRead    = $01              ; read a block
DAN2_DoWrite   = $02              ; write a block
DAN2_DoFormat  = $03              ; format a block (well, does nothing really)
DAN2_DoGetVol  = $05              ; get selected volumes (both units)
DAN2_DoSetVolT = $06              ; select volumes (not in EEPROM)
DAN2_DoSetVol  = $07              ; select volumes in EEPROM

DAN2CardIdLen = $05               ; check 5 bytes in ROM for card detection
DAN2CardIdOfs = $0A               ; offset where to find the DAN2 card's ID
DAN2CardId:
          .BYTE $A9,$01           ; ROM bytes at offset $0A: "LDA #$01"
          .BYTE $9D,$FB,$BF       ; ROM bytes at offset $0C: "STA $BFFB,X"

;
; Parameter block for DAN2 commands
;
DAN2Cmd   = $42                   ; DAN2 command byte
DAN2Unit  = $43                   ; DAN2 Unit (slot): slot 1=$00, slot 2 = $80
DAN2Buf   = $44                   ; DAN2 Buffer Address (2 bytes, little endian)
DAN2BlkNum= $46                   ; DAN2 Block Location (2 bytes, little endian)

;
; Private temp registers
;
CURSOR    = $CA                   ; 2 bytes

; DAN2 temp registers
INSTRUC = $F0
LOWBT   = $F1
HIGHBT  = $F2
RTSBYT  = $F3
VOLDRIVE0 = $F5
VOLDRIVE1 = $F6
GVOLDRIVE0 = $F7
GVOLDRIVE1 = $F8
LENGTH = $F9
LASTVOL = $FA
VOL = $FB

BLKBUF = $1000

;
; Macros
;
.MACRO CURSOR line
          LDA #<(line)
          STA CURSOR
          LDA #>(line)
          STA CURSOR+1
.ENDMACRO

.MACRO PRINT msg
          LDY #<(msg)             ; load low byte of string address in Y
          LDA #>(msg)             ; load high byte of string address in A
          JSR DO_PRINT
.ENDMACRO

.MACRO PRINTY line,msg
          CURSOR (line)
          PRINT (msg)
.ENDMACRO

; generate Apple-ASCII string (with MSB set)
.MACRO   ASCHI STR
.REPEAT  .STRLEN (STR), C
.BYTE    .STRAT (STR, C) | $80
.ENDREP
.ENDMACRO

; generated string with inverted characters
.MACRO   ASCINV STR
.REPEAT  .STRLEN (STR), C
.BYTE    .STRAT (STR, C)
.ENDREP
.ENDMACRO

;
; Strings (in first boot block)
;
TITLE_MSG: .BYTE "DAN2ON3 - APPLE /// SD CARD STORAGE MENU",0
APPLE4EVR: .BYTE "APPLE III FOREVER!",0

LINEFEED:
	  LDA #$8D
COUT:
          STY     TEMPY
          STX     TEMPX
          JSR     COUT1
          LDY     TEMPY
          LDX     TEMPX
          RTS
COUT1:    JMP     (CSWL)

;
; Read any key (=> A)
;
READKEY:
          LDA  KBD_KEY               ; do we have a key
          BPL  READKEY               ; wait until we have a key
          STA  KBD_STROBE            ; clear key
          RTS

;
; Print string at address A/Y
; (always exits with C=0, A!=0)
;
DO_PRINT: STA TEMPX+1                ; store A/Y in pointer
          STY TEMPX
          LDY #$00                   ; simple print routine
PRINT_NEXT:
          LDA (TEMPX),Y              ; read byte from string
          BEQ PRINT_DONE             ; done when 0
          STA (CURSOR),Y             ; write to screen
          INY
          BNE PRINT_NEXT             ; next
PRINT_DONE:
          TYA                        ; update screen address (behind the printed string)
          CLC
          ADC CURSOR                 ; move cursor behind printed string
          STA CURSOR
          BCC noCarry
          INC CURSOR+1               ; add carry
noCarry:  RTS

;
; boot entry
;
boot:
          SEI                            ; interrupt disable
          CLD                            ; decimal mode off
          LDA #$77
          STA ENVREG                     ; enable ROMs, select 2MHz operation
          LDA #$00
          STA BANKREG                    ; bank 0 select
          STA GVOLDRIVE0
          StA GVOLDRIVE1
          LDX #$FB                       ; set stack
          TXS
          JSR CLRSCR                     ; init screen

          JSR LINEFEED
          JSR LINEFEED
          STA  KBD_STROBE                ; clear pending keypress

ShowTitle:LDA #$00                       ; show title
          PRINTY TITLE_LINE,  TITLE_MSG
          CURSOR FOOTER_LINE
          LDA #$20
          LDY #$27                       ; clear 40 characters ($00-$27)
CLRLINE:  STA (CURSOR),Y
          DEY
          BPL CLRLINE
          LDA #<(FOOTER_LINE+10)
          STA CURSOR
          PRINT APPLE4EVR

.IFNDEF DEBUG
LoadBlock2:                              ; load the second part of the bootloader from disk
          LDA #$01                       ; load sector1/block 1 (=A)
          STA IBCMD                      ; set BLOCKIO command: 1=READ
          LDX #$A2
          STX IBBUFP+1                   ; set upper address byte
          LDX #$00                       ; load track 0 (=X)
          STX IBBUFP                     ; clear lower address byte
          JSR BLOCKIO                    ; now load block 1 (A), track 0 (X)
          BCS BEEP_EXIT                  ; unable to load?
LoadOK:
          LDA OK_MSG                     ; verify content of second bootloader block
          CMP #'O'+128                   ; data as expected?
          BNE BEEP_EXIT                  ; no? then give up...
.ENDIF

          LDA #14                        ; horizontal cursor at position 7(x2)
          STA CH
          LDX #(DANII_MSG-MSGS)          ; show controller message
          JSR DISPMSG

          JSR DAN2Init                   ; find the DAN2 card
          BCC HaveCard

HaveNoCard:                              ; No card? Damn!
          LDX #(NOSLOT_MSG-MSGS)
          JSR DISPMSG
          BEQ BEEP_EXIT                  ; unconditional branch, just block
BEEP_EXIT:BIT BEEPER                     ; just ring the bell
EXIT:
.IFDEF DEBUG
          JMP REBOOT
.ELSE
          JMP EXIT                       ; full stop!
.ENDIF

HaveCard: LDA HIGHBT                     ; get slot address
          AND #$07                       ; mask slot number
          ORA #'0'+$80                   ; convert to ASCII
          STA SLOT_NUMBER                ; Update message
          LDX #(SLOT_MSG-MSGS)
          JSR DISPMSG

          JSR GETVOL                     ; get current volume selection
          JSR SHOW_VOLUMES

ASK_SELECTION:                           ; ask for new selection
          JSR CARDMS0
          LDA #20
          STA CH
          LDA GVOLDRIVE0
          JSR ASKVOL
          STA VOLDRIVE0
          JSR PRHEX

          LDA #40
          STA CH
          JSR CARDMS1
          LDA #60
          STA CH
          LDA GVOLDRIVE1
          JSR ASKVOL
          STA VOLDRIVE1
          JSR PRHEX

SET_VOLUMES:
          LDA VOLDRIVE0
          STA GVOLDRIVE0
          LDA VOLDRIVE1
          STA GVOLDRIVE1
          JSR SETVOLW
          BCS CFG_ERR
          LDA #66
          STA CH
          LDX #(OK_MSG-MSGS)
          .BYTE $2C ; "BIT", ignore next two bytes
CFG_ERR:
          LDX #(ERR_MSG-MSGS)
          JSR DISPMSG

          LDA #3
          STA CV
          JSR LINEFEED
          JSR SHOW_VOLUMES

          JMP BEEP_EXIT

SHOW_VOLUMES:
          LDA #0
          STA VOL         ; set drive number
UNITLOOP:
          LDA VOL         ; set both drives to location
          STA VOLDRIVE0
          STA VOLDRIVE1
          JSR SETVOL


          LDY GVOLDRIVE0
          LDA #0          ; start at column 0
          JSR DISPVOLUME  ; show item number and volume name

          LDA DAN2Unit
          ORA #$80        ; check SD-card 2 (drive 1)
          STA DAN2Unit    ; set high bit to get drive 1
          LDY GVOLDRIVE1
          LDA #40         ; start at column 20(*2)
          JSR DISPVOLUME  ; show item number for volume
          LDA DAN2Unit    ; clear high bit
          AND #$7F
          STA DAN2Unit

          JSR LINEFEED

          INC VOL         ; go to next volume
          LDA VOL
          CMP #$10
          BCC UNITLOOP
          JSR LINEFEED

RESTORE:
          LDA GVOLDRIVE0
          STA VOLDRIVE0
          LDA GVOLDRIVE1
          STA VOLDRIVE1
          JMP SETVOL

;
; Search DAN2 card in all slots - and intialize the card
;
DAN2Init:
          LDA #$00
          TAY
@0:       STA DAN2Cmd,Y           ; zero out block numbers, buffer address etc
          INY
          CPY #$06                ; initialize 6 bytes
          BNE @0
DAN2FindCard:                     ; let's find the card in any slot
          LDA $C1                 ; start with slot 1
          STA HIGHBT              ; setup the address
          LDA #DAN2CardIdOfs      ; store offset of ID in ROM 
          STA LOWBT               ; lower address offset
CheckSlotId:
          LDY #$00
CheckSlotIdNext:
          LDA DAN2CardId,Y        ; load signature byte
          CMP (LOWBT),Y           ; check if signature byte matches ROM
          BNE NextSlot            ; no match?
          INY                     ; next signature byte
          CPY #DAN2CardIdLen      ; all bytes of ID checked?
          BNE CheckSlotIdNext     ; jump to check more bytes
          LDA HIGHBT              ; Yay, found a card!
          ASL                     ; shift slot number in upper nibble
          ASL
          ASL
          ASL
          STA DAN2Unit            ; store UNIT ($10,$20,$30,$40 for slot 1..4)

          LDA #$20                ; store JSR at $F0
          STA INSTRUC
          LDA #$60                ; store RTS at $F3
          STA RTSBYT
          LDY #$00                ; store zero in low byte
          STY LOWBT
          DEY                     ; make zero a $FF
          LDA (LOWBT),Y           ; get low byte of address
          STA LOWBT               ; place at low byte
          CLC
          RTS
NextSlot:
          INC HIGHBT
          LDA HIGHBT
          CMP #$C5
          BNE CheckSlotId         ; try next slot
          SEC                     ; error: no card found
          RTS

CARDMS1: LDA #'2'
         STA CARD_MSG+5
CARDMS0:
         LDX #(CARD_MSG-MSGS)
DISPMSG: LDA MSGS,X
         BEQ RTSL
         JSR COUT
         INX
         BNE DISPMSG
BUFLOC:
         LDA #<BLKBUF    ; store buffer location
         STA DAN2Buf
         LDA #>BLKBUF
         STA DAN2Buf+1
RTSL:    RTS

READB:
         LDA #DAN2_DoRead; read block
         STA DAN2Cmd     ; store at $42
         JSR BUFLOC      ; store buffer location
         LDA #$02        ; which block (in this example $0002)
         STA DAN2BlkNum
         LDA #$00
         STA DAN2BlkNum+1
         JMP INSTRUC

SETVOLW: LDA #DAN2_DoSetVol; set volume but write to EEPROM
         BNE SETVOLC
SETVOL:
         LDA #DAN2_DoSetVolT; set volume dont write to EEPROM
SETVOLC:
         STA DAN2Cmd
         LDA VOLDRIVE0
         STA DAN2BlkNum
         LDA VOLDRIVE1
         STA DAN2BlkNum+1
         JSR BUFLOC      ; dummy buffer location
         JMP INSTRUC

GETVOL:
         LDA #DAN2_DoGetVol ; get selected volumes
         STA DAN2Cmd     ; store at $42
         JSR BUFLOC      ; store buffer location
         JSR INSTRUC
         BCS RTSL
         LDA BLKBUF
         STA GVOLDRIVE0
         LDA BLKBUF+1
         STA GVOLDRIVE1
         RTS

SETVIDEO:
         LDA MODES
         AND #$7F
         BCS INVERSED
         ORA #$80
INVERSED:
         STA MODES
         RTS

DISPVOLUME:              ; display volume number/name
         STY TEMPY
         STA CH
         LDA VOL         ; print hex digit for row
         PHA
         JSR PRHEX
         LDA #':'+128
         JSR COUT        ; print ":"
         PLA
         CMP TEMPY
         BNE NORMVID
         JSR SETVIDEO
NORMVID:
         INC CH          ; skip space
         INC CH          ; skip space
         JSR READB       ; read a block from drive 0
DISPNAME:
         LDX #0
         BCS NOHEADER    ; didn't read a sector
         LDA BLKBUF+5    ; if greater than $80 not a valid ASCII
         BMI NOHEADER
         LDA BLKBUF+4    ; look at volume directory header byte
         AND #$F0
         CMP #$F0
         BNE NOHEADER
         LDA BLKBUF+4
         AND #$0F
         BEQ NOHEADER
         STA LENGTH
DISPL:
         LDA BLKBUF+5,X
         ORA #$80
         JSR COUT
         INX
         CPX LENGTH
         BNE DISPL
         BEQ VIDEO
NOHEADER:
         LDX #(NO_VOL_MSG-MSGS)
         JSR DISPMSG
VIDEO:
         CLC
         JSR SETVIDEO
         RTS

PRHEX:
	CMP #$0A
	BCC IS09
	ADC #$06
IS09:   ADC #$B0
        JMP COUT

.IFDEF DISABLED
ABORT:
         LDA GVOLDRIVE0
         STA VOLDRIVE0
         LDA GVOLDRIVE1
         STA VOLDRIVE1
         JSR SETVOL
         PLA
         PLA
         JMP EXIT
.ENDIF

ASKVOL:
         STA LASTVOL   ; remember previous volume selection
         LDA #'?'
         JSR COUT
         DEC CH
         DEC CH
GETHEX:
         JSR READKEY
         CMP #13+128   ; RETURN key
         BNE NORET
         LDA LASTVOL   ; load previous volume selection
         RTS
NORET:
;         CMP #27+128   ; ESCAPE key
;         BEQ ABORT
;         CMP #'!'+128   ; is !
;         BEQ SPCASE
         CMP #'a'+128
         BCC NOLOWER
         SEC
         SBC #$20
NOLOWER:
         CMP #'A'+128
         BCC NOLET
         CMP #'F'+128+1
         BCC ISLET
NOLET:   CMP #'0'+128
         BCC GETHEX
         CMP #'9'+128+1
         BCS GETHEX
         AND #$0F
         RTS
ISLET:
         SEC
         SBC #7
         AND #$0F
         RTS
SPCASE:
         LDA #$FF
         RTS

MSGS:
NO_VOL_MSG: ASCHI "---"
           .BYTE 0
DANII_MSG:  ASCHI "DANII CONTROLLER: "
           .BYTE 0
NOSLOT_MSG: ASCHI "NOT FOUND!"
           .BYTE $8D,0
SLOT_MSG:   ASCHI "SLOT "
SLOT_NUMBER:ASCHI "0"
           .BYTE $8D,$8D,0
CARD_MSG:   ASCINV "CARD 1:"
           .BYTE 0
ERR_MSG:    ASCHI "ERROR!"
           .BYTE 0
OK_MSG:     ASCHI "OK!"
           .BYTE 0

.IFDEF DEBUG
REBOOT:
          LDA #40
DLY3:     LDY #0
DLY1:     LDX #0
DLY2:     DEX
          BNE DLY2
          DEY
          BNE DLY1
          TAX
          DEX
          TXA
          BNE DLY3
	  JMP $A000
.ENDIF

