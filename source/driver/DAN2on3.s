; DAN2on3: Apple /// SOS driver for the DAN II SD Card. Thorsten Brehm, 2022.
;
; Based on SOS block driver skeleton by Apple and CFFA3K driver by David Schmitt.
;
; Apple II(I) forever!
;

;          .TITLE "DAN2on3 - DAN II Card Storage Driver for Apple /// SOS. Thorsten Brehm, 2022."
           .PROC  DAN2on3

           .setcpu "6502"         ; of course!
           .reloc                 ; SOS driver must be relocatable (no fixed memory address)

;FORMAT_SUPPORT = 1               ; disabled for now (not implemented yet)
;UART_DEBUGGING = 1               ; enable/disable DEBUG output

DriverVersion   = $1100           ; Driver Version 1.0.1 ($ABC0 = A.B.C)
DriverVendor    = $5442           ; Driver Vendor "TB"
.IFDEF FORMAT_SUPPORT
DriverType      = $D1             ; Block device/Write/non-removable/format support
.ELSE
DriverType      = $C1             ; Block device/Write/non-removable/no format support
.ENDIF
DriverSubtype   = $02		  ; subtype "profile"
InitialSlot     = $FF             ; Slot number to assume we're in ($FF=automatically search slot)

;
; DANII Command Constants
;
DAN2_DoStatus = $00
DAN2_DoRead   = $01
DAN2_DoWrite  = $02
.IFDEF FORMAT_SUPPORT
DAN2_DoFormat = $03
.ENDIF
DAN2_DoSetVol = $04

.IFDEF FORMAT_SUPPORT
DAN2_DoWrite0  = $FE
DAN2_DoWriteFF = $FF
.ENDIF

; DAN II card protocol:
;   Magic byte  (1 byte: $AC)
;   Command     (1 byte: $00-$04)
;   UnitNumber  (1 byte: $00=slot 1, $80=slot 2)
;   BufAddress  (2 bytes: for debugging only, little endian)
;   BlockNumber (2 bytes, little endian)

;
; SOS Equates
;
ExtPG     = $1401                 ; Driver extended bank address offset
AllocSIR  = $1913                 ; Allocate system internal resource
DeallocSIR= $1916                 ; Deallocated system internal resource
SelC800   = $1922                 ; Select/deselect I/O space
SysErr    = $1928                 ; Report error to system
EReg      = $FFDF                 ; Environment register
BReg      = $FFEF                 ; Bank register

ReqCode   = $C0                   ; Request code
SOS_Unit  = $C1                   ; Unit number
SosBuf    = $C2                   ; buffer pointer (2 bytes)
ReqCnt    = $C4                   ; Requested byte count (2 bytes)
CtlStat   = $C2                   ; Control/status code
CSList    = $C3                   ; Control/status list pointer
SosBlk    = $C6                   ; Starting block number
QtyRead   = $C8                   ; pointer to bytes read returned by D_READ (2 bytes)

;
; Our temps in zero page
;
Count     = $CC                   ; 2 bytes

.IFDEF FORMAT_SUPPORT
FormBufPtr= $CE                   ; 2 bytes pointer to format buffer
.ENDIF

;
; Parameter block specific to current SOS request
;
DAN2Cmd   = $D0                   ; DAN2 command byte
DAN2Unit  = $D1                   ; DAN2 Unit (slot): slot 1=$00, slot 2 = $80
DAN2Buf   = $D2                   ; DAN2 Buffer Address (2 bytes, little endian)
DAN2BlkNum= $D4                   ; DAN2 Block Location (2 bytes, little endian)
Num_Blks  = $D6                   ; 2 bytes lsb, msb (calculated by CkCnt)
DAN2uppage= $D8                   ; count pages when we process 2x256 bytes

;
; SOS Error Codes
;
XDNFERR   = $10                   ; Device not found
XBADDNUM  = $11                   ; Invalid device number
XREQCODE  = $20                   ; Invalid request code
XCTLCODE  = $21                   ; Invalid control/status code
XCTLPARAM = $22                   ; Invalid control/status parameter
XNORESRC  = $25                   ; Resources not available
XBADOP    = $26                   ; Invalid operation
XIOERROR  = $27                   ; I/O error
XNODRIVE  = $28                   ; Drive not connected
XBYTECNT  = $2C                   ; Byte count not a multiple of 512
XBLKNUM   = $2D                   ; Block number to large
XDISKSW   = $2E                   ; Disk switched
XNORESET  = $33                   ; Device reset failed

;
; Switch Macro
;
.MACRO  SWITCH index,bounds,adrs_table,noexec ; See SOS Reference
  .IFNBLANK index                ; If PARM1 is present,
          LDA     index          ; load A with switch index
  .ENDIF
  .IFNBLANK bounds               ; If PARM2 is present,
          CMP     #bounds+1      ; perform bounds checking
          BCS     @110           ; on switch index
  .ENDIF
          ASL     A              ; Multiply by 2 for table index
          TAY
          LDA     adrs_table+1,Y ; Get switch address from table
          PHA                    ; and push onto Stack
          LDA     adrs_table,Y
          PHA
  .IFBLANK noexec                ; If PARM4 is omitted,
          RTS                    ; exit to code
  .ENDIF
