; DAN2on3config: Apple /// Configuration Menu for the DAN II Card. Thorsten Brehm, 2022.
;
; Based on DAN II Firmware by profc9 (https://github.com/profdc9/Apple2Card).
;
; Apple II(I) forever!
;

;          .TITLE "DAN2on3config - Apple /// Configuration Menu for the DAN II Card. Thorsten Brehm, 2022."

           .ORG $A000  ; this is where Apple III bootloaders live
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
SLOT_LINE   = $0580
STATUS1_LINE= $0780
STATUS2_LINE= $0428
CARD1_LINE  = $0628
CARD2_LINE  = $06A8
CONFIG_LINE = $0650
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
DAN2_DoStatus = $00               ; get status of a unit
DAN2_DoRead   = $01               ; read a block
DAN2_DoWrite  = $02               ; write a block
DAN2_DoFormat = $03               ; format a block (well, does nothing really)
DAN2_DoSetVol = $04               ; select volumes (both units)

;
; DANII Error Constants
;
IOERR = $27                       ; I/O error code
NODEV = $28                       ; no device connected
WPERR = $2B                       ; write protect error

DAN2CardIdLen = $05               ; check 5 bytes in ROM for card detection
DAN2CardIdOfs = $0A               ; offset where to find the DAN2 card's ID
DAN2CardId:
          .BYTE $A9,$01           ; ROM bytes at offset $08: "BNE +3;STA $BFFB,X"
          .BYTE $9D,$FB,$BF

;
; Parameter block for DAN2 commands
;
DAN2Cmd   = $D0                   ; DAN2 command byte
DAN2Unit  = $D1                   ; DAN2 Unit (slot): slot 1=$00, slot 2 = $80
DAN2Buf   = $D2                   ; DAN2 Buffer Address (2 bytes, little endian)
DAN2BlkNum= $D4                   ; DAN2 Block Location (2 bytes, little endian)

;
; Private temp registers
;
INVERSE   = $C8                   ; character mode (normal, inverse etc)
DAN2Slot  = $C9                   ; 1 byte: slot number of the DAN2 card
CURSOR    = $CA                   ; 2 bytes
POINTER   = $CC                   ; 2 bytes

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

;
; Strings (in first boot block)
;
TITLE_MSG: .BYTE "DAN2ON3 - APPLE /// SD CARD STORAGE MENU",0
APPLE4EVR: .BYTE "APPLE II(I) FOREVER!",0

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
DO_PRINT: STA POINTER+1              ; store A/Y in pointer
          STY POINTER
          LDY #$00                   ; simple print routine
PRINT_NEXT:
          LDA (POINTER),Y            ; read byte from string
          BEQ PRINT_DONE             ; done when 0
          ORA INVERSE                ; add inverse/normal text flag
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
          LDX #$FB                       ; set stack
          TXS
          JSR CLRSCR                     ; init screen
;          BIT BEEPER                     ; beep

ShowTitle:LDA #$00                       ; show title
          STA INVERSE                    ; enable inverse printing
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
          LDA #$80
          STA INVERSE                    ; disable inverse printing
LoadBlock2:                              ; load the second part of the bootloader
          LDA #$01                       ; load sector1/block 1 (=A)
          STA IBCMD                      ; set BLOCKIO command: 1=READ
          LDX #$A2
          STX IBBUFP+1                   ; set upper address byte
          LDX #$00                       ; load track 0 (=X)
          STX IBBUFP                     ; clear lower address byte
          JSR BLOCKIO                    ; now load block 1 (A), track 0 (X)
          BCS ErrorBeep                  ; unable to load?
LoadOK:
          LDA OK_MSG                     ; verify content of second bootloader block
          CMP #'O'                       ; data as expected?
          BNE ErrorBeep                  ; no? then give up...
          JSR DAN2Init                   ; find the DAN2 card
          BCS HaveNoCard                 ; No card? Damn!
HaveCard: LDA DAN2Slot                   ; Get slot number
          ORA #'0'                       ; convert to ASCII
          STA SLOT_NUMBER                ; Update message
          PRINTY SLOT_LINE+5, SLOT_MSG   ; Show message with slot number

          JSR DAN2CheckVolumes           ; Show status of volumes

          PRINTY CARD1_LINE+5, CARD1_MSG ; Ask for card1 configuration
          LDX #$01                       ; allow entering '!'
          JSR GETCARDKEY
          STA DAN2BlkNum                 ; remember card 1 selection

          PRINTY CARD2_LINE+5, CARD2_MSG ; Ask for card2 configuration
          LDX #$00                       ; do not allow entering '!'
          JSR GETCARDKEY
          STA DAN2BlkNum+1

          LDA #DAN2_DoSetVol             ; cofiguration command
          JSR DAN2_Do
          BCS CfgErr                     ; error?
          PRINTY CONFIG_LINE+11, CFGOK_MSG ; "configuration "
          BCC CfgDone

ErrorBeep:BIT BEEPER                     ; just ring the bell
EXIT:     JMP EXIT                       ; full stop!

CfgErr:   PRINTY CONFIG_LINE+9, CFGERR_MSG  ; "configuration "
CfgDone:  JSR DAN2CheckVolumes           ; Update status of volumes
          BCC EXIT                       ; unconditional branch, just block

HaveNoCard:
          PRINTY SLOT_LINE+7, NOSLOT_MSG
          BCC ErrorBeep                  ; unconditional branch, just block

;
; Check status of both volumes
;
DAN2CheckVolumes:
          LDX #$00                ; volume 1
          STX DAN2Unit
          LDX #'1'
          STX CARD_NUM            ; update VOL_MSG string: "CARD 1"
          PRINTY STATUS1_LINE+6,VOL_MSG
          LDA #DAN2_DoStatus      ; status command
          JSR DAN2_Do             ; get status
          JSR PrintStatus

          LDX #'2'
          STX CARD_NUM            ; update VOL_MSG string: "CARD 2"
          PRINTY STATUS2_LINE+6,VOL_MSG
          LDA #$80                ; volume 2
          STA DAN2Unit
          LDA #DAN2_DoStatus      ; status command
          JSR DAN2_Do             ; get status
PrintStatus:
          BCS StatusError
          LDY #<OK_MSG            ; load low byte
          BCC PrintStatus2
StatusError:
          LDY #<NOVOL_MSG         ; load low byte of string address in Y
PrintStatus2:
          LDA #>NOVOL_MSG         ; load high byte of string address in A
          JSR DO_PRINT
          RTS

;
; Search DAN2 card in all slots - and intialize the card
;
DAN2Init:
          LDA #$00
          STA DAN2Slot
          TAY
@0:       STA DAN2Cmd,Y           ; zero out block numbers, buffer address etc
          INY
          CPY #$06                ; initialize 6 bytes
          BNE @0
DAN2FindCard:                     ; let's find the card in any slot
          LDA $C1                 ; start with slot 1
          STA POINTER+1           ; setup the address
          LDA #DAN2CardIdOfs      ; store offset of ID in ROM 
          STA POINTER
CheckSlotId:
          LDY #$00
CheckSlotIdNext:
          LDA DAN2CardId,Y        ; load signature byte
          CMP (POINTER),Y         ; check if signature byte matches ROM
          BNE NextSlot            ; no match?
          INY                     ; next signature byte
          CPY #DAN2CardIdLen      ; all bytes of ID checked?
          BNE CheckSlotIdNext     ; jump to check more bytes
          LDA POINTER+1           ; Yay, found a card!
          AND #$07                ; mask slot number (1-4)
          STA DAN2Slot            ; remember slot number of DAN2 card
          JSR DAN2_GetX           ; get X to address the slot 
          LDA #$FA                ; set register A control mode to 2
          STA $BFFB,X             ; write to 82C55 mode register (mode 2 reg A, mode 0 reg B)
          CLC
          RTS
NextSlot:
          INC POINTER+1
          LDA POINTER+1
          CMP #$C5
          BNE CheckSlotId         ; try next slot
          SEC                     ; error: no card found
          RTS

;
; Read volume selection key.
;  Does not allow user to select '!' unless called with X!=0.
;  Selected volume number is returned in A.
;  A: 0-9 or $FF for '!'
;
GETCARDKEY:
          JSR READKEY             ; read keyboard
          LDY #$01                ; load offset for character output
          CMP #'!'+128            ; check '!'
          BEQ EXCL
          CMP #'0'+128            ; less than '0'?
          BCC KEYERR
          CMP #'9'+128+1          ; beyond '9'?
          BCS KEYERR
          STA (CURSOR),Y          ; print selected character to screen
          AND #$0F                ; mask 0..9
          RTS
KEYERR:   BIT BEEPER              ; beep on invalid entries
          JMP GETCARDKEY          ; try again
EXCL:     CPX #$00                ; was '!' selection allowed?
          BEQ KEYERR              ; otherwise try again
          STA (CURSOR),Y          ; print selected character to screen
          LDA #$FF                ; ok, return $FF
          RTS

;
; Calculate X register to address the DAN2 I/O area
;
DAN2_GetX:
          LDA DAN2Slot               ; load slot number
          ASL A                      ; shift by 4
          ASL A
          ASL A
          ASL A
          ORA #$88                   ; add $88 to it so we can address from page $BF ($BFF8-$BFFB)
                                     ; this works around 6502 phantom read
          TAX
          RTS

;
; communicate with DAN2 card
;   call convention: command byte to be executed in A.
;   return convention: carry is set on error, cleared on success.
;
DAN2_Do:
          STA DAN2Cmd                ; store command byte
          JSR DAN2_GetX              ; get X to address the correct slot of the DAN2 card

          LDY #$FF                   ; lets send the command bytes directly to the Arduino
          LDA #$AC                   ; send this byte first as a magic byte
          BNE DAN2send
DAN2byte:
          LDA DAN2Cmd,Y              ; get next byte
DAN2send:
          STA $BFF8,X                ; push it to the Arduino
DAN2byte2:
          LDA $BFFA,X                ; get port C
          BPL DAN2byte2              ; wait until its received (OBFA is high)
          INY
          CPY #$06                   ; 6 bytes to be sent for the command
          BNE DAN2byte               ; send next byte
DAN2wait:
          LDA $BFFA,X                ; get port C
          AND #$20                   ; check IBF (input buffer full flag)
          BEQ DAN2wait               ; wait until there's a byte available
          LDA $BFF8,X                ; get the byte
          BEQ DAN2ok                 ; yay, no errors!  can process the result
          SEC                        ; return the error: carry set
          RTS
DAN2ok:                              ; A=0 at this point
          CLC                        ; no error
          RTS

NOSLOT_MSG:.BYTE "NO DANII CONTROLLER FOUND!",0
SLOT_MSG:  .BYTE "DANII CONTROLLER IN SLOT "
SLOT_NUMBER:.BYTE "0 OK!",0
CFGOK_MSG: .BYTE "CONFIGURATION OK!",0
CFGERR_MSG:.BYTE "CONFIGURATION FAILED!",0
VOL_MSG:   .BYTE "STATUS CARD "
CARD_NUM:  .BYTE "0: ",0
CARD1_MSG: .BYTE "CARD 1 (0-9,!):",0
CARD2_MSG: .BYTE "CARD 2 (0-9)  :",0
NOVOL_MSG: .BYTE "NO VOLUME",0
OK_MSG:    .BYTE "OK       ",0

