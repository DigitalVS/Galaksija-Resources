; ROM A routines
KbdStrInput = $07BD         ; Input string from keyboard into input buffer with CR at the end. DE = address of the last string character + 1.
; ROM B routines
ShowRegs    = $1978         ; Prints all register values.
DumpMemory  = $19DE         ; Print memory as HEX values, from HL address, A rows
; ROM B table addresses used by disassembler
TABEL1 = $1EE4              ; TABEL1 pointer to first mnemonic string (skipped other command strings at the beginning)
TABEL2 = $1FB4              ; Register and flag labels table

  STRUCT v                  ; Start of variables declaration
_PREFIX         BYTE
_TABEL1_INDEX   BYTE        ; Opcode index in TABEL1
_OPCODE         BYTE
_CODE_LEFT      BYTE
_CODE_RIGHT     BYTE
_VALUE_1        BYTE        ; Instruction 8-bit data value or low byte from 16-bit value
_VALUE_2        BYTE
_DISASS_START   WORD        ; Disassembling start address
_DISASS_END     WORD        ; Disassembling end address
_BRKPTR_HANDLER BLOCK 3     ; Contains breakpoint handler call instruction
_BRKPTR_TEMP    BLOCK 3     ; Memory address to hold 3 bytes temporary replaced by JP instruction for breakpoint with R command
  ENDS

  include "galaksija.inc"

; Disassembler and other variables
vars = INPUTBUFFER + 26     ; 26 is now effective input buffer space, vars is actual variables start address
PREFIX         = vars + v._PREFIX
TABEL1_INDEX   = vars + v._TABEL1_INDEX
OPCODE         = vars + v._OPCODE
CODE_LEFT      = vars + v._CODE_LEFT
CODE_RIGHT     = vars + v._CODE_RIGHT
VALUE_1        = vars + v._VALUE_1
VALUE_2        = vars + v._VALUE_2
DISASS_START   = vars + v._DISASS_START
DISASS_END     = vars + v._DISASS_END
BRKPTR_HANDLER = vars + v._BRKPTR_HANDLER
BRKPTR_TEMP    = vars + v._BRKPTR_TEMP

  .org  $3800

; -----------------------------------------------------------------------------
; Subscribe to command processor callback
; -----------------------------------------------------------------------------
  ld a, $C3                 ; C3 is unconditional JUMP instruction opcode
  ld (BASICLINK), a
  ld hl, Start              ; Address to jump to
  ld (BASICLINK + 1), hl
  ret

Start:                      ; First, check if monitor has been called by CatchAllCmds (that address should be on stack). If not, go back to BASIC command processing.
  ex (sp), hl
  push de
  ld de, CatchAllCmds       ; Catch-all commands.
  rst $10                   ; Compare HL with DE, Z flag is 0 if input is recognized as a command.
  pop de
  ex (sp), hl
.GotoRomB:
  jp nz, $100F              ; If Z flag is reseted, continue to ROM B (or if ROM C V36 is present, address is then $E7F8)
  ld a, (de)                ; Try to recognize command. Register DE points to next character to process.
  cp '*'                    ; Check if character is '*'
  jr nz, .GotoRomB
  inc de                    ; Set BASIC pointer to next character after '*'
  ld a, $01                 ; Next two flags have to have value 1 because otherwise PrintHex16 call won't work!
  ld (ASMOPTFLAG), a        ; Set OPT flag value for assembler program
  ld (ASMPASSNO), a         ; Assembler pass number (1 or 2)
  rst $18                   ; Read character
  db 'L'                    ; If next character is ASCII code for 'L' character, sets command output to printer
  db .NoPrinting-$-1        ; If not printing - skip setting printer flag

  call $1060                ; Set LPRINT flag
  call NoValue              ; Print new line (CR) on paper
.NoPrinting:
  ld a, (de)                ; Command character is in A
  inc de                    ; Points to posible command parameter value
  ld hl, EndCmd             ; HL = command end address
  push hl                   ; Return address (end) to stack (to turn of the printing)
  cp '$'                    ; Check if command is '$'
  jr z, FindString          ; If '$', jump (treated separately because of 3rd alphanumeric parameter)
  ld hl, TABLE-2            ; HL = command table address - 2
.FindCmd:
  inc hl
  inc hl                    ; HL + 2 (skip command address)
  bit 7, (hl)               ; Is it end of a table (marked as value $80)?
  jp nz, ShowWhatErr        ; If yes, command not found, show "WHAT?" error
  cp (hl)                   ; Is it correct command?
  inc hl                    ; HL = command address
  jr nz, .FindCmd           ; If not correct command, search further
  ld c, (hl)                ; Command has been found!
  inc hl
  ld b, (hl)                ; BC = command handler address
  push bc                   ; Command address to stack
  call GetParameter         ; Get 1st command parameter and put it to stack
  rst $28                   ; Clear HL
  jr z, .NoParameter        ; If there are no parameters, jump (H has no parameters, E, K and R have one parameter)
  call GetParameter         ; Read 2nd parameter and push it to stack
  jr z, .Param1             ; If there are no more parameters, jump (D, A and C have two parameters)
  call GetParameter         ; Read 3rd parameter and push it to stack
  ld bc, $0000
  jr z, .Param2             ; If there are no more parameters, jump (T, X, Z, V, B, W, S)
  call GetParameter         ; If there is 4th parameter...
  jp nz, ShowWhatErr        ; Show "WHAT?" error
                            ; At this point command has three parameters
  pop bc                    ; 3 parameters: BC = third parameter, A will be 3 at the end
  inc a                     ; A = 1 (previous A value is allways 0 because SUB $0D if there are no more parameters)
.Param2:
  pop de                    ; Command has TWO parameters: DE = second parameter, A = 2
  inc a
  inc a                     ; A += 2 (2 or 3)
  pop hl                    ; HL = first parameter
.Execute:
  cp $03                    ; Set Zf = 1 if command has THREE parameters
  ret                       ; Jump to command execution (command address is on the stack top)
.Param1:
  pop hl                    ; Command has ONE parameter: HL = parameter
  inc a                     ; A = 1
.NoParameter:               ; Command has no parameters: BC = 0 (HL = 0)
  ld bc, $0000
  ld de, $FFFF
  jr .Execute               ; Set Z flag and jump to command execution

; -----------------------------------------------------------------------------

FindString:
  rst $08                   ; Read first parameter (start address) - call EVAL_EXPRESSION
  push hl                   ; Put start addres to stack
  rst $18                   ; Read character
  db ','
  db .Space1-$-1
.Space1
  call SkipSpaces           ; Skip SPACE characters, A points to first non blank character
  rst $08                   ; HL = second paramater (end address)
  rst $18                   ; Read character
  db ','
  db .Space2-$-1
.Space2
  call SkipSpaces           ; Skip SPACE characters, A points to first non blank character
  ld c, e
  ld b, d                   ; BC = searched string start address
  ex de, hl                 ; DE = end search address
  pop hl                    ; HL = start search address
  dec hl
.Loop:
  inc hl
  call CheckBrkKey          ; Check if BREAK or DEL key pressed
  rst $10                   ; Compare HL with DE
  ret nc                    ; If yes, end of searching and end of command (return to BASIC - FARMA)

  ld a, (bc)                ; A = character from searched string
  cp CR                     ; Is it CR?
  jp z, ShowWhatErr         ; If yes, show "WHAT?" error
  cp (hl)                   ; Check if character at HL address is the same?
  jr nz, .Loop              ; If not, check the next address
  push bc                   ; If it is the same, store searched string address...
  push hl                   ; ...and address of this character
.Matches:
  inc bc                    ; Next searched character address
  inc hl                    ; Next memory address
  ld a, (bc)                ; A = next searched character
  cp CR                     ; If character is CR it is the end of searched string...
  jr z, .Found              ; ...string has been found
  cp (hl)                   ; If not CR, does it the same as memory character?
  jr z, .Matches            ; If it is the same character, go on with next character
  pop hl                    ; If not, return memory address of previous hit
.NextString:
  pop bc                    ; and searched address string
  jr .Loop                  ; search further
.Found:
  pop hl                    ; HL = found string address
  call PrintHexWord         ; Print found string HEX address
  ld a, CR
  rst $20                   ; Go to next row
  jr .NextString            ; Return searched string address and continue searching

; -----------------------------------------------------------------------------

GetParameter:
  call SkipSpaces           ; Skip SPACE characters, A points to first non blank character
  sub CR                    ; Is that character a CR?
  ret z                     ; If yes, it is the end of line and there is no more parameters (A = 0, Zf = 1)
  rst $18                   ; Skip not mandatory comma sign
  db ','
  db .Same-$-1