@110:
.ENDMACRO

          .SEGMENT "TEXT"
;
; Driver Comment Field (the only thing in the text section)
;
          .WORD  $FFFF               ; Signal that we have a comment
          .WORD  COMMENT_END-COMMENT ; comment string length
COMMENT:  .BYTE  "DAN2on3 - DAN II Card Storage Driver for Apple /// SOS. Thorsten Brehm, 2022."
COMMENT_END:

          .SEGMENT "DATA"            ; yes, _everything_ else is in the DATA section

;------------------------------------
;
; Device identification Block (DIB) - Volume #0, ".DAN1"
;
;------------------------------------

DIB_0:    .WORD     DIB_1            ; Link pointer
          .WORD     Entry            ; Entry pointer
          .BYTE     $05              ; Name length byte
          .BYTE     ".DAN1          "; Device name
          .BYTE     $80              ; Active, no page alignment
DIB0_Slot:.BYTE     InitialSlot      ; Slot number
          .BYTE     $00              ; Unit number
          .BYTE     DriverType       ; Type
          .BYTE     DriverSubtype    ; Subtype
          .BYTE     $00              ; Filler
DIB0_Blks:.WORD     $0000            ; # Blocks in device
          .WORD     DriverVendor     ; Manufacturer
          .WORD     DriverVersion    ; Driver version
          .WORD     $0000            ; DCB length followed by DCB
;
; Device identification Block (DIB) - Volume #1, ".DAN2"
;
DIB_1:    .WORD     $0000            ; Link pointer
          .WORD     Entry            ; Entry pointer
          .BYTE     $05              ; Name length byte
          .BYTE     ".DAN2          "; Device name
          .BYTE     $80              ; Active
DIB1_Slot:.BYTE     InitialSlot      ; Slot number
          .BYTE     $01              ; Unit number
          .BYTE     DriverType       ; Type
          .BYTE     DriverSubtype    ; Subtype
          .BYTE     $00              ; Filler
DIB1_Blks:.WORD     $0000            ; # Blocks in device
          .WORD     DriverVendor     ; Driver manufacturer
          .WORD     DriverVersion    ; Driver version
          .WORD     $0000            ; DCB length followed by DCB

;------------------------------------
;
; Local storage locations
;
;------------------------------------

LastOP:    .RES      $08, $FF             ; Last operation for D_REPEAT calls
SIR_Addr:  .WORD     SIR_Tbl              ; System Internal Resource
SIR_Tbl:   .RES      $05, $00
SIR_Len     =      *-SIR_Tbl
RdBlk_Proc:.WORD     $0000
WrBlk_Proc:.WORD     $0000
MaxUnits:  .BYTE     $00                  ; The maximum number of units
DCB_Idx:   .BYTE     $00                  ; DCB 0's blocks
           .BYTE     DIB1_Blks-DIB0_Blks  ; DCB 1's blocks

DAN2CardIdLen = $05                       ; check 5 bytes in ROM for card detection
DAN2CardIdOfs = $0A                       ; offset where to find the DAN2 card's ID
DAN2CardId:.BYTE     $A9,$01,$9D,$FB,$BF  ; ROM bytes at offset $0A: "LDA #$01;STA $BFFB,X"

InitOK:    .BYTE     $00                  ; Have we initialized the DANII card successfully?
LastError: .BYTE     $00                  ; Recent error RC from DAN2 card

;------------------------------------
;
; Driver request handlers
;
;------------------------------------

Entry:    LDA SOS_Unit               ; SOS volume unit number (0, 1)
          CLC                        ; map SOS unit 0 => DAN card unit 0; SOS unit 1 => DAN card unit $80
          ROR
          ROR
          AND #$80                   ; make sure it's only SD slot1 = $00 or SD slot 2=$80
          STA DAN2Unit               ; store DAN card unit number
          JSR Dispatch               ; Call the dispatcher
          LDX SOS_Unit               ; Get drive number for this unit
          LDA ReqCode                ; Keep request around for D_REPEAT
          STA LastOP,X               ; Keep track of last operation
          LDA #$00                   ; Return code
          RTS

;
; The Dispatcher.  Note that if we came in on a D_INIT call,
; we do a branch to Dispatch normally.  
; Dispatch is called as a subroutine!
;
DoTable:  .WORD     DRead-1          ; 0 Read request
          .WORD     DWrite-1         ; 1 Write request
          .WORD     DStatus-1        ; 2 Status request
          .WORD     DControl-1       ; 3 Control request
          .WORD     BadReq-1         ; 4 Unused
          .WORD     BadReq-1         ; 5 Unused
          .WORD     BadOp-1          ; 6 Open - valid for character devices
          .WORD     BadOp-1          ; 7 Close - valid for character devices
          .WORD     DInit-1          ; 8 Init request
          .WORD     DRepeat-1        ; 9 Repeat last read or write request

Dispatch: SWITCH ReqCode,9,DoTable   ; Serve the request

;
; Dispatch errors
;
BadReq:   LDA #XREQCODE              ; Bad request code!
          JSR SysErr                 ; Return to SOS with error in A
BadOp:    LDA #XBADOP                ; Invalid operation!
          JSR SysErr                 ; Return to SOS with error in A

;
; D_REPEAT - repeat the last D_READ or D_WRITE call
;
DRepeat:  LDX SOS_Unit
          LDA LastOP,X               ; Recall the last thing we did (LastOP has space for 2 units)
          CMP #$02                   ; Looking for operation < 2
          BCS BadOp                  ; Can only repeat a read or write
          STA ReqCode                ; restore last SOS command
          JMP Dispatch               ; now execute SOS command normally

;
; D_INIT call processing - called once each for all volumes.
;
DInit:
.IFDEF UART_DEBUGGING
          JSR DEBUG_INIT             ; enable DEBUG output
.ENDIF
          LDA SOS_Unit               ; Check if we're initting the zeroeth unit
          BNE UnitInit               ; No - then skip the signature check

CheckSig: LDX DIB0_Slot              ; Load slot number
          BPL SlotNext               ; check if fixed slot (1-4) is given or search is enabled (FF)
          LDX #$01                   ; start scanning at slot 1
SlotNext: TXA                        ; Form a $CsXX address, where s = slot #, XX=offset
          ORA #$C0                   ; I/O segment address
          STA Count+1
          LDA #DAN2CardIdOfs         ; load offset of card ID
          STA Count
          LDY #DAN2CardIdLen-1       ; load length of card ID
SigNext:  LDA (Count),Y              ; load byte from slot ROM
          CMP DAN2CardId,Y           ; Compare with known DAN2 ROM signature
          BNE NoMatch                ; Not a DAN2 controller if bytes don't match
          DEY                        ; count remaining bytes to check
          BPL SigNext                ; continue signature check?
          BMI Match                  ; All bytes matched: found a DAN2 card!

NoMatch:  LDA DIB0_Slot              ; Get original slot number
          BPL NoDevice               ; a fixed slot number was given? Abort!
          INX                        ; advance to scan next slot
          CPX #$05                   ; Already at slot 5?
          BEQ NoDevice               ; abort: no device (we have only 4 slots)
          BNE SlotNext               ; scan the next slot

Match:    TXA                        ; get slot number
          STA DIB0_Slot              ; remember slot number
          STA DIB1_Slot
          ORA #$10                   ; SIR = 16+slot#
          STA SIR_Tbl
          LDA #SIR_Len
          LDX SIR_Addr
          LDY SIR_Addr+1
          JSR AllocSIR               ; This one's mine!
          BCS NoDevice

          ; prepare DAN2 card 8255 PIO
          JSR DAN2_GetX              ; get X to address the slot 
          LDA #$FA                   ; set register A control mode to 2
          STA $BFFB,X                ; write to 82C55 mode register (mode 2 reg A, mode 0 reg B)
                                     ; How many units can we expect at maximum?
          LDA #$02                   ; fixed number of volumes so far
          STA MaxUnits
          STA InitOK                 ; Remember we found the card!

UnitInit:
          LDA InitOK                 ; Did we previously find a card?
          BEQ NoDevice               ; If not... then bail

          LDA #$00                   ; clear parameters
          STA DAN2Buf
          STA DAN2Buf+1
          STA DAN2BlkNum
          STA DAN2BlkNum+1

          LDA #DAN2_DoStatus         ; Ask for the status of this unit
          JSR DAN2_Do                ; communicate with DAN2 card
          BCS NoDevice               ; no device on error...

SaveCapacity:
          LDX SOS_Unit               ; Get the stats on this unit
          LDY DCB_Idx,X
          LDA #$FF                   ; just report $FFFF blocks (32MB)
          STA DIB0_Blks,Y
          STA DIB0_Blks+1,Y

UIDone:   CLC
          RTS

NoDevice: LDA #XDNFERR               ; Device not found
          JSR SysErr                 ; Return to SOS with error in A

;
; D_READ call processing
;
DRead:
          LDA InitOK                 ; Did we previously find a card?
          BNE DReadGo
          BEQ NoDevice               ; If not... then bail
DReadGo:
          JSR CkCnt                  ; Checks for validity, aborts if not
          JSR CkUnit                 ; Checks for unit below unit max
          LDA #$00                   ; Zero # bytes read
          STA Count                  ; Local count of bytes read
          STA Count+1
          TAY
          STA (QtyRead),Y            ; Userland count of bytes read
          INY
          STA (QtyRead),Y            ; Msb of userland bytes read
          LDA Num_Blks               ; Check for Num_Blks greater than zero
          ORA Num_Blks+1
          BEQ ReadExit
          JSR FixUp                  ; Correct for addressing anomalies
          JSR Read_Block             ; Transfer a block to/from the disk
          LDY #$00
          LDA Count                  ; Local count of bytes read
          STA (QtyRead),Y            ; Update # of bytes actually read
          INY
          LDA Count+1
          STA (QtyRead),Y
          BCS IO_Error               ; An error occurred