.Same:
  rst $08                   ; HL = parameter
  ex (sp), hl               ; Put parameter to stack, HL = return address
  xor a                     ; Clear A register
  inc a                     ; A = A + 1, Zf = 0
  jp (hl)                   ; Go back

; -----------------------------------------------------------------------------

RunAsm:
  jp (hl)                   ; Go back (and command *G with 1 to 3 parameters)

TABLE   BYTE "D"            ; Command list
        WORD Disassembler
        BYTE "A"
        WORD ASCIIDump
        BYTE "E"
        WORD EditMem
        BYTE "T"
        WORD CopyMem
        BYTE "B"
        WORD FindByte
        BYTE "W"
        WORD FindWord
        BYTE "S"
        WORD SaveReloc
        BYTE "R"
        WORD BreakPtr
        BYTE "V"
        WORD SectionDiff
        BYTE "Z"
        WORD FillSection
        BYTE "K"
        WORD KeyboardInput
        BYTE "H"
        WORD TapeHeader
        BYTE "C"
        WORD CRCMemory
        BYTE "G"
        WORD RunAsm
        BYTE "X"
        WORD SectionSwap
        BYTE $80            ; End list byte

; -------------------------------------------------------------------------------------------------

BreakPtr:
  dec	a                     ; If not one parameter then WHAT?
  jp nz, ShowWhatErr
  ld a, h
  or l                      ; Check if parameter value is 0 (or there is no parameter)
  jr z, RemBrkPtr           ; If yes, remove breakpoint
  push	hl                  ; Save breakpoint address on stack
  ld de, BRKPTR_TEMP
  call CopyPtrMem           ; Copy 3 bytes from breakpoint address to $2AFF
  pop	hl                    ; HL = breakpoint address
  ld (hl), $C3
  inc	hl
  ld (hl), $FC
  inc	hl
  ld (hl), $2A              ; JP BRKPTR_HANDLER at breakpoint address
  inc	hl
  ld ($2B03), hl
  ld a, $C3
  ld ($2B02), a             ; JP breakpoint address + 3 to address $2B02
  ld a, $CD
  ld (BRKPTR_HANDLER), a
  ld hl, ShowRegs
  ld (BRKPTR_HANDLER + 1), hl ; call ASM_BRK_REG from ROM B (BRKPTR_HANDLER: CD 78 19 (MM) (MM + 1) (MM + 2) C3 MM + 3 MM + 3)
  ret

RemBrkPtr:
  ld hl, ($2B03)            ; HL = breakpoint address + 3
  dec	hl                    ; HL = breakpoint address + 2
  ld a, (hl)
  cp $2A                    ; Check if at MM + 2 is higher breakpoint byte?
  jr nz, NotBrkPtr          ; If not then HOW? (there is no breakpoint here)
  dec	hl
  ld a, (hl)
  dec	hl                    ; HL = adresa prekidne tačke
  cp $FC                    ; Check if at MM + 1 is lower breakpoint byte?
NotBrkPtr:
  jp nz,	ShowHowErr        ; If not then HOW? (there is no breakpoint here)
  ex de, hl                 ; DE = breakpoint address
  ld hl, BRKPTR_TEMP        ; HL = address of temorary copied memory contents, this will remove the breakpoint
CopyPtrMem:
  ld bc, $0003
  ldir                      ; Copy 3 bytes to or from temporary space
  ret

; -------------------------------------------------------------------------------------------------

SectionSwap:
  jp nz, ShowWhatErr        ; If not three parameters
.SectionLoop:
  ld a, (bc)                ; Target section byte...
  push af                   ; ...to stack
  ld a, (hl)                ; Source section byte...
  ld (bc), a                ; ...into target section
  pop af                    ; Target section byte from stack...
  ld (hl), a                ; ...to source section
  rst $10                   ; Are all bytes swapped?
  inc hl                    ; Next source byte
  inc bc                    ; Next target byte
  jr c, .SectionLoop        ; If not all swapped, continue
  ret

; -------------------------------------------------------------------------------------------------

CRCMemory:
  jp z, ShowWhatErr         ; If there are three parameters then WHAT?
.Loop:
  ld a, (hl)                ; A = one byte from the section
  add a, b                  ; Add old CRC (at beginning BC = 0)
  ld b, a                   ; Put CRC value in B
  rst $10                   ; Are all section bytes have been read?
  inc hl                    ; Next section byte
  jr c, .Loop               ; If there are more bytes, continue to read them
  push bc                   ; Save CRC on stack
  ld a, '&'
  rst $20                   ; Print '&'
  pop af                    ; A = CRC from stack
  jp HexA                   ; Print HEX CRC byte

; -------------------------------------------------------------------------------------------------

KeyboardInput:
  dec a                     ; If there are more then one parameter then WHAT?
  jp nz, ShowWhatErr
.Loop:
  ld de, (CURSORPOS)        ; DE = cursor address
  ld a, '_'
  ld (de), a                ; Print cursor ('_')
.IsCR:
  call ReadKey              ; Wait for key to be pressed (BRK and STOP/LIST stops input)
  cp CR                     ; Is it CR?
  jr z, .NoCR               ; If yes, jump
  cp $20                    ; If key code is less then 32? (SHIFT+DEL, delete and arrows)
  jr c, .IsCR               ; Then ignore key press
.NoCR:
  ld (hl), a                ; Save to the memory
  inc hl                    ; Next address
  rst $20                   ; Print character to the screen
  jr .Loop                  ; Wait for next key press

; -------------------------------------------------------------------------------------------------

SectionDiff:
  jp nz, ShowWhatErr        ; If not three parameters then
.Loop:
  ld a, (bc)                ; Does target section byte...
  cp (hl)                   ; ...is equal to source section byte?
  jr z, .Next               ; If they are equal, next byte
  push  bc                  ; If not equal, save target byte address
  call PrintHexHLD          ; Print source HEX address, space and source byte value
  ld a, ' '
  rst $20                   ; Print space
  ex (sp), hl
  call PrintHexD            ; Print source HEX byte
  ex (sp), hl               ; HL = source address
  pop bc                    ; BC = target address from stack

  call CheckBrk             ; Check BRK and DEL + ENTER if printing is turned on
  ld a, CR
  rst $20                   ; Print CR
.Next:
  rst $10                   ; Does all bytes are compared?
  inc hl
  inc bc
  jr c, .Loop               ; If not, continue
  ret

; -------------------------------------------------------------------------------------------------

FillSection:
  cp $02                    ; Check if there are two parameters
  jp c, ShowWhatErr         ; If not at least two then WHAT? (third is 0 if not provided)
.Loop:
  ld (hl), c                ; Write byte pointed by HL with byte from BC (lower byte from C)
  rst $10                   ; Does whole section has been filled?
  inc hl
  jr c, .Loop               ; If not, continue
  ret

; -------------------------------------------------------------------------------------------------

FindByte:
  jp nz, ShowWhatErr        ; If not three parameters
  ld a, b
  or a
  jp nz, ShowHowErr         ; If searched byte is bigger then 255 then HOW?