ReadExit: RTS                        ; Exit read routines
IO_Error: LDA #XIOERROR              ; I/O error
          JSR SysErr                 ; Return to SOS with error in A

;
; D_WRITE call processing
;
DWrite:
          LDA InitOK                 ; Did we previously find a card?
          BNE DWriteGo
          BEQ NoDevice               ; If not... then bail

DWriteGo:
          JSR CkCnt                  ; Checks for validity
          JSR CkUnit                 ; Checks for unit below unit max
CWrite:   LDA Num_Blks               ; Check for Num_Blks greater than zero
          ORA Num_Blks+1
          BEQ WriteExit              ; Quantity to write is zero - so done
          JSR FixUp
          JSR Write_Block
          BCS IO_Error
WriteExit:RTS

;
; D_STATUS call processing
;  $00 = Driver Status
;  $FE = Return preferred bitmap location ($FFFF)
;
DStatus:
          LDA InitOK                 ; Did we previously find a card?
          BNE DStatusGo
          BEQ NoDevice               ; If not... then bail

DStatusGo:
                                     ; Unit number we're talking about is already in DAN2Unit
          LDA CtlStat                ; Which status code to run?
          BNE DS0
          LDA #DAN2_DoStatus         ; Status code 0 - return the status byte
          JSR DAN2_Do                ; Get status of DAN2 unit => status in A
          BCS StatErr

          LDY #$00                   ; status is ok
          TYA                        ; DAN2 status is always 0 on success
          STA (CSList),Y
          JSR SaveCapacity
          CLC
          RTS
StatErr:  CMP #$2F                   ; Did we get a fancy new $2f error?
          BNE DS2
          LDA #XDNFERR               ; Then change it to XDNFERR instead.
DS2:      JSR SysErr                 ; Return to SOS with error in A
DS0:      CMP #$FE
          BNE DSWhat

          LDY #$00                   ; Return preferred bit map locations.
          LDA #$FF                   ; We return FFFF, don't care
          STA (CSList),Y
          INY
          STA (CSList),Y       
          CLC
          RTS

DSWhat:   LDA #XCTLCODE              ; Control/status code no good
          JSR SysErr                 ; Return to SOS with error in A

;
; D_CONTROL call processing
;  $00 = Reset device
;  $FE = Perform media formatting
;
DControl:
          LDA InitOK                 ; Did we previously find a card?
          BNE DContGo
          JMP NoDevice               ; If not... then bail

DContGo:  LDA CtlStat                ; Control command
          BEQ CReset
.IFDEF FORMAT_SUPPORT
          CMP #$FE                   ; Format?
          BEQ DCFormat
.ENDIF
          BNE DCWhat                 ; Control code no good!
CReset:   JSR UnitInit               ; Reset this unit
          BCS DCNoReset
DCDone:   RTS
DCNoReset:LDA #XNORESET              ; Things went bad after reset
          JSR SysErr                 ; Return to SOS with error in A
DCWhat:   LDA #XCTLCODE              ; Control/status code no good
          JSR SysErr                 ; Return to SOS with error in A

.IFDEF FORMAT_SUPPORT
;
; Write Block0, Block1 to disk
;
DCFormat:
          LDX SOS_Unit               ; Get the stats on this unit
          LDY DCB_Idx,X
          LDA DIB0_Blks,Y
          STA VolBlks                ; Fill VolBlks with capacity
          LDA DIB0_Blks+1,Y
          STA VolBlks+1
          STA DAN2BlkNum
          STA DAN2BlkNum+1
                                     ; Unit number we're talking about is already in DAN2Unit
          LDA #DAN2_DoWrite0         ; write a block of zero bytes
          JSR DAN2_Do
          BCS FrmtError

          INC DAN2BlkNum
          LDA #DAN2_DoWrite0         ; write a block of zero bytes
          JSR DAN2_Do
          BCS FrmtError

          JSR FormatFill
          JSR Catalog                ; Write Directory information to the disk
          RTS
FrmtError:SEC
          JSR SysErr                 ; Return to SOS with error in A
.ENDIF

;------------------------------------
;
; Utility routines
;
;------------------------------------

;
; Read_Block - Read requested blocks from device into memory
;
Read_Block:
          LDA SosBuf                 ; Copy out buffer pointers
          STA DAN2Buf
          LDA SosBuf+1
          STA DAN2Buf+1
          LDA SosBuf+ExtPG
          STA DAN2Buf+ExtPG

                                     ; Unit number we're talking about is already in DAN2Unit
          LDA SosBlk
          STA DAN2BlkNum
          LDA SosBlk+1
          STA DAN2BlkNum+1
ReadDAN2: LDA #DAN2_DoRead
          JSR DAN2_Do                ; read data. 512byte block is stored at pointer at DAN2Buf.
          BCC @1                     ; Branch past error

          STA LastError
          CMP #XDISKSW
          BNE @0
          JSR ZeroUnit               ; clear volume capacity
          JSR UnitInit               ; Re-initialize this unit
          JMP Dispatch               ; Go around again!
@0:       LDA LastError
          JSR SysErr                 ; Return to SOS with error in A
@1:       
          DEC Num_Blks               ; Did we get what was asked for?
          BNE RdBlk2
          DEC Num_Blks+1
          BPL RdBlk2
          CLC
          RTS

RdBlk2:   INC DAN2BlkNum             ; 16-bit increment of block number
          BNE ReadDAN2
          INC DAN2BlkNum+1
          JMP ReadDAN2

;
; Write_Block - write memory out to requested blocks
;
Write_Block:
          LDA SosBuf                 ; Copy out buffer pointers
          STA DAN2Buf
          LDA SosBuf+1
          STA DAN2Buf+1
          LDA SosBuf+ExtPG
          STA DAN2Buf+ExtPG
                                     ; Unit number we're talking about is already in DAN2Unit
          LDA SosBlk
          STA DAN2BlkNum
          LDA SosBlk+1
          STA DAN2BlkNum+1

WriteDAN2: 
          LDA #DAN2_DoWrite
          JSR DAN2_Do
          BCC @1                     ; Branch past error

          STA LastError
          CMP #XDISKSW
          BNE @0
          JSR ZeroUnit               ; clear volume capacity
          JSR UnitInit               ; Re-initialize this unit
          JMP Dispatch               ; Go around again!
@0:       LDA LastError
          JSR SysErr                 ; Return to SOS with error in A
 
@1:       DEC Num_Blks               ; Did we put what was asked for?
          BNE WrBlk2                 ; Not done yet... go around again
          DEC Num_Blks+1             ; (16 bit decrement)
          BPL WrBlk2                 ; Not done yet... go around again
          CLC
          RTS                        ; We're done

WrBlk2:   INC DAN2BlkNum             ; 16-bit increment of block number
          BNE WriteDAN2
          INC DAN2BlkNum+1
          JMP WriteDAN2

;
; ZeroUnit - clear out the capacity bytes of this unit
;
ZeroUnit: LDX SOS_Unit
          LDY DCB_Idx,X
          LDA #$00
          STA DIB0_Blks,Y
          STA DIB0_Blks+1,Y
          RTS

;
; Check ReqCnt to ensure it's a multiple of 512.
;
CkCnt:    LDA ReqCnt                 ; Look at the lsb of bytes requested
          BNE @1                     ; No good!  lsb should be 00
          STA Num_Blks+1             ; Zero out the high byte of blocks
          LDA ReqCnt+1               ; Look at the msb
          LSR A                      ; Put bottom bit into carry, 0 into top
          STA Num_Blks               ; Convert bytes to number of blks to xfer
          BCC CvtBlk                 ; Carry is set from LSR to mark error.
@1:       LDA #XBYTECNT
          JSR SysErr                 ; Return to SOS with error in A

;
; Test for valid block number; abort on error
;
CvtBlk:   LDX SOS_Unit
          LDY DCB_Idx,X
          SEC
          LDA DIB0_Blks+1,Y          ; Blocks on unit msb
          SBC SosBlk+1               ; User requested block number msb
          BVS BlkErr                 ; Not enough blocks on device for request
          BEQ @1                     ; Equal msb; check lsb.
          RTS                        ; Greater msb; we're ok.
@1:       LDA DIB0_Blks,Y            ; Blocks on unit lsb
          SBC SosBlk                 ; User requested block number lsb
          BVS BlkErr                 ; Not enough blocks on device for request
          RTS                        ; Equal or greater msb; we're ok.
BlkErr:   LDA #XBLKNUM
          JSR SysErr                 ; Return to SOS with error in A

IncrAdr:  INC Count+1                ; Increment byte count MSB
BumpAdr:  INC DAN2Buf+1              ; Increment buffer MSB in userland

;
; Fix up the buffer pointer to correct for addressing
; anomalies.  We just need to do the initial checking
; for two cases:
; 00xx bank N -> 80xx bank N-1
; 20xx bank 8F if N was 0
; FDxx bank N -> 7Dxx bank N+1
; If pointer is adjusted, return with carry set
;
FixUp:    LDA DAN2Buf+1              ; Look at msb
          BEQ @1                     ; That's one!
          CMP #$FD                   ; Is it the other one?
          BCS @2                     ; Yep. fix it!
          RTS                        ; Pointer unchanged, return carry clear.
@1:       LDA #$80                   ; 00xx -> 80xx
          STA DAN2Buf+1
          DEC DAN2Buf+ExtPG          ; Bank N -> band N-1
          LDA DAN2Buf+ExtPG          ; See if it was bank 0
          CMP #$7F                   ; (80) before the DEC.
          BNE @3                     ; Nope! all fixed.
          LDA #$20                   ; If it was, change both
          STA DAN2Buf+1              ; Msb of address and
          LDA #$8F
          STA DAN2Buf+ExtPG          ; Bank number for bank 8F
          RTS                        ; Return carry set