.FindNext:
  call CheckLatch           ; If address is in latch area then SORRY (It's not allowed to read LATCH memory space because computer may crash)
  ld a, c                   ; A = byte value to be found
  cp (hl)                   ; Zf = 1 if byte at HL address is equal
  push bc                   ; Save that byte on stack
  call z, FoundByte         ; If byte has been found, print address and its content as HEX value
  pop bc                    ; BC = load searched byte from stack
  inc hl                    ; Next address to check
  rst $10                   ; Is it the end address?
  ret nc                    ; If so, stop searching.
  call CheckBrk             ; If not, check BRK, DEL and ENTER if printing is turned on
  jr .FindNext              ; Continue to search

PrintHexHLD:                ; Print HL address and (HL) value as HEX
  call HexAddr              ; Print '&' + HL address + ':'
PrintHexD:
  ld a, ' '
  rst $20                   ; Print space character
  ld a, '&'
  rst $20                   ; Print '&' and...
  jp HexA-1                 ; ...byte from (HL) and go back

FoundByte:
  call PrintHexHLD          ; Print HL address and (HL) value
PrintCR:
  ld a, CR                  ; A = CR
  rst $20                   ; Print new line
  ret

; -------------------------------------------------------------------------------------------------

FindWord:
  jp nz, ShowWhatErr        ; If not three parameters
.FindNext:
  call CheckLatch           ; If address is in latch area then SORRY (It's not allowed to read LATCH memory space because computer may crash)
  ld a, c                   ; A = low byte to search for
  cp (hl)                   ; Zf = 1 if byte at HL address is equal
  inc hl                    ; Next address
  jr nz, .CheckEnd          ; If not found then jump
  ld a, b                   ; If it is found, A = higher byte of searched word
  cp (hl)                   ; Is it found at HL + 1 address?
  call z, .Found            ; If word is found, jump to printing output
.CheckEnd:
  rst $10                   ; If not found, is it the end of searching?
  ret nc                    ; If it is, go to end
  call CheckBrk             ; If not, check BRK, DEL and ENTER if printing is turned on
  jr .FindNext              ; Continue to search
.Found:
  push hl                   ; Save current address
  push bc                   ; Save searched word
  push bc                   ; ...twice
  dec hl
  dec hl                    ; HL = address before found word
  call PrintHexHLD          ; Print HL address and (HL) value (it should be kind of hint of word function)
  inc hl                    ; Next address (address of found word)
  ld a, ' '
  rst $20
  rst $20
  rst $20                   ; Print three spaces
  call HexAddr              ; Print '&' + HL address + ':'
  ld a, ' '
  rst $20                   ; Print space character
  pop hl                    ; HL = searched word
  call PrintHexWord         ; Print HEX word from HL
  call PrintCR              ; Print CR character
  pop bc
  pop hl
  ret

; -------------------------------------------------------------------------------------------------

SaveReloc:
  jp nz, ShowWhatErr        ; If not three parameters
  push hl                   ; Start address to stack...
  push hl                   ; ...twice
  ex de, hl                 ; HL = end address...
  inc hl                    ; ...+1 (which will not be saved!)
  pop de                    ; DE = start address
  push hl                   ; End address + 1 to stack
  or a                      ; Cf = 0 for subtraction
  sbc hl, de                ; HL = length of section to be saved
  push hl                   ; Length to stack
  push bc                   ; Loading address to stack
  ld b, $60
  di                        ; Disable interrupts (turn of the screen)
.SaveLead:
  xor a                     ; Clear A register
  call TapeSaveByte         ; Save one byte to audio cassette
  djnz .SaveLead            ; Save 96 lider bytes (zeros)
  ld a, TAPELEAD
  call TapeSaveByte         ; Save $A5 header byte
  pop hl
  call $0E63                ; Save loading start address
  pop de                    ; DE = length
  add hl, de                ; HL = loading end address
  call $0E63                ; Save loading end address
  pop hl                    ; HL = end address + 1 in memory
  pop de                    ; DE = start address in memory
  jp $0E57                  ; Save whole memory section + CRC and finish.

; -------------------------------------------------------------------------------------------------

CopyMem:
  jp nz, ShowWhatErr        ; If not three parameters
  ex de, hl                 ; DE = section to be coppied start address, HL = end address
  or a
  sbc hl, de                ; HL = section to be coppied length
  jp c, ShowHowErr          ; If end is before start then HOW?
  inc hl                    ; Length + 1 (+1 will not be coppied)
  push hl                   ; Length to stack
  push de                   ; Start address to stack
  ld d, b
  ld e, c                   ; DE = target section address
  pop hl                    ; HL = source section start address
  pop bc                    ; BC = section length
  rst $10                   ; Is target section start address in source section?
  jr c, .Backword           ; If yes, copy backward
  ldir                      ; If not, copy forward
  ret
.Backword:
  add hl, bc                ; HL = start + length + 1
  dec hl                    ; HL = source section end address
  ex de, hl                 ; DE = source section end address, HL = target section start address
  add hl, bc                ; HL = end + length + 1
  dec hl                    ; HL = target section end address
  ex de, hl                 ; DE = target section end address, HL = source section end address
  lddr                      ; Copy section backwards
  ret

; -------------------------------------------------------------------------------------------------

ASCIIDump:
  jp nc, ShowWhatErr        ; If there are three parameters, show WHAT?
  inc de                    ; DE = end section address + 1 (or 0 if not provided)
  ld a, d
  or e
  jr nz, .RowLoop           ; If end address is 0...
  dec de                    ; ...then DE = end of memory address
.RowLoop:
  call CheckBrk             ; Check BRK, DEL and ENTER if printing is turned on
  call HexAddr              ; Print '&' + HL address + ':'
  ld a, ' '
  rst $20                   ; Print space
  ld b, $18                 ; Print 24 ASCII characters after HEX address
.ColumnLoop:
  call CheckLatch           ; Check if address is in LATCH memory (and SORRY if it is)
  rst $10                   ; Is current address is bigger then end address
  ret nc                    ; If equal or bigger then end address
  ld a, (hl)                ; A = byte at current address
  inc hl                    ; Next address
  cp CR                     ; Is current byte CR?
  jr z, .EndRow             ; If yes, start a new line
  and $7F                   ; Clear character 7th bit (graphics character becomes ASCII)
  cp $20                    ; Is ASCII code value less then 32 (control characters)?
  jr nc, .PrintChar         ; If not, print character
  ld a, '.'                 ; If yes, print '.'
.PrintChar:
  rst $20                   ; Print character
  djnz .ColumnLoop          ; Repeat 23 times
  ld a, CR
.EndRow:
  rst $20                   ; New line
  jr .RowLoop               ; Checking and print of next 24 characters
HexAddr:
  call PrintHexWord         ; Print '&' + HL address
  ld a, ':'
  rst $20                   ; Print ':'
CheckLatch:                 ; Check if address is in LATCH memory ($2000-$27FF)
  ld a, h
  and $F8                   ; Mask lower 3 bits of higher address byte ($20-$27)
  cp $20                    ; Is HL address in LATCH?
  ret nz                    ; Go back if address is not in LATCH
  jp ShowSorryErr           ; If it is in LATCH, display SORRY message and stop

; -------------------------------------------------------------------------------------------------

TapeHeader:                 ; Reads tape header
  or a                      ; If there are any parameters...
  jp nz, ShowWhatErr        ; ...WHAT?
  di                        ; disable interrupts (turn off screen)
.WaitID:
  call TapeLoadByte         ; Wait for byte from tape
  ld a, c
  cp TAPELEAD               ; Does loaded byte represent heder ID?
  jr nz, .WaitID            ; If not, load next byte
  call TapeLoadWord         ; If yes, load word (start address in memory)
  ld h, c
  push  hl                  ; Start address to stack
  call TapeLoadWord         ; Load word (end address in memory)
  ld h, c
  ex (sp), hl               ; HL = start address, stack = end address
  call PrintHexWord         ; Print start HEX address from HL
  ld a, ','
  rst $20                   ; Print ','
  pop hl                    ; HL = end address from stack

PrintHexWord:               ; Subroutine to print HEX word with '&' at the beginning
  ld a, '&'
  rst $20                   ; Print character
  jp PrintHex16             ; Print HEX value from HL (This is the end of *H command)

; -------------------------------------------------------------------------------------------------

EditMem:
  dec a                     ; If there are more then one parameter, show WHAT?
  jp nz, ShowWhatErr
  push hl
.Loop:
  pop hl
  call HexAddr              ; Print start HEX address from HL
  push hl                   ; Save start address on stack
  ld a, ' '
  call KbdStrInput          ; INPUT (HEX bytes without '&' + ENTER, or BRK for end)
  ld de, INPUTBUFFER        ; DE = INPUT buffer address
.ReadNextByte:
  call SkipSpaces           ; Skip SPACE characters, A points to first non blank character
  cp CR                     ; Is it the end of string (CR)?
  jr z, .Loop               ; If yes, new address in new line
  call ReadHexByte          ; Read HEX value
  ld a, h
  or a                      ; Is value larger then 255 (higher byte is not zero)?
  jp nz, ShowHowErr         ; If yes then HOW?
  ld c, l                   ; C = value byte
  pop hl                    ; HL = store address for value
  call CheckLatch           ; If address is in latch then SORRY
  ld (hl), c                ; Otherwise, save byte to memory
  inc hl                    ; Next address...
  push hl                   ; ...to stack
  jr .ReadNextByte          ; Repeat for whole input buffer contents

; -------------------------------------------------------------------------------------------------

EndCmd:
  ld hl, $0066              ; Every command ends like this. HL = farm off address...
  push hl                   ; ...to stack (return address to delegate control to BASIC)
NoValue:
  ld a, (PRINTERFLAG)
  inc a                     ; If printing is turned off...
  ret nz                    ; ...end of command.
  ld a, CR
  jp $106F                  ; Print CR, turn off printing flag. Command execution is finished.

; -------------------------------------------------------------------------------------------------

Disassembler:
  jp nc, ShowWhatErr        ; If there are three parameters, show WHAT?
  inc de                    ; DE = end address + 1 (if not provided: 0)
  ld a, d
  or e
  jr nz, .Start             ; If end address is provided then jump
  dec de                    ; If not, then the end address is $FFFF (end of address space)
.Start:
  ld (DISASS_END), de       ; Save end address
  ld (DISASS_START), hl     ; Save start address
.Continue:
  ld bc, .Continue          ; Return address after one chunk has been dissasembled...
  push bc                   ; ... to stack
  call CheckBrk             ; Check BRK/DEL and ENTER keys
  ld hl, (DISASS_START)     ; HL = start address
  ld de, (DISASS_END)       ; DE = end address
  rst $10                   ; Compare HL with DE and and set C and Z flags
  jp nc, EndCmd             ; If equal (or if 1st greater then 2nd) then end of command
  ld hl, SCROLLCNT          ; HL = address for scroll counter value
  call ScrollWait           ; Wait for scroll to end (if there is a picture)
  ld a, CR
  rst $20                   ; Print new line
  ld hl, (DISASS_START)     ; HL = dissasembling start address
  call PrintHex16           ; Print HEX address value from HL (four digit address at the beginning of the line)
  ld a, ' '
  rst $20                   ; Print space
  call CheckLatch           ; If address is in latch area then SORRY
  ld hl, PrintInstruction   ; Next address...
  push hl                   ; ...to stack
  rst $28
  ld (CODE_LEFT), hl        ; Clear CODE_LEFT and CODE_RIGHT locations
  call HexCode              ; Read next byte to be decoded to A register and print it as HEX value
  ld c, a                   ; C = byte to be decoded
  cp $ED                    ; Is byte ED prefix?
  jr nz, .CheckDD           ; If not, continue
  call SavePrefixNext       ; If it is ED, $2BE5 = $ED; address + 1; Print next HEX byte
  jr ED_Prefix
.CheckDD:
  cp $DD                    ; Is byte DD prefix? (IX instruction)
  jr nz, .CheckFD           ; If not, continue
  call SavePrefixNext
  jr .CheckCB               ; Check CB after DD as a second opcode byte
.CheckFD:
  cp $FD                    ; Is byte FD prefix? (IY instruction)
  call z, SavePrefixNext
.CheckCB:
  cp $CB                    ; Is byte the CB prefix?
  jr nz, .FindOpcode        ; If not, continue
  call SavePrefixNext
  jr CB_Prefix
.FindOpcode:                ; C = PREFIX, A = opcode
  ld b, a
  ld a, c
  cp $DD
  jr z, DDFD_Prefix
  ld a, c
  cp $FD
  jr z, DDFD_Prefix

  ld c, a
  ld ix, SIMPLE_TABLE
  call SearchSimpleTable    ; Recognize instruction opcode
  call c, CheckGeneralTable
  ret nc                    ; If found skip further searching
  ld a, c
  ld ix, BLOCK_TABLE
  call SearchBlockTable
  jr c, Unknown             ; Opcode not found
  ret

DDFD_Prefix:
  ld c, b                   ; B = opcode
  ld ix, DD_FD_TABLE
  call SearchTable
  jr c, Unknown
  ret

ED_Prefix:
  ld c, a
  ld ix, ED2_TABLE          ; First, check simple instructions
  call SearchSimpleTable    ; Recognize instruction opcode
  ret nc
  ld ix, ED_TABLE           ; Check ED_TABLE
  call SearchTable
  jr c, Unknown             ; Opcode not found
  ret

CB_Prefix:
  ; Check DD/FD prefix (C register) before CB prefix
  ld b, a                   ; B = opcode value
  ld a, c
  cp $DD
  jr z, .DDFD_CB_Prefix
  cp $FD
  jr z, .DDFD_CB_Prefix
  ; CB prefix w/o DD or FD
  ld c, b
  ld ix, CB_BLOCK_TABLE
  call SearchBlockTable
  jr c, Unknown
  ret
.DDFD_CB_Prefix:            ; Special case!
  ld hl, VALUE_1            ; Save displacement value
  ld (hl), b
  call NextByte             ; Read next byte because it is the opcode byte
  ld c, a
  ld ix, DDFD_CB_TABLE
  call SearchTable
  jr c, Unknown             ; Opcode not found
  ret

CheckGeneralTable:
  ld a, c
  bit 7, a                  ; A = operand to find
  jr nz, .General2
  ld ix, GENERAL_TABLE      ; Check GENERAL_TABLE for operand value smaller then $80
  jr .SearchTable
.General2:
  ld ix, GENERAL2_TABLE     ; Check GENERAL2_TABLE for operand value larger then $80
.SearchTable:
  call SearchTable
  ret

SavePrefixNext:
  ld hl, PREFIX
  ld (hl), c
NextByte:
  call IncDisassStart
HexCode:
  ld hl, (DISASS_START)
  ld a, (hl)
HexA:
  push af
  push bc
  push de
  call PrintAHex8
  pop de
  pop bc
  pop af
  ret

Unknown:
  pop af                    ; Just remove address from stack to not call PrintInstruction
  call TextGap
  ld a, '?'                 ; '?' character
  rst $20
IncDisassStart:
  ld hl, (DISASS_START)     ; Increment current disassembling address
  inc hl
  ld (DISASS_START), hl
  ret

PrintFromTabel2:
  ld hl, TABEL2
PrintFromTable:             ; Print mnemonic
  dec a
  jr z, .Print
.Find:
  inc hl                    ; Before INC, HL is pointing to table beginning
  bit 7, (hl)               ; Test for string end (value $80)
  jr z, .Find               ; Skip A mnemonics
  jr PrintFromTable
.Print:
  ld a, (hl)                ; A contains character code from table (Eg. CC for L letter from LD instruction at $1F8F)
  and $7F                   ; Characters in the table have set most significant bit and this instruction will reset it
  rst $20                   ; Print ASCII character in A to the screen
  inc hl
  bit 7, (hl)               ; Test for string end (value $80)
  jr z, .Print              ; Repeat until the end of mnemonic
  ret

SearchSimpleTable:          ; C = byte to be decoded, IX = start of the opcodes table
  ld a, c
  xor (ix)                  ; Compare values
  jr z, IndexFound.End
  inc ix                    ; INC two times because one table entry is two bytes
  inc ix
  ld a, (ix)
  or a                      ; Is it the end of the table ($00 byte at the end)?
  jr nz, SearchSimpleTable
  scf                       ; C flag set if opcode is not found
  ret

SearchTable:                ; C = byte to be decoded, IX = start of the opcodes table
  ld de, $04
.Loop:
  ld a, c
  xor (ix)                  ; Compare values
  jr z, IndexFound
  add ix, de                ; Increment IX by 4 because table row is 4 bytes
  ld a, (ix)
  or a                      ; Is it the end of the table ($00 byte at the end)?
  jr nz, .Loop
  scf                       ; C flag set if opcode is not found
  ret

IndexFound:                 ; Read table data for index pointed by IX and read optional data operands, put these into temporary variables.
  ld a, c                   ; C = instruction opcode byte
  ld (OPCODE), a
  ld a, (ix + 2)
  ld (CODE_LEFT), a
  bit 7, a
  call nz, .ReadByte        ; Jump for codes $80 and bigger
  ld a, (ix + 3)
  ld (CODE_RIGHT), a
  bit 7, a
  call nz, .ReadByte        ; Jump for codes $80 and bigger (Only one of CODE_LEFT and CODE_RIGHT values need reading more data)
.End:
  ld a, (ix + 1)
  ld (TABEL1_INDEX), a
  ret
.ReadByte:
  ld e, a
  call NextByte
  ld (VALUE_1), a           ; Save second instruction byte
  ld a, e
  bit 6, a
  ret z
  call NextByte
  ld (VALUE_2), a           ; Save third instruction byte
  ret

SearchBlockTable:           ; C = byte to be decoded, IX = start of the opcodes table
  ld de, $04                ; Table row size in bytes
  ld a, (ix)                ; A has first byte from first table row
.TableLoop:
  cp c                      ; Next lines will check if A <= C < A+8
  jr z, IndexFound          ; Jump if A = C
  jr nc, .Next              ; Jump if A > C
  ; A < C
  add a, $07
  cp c
  jr nc, IndexFound         ; Jump if A >= C
.Next:
  add ix, de                ; Increment IX by 4
  ld a, (ix)
  or a                      ; Is it the end of the table ($00 byte at the end)?
  jr nz, .TableLoop
  scf                       ; C flag set if opcode is not found
  ret

TextGap:
  ld b, $0E                 ; Align cursor position to column 14
.GapLoop:
  ld a, (CURSORPOS)
  and $1F                   ; Take into account only 5 bits (there are 32 columns)
  cp b
  ret nc                    ; Return if column index in A >= $0E
  ld a, ' '
  rst $20                   ; Print space character
  jr .GapLoop

PrintInstruction:           ; Print mnemonic and operands
  call TextGap
  ld a, (TABEL1_INDEX)
  ld hl, TABEL1
  inc a                     ; Increment A because it will be decremented at the beginning subroutine call
  call PrintFromTable
  ld b, $13                 ; Align output to column 19 for printing operands
  call TextGap.GapLoop
  ld a, (CODE_LEFT)
  or a
  call nz, .PrtOperand
  ld a, (CODE_RIGHT)
  ld b, a
  or a
  ld a, ','
  call nz, $0020
  ld a, b
  call nz, .PrtOperand
  jp IncDisassStart         ; Go to process the next instruction
  ;call IncDisassStart         ; Go to process the next instruction
  ;ret
.PrtOperand:
  cp $1F
  jr c, .PrintReg           ; Jump if less then $1F, these values are in TABEL2
  cp CODE_REG
  ld b, $0                  ; Set displacement value in B to no displacement
  jp c, .IndirectRegsByCode ; If less then CODE_REG then these are indirect register codes
  jr nz, .NotCodeReg
  ; CODE_REG
  ld a, (OPCODE)            ; Code is CODE_REG, read register value from opcode byte
  and $7                    ; 3-bit masking. Operand lowest 3 bits are register code
  cp $6                     ; Test HL register index
  jp z, .IndirectRegs       ; For (HL)
  add $8                    ; Add 8 for TABLE2 B register index
  cp 15                     ; For register index 15 decimal (A register, code: 111) decrease by one
  jr nz, .PrintReg
  dec a                     ; For A register table index
.PrintReg:                  ; Print register label from TABEL2
  cp CODE_IX
  jr nz, .NotIXReg
  call ChangeIXToIY
.NotIXReg:
  call PrintFromTabel2
  ret
.NotCodeReg:
  bit 7, a
  jr z, .Numbers            ; Jump if code is less then $80 (bit 7 is 0)
  bit 6, a
  jr z, .OneByte            ; Jump if code is in range of $80-$BF (bit 7 is 1, bit 6 is 0)
  cp CODE_NN
  bit 0, a
  ld hl, (VALUE_1)          ; Before JR because it is used in both branches
  jr z, .NN_Indirect
  call PrintHexWord
  ret
.NN_Indirect:               ; CODE_NN_INDIRECT
  ld a, '('
  rst $20
  call PrintHexWord
  ld a, ')'
  rst $20
  ret
.OneByte:
  bit 0, a
  jr nz, .Op_IXD            ; CODE_IX_D ($81)
  bit 1, a
  jr nz, .Op_N              ; CODE_N ($82)
  bit 2, a
  jr nz, .Op_N_Indirect     ; CODE_N_INDIRECT ($84)
  bit 3, a
  jr nz, .Op_D_Abs          ; CODE_DISPLACEMENT_ABS ($88)
  ; CODE_DISPLACEMENT ($80)
  jr .Op_N                  ; The same as for CODE_N?
.Op_IXD:
  ld a, CODE_IX
  call ChangeIXToIY
  ld hl, VALUE_1
  ld b, (hl)
  jr .IndirectRegs
.Op_N:
  ld a, '&'
  rst $20                   ; Print '&' character
  ld a, (VALUE_1)
  call HexA
  ret
.Op_N_Indirect:
  ld a, '('
  rst $20
  ld a, '&'
  rst $20                   ; Print '&' character
  ld a, (VALUE_1)
  call HexA
  ld a, ')'
  rst $20
  ret
.Op_D_Abs:
  ld a, (VALUE_1)
  ld hl, (DISASS_START)
  inc hl                    ; Because JR/DJNZ offset is relative to the next address after the instruction. DISASS_START is current byte pointer.
  ld e, a                   ; Next instructions will sign extend 8-bit value to 16-bit
  add a, a                  ; Sign bit of A into carry
  sbc a, a                  ; A = 0 if carry == 0, $FF otherwise
  ld d, a                   ; DE is sign extended A
  add hl, de
  call PrintHexWord
  ret
.Numbers:
  cp CODE_IX_D2
  jr z, .Op_IXD             ; Same print as for CODE_IX_D
  cp CODE_VALUE_8_HEX
  jr c, .PrintDecimal
  cp CODE_VALUE_0_HEX
  jr nz, .Skip_0_Hex
  sub CODE_VALUE_0_HEX - $40 ; -$40 because it will be subtracted by next instruction
.Skip_0_Hex:
  sub $40
  ld b, a
  ld a, '&'
  rst $20                   ; Print '&' character
  ld a, b
  call HexA
  ret
.PrintDecimal:              ; Print decimal digits from 0 to 7
  sub $10                   ; Subtract $10 from CODE_VALUE_x to get ASCII digit (ASCII '0' has code $30)
  rst $20
  ret
.IndirectRegsByCode:
  sub $1F                   ; Subtract $1F from $2x codes to get register table index
.IndirectRegs:              ; B = displacement, 0 means no displacement; A = table index
  ld c, a
  ld a, '('
  rst $20
  ld a, c
  call PrintFromTabel2
  ; Print displacement
  ld a, b
  or a
  jr z, .Close              ; Jump if there is no displacement
  jp p, .Positive           ; Jump if A has positive value
  neg
.Positive:
  ld c, a
  ld a, '+'                 ; '+' character
  jr nc, .Plus              ; Jump if printing positive number
  ld a, '-'                 ; '-' character
.Plus:
  rst $20
  ld a, '&'
  rst $20                   ; Print '&' character
  ld a, c
  call HexA
.Close:
  ld a, ')'
  rst $20
  ret

ChangeIXToIY:               ; Change IX to IY if prefix is FD, C = table index
  ld c, a
  ld a, (PREFIX)
  cp $FD
  ld a, c
  jr nz, .No_IY             ; No need to change IX to IY
  inc a                     ; IY table index is next after IX
.No_IY:
  ret

CheckBrk:                   ; If not, check BRK, DEL and ENTER if printing is turned on
  call CheckBrkKey          ; Check BRK and DEL keys
  ld a, (PRINTERFLAG)
  inc a                     ; Is printing turned on?
  ret z                     ; If it is, go back (continual printing output)
  ld a, (KBDBASEADDR + KEY_CR) ; If not, check ENTER key in memory mapped keyboard
  rrca                      ; (print while ENTER is pressed)
  jr c, CheckBrk            ; If ENTER is not pressed, check again
  ret                       ; If it is pressed, continue printing

SIMPLE_TABLE: ; Simple instructions (OPCODE, TABEL1 index)
  BYTE $00, $00 ; NOP
  BYTE $2F, $01 ; CPL
  BYTE $3F, $02 ; CCF
  BYTE $37, $03 ; SCF
  BYTE $76, $04 ; HALT
  BYTE $F3, $05 ; DI
  BYTE $FB, $06 ; EI
  BYTE $D9, $07 ; EXX
  BYTE $07, $08 ; RLCA
  BYTE $17, $09 ; RLA
  BYTE $0F, $0A ; RRCA
  BYTE $1F, $0B ; RRA
  BYTE $27, $0C ; DAA
  BYTE $00      ; Table terminator value

BLOCK_TABLE: ; (OPCODE start, TABEL1 index, CODE_LEFT, CODE_RIGHT) Register index order: B C D E H L (HL) A
  BYTE $40, $36, CODE_B, CODE_REG ; LD B,r - r value is derived from the opcode
  BYTE $48, $36, CODE_C, CODE_REG ; LD C,r
  BYTE $50, $36, CODE_D, CODE_REG ; LD D,r
  BYTE $58, $36, CODE_E, CODE_REG ; LD E,r
  BYTE $60, $36, CODE_H, CODE_REG ; LD H,r
  BYTE $68, $36, CODE_L, CODE_REG ; LD L,r
  BYTE $70, $36, CODE_HL_INDIRECT, CODE_REG ; LD (HL),r
  BYTE $78, $36, CODE_A, CODE_REG ; LD A,r
  BYTE $80, $2C, CODE_A, CODE_REG ; ADD A,r
  BYTE $88, $2D, CODE_A, CODE_REG ; ADC A,r
  BYTE $90, $2F, CODE_REG, $0 ; SUB r
  BYTE $98, $2E, CODE_A, CODE_REG ; SBC A,r
  BYTE $A0, $30, CODE_REG, $0 ; AND r
  BYTE $A8, $32, CODE_REG, $0 ; XOR r
  BYTE $B0, $31, CODE_REG, $0 ; OR r
  BYTE $B8, $33, CODE_REG, $0 ; CP r
  BYTE $00

GENERAL_TABLE: ; (OPCODE, TABEL1 index, CODE_LEFT, CODE_RIGHT), instructions with one byte opcode, opcodes $00-$3F
  BYTE $01, $36, CODE_BC, CODE_NN ; LD BC,nn
  BYTE $02, $36, CODE_BC_INDIRECT, CODE_A ; LD (BC),A
  BYTE $06, $36, CODE_B, CODE_N ; LD B,n
  BYTE $0A, $36, CODE_A, CODE_BC_INDIRECT ; LD A,(BC)
  BYTE $0E, $36, CODE_C, CODE_N ; LD C,n
  BYTE $11, $36, CODE_DE, CODE_NN ; LD DE,nn
  BYTE $12, $36, CODE_DE_INDIRECT, CODE_A ; LD (DE),A
  BYTE $16, $36, CODE_D, CODE_N ; LD D,n
  BYTE $1A, $36, CODE_A, CODE_DE_INDIRECT ; LD A,(DE)
  BYTE $1E, $36, CODE_E, CODE_N ; LD E,n
  BYTE $21, $36, CODE_HL, CODE_NN ; LD HL,nn
  BYTE $22, $36, CODE_NN_INDIRECT, CODE_HL ; LD (nn),HL
  BYTE $26, $36, CODE_H, CODE_N ; LD H,n
  BYTE $2A, $36, CODE_HL, CODE_NN_INDIRECT ; LD HL,(nn)
  BYTE $2E, $36, CODE_L, CODE_N ; LD L,n
  BYTE $31, $36, CODE_SP, CODE_NN ; LD SP,nn
  BYTE $32, $36, CODE_NN_INDIRECT, CODE_A ; LD (nn),A
  BYTE $36, $36, CODE_HL_INDIRECT, CODE_N ; LD (HL),n
  BYTE $3A, $36, CODE_A, CODE_NN_INDIRECT ; LD A,(nn)
  BYTE $3E, $36, CODE_A, CODE_N ; LD A,n

  BYTE $03, $34, CODE_BC, $0 ; INC BC
  BYTE $04, $34, CODE_B, $0 ; INC B
  BYTE $0C, $34, CODE_C, $0 ; INC C
  BYTE $13, $34, CODE_DE, $0 ; INC DE
  BYTE $14, $34, CODE_D, $0 ; INC D
  BYTE $1C, $34, CODE_E, $0 ; INC E
  BYTE $23, $34, CODE_HL, $0 ; INC HL
  BYTE $24, $34, CODE_H, $0 ; INC H
  BYTE $2C, $34, CODE_L, $0 ; INC L
  BYTE $33, $34, CODE_SP, $0 ; INC SP
  BYTE $34, $34, CODE_HL_INDIRECT, $0 ; INC (HL)
  BYTE $3C, $34, CODE_A, $0 ; INC A

  BYTE $05, $35, CODE_B, $0 ; DEC B
  BYTE $0B, $35, CODE_BC, $0 ; DEC BC
  BYTE $0D, $35, CODE_C, $0 ; DEC C
  BYTE $15, $35, CODE_D, $0 ; DEC D
  BYTE $1B, $35, CODE_DE, $0 ; DEC DE
  BYTE $1D, $35, CODE_E, $0 ; DEC E
  BYTE $25, $35, CODE_H, $0 ; DEC H
  BYTE $2B, $35, CODE_HL, $0 ; DEC HL
  BYTE $2D, $35, CODE_L, $0 ; DEC L
  BYTE $35, $35, CODE_HL_INDIRECT, $0 ; DEC (HL)
  BYTE $3B, $35, CODE_SP, $0 ; DEC SP
  BYTE $3D, $35, CODE_A, $0 ; DEC A

  BYTE $18, $3B, CODE_DISPLACEMENT_ABS, $0 ; JR d
  BYTE $20, $3B, CODE_F_NZ, CODE_DISPLACEMENT_ABS ; JR nz,d
  BYTE $28, $3B, CODE_F_Z, CODE_DISPLACEMENT_ABS ; JR z,d
  BYTE $30, $3B, CODE_F_NC, CODE_DISPLACEMENT_ABS ; JR nc,d
  BYTE $38, $3B, CODE_F_C, CODE_DISPLACEMENT_ABS ; JR c,d

  BYTE $09, $2C, CODE_HL, CODE_BC ; ADD HL,BC
  BYTE $19, $2C, CODE_HL, CODE_DE ; ADD HL,DE
  BYTE $29, $2C, CODE_HL, CODE_HL ; ADD HL,HL
  BYTE $39, $2C, CODE_HL, CODE_SP ; ADD HL,SP

  BYTE $10, $3A, CODE_DISPLACEMENT_ABS, $0 ; DJNZ d
  BYTE $08, $37, CODE_AF, CODE_AF_PRIM ; EX AF,AF'
  BYTE $00

GENERAL2_TABLE: ; Second half of the table, opcodes $C0-$FF, split into second table to improve search speed
  BYTE $C0, $3E, CODE_F_NZ, $0 ; RET nz
  BYTE $C8, $3E, CODE_F_Z, $0 ; RET z
  BYTE $C9, $3E, $0, $0 ; RET
  BYTE $D0, $3E, CODE_F_NC, $0 ; RET nc
  BYTE $D8, $3E, CODE_F_C, $0 ; RET c
  BYTE $E0, $3E, CODE_F_PO, $0 ; RET po
  BYTE $E8, $3E, CODE_F_PE, $0 ; RET pe
  BYTE $F0, $3E, CODE_F_P, $0 ; RET p
  BYTE $F8, $3E, CODE_F_M, $0 ; RET m

  BYTE $C2, $3C, CODE_F_NZ, CODE_NN ; JP nz,nn
  BYTE $C3, $3C, CODE_NN, $0 ; JP nn - Saved with low-high byte order (addr -> 'dr ad')
  BYTE $CA, $3C, CODE_F_Z, CODE_NN ; JP z,nn
  BYTE $D2, $3C, CODE_F_NC, CODE_NN ; JP nc,nn
  BYTE $DA, $3C, CODE_F_C, CODE_NN ; JP c,nn
  BYTE $E2, $3C, CODE_F_PO, CODE_NN ; JP po,nn
  BYTE $E9, $3C, CODE_HL_INDIRECT, $0 ; JP (HL)
  BYTE $EA, $3C, CODE_F_PE, CODE_NN ; JP pe,nn
  BYTE $F2, $3C, CODE_F_P, CODE_NN ; JP p,nn
  BYTE $FA, $3C, CODE_F_M, CODE_NN ; JP m,nn

  BYTE $C4, $3D, CODE_F_NZ, CODE_NN ; CALL nz,nn
  BYTE $CC, $3D, CODE_F_Z, CODE_NN ; CALL z,nn
  BYTE $CD, $3D, CODE_NN, $0 ; CALL nn
  BYTE $D4, $3D, CODE_F_NC, CODE_NN ; CALL nc,nn
  BYTE $DC, $3D, CODE_F_C, CODE_NN ; CALL c,nn
  BYTE $E4, $3D, CODE_F_PO, CODE_NN ; CALL po,nn
  BYTE $EC, $3D, CODE_F_PE, CODE_NN ; CALL pe,nn
  BYTE $F4, $3D, CODE_F_P, CODE_NN ; CALL p,nn
  BYTE $FC, $3D, CODE_F_M, CODE_NN ; CALL m,nn

  BYTE $C1, $41, CODE_BC, $0 ; POP BC
  BYTE $D1, $41, CODE_DE, $0 ; POP DE
  BYTE $E1, $41, CODE_HL, $0 ; POP HL
  BYTE $F1, $41, CODE_AF, $0 ; POP AF

  BYTE $C5, $42, CODE_BC, $0 ; PUSH BC
  BYTE $D5, $42, CODE_DE, $0 ; PUSH DE
  BYTE $E5, $42, CODE_HL, $0 ; PUSH HL
  BYTE $F5, $42, CODE_AF, $0 ; PUSH AF

  BYTE $C7, $3F, CODE_VALUE_0_HEX, $0 ; RST $00
  BYTE $CF, $3F, CODE_VALUE_8_HEX, $0 ; RST $08
  BYTE $D7, $3F, CODE_VALUE_16_HEX, $0 ; RST $10
  BYTE $DF, $3F, CODE_VALUE_24_HEX, $0 ; RST $18
  BYTE $E7, $3F, CODE_VALUE_32_HEX, $0 ; RST $20
  BYTE $EF, $3F, CODE_VALUE_40_HEX, $0 ; RST $28
  BYTE $F7, $3F, CODE_VALUE_48_HEX, $0 ; RST $30
  BYTE $FF, $3F, CODE_VALUE_56_HEX, $0 ; RST $38

  BYTE $C6, $2C, CODE_A, CODE_N ; ADD A,n
  BYTE $CE, $2D, CODE_A, CODE_N ; ADC A,n
  BYTE $D6, $2F, CODE_N, $0 ; SUB n
  BYTE $DE, $2E, CODE_A, CODE_N ; SBC A,n

  BYTE $E6, $30, CODE_N, $0 ; AND n
  BYTE $EE, $32, CODE_N, $0 ; XOR n
  BYTE $F6, $31, CODE_N, $0 ; OR n
  BYTE $FE, $33, CODE_N, $0 ; CP n

  BYTE $D3, $39, CODE_N_INDIRECT, CODE_A ; OUT (n),A
  BYTE $DB, $38, CODE_A, CODE_N_INDIRECT ; IN A,(N)
  BYTE $E3, $37, CODE_SP_INDIRECT, CODE_HL ; EX (SP),HL
  BYTE $EB, $37, CODE_DE, CODE_HL ; EX DE,HL
  BYTE $00

ED_TABLE:
  BYTE $40, $38, CODE_B, CODE_C_INDIRECT ; IN B,(C)
  BYTE $41, $39, CODE_C_INDIRECT, CODE_B ; OUT (C),B
  BYTE $42, $2E, CODE_HL, CODE_BC ; SBC HL,BC
  BYTE $43, $36, CODE_NN_INDIRECT, CODE_BC ; LD (nn),BC
  BYTE $44, $1D, $0, $0 ; NEG
  BYTE $45, $1F, $0, $0 ; RETN
  BYTE $46, $40, CODE_VALUE_0, $0 ; IM 0
  BYTE $47, $36, CODE_I, CODE_A ; LD I,A
  BYTE $48, $38, CODE_C, CODE_C_INDIRECT ; IN C,(C)
  BYTE $49, $39, CODE_C_INDIRECT, CODE_C ; OUT (C),C
  BYTE $4A, $2D, CODE_HL, CODE_BC ; ADC HL,BC
  BYTE $4B, $36, CODE_BC, CODE_NN_INDIRECT ; LD BC,(nn)
  BYTE $4D, $1E, $0, $0 ; RETI
  BYTE $4F, $36, CODE_R, CODE_A ; LD R,A
  BYTE $50, $38, CODE_D, CODE_C_INDIRECT ; IN D,(C)
  BYTE $51, $39, CODE_C_INDIRECT, CODE_D ; OUT (C),D
  BYTE $52, $2E, CODE_HL, CODE_DE ; SBC HL,DE
  BYTE $53, $36, CODE_NN_INDIRECT, CODE_DE ; LD (nn),DE
  BYTE $56, $40, CODE_VALUE_1, $0 ; IM 1
  BYTE $57, $36, CODE_A, CODE_I ; LD A,I
  BYTE $58, $38, CODE_E, CODE_C_INDIRECT ; IN E,(C)
  BYTE $59, $39, CODE_C_INDIRECT, CODE_E ; OUT (C),E
  BYTE $5A, $2D, CODE_HL, CODE_DE ; ADC HL,DE
  BYTE $5B, $36, CODE_DE, CODE_NN_INDIRECT ; LD DE,(nn)
  BYTE $5E, $40, CODE_VALUE_2, $0 ; IM 2
  BYTE $5F, $36, CODE_A, CODE_R ; LD A,R
  BYTE $60, $38, CODE_H, CODE_C_INDIRECT ; IN H,(C)
  BYTE $61, $39, CODE_C_INDIRECT, CODE_H ; OUT (C),H
  BYTE $62, $2E, CODE_HL, CODE_HL; SBC HL,HL
  BYTE $67, $21, $0, $0 ; RRD
  BYTE $68, $38, CODE_L, CODE_C_INDIRECT ; IN L,(C)
  BYTE $69, $39, CODE_C_INDIRECT, CODE_L ; OUT (C),L
  BYTE $6A, $2D, CODE_HL, CODE_HL ; ADC HL,HL
  BYTE $6F, $20, $0, $0 ; RLD
  BYTE $72, $2E, CODE_HL, CODE_SP ; SBC HL,SP
  BYTE $73, $36, CODE_NN_INDIRECT, CODE_SP ; LD (nn),SP
  BYTE $78, $38, CODE_A, CODE_C_INDIRECT ; IN A,(C)
  BYTE $79, $39, CODE_C_INDIRECT, CODE_A ; OUT (C),A
  BYTE $7A, $2D, CODE_HL, CODE_SP ; ADC HL,SP
  BYTE $7B, $36, CODE_SP, CODE_NN_INDIRECT ; LD SP,(nn)
  BYTE $00

ED2_TABLE:
  BYTE $A0, $0E ; LDI
  BYTE $A1, $12 ; CPI
  BYTE $A2, $16 ; INI
  BYTE $A3, $1A ; OUTI
  BYTE $A8, $10 ; LDD
  BYTE $A9, $14 ; CPD
  BYTE $AA, $18 ; IND
  BYTE $AB, $1C ; OUTD
  BYTE $B0, $0D ; LDIR
  BYTE $B1, $11 ; CPIR
  BYTE $B2, $15 ; INIR
  BYTE $B3, $19 ; OTIR
  BYTE $B8, $0F ; LDDR
  BYTE $B9, $13 ; CPDR
  BYTE $BA, $17 ; INDR
  BYTE $BB, $1B ; OTDR
  BYTE $00

DD_FD_TABLE: ; DD for IX, FD for IY
  BYTE $86, $2C, CODE_A, CODE_IX_D ; ADD A,(IX+d)
  BYTE $09, $2C, CODE_IX, CODE_BC ; ADD IX,BC
  BYTE $19, $2C, CODE_IX, CODE_DE ; ADD IX,DE
  BYTE $29, $2C, CODE_IX, CODE_IX ; ADD IX,IX
  BYTE $39, $2C, CODE_IX, CODE_SP ; ADD IX,SP
  BYTE $A6, $30, CODE_IX_D, $0 ; AND (IX+d)
  BYTE $77, $36, CODE_IX_D, CODE_A ; LD (IX+d),A
  BYTE $70, $36, CODE_IX_D, CODE_B ; LD (IX+d),B
  BYTE $71, $36, CODE_IX_D, CODE_C ; LD (IX+d),C
  BYTE $72, $36, CODE_IX_D, CODE_D ; LD (IX+d),D
  BYTE $73, $36, CODE_IX_D, CODE_E ; LD (IX+d),E
  BYTE $74, $36, CODE_IX_D, CODE_H ; LD (IX+d),H
  BYTE $75, $36, CODE_IX_D, CODE_L ; LD (IX+d),L
  BYTE $36, $36, CODE_IX_D, CODE_N ; LD (IX+d),n
  BYTE $7E, $36, CODE_A, CODE_IX_D ; LD A,(IX+d)
  BYTE $46, $36, CODE_B, CODE_IX_D ; LD B,(IX+d)
  BYTE $4E, $36, CODE_C, CODE_IX_D ; LD C,(IX+d)
  BYTE $56, $36, CODE_D, CODE_IX_D ; LD D,(IX+d)
  BYTE $5E, $36, CODE_E, CODE_IX_D ; LD E,(IX+d)
  BYTE $66, $36, CODE_H, CODE_IX_D ; LD H,(IX+d)
  BYTE $6E, $36, CODE_L, CODE_IX_D ; LD L,(IX+d)
  BYTE $2A, $36, CODE_IX, CODE_NN_INDIRECT; LD IX,(nn)
  BYTE $21, $36, CODE_IX, CODE_NN; LD IX,nn
  BYTE $9E, $2E, CODE_A, CODE_IX_D; SBC A,(IX+d)
  BYTE $BE, $33, CODE_IX_D, $0 ; CP (IX+d)
  BYTE $35, $35, CODE_IX_D, $0 ; DEC (IX+d)
  BYTE $2B, $35, CODE_IX, $0 ; DEC IX
  BYTE $E3, $37, CODE_SP_INDIRECT, CODE_IX ; EX (SP),IX
  BYTE $34, $34, CODE_IX_D, $0 ; INC (IX+d)
  BYTE $23, $34, CODE_IX, $0 ; INC IX
  BYTE $E9, $3C, CODE_IX_INDIRECT, $0 ; JP (IX)
  BYTE $F9, $36, CODE_SP, CODE_IX ; LD SP,IX
  BYTE $B6, $31, CODE_IX_D, $0 ; OR (IX+d)
  BYTE $E1, $41, CODE_IX, $0 ; POP IX
  BYTE $E5, $42, CODE_IX, $0 ; PUSH IX
  BYTE $96, $2F, CODE_IX_D, $0 ; SUB (IX+d)
  BYTE $AE, $32, CODE_IX_D, $0 ; XOR (IX+d)
  BYTE $00

CB_BLOCK_TABLE:
  BYTE $00, $22, CODE_REG, $0 ; RLC r
  BYTE $08, $24, CODE_REG, $0 ; RRC r
  BYTE $10, $23, CODE_REG, $0 ; RL r
  BYTE $18, $25, CODE_REG, $0 ; RR r
  BYTE $20, $26, CODE_REG, $0 ; SLA r
  BYTE $28, $27, CODE_REG, $0 ; SRA r
  BYTE $38, $28, CODE_REG, $0 ; SRL r
  BYTE $40, $29, CODE_VALUE_0, CODE_REG ; BIT 0,r
  BYTE $48, $29, CODE_VALUE_1, CODE_REG ; BIT 1,r
  BYTE $50, $29, CODE_VALUE_2, CODE_REG ; BIT 2,r
  BYTE $58, $29, CODE_VALUE_3, CODE_REG ; BIT 3,r
  BYTE $60, $29, CODE_VALUE_4, CODE_REG ; BIT 4,r
  BYTE $68, $29, CODE_VALUE_5, CODE_REG ; BIT 5,r
  BYTE $70, $29, CODE_VALUE_6, CODE_REG ; BIT 6,r
  BYTE $78, $29, CODE_VALUE_7, CODE_REG ; BIT 7,r
  BYTE $80, $2B, CODE_VALUE_0, CODE_REG ; RES 0,r
  BYTE $88, $2B, CODE_VALUE_1, CODE_REG ; RES 1,r
  BYTE $90, $2B, CODE_VALUE_2, CODE_REG ; RES 2,r
  BYTE $98, $2B, CODE_VALUE_3, CODE_REG ; RES 3,r
  BYTE $A0, $2B, CODE_VALUE_4, CODE_REG ; RES 4,r
  BYTE $A8, $2B, CODE_VALUE_5, CODE_REG ; RES 5,r
  BYTE $B0, $2B, CODE_VALUE_6, CODE_REG ; RES 6,r
  BYTE $B8, $2B, CODE_VALUE_7, CODE_REG ; RES 7,r
  BYTE $C0, $2A, CODE_VALUE_0, CODE_REG ; SET 0,r
  BYTE $C8, $2A, CODE_VALUE_1, CODE_REG ; SET 1,r
  BYTE $D0, $2A, CODE_VALUE_2, CODE_REG ; SET 2,r
  BYTE $D8, $2A, CODE_VALUE_3, CODE_REG ; SET 3,r
  BYTE $E0, $2A, CODE_VALUE_4, CODE_REG ; SET 4,r
  BYTE $E8, $2A, CODE_VALUE_5, CODE_REG ; SET 5,r
  BYTE $F0, $2A, CODE_VALUE_6, CODE_REG ; SET 6,r
  BYTE $F8, $2A, CODE_VALUE_7, CODE_REG ; SET 7,r
  BYTE $00

DDFD_CB_TABLE: ; DD CB fo IX, FD CB for IY
  BYTE $46, $29, CODE_VALUE_0, CODE_IX_D2 ; BIT 0,(IX+d)
  BYTE $4E, $29, CODE_VALUE_1, CODE_IX_D2 ; BIT 1,(IX+d)
  BYTE $56, $29, CODE_VALUE_2, CODE_IX_D2 ; BIT 2,(IX+d)
  BYTE $5E, $29, CODE_VALUE_3, CODE_IX_D2 ; BIT 3,(IX+d)
  BYTE $66, $29, CODE_VALUE_4, CODE_IX_D2 ; BIT 4,(IX+d)
  BYTE $6E, $29, CODE_VALUE_5, CODE_IX_D2 ; BIT 5,(IX+d)
  BYTE $76, $29, CODE_VALUE_6, CODE_IX_D2 ; BIT 6,(IX+d)
  BYTE $7E, $29, CODE_VALUE_7, CODE_IX_D2 ; BIT 7,(IX+d)
  BYTE $06, $22, CODE_IX_D2, $0 ; RLC (IX+d)
  BYTE $16, $23, CODE_IX_D2, $0 ; RL (IX+d)
  BYTE $0E, $24, CODE_IX_D2, $0 ; RRC (IX+d)
  BYTE $1E, $25, CODE_IX_D2, $0 ; RR (IX+d)
  BYTE $26, $26, CODE_IX_D2, $0 ; SLA (IX+d)
  BYTE $2E, $27, CODE_IX_D2, $0 ; SRA (IX+d)
  BYTE $3E, $28, CODE_IX_D2, $0 ; SRL (IX+d)
  BYTE $86, $2B, CODE_VALUE_0, CODE_IX_D2 ; RES 0,(IX+d) Byte order: DD CB d 86
  BYTE $8E, $2B, CODE_VALUE_1, CODE_IX_D2 ; RES 1,(IX+d)
  BYTE $96, $2B, CODE_VALUE_2, CODE_IX_D2 ; RES 2,(IX+d)
  BYTE $9E, $2B, CODE_VALUE_3, CODE_IX_D2 ; RES 3,(IX+d)
  BYTE $A6, $2B, CODE_VALUE_4, CODE_IX_D2 ; RES 4,(IX+d)
  BYTE $AE, $2B, CODE_VALUE_5, CODE_IX_D2 ; RES 5,(IX+d)
  BYTE $B6, $2B, CODE_VALUE_6, CODE_IX_D2 ; RES 6,(IX+d)
  BYTE $BE, $2B, CODE_VALUE_7, CODE_IX_D2 ; RES 7,(IX+d)
  BYTE $C6, $2A, CODE_VALUE_0, CODE_IX_D2 ; SET 0,(IX+d)
  BYTE $CE, $2A, CODE_VALUE_1, CODE_IX_D2 ; SET 1,(IX+d)
  BYTE $D6, $2A, CODE_VALUE_2, CODE_IX_D2 ; SET 2,(IX+d)
  BYTE $DE, $2A, CODE_VALUE_3, CODE_IX_D2 ; SET 3,(IX+d)
  BYTE $E6, $2A, CODE_VALUE_4, CODE_IX_D2 ; SET 4,(IX+d)
  BYTE $EE, $2A, CODE_VALUE_5, CODE_IX_D2 ; SET 5,(IX+d)
  BYTE $F6, $2A, CODE_VALUE_6, CODE_IX_D2 ; SET 6,(IX+d)
  BYTE $FE, $2A, CODE_VALUE_7, CODE_IX_D2 ; SET 7,(IX+d)
  BYTE $00

; Table values for CODE_LEFT and CODE_RIGHT
; Registers, same order as in TABEL1
CODE_IX = 1
;CODE_IY = 2 ; Not used
CODE_AF = 3
CODE_BC = 4
CODE_DE = 5
CODE_HL = 6
CODE_SP = 7
CODE_B = 8
CODE_C = 9
CODE_D = 10
CODE_E = 11
CODE_H = 12
CODE_L = 13
CODE_A = 14
CODE_I = 15
CODE_R = 16
; Flags
CODE_F_NZ = 17
CODE_F_Z = 18
CODE_F_NC = 19
CODE_F_C = 20
CODE_F_PO = 21
CODE_F_PE = 22
CODE_F_P = 23
CODE_F_M = 24
; Indirect registers
CODE_IX_INDIRECT = $20
;CODE_IY_INDIRECT = $21 ; Not used
CODE_BC_INDIRECT = $23 ; Once code value skiped for AF in table
CODE_DE_INDIRECT = $24
CODE_HL_INDIRECT = $25 ; (HL), $20 = 32 decimal, has bit 5 set
CODE_SP_INDIRECT = $26
CODE_C_INDIRECT = $28

CODE_REG = $30 ; Bits 5 and 4 are set
CODE_IX_D2 = $31 ; This is different then CODE_IX_D because displacement is not the last instruction byte. It is read at other place then for CODE_IX_D.
CODE_AF_PRIM = $32 ; AF' TODO This is not implemented - there is no ''' character in Galaksija!
; Unsupported 8-bit registers high and low IX/IY
; CODE_HIX = $32
; CODE_HIY = $33
; CODE_LIX = $34
; CODE_LIY = $35

CODE_VALUE_0 = $40
CODE_VALUE_1 = $41
CODE_VALUE_2 = $42
CODE_VALUE_3 = $43
CODE_VALUE_4 = $44
CODE_VALUE_5 = $45
CODE_VALUE_6 = $46
CODE_VALUE_7 = $47
CODE_VALUE_8_HEX = $48
CODE_VALUE_16_HEX = $50
CODE_VALUE_24_HEX = $58
CODE_VALUE_32_HEX = $60
CODE_VALUE_40_HEX = $68
CODE_VALUE_48_HEX = $70
CODE_VALUE_56_HEX = $78
CODE_VALUE_0_HEX = $7A ; Print 0 as HEX value &00

; d = displacement byte (8-bit signed integer)
; n = 8-bit immediate operand (unsigned integer)
; nn = 16-bit immediate operand (unsigned integer)

; One byte digit values (7th bit set)
CODE_DISPLACEMENT = $80 ; -126 to +129. TODO This is not used now!
; Index registers with displacement
CODE_IX_D = $81 ; (IX + d)
CODE_N = $82
CODE_N_INDIRECT = $84
CODE_DISPLACEMENT_ABS = $88 ; Displacement as absolute address
; (7th and 6th bits set)
CODE_NN = $C3
CODE_NN_INDIRECT = $C4

  .end