@2:       AND #$7F                   ; Strip off high bit
          STA DAN2Buf+1              ; FDxx ->7Dxx
          INC DAN2Buf+ExtPG          ; Bank N -> bank N+1
@3:       RTS                        ; Return carry set

CkUnit:   LDA SOS_Unit               ; Checks for unit below unit max
          CMP MaxUnits
          BMI UnitOk
NoUnit:   LDA #$11                   ; Report no unit to SOS
          JSR SysErr
UnitOk:   CLC
          RTS

.IFDEF FORMAT_SUPPORT
;
; Prepare BitMap and Link blocks for writing to disk
; Part of formatting support
;
FormatFill:
          LDA #$05                   ; Block 5 on Disk
          STA DAN2BlkNum
          STA Storage                ; Length of DirTbl
          JSR ZeroFillFormBuffer
LLink:    LDX Storage
          LDA DirTbl,X               ; Move Directory Link values into Buffer
          STA FormatBuffer+2         ; Store next Directory block #
          DEX
          LDA DirTbl,X               ; Fetch another # from DirTbl
          STA FormatBuffer           ; Store previous Directory block #
          DEX
          STX Storage
          LDA #DAN2_DoWrite
          JSR DAN2_Do                ; Write Directory Link values to disk
LDec:     DEC DAN2BlkNum             ; Decrement MLI block number
          LDA DAN2BlkNum             ; See if MLIBlk = 2
          CMP #$02
          BNE LLink                  ; Process another Link block

;
; Calculate BitMap Size and cndo
; Part of formatting support
;
BlkCount:                            ; Fill full pages first, then remainder
          LDA #$06                   ; First block to deal with: $06
          STA DAN2BlkNum
          CLC
          LDA VolBlks+1
          STA FullPages
          ROR FullPages              ; VolBlks is now divided by 512
          LSR FullPages              ; ... by 1024
          LSR FullPages              ; ... by 2048
          LSR FullPages              ; ... by 4096

          BEQ LastBlock              ; No full blocks?  Skip to remainder part.

          LDA #DAN2_DoWriteFF        ; write a 512byte block with FFs
          JSR DAN2_Do

          LDA #$00
          STA BlkCnt
          STA FormatBuffer           ; Mark first blocks as used
          STA FormatBuffer+1
          LDA #$03
          STA FormatBuffer+2

@2:
          LDA #DAN2_DoWrite
          JSR DAN2_Do                ; Write Buffer BitMap to block on the disk
          LDA #$FF                   ; Mark first blocks as unused again
          STA FormatBuffer
          STA FormatBuffer+1
          STA FormatBuffer+2
          INC DAN2BlkNum
          INC BlkCnt
          LDA BlkCnt
          CMP FullPages
          BNE @2

LastBlock:
          JSR BlkRemainder
          LDA #DAN2_DoWrite
          JSR DAN2_Do
          RTS

BlkRemainder:
          JSR ZeroFillFormBuffer
          LDA VolBlks+1              ; Where # of blocks are stored
          LDX VolBlks
          LDY #$00
          STX Storage+1              ; Divide the # of blocks by 8 for bitmap
          LSR A                      ;   calculation
          ROR Storage+1
          LSR A
          ROR Storage+1
          LSR A
          ROR Storage+1
          STA Storage+2
;BitMapCode:
          LDA FullPages              ; Only tick off 7 blocks if
          BNE BitMapNotFirst         ; this is the only page in the BAM
          LDA #$01                   ; Clear first 7 blocks (i.e. %00000001)
          STA (FormBufPtr),Y
          BNE BitMapGo
BitMapNotFirst:
          LDA #$FF
          STA (FormBufPtr),Y
BitMapGo:
          LDY Storage+1              ; Original low block count value
          BNE @11                    ; If it is 0 then make FF
          DEY                        ; Make FF
          DEC Storage+2              ; Make 256 blocks less one
          STY Storage+1              ; Make FF new low block value
@11:      LDX Storage+2              ; High Block Value
          BNE @15                    ; If it isn't equal to 0 then branch
          LDY Storage+1
          JMP @19

@15:      LDY #>FormatBuffer         ; Set the address of the upper part of
          INY
          STY FormBufPtr+1           ; block in bitmap being created
          LDA #<FormatBuffer
          STA FormBufPtr
          LDA #$FF
          LDY Storage+1              ; Using the low byte count
@20:      DEY
          STA (FormBufPtr),Y         ; Store them
          BNE @20
          DEY                        ; Fill in first part of block
          DEC FormBufPtr+1
@19:
          LDA #$FF
          DEY
          STA (FormBufPtr),Y
          CPY #$01                   ; Except the first byte.
          BNE @19
          RTS

BlkCnt:   .BYTE $00

;
; Catalog - Build a Directory Track
; Part of formatting support
;
Catalog:  CLC
          LDA #$06
          ADC FullPages
          STA DAN2BlkNum
          LDA #DAN2_DoWrite
          JSR DAN2_Do                ; Write Buffer (BitMap) to block #6
          JSR ZeroFillFormBuffer
          LDY #$2A                   ; Move Block2 information to $C800
CLoop:    LDA Block2,Y
          STA (FormBufPtr),Y
          DEY
          BPL CLoop
          LDA #$02                   ; Write block #2 to the disk
          STA DAN2BlkNum
          LDA #DAN2_DoWrite
          JSR DAN2_Do
          RTS

;
; FillFormBuffer: clear format buffer
;
FFFillFormBuffer:
          LDA #$FF
          PHA
          BNE FillFormBufferGo
ZeroFillFormBuffer:
          LDA #$00
          PHA
FillFormBufferGo:
          LDA #>FormatBuffer
          STA FormBufPtr+1
          LDA #<FormatBuffer
          STA FormBufPtr
          TAY
          LDX #$01                   ; Loop twice... 512 bytes
          PLA
FillLoop:
          STA (FormBufPtr),Y
          INY
          BNE FillLoop
          INC FormBufPtr+1
          DEX
          BPL FillLoop

          LDA #>FormatBuffer
          STA FormBufPtr+1
          LDA #<FormatBuffer
          STA FormBufPtr
          RTS

.ENDIF ; FORMAT_SUPPORT

;
; Calculate X register to address the DAN2 I/O area
;
DAN2_GetX:
          LDA DIB0_Slot              ; load slot number
          ASL A                      ; shift by 4
          ASL A
          ASL A
          ASL A
          ORA DAN2Unit               ; encode slot number in upper 4 bits of DAN2 unit number
          STA DAN2Unit               ; update DAN2 unit number (bit 7=selects SD slot 1 or 2, bits 6-4 selects Apple slot)
          ORA #$88                   ; adjust address, so we can address from page $BF ($BFF8-$BFFB)
                                     ; this works around 6502 phantom read
          TAX
          RTS

; communicate with DAN2 card
;   call convention: command to be executed in A
;   return convention: carry is set on error, cleared on success
DAN2_Do:
          STA DAN2Cmd                ; store command byte
.IFDEF UART_DEBUGGING
          JSR DEBUG_DAN2_COMMAND
.ENDIF
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
.IFDEF UART_DEBUGGING
          PHA
          JSR DEBUG_DAN2_ERROR
          PLA
.ENDIF
          SEC                        ; return the error: carry set
          RTS
DAN2ok:                              ; A=0 at this point
          STA DAN2uppage             ; keep track if we are in upper page (store 0 in uppage)
          TAY                        ; (store 0 in y)
          LDA DAN2Cmd
          BNE notStatusCmd           ; not a status command

DANStatusCmd:                        ; evaluation a status command
                                     ; not returning any data for now
          CLC                        ; no error
          RTS

notStatusCmd:
          CMP #DAN2_DoRead            ; a read command?
          BNE notReadCmd              ; not a read command

DAN2readbytes:
          LDA $BFFA,X                ; get port C
          AND #$20                   ; check IBF (input buffer full flag)
          BEQ DAN2readbytes          ; wait until there's a byte available
          LDA $BFF8,X                ; get the byte
          STA (DAN2Buf),Y            ; store in the buffer
.IFDEF UART_DEBUGGING
          JSR DEBUG_HEX
.ENDIF
          INY
          BNE DAN2readbytes          ; get next byte to 256 bytes
          LDY DAN2uppage             ; check 256byte page
          BNE DAN2exit512            ; already read upper page
          JSR IncrAdr                ; advance buffer pointer (and do necessary fixup)
          INC DAN2uppage             ; remember we're processing the second page now
          BNE DAN2readbytes          ; unconditional branch to process second page

DAN2exit512:                         ; quit with no error
          JSR IncrAdr                ; advance buffer pointer (and do necessary fixup)
DAN2quitOk:
.IFDEF UART_DEBUGGING
          JSR DEBUG_LF
          LDA #$3E                   ; load '>'
          JSR DEBUG_DAN2_RESULT      ; dump registers
.ENDIF
          LDA #$00
          CLC
          RTS                

notReadCmd:              
          CMP #DAN2_DoWrite          ; assume its an allowed format if not these others
          BNE DAN2quitOk
DAN2writeBytes:
          LDA (DAN2Buf),Y            ; load byte from buffer
          STA $BFF8,X                ; write a byte to the Arduino
DAN2waitWrite:
          LDA $BFFA,X                ; wait until its received
          BPL DAN2waitWrite    
          INY
          BNE DAN2writeBytes         ; send next byte to 256 bytes
          LDY DAN2uppage             ; check 256byte page
          BNE DAN2exit512            ; already wrote upper page
          JSR IncrAdr                ; advance buffer pointer (and do necessary fixup)
          INC DAN2uppage             ; remember we're processing the second page now
          BNE DAN2writeBytes         ; unconditional branch to process second page

.IFDEF UART_DEBUGGING
DEBUG_INIT:                          ; init RS232
          LDA #$0B                   ; no parity, RTS on
          STA $C0F2
          LDA #$10                   ; 8bit + 1 stop bit
          STA $C0F3
          LDA #$54
          JSR UART_OUT               ; send character in A
          JMP DEBUG_LF

DEBUG_DAN2_ERROR:
          PHA
          LDA #$3E                   ; load '>'
          JSR UART_OUT
          LDA #$45                   ; load 'E'
          JSR UART_OUT
          LDA #$52                   ; load 'R'
          JSR UART_OUT
          JSR DEBUG_SPACE
          PLA
          PHA
          JSR DEBUG_HEX              ; show returned error code
          PLA
          RTS

DEBUG_DAN2_COMMAND:
          LDA DAN2Cmd
          CLC
          ADC #$61
DEBUG_DAN2_RESULT:
          JSR UART_OUT
          JSR DEBUG_SPACE

          LDA DAN2Unit
          JSR DEBUG_HEX
          JSR DEBUG_SPACE

          LDA DAN2Buf+1
          JSR DEBUG_HEX
          LDA DAN2Buf
          JSR DEBUG_HEX
          JSR DEBUG_SPACE

          LDA DAN2BlkNum+1
          JSR DEBUG_HEX
          LDA DAN2BlkNum
          JSR DEBUG_HEX

          JSR DEBUG_SPACE
          JMP DEBUG_LF

DEBUG_HEX:
          PHA
          LSR                        ; top nibble first
          LSR
          LSR
          LSR
          JSR NIBBLE_OUT
          PLA
          AND #$0F                   ; show lower nibble
          JMP NIBBLE_OUT

DEBUG_SPACE:
          LDA #$20                   ; space
          BNE UART_OUT               ; send white-space

DEBUG_LF:
          LDA #$0A                   ; line-feed
          BNE UART_OUT               ; unconditional jump

NIBBLE_OUT:
          CLC
          ADC #$30                   ; map 0=>'0', 1=>'1', ...
          CMP #$3A
          BMI UART_OUT
          CLC
          ADC #$07
UART_OUT:
          PHA
          LDA #$10                   ; load TX EMPTY flag
UART_WAIT:
          BIT $C0F1                  ; check TX EMPTY?
          BEQ UART_WAIT
          PLA
          STA $C0F0                  ; write data to TX register
          LDA #$10                   ; load TX EMPTY flag
UART_WAIT2:
          BIT $C0F1                  ; check TX EMPTY?
          BEQ UART_WAIT2
          RTS
.ENDIF

.IFDEF FORMAT_SUPPORT
; Formatter Variable Storage Area
;
VolBlks: .BYTE $00, $00, $00         ; Number of blocks available
DirTbl:  .BYTE $02, $04, $03         ; Linked list for directory blocks
         .BYTE $05, $04, $00
BitTbl:  .BYTE $7f ; '01111111'      ; BitMap mask for bad blocks
         .BYTE $bf ; '10111111'
         .BYTE $df ; '11011111'
         .BYTE $ef ; '11101111'
         .BYTE $f7 ; '11110111'
         .BYTE $fb ; '11111011'
         .BYTE $fd ; '11111101'
         .BYTE $fe ; '11111110'
Storage: .BYTE $00, $00, $00         ; General purpose counter/storage byte
Pointer: .BYTE $00, $00              ; Storage for track count (8 blocks/track)
Track:   .BYTE $00, $00              ; Track number being FORMATted
Sector:  .BYTE $00, $00              ; Current sector number (max=16)
SlotF:   .BYTE $00, $00              ; Slot/Drive of device to FORMAT
TRKcur:  .BYTE $00, $00              ; Current track position
TRKdes:  .BYTE $00, $00              ; Destination track position
TRKbeg:  .BYTE $00                   ; Starting track number
TRKend:  .BYTE $35                   ; Ending track number
FullPages:
         .BYTE $00                   ; Number of BAM pages to fill
DevIndex:.BYTE $00                   ; Space for index into DEVICES table
Util:    .BYTE $00


Block2:  .BYTE $00, $00, $03, $00    ; Image of block 2 - for $42 bytes
VolLen:  .BYTE $F5                   ; $F0 + length of Volume Name
Volnam:  .BYTE "BLANK          "     ; Volume Name
Reserved:.BYTE $00, $00, $00, $00, $00, $00
UpLowCase:
         .BYTE $00, $00
Datime:  .BYTE $00, $00, $00, $00
Version: .BYTE $01
MinVers: .BYTE $00
Access:  .BYTE $C3
EntryLen:.BYTE $27
EntrPBlk:.BYTE $0D
FileCnt: .BYTE $00, $00
BitMapP: .BYTE $06, $00

FormatBuffer: 
   .REPEAT 512
         .BYTE 0
   .ENDREPEAT

.ENDIF

         .ENDPROC
         .END
