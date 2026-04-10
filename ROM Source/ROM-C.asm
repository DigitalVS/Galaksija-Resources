;-------------------------------------------------------------------------------------------------
;
; Listing of ROM C for the "Galaxy Plus" computer
; Version 36
;
; Authors: Nenad Dunjić and Milan Tadić
; Comments: Ferenc Hindicki, translated to english and adapted to sjasmplus by issalig
;
; Final touch and overall most deserving for this file contents: DigitalVS
;
;-------------------------------------------------------------------------------------------------

;-------------------------------------------------------------------------------------------------
; Galaksija Plus variables at RAMTOP (default value $C5E0, graphics video memory is at $C600 (RAMTOP + 32)):
;
; 0  Number of characters at screen row 1
; ...
; 15 Number of characters at screen row 16
; 16 Picture counter which determines cursor state, 0 - not blinking, 1 - blinking with period T=0,8s
; 17 Character code at cursor position or cursor code (191)
; 18 Arrow execution indicator, 255 - print an arrow control character, 0 - cursor is moving, 1 to 254 - option is turned-off
; 19 Graphics indicator, 0 - memory not reserved (or any other value then 255), 255 - memory is reserved
; 20 Coordinate X for last drawn point
; 21 Coordinate Y for last drawn point
; 22 Character definition table start address lower byte
; 23 Character definition table start address higher byte
; 24 Used by screen editor (cursor position)
; 25 Used by screen editor
; 26 Value necessary for the graphics driver to work
; 27 Value necessary for the graphics driver to work
; 28 Number of screen lines visible (default 208)
; 29 Value necessary for the graphics driver to work
; 30 Value necessary for the graphics driver to work
; 31 Graphics memory start address higher byte
;-------------------------------------------------------------------------------------------------

  include "galaksija.inc"

; Additional ROM A and ROM B routines
CmdRecognize  = $039A

        .ORG  $E000

Init:
        LD   DE, BASICLINK
        LD   HL, NewLinks
        LD   BC, $0006
        LDIR                 ; Sets new BASIC and video links
        LD   HL, (RAMTOP)
        LD   DE, $0020
        LD   A, L
        AND  $E0             ; Mask lower 5 bits
        LD   L, A            ; RAMTOP address must be divisible by 32
        LD   A, $0C
        LD   (TEXTHORPOS), A ; Centers the screen position
        SBC  HL, DE
        LD   (RAMTOP), HL    ; Sets new RAMTOP (old rounded value lowered by 32 bytes)
        LD   DE, IntroScreen ; Splash screen text address
        CALL PrintString     ; Prints introductory text
        LD   IY, InterruptLink ; New interrupt link
ClearVars:
        LD   B, $17          ; System variables from RAMTOP to RAMTOP+23
.Clear:
        LD   (HL), $0        ; ...are reset
        INC  HL
        DJNZ .Clear
        LD   DE, CharDef     ; Character definition table address
        LD   (HL), D         ; Higher byte to RAMTOP+23
        DEC  HL
        LD   (HL), E         ; Lower byte to RAMTOP+22
        DEC  HL
        DEC  HL
        DEC  HL
        DEC  HL
        DEC  HL
        LD   (HL), 191       ; Block cursor code to RAMTOP+17
        RET

NewLinks:
        JP   CmdLink         ; New BASIC command link
        JP   VideoLink       ; New video link
        DB   36              ; ROM version 36

GRAPH_CMD:
        POP  AF              ; GRAPH command
        PUSH DE              ; Save BASIC pointer
        CALL .E057           ; check and/or reserve graphics memory
        LD   A, $FF
        LD   (TEXTHORPOS), A ; Graphic mode indicator = 255
        LD   A, FF           ; Form feed character
        RST  $20             ; Clears the TEXT (and thus the GRAPH) screen
        HALT                 ; Wait for the next video interrupt
        IM   2               ; No IM2 interrupt table! I=$E0,($E0FF)=$E3FB -> points to video driver
        POP  DE              ; DE = BASIC pointer
        RST  $30             ; Return to basic

.E057:
        CALL E4CC            ; HL=RAMTOP+16
        INC  HL
        INC  HL
        INC  HL              ; HL=RAMTOP+19
        LD   A, (HL)         ; A=graphics memory reserved indicator
        INC  A
        RET  Z               ; if A=255 - graphics memory reserved, return
        LD   HL, (RAMTOP)    ; if not, HL=RAMTOP
        LD   DE, $1A00       ; DE=size of 256x208 image in bytes
        SBC  HL, DE          ; HL=new RAMTOP
        LD   DE, (BASICEND)  ; DE=end of basic program address
        RST  $10             ; is there sufficient free space?
        JP   C, $0154        ; if there is not, SORRY
        LD   (RAMTOP), HL    ; if there is, save new RAMTOP...
        CALL ClearVars       ; ...and clear new system variables
        INC  HL
        INC  HL              ; HL=RAMTOP+19
        LD   (HL), $FF       ; Set graphics memory reserved indicator
        LD   DE, 13
        ADD  HL, DE
        PUSH HL              ; HL=RAMTOP+32 (start of graphic memory) and onto the stack

        LD   A, L            ; Setting 6 bytes values for video driver (RAMTOP + 26-31)
        BIT  7, A
        LD   E, 2
        JR   NZ, .E088
        SET  7, E
.E088:
        SUB  5               ; Offset for R register start value is -5
        LD   L, A
        LD   A, $DB
        LD   B, $0F
        LD   C, 1
.E091:
        CP   L
        JR   Z, .E09C
        SUB  $20
        RLC  B
        RLC  C
        JR   .E091
.E09C:
        AND  $7F             ; Clear bit 7
        POP  HL              ; HL=RAMTOP+32 from stack
        LD   D, H
        DEC  HL              ; HL=RAMTOP+31
        LD   (HL), D         ; RAMTOP+31=image start higher byte
        DEC  HL              ; HL=RAMTOP+30
        LD   (HL), A
        DEC  HL              ; HL=RAMTOP+29
        LD   (HL), E
        DEC  HL              ; HL=RAMTOP+28
        LD   (HL), 208       ; RAMTOP+28=initial number of screen lines visible
        DEC  HL              ; HL=RAMTOP+27
        LD   (HL), B
        DEC  HL              ; HL=RAMTOP+26
        LD   (HL), C
        RET

SOUND_CMD:
        POP  AF              ; SOUND command
        RST  $8              ; read the first parameter
        LD   A, L            ; A=number of AY port
        OUT  ($BE), A        ; send to port 190
        CALL $0005           ; read second parameter
        LD   A,L             ; A=data for AY port
        OUT  ($BF), A        ; send to port 191
        RST  $30             ; return to basic

TEXT_CMD:
        POP  AF              ; TEXT command
        LD   A, $0C          ; Instead of the graphic indicator set...
        LD   (TEXTHORPOS), A ; ...horizontal position of TEXT image
        IM   1               ; Activates video routine in ROM A
        RST  $30             ; return to basic

UNPLOT_CMD:
        XOR  A               ; UNPLOT command
        INC  A               ; A=1, Z flag=0
        DB $06               ; Dummy LD B, for UNPLOT (plus 7T)
PLOT_CMD:
        XOR  A               ; PLOT command (A=0, Z flag=1)
        POP  BC              ; remove return address
        PUSH AF              ; save Z flag
        CALL E46A            ; read coordinates Y,X in BC
        POP  AF
        PUSH AF              ; refresh Z flag
        PUSH BC              ; pass coordinates to PLOT/UNPLOT subroutine
        CALL PLOT_UNPLOT     ; turns the dot on/off
E0D2:
        POP  AF
        POP  DE
        RST  $30             ; return to basic

UNDRAW_CMD:
        XOR  A               ; UNDRAW command
        INC  A               ; A=1, Z flag=0
        DB $06               ; Dummy LD B, for UNDRAW
DRAW_CMD:
        XOR  A               ; DRAW command (A=0, Z flag=1)
        POP  BC              ; remove return address
        PUSH AF              ; keep Z flag
        CALL E46A            ; read coordinates Y2,X2 in BC
        CALL .DRAW_UNDRAW    ; draw / erase line
        LD   IX, ARITHMACC   ; reset arithmetic stack pointer
        JR   E0D2            ; return to basic
.DRAW_UNDRAW:
        LD   HL, (RAMTOP)    ; DRAW subroutine, HL=RAMTOP
        LD   DE, $0014
        ADD  HL, DE          ; HL=RAMTOP+20
        LD   E, (HL)         ; E=current (initial) X1 coordinate
        INC  HL              ; HL=RAMTOP+21
        LD   D, (HL)         ; D=current (initial) Y1 coordinate
        EX   DE, HL          ; HL=Y1,X1
        LD   A, B            ; A=Y2
        SUB  H               ; A=difference between Y1 and Y2 points
        LD   D, 1            ; D=Y step +1
        JR   NC, .E0FC       ; if Y2 is greater than Y1, step +1
        LD   D, -1           ; else Y step -1
        LD   A, H            ; A=Y1
        SUB  B               ; A=Y1-Y2
.E0FC:
        LD   B, A            ; B=difference between Y2 and Y1 points
        JR   .Skip           ; skip IM 2 vector

        DW   VideoDriver     ; This is IM2 vector at fixed address $E0FF. It points to interrupt service routine.

.Skip:
        LD   A, C
        SUB  L               ; A=difference between X1 and X2 points
        LD   E, 1            ; E=X step +1
        JR   NC, .E10B       ; if X2 is greater than X1, step +1
        LD   E, -1           ; otherwise X step -1
        LD   A, L
        SUB  C
.E10B:
        LD   C, A            ; C=difference between X2 and X1 points
        POP  IX              ; IX=return address
        SUB  B               ; A=(X2-X1)-(Y2-Y1),
        JR   NC, .E11E
        POP  AF              ; flags: Zf=1-DRAW/0-UNDRAW, Cf=0 (because XOR A)
        SCF                  ; Cf=1 (drawing from back to the beginning?)
        PUSH AF              ; flags back to stack
        LD   A, D
        LD   D, E
        LD   E, A            ; DE=ED
        LD   A, H
        LD   H, L
        LD   L, A            ; HL=LH
        LD   A, B
        LD   B, C
        LD   C, A            ; BC=CB
        SUB  B               ; A=(Y2-Y1)-(X2-X1),
.E11E:
        PUSH BC
        INC  B
        INC  C
        EXX
        POP  DE
        INC  E
.E124:
        DEC  E
        EXX
        PUSH IX
        RET  Z
        POP  IX
        SUB  B
        JR   NC, .E134
        ADD  A, C
        EX   AF, AF'
        LD   A, H
        ADD  A, D
        LD   H, A
        EX   AF, AF'
.E134:
        EX   AF, AF'
        LD   A, L
        ADD  A, E
        LD   L, A
        POP  AF
        PUSH AF
        PUSH HL
        JR   NC, .E140
        LD   A, H
        LD   H, L
        LD   L, A
.E140:
        EX   (SP), HL
        EXX
        CALL PLOT_UNPLOT
        EX   AF, AF'
        JR   .E124

PLOT_UNPLOT:
        POP  HL              ; HL=return address, stack=YX coordinates
        EX   (SP), HL        ; HL=YX, stack=return address
        PUSH HL              ; stack=YX, return address
        LD   HL, .E18A       ; HL=end address for PLOT
        JR   Z, .E153        ; jump if PLOT
        LD   HL, .E187       ; HL=end address for UNPLOT
.E153:
        EX   (SP), HL        ; HL=YX, stack=address of continuation
        LD   A, H
        CP   $D0
        JR   C, .E15C        ; if Y < 208, then
        LD   A, $CF          ; if Y >= 208, Y=207
        LD   H, A            ; H=limited Y
.E15C:
        PUSH HL              ; YX onto stack
        CPL
        SUB  $30
        LD   H, A
        LD   A, L
        AND  $7
        LD   B, $3
.E166:
        SRL  H
        RR   L
        DJNZ .E166
        EX   (SP), HL        ; HL=YX, stack=sequence number of the byte for the dot
        PUSH HL              ; stack=YX
        LD   H, B            ; H=0
        LD   L, A            ; HL=Points bit sequence number
        LD   BC, BitMaskTable ; BC=Points bit mask table start address
        ADD  HL, BC
        LD   A, (HL)         ; A=mask for a points bit
        LD   HL, (RAMTOP)
        LD   BC, $0014
        ADD  HL, BC          ; HL = RAMTOP + 20
        POP  BC              ; BC = YX
        LD   (HL), C         ; New latest X
        INC  HL
        LD   (HL), B         ; New latest Y
        POP  BC              ; BC=sequence number of the byte in which a dot is
        ADD  HL, BC
        LD   BC, $000B       ; BC=offset from RAMTOP+20 to the beginning of the picture
        ADD  HL, BC          ; HL=address of the byte where a dot is
        RET                  ; continue from PLOT/UNPLOT address from stack
.E187:
        CPL                  ; UNPLOT - dot turn-off
        OR   (HL)
        DB $06               ; dummy LD B, for UNPLOT
.E18A:
        AND  (HL)            ; PLOT - dot turn-on
        LD   (HL), A
        RET

BitMaskTable:
        DB $FE               ; bit 0
        DB $FD               ; bit 1
        DB $FB               ; bit 2
        DB $F7               ; bit 3
        DB $EF               ; bit 4
        DB $DF               ; bit 5
        DB $BF               ; bit 6
        DB $7F               ; bit 7

VideoLink:
        CALL E4BB
        POP  HL              ; HL=$09B9 (remove link return address)
        POP  BC              ; BC=AF from stack
        POP  DE              ; DE=$0026 (return address in RST 20)
        POP  HL              ; HL=return address from RST 20 (caller's address)
        LD   A, L
        CP   $A5             ; is it called from the EDIT command? ($02A5 - EDIT)
        JR   NZ, .NotEdit    ; if not, continue
        EXX                  ; if so, EDIT is not executed
        JP   $0066           ; jump to basic reset (HARD-BREAK)
.NotEdit:
        CP   $C1             ; was it called from the old INPUT command? ($07C1 - GETSTR)
        JP   Z, E26A         ; if old INPUT, jump to new INPUT command
        PUSH HL
        PUSH BC
        CALL E4CC            ; HL=RAMTOP+16
        INC  HL
        INC  HL              ; HL=RAMTOP+18 (arrow execution indicator)
        CP   $B1             ; is it called from a NEW INPUT statement? ($E2B1)
        JR   Z, .E1D5        ; if so, jump to print character
        CP   CR              ; is it called from ......... ? ($E30D)
        JR   Z, .E1D5        ; if yes, jump jump to print character
        LD   A,B             ; A=character to be printed
        CP   $20             ; is the character an old control code (0-31)?
        JR   C, .E1F6        ; if so, jump to control code processing
        CP   $DF             ; is the character a new control code (219-222, arrows)?
        JR   NC, .E1CE       ; if not, check again for quotation mark (")
        CP   $DB             ; Is the sign of any arrow?
        JR   C, .E1CE        ; if not, check again for quotation mark (")
        LD   B, (HL)         ; B=arrow execution indicator
        INC  B               ; Should print arrows? (B=255)
        JR   Z, .E1D6        ; if yes, jump to print character
        AND  $3F             ; if executed, A=old arrow code (27-30)
        JR   .E236           ; jump to cursor move
.E1CE:
        CP   '"'             ; is the character a quotation mark (")?
        JR   NZ, .E1D6       ; if not, jump to print character
        LD   A, (HL)         ; if so, arrow execution indicator...
        CPL                  ; ...changes from 255 to 0 or vice versa
        LD   (HL), A         ; write the new state of the indicator
.E1D5:
        LD   A, B            ; A=character to be printed
.E1D6:
        LD   HL, (CURSORPOS)
        LD   (HL), A         ; print character on text screen
        PUSH HL              ; store cursor address on stack
        CALL E484            ; BC=XY cursor coordinate text
        CALL CheckGraph      ; character is drawn on the graphics screen if GRAPH mode is enabled (TEXTHORPOS ($2BA8) equal to 255)
        INC  B               ; B=X+1, (new cursor coordinate to the right of the written character)
        CALL E4CA            ; HL=RAMTOP+Y (screen editor variable for the line where the cursor is)
        LD   A, (HL)         ; A=length of the line where the cursor is
        CP   B               ; Is the new position of the cursor at the end of the line?
        JR   C, .E1EA        ; if at right side of the end of the line, skip next instruction
        LD   B,A             ; if it is at the end of the line (or to the left of the end)
.E1EA:
        LD   (HL), B
        POP  HL
        INC  HL
        CALL E4FC
.E1F0:
        POP  AF              ; A = character to be printed
        CALL $106F
        EXX
        RET
.E1F6:
        CP   CR
        JR   NZ, .E1FF
        CALL E4E5
        JR   .E1F0
.E1FF:
        CP   $0C
        JR   NZ, .E22E
        LD   HL, .E20A       ; ROM-A routine return address
        PUSH HL              ; Return address on stack
        CALL $0A1A           ; Clear TEXT screen
.E20A:
        LD   HL, (RAMTOP)
        LD   B, $10
.E20F:
        LD   (HL), $0
        INC  HL
        DJNZ .E20F
        INC  HL
        INC  HL              ; HL=RAMTOP+18 (Arrow execution indicator)
        LD   (HL), $0
        LD   A, (TEXTHORPOS)
        INC  A               ; Graphic screen is active?
        JR   NZ, .E1F0       ; If not, continue to ROM-B
        LD   DE, $000E
        ADD  HL, DE          ; HL=graphic memory base address
        LD   BC, $1A00       ; Clear graphic screen
        LD   D,H             ; (BUG - BC=&19FF does not clear a byte outside the screen !!)
        LD   E,L
        INC  DE
        LD   (HL), $FF       ; (BUG - LD (HL),C is first screen byte, therefore BC is less for 1)
        LDIR
        JR   .E1F0           ; Continue to ROM-B
.E22E:
        LD   B, (HL)         ; B=arrow execution indicator (RAMTOP+18 from &E1B0))
        INC  B               ; Do arrows print?
        JR   NZ, .E236       ; If not, jump to move cursor
        OR   $C0             ; A=new arrow code (1B...1E -> DB...DE)
        JR   .E1D6           ; Jump to arrow print
.E236:                       ; (BUG - code 31 is 16 places to right side, because not checking !!!)
        CP   $1B             ; Move - is it code for UP?
        JR   C, .E1F0        ; If less (already done), continue to ROM-B
        JR   NZ, .E23F       ; If more, jump to the next
        LD   DE, -32         ; DE=-32 if UP
.E23F:
        CP   $1C             ; If code is for DOWN?
        JR   NZ, .E246       ; If not, jump to next
        LD   DE, 32          ; DE=32 if DOWN
.E246:
        CP   $1D             ; Is it code for LEFT?
        JR   NZ, .E24D       ; If not, jump to next
        LD   DE, $FFFF       ; DE=-1 if LEFT
.E24D:
        CP   $1E             ; Is it code for RIGHT?
        JR   NZ, .E254       ; If not (???) jump
        LD   DE, $0001       ; DE=1 if RIGHT
.E254:
        LD   HL, (CURSORPOS) ; HL=cursor address
        ADD  HL, DE          ; HL=new cursor address
        LD   A, H
        CP   $2A             ; Does cursor went down of the screen?
        JR   C, .E25F        ; If not, check next
        LD   H, $28          ; HL=first screen row if went down of the screen
.E25F:
        CP   $28             ; Does cursor went up of the screen top?
        JR   NC, .E265       ; If not, jump to end
        LD   H, $29          ; HL=last screen row if went up of the screen top
.E265:
        LD   (CURSORPOS), HL ; Save new cursor address
        JR   .E1F0           ; Continue to ROM-B

E26A:
        EXX                  ; save BC, $DE, HL - NEW INPUT COMMAND
        CALL E4CC            ; HL=RAMTOP+16 (cursor flicker), $DE=16
        SRL  E               ; DE=8
        ADD  HL, DE          ; HL=RAMTOP+24 (use screen editor - 2 bytes)
        LD   DE, (CURSORPOS) ; DE=address of screen cursor
        LD   (HL), E
        INC  HL
        LD   (HL), D         ; store cursor address in RAMTOP+24
.E278:
        CALL E4CC            ; HL=again RAMTOP+16
        LD   (HL), $1        ; set blink counter just before blink cursor
        CALL ReadKey         ; wait for keystroke
        CALL E4BB            ; turn off cursor blinking (AF is saved)
        LD   HL, (CURSORPOS) ; HL=address of screen cursor
        PUSH AF              ; keep AF
        CALL E484            ; BC=XY cursor coordinate text
        POP  AF              ; A=ASCII at pressed key
        OR   A               ; is it 0 ? (PART)
        JR   Z, .E29A        ; if 0, process DELETE
        CP   CR              ; is it ENTER ?
        JP   Z, .E317        ; if so, process ENTER
        CP   $5F             ; is it "_" ? (SHIFT + 0)
        JR   Z, .E2D1        ; if yes, process INSERT
        RST  $20             ; if it's something else, print it
        JR   .E278           ; turn on the cursor again and wait for the next key
.E29A:
        PUSH HL              ; DELETE PROCESSING
        PUSH HL              ; cursor address 2x on stack
        CALL E4CA            ; HL=RAMTOP+Y coordinate (screen row for screen editor)
        LD   A, (HL)         ; A=number of characters in line (empty line = 0)
        SUB  B               ; A=A-position of the cursor (X coordinate)
        JR   Z, .E2A5        ; if cursor is at end of line, jump
        JR   NC, .E2A9       ; if the cursor is right at the end of the line, jump
.E2A5:
        POP  HL              ; no deletion (right !!)
        POP  HL              ; remove cursor addresses from stack 2x
        JR   .E278           ; turn on the cursor again and wait for the next key
.E2A9:
        OR   A
        JR   Z, .E2BA
        LD   B, A
        EX   (SP), HL
.E2AE:
        INC  HL
        LD   A, (HL)
        RST  $20
        DJNZ .E2AE
        EX   (SP), HL
        BIT  5, (HL)
        INC  HL
        LD   A, (HL)
        JR   NZ, .E2A9
.E2BA:
        DEC  HL
        EX   (SP), HL
        CALL E484
        XOR  A
        CP   B
        JR   NZ, .E2C5
        LD   B, $20
.E2C5:
        DEC  B
        POP  HL
        LD   A, $20
        RST  $20
        LD   (HL), B
        POP  HL
.E2CC:
        LD   (CURSORPOS), HL
        JR   .E278
.E2D1:
        PUSH HL
        CALL E4CA
        XOR  A
.E2D6:
        ADD  A, (HL)
        JR   NC, .E2E0
        POP  HL
        CALL E4F6
        JP   $0154           ; SORRY message
.E2E0:
        BIT  5, (HL)
        INC  HL
        JR   NZ, .E2D6
        SUB  B
        JR   Z, .E2EA
        JR   NC, .E2ED
.E2EA:
        POP  HL
        JR   .E278
.E2ED:
        DEC  HL
        INC  (HL)
        POP  HL
        LD   D, 0
        LD   E, A
        ADD  HL, DE
        LD   B, A
        LD   DE, $29FF
        RST  $10             ; CMP HL=DE
        JR   C, .E307
        PUSH BC
        PUSH HL
        CALL E388
        POP  HL
        LD   DE, $0020
        SBC  HL, DE
        POP  BC
.E307:
        LD   (CURSORPOS), HL
        DEC  HL
        LD   A, (HL)
        RST  $20
        DJNZ .E307
        LD   (CURSORPOS), HL
        LD   A, $20
        RST  $20
        JR   .E2CC
.E317:
        CALL E4CA
        XOR  A
.E31B:
        CP   C
        JR   Z, .E326
        DEC  C
        DEC  HL
        BIT  5, (HL)
        JR   NZ, .E31B
        INC  C
        INC  HL
.E326:
        PUSH HL
        LD   HL, $2800       ; VIDEO RAM
        JR   Z, .E333
        LD   DE, $0020
        LD   B, C
.E330:
        ADD  HL, DE
        DJNZ .E330
.E333:
        EX   (SP), HL
        POP  BC
        PUSH BC
        PUSH BC
        LD   B, 0
.E339:
        LD   C, (HL)
        EX   (SP), HL
        ADD  HL, BC
        EX   (SP), HL
        INC  HL
        BIT  5, C
        JR   NZ, .E339
        CALL E4CC
        INC  HL
        INC  HL
        INC  (HL)
        JR   Z, .E34B
        DEC  (HL)
.E34B:
        LD   E, 6
        ADD  HL, DE
        LD   E, (HL)
        INC  HL
        LD   D, (HL)
        POP  BC
        POP  HL
        RST  $10
        JR   NC, .E35D
        PUSH HL
        LD   H, B
        LD   L, C
        RST  $10
        POP  HL
        JR   NC, .E35E
.E35D:
        EX   DE, HL
.E35E:
        LD   H, B
        LD   L, C
        AND  A
        SBC  HL, DE
        PUSH DE
        LD   DE, $007D
        RST  $10
        JR   C, .E374
        LD   (CURSORPOS), BC
        CALL E4E5
        JP   $0154           ; SORRY message
.E374:
        LD   B, H
        LD   C, L
        POP  HL
        LD   DE, INPUTBUFFER
        INC  BC
        LDIR
        DEC  DE
        LD   A, CR
        LD   (DE), A
        INC  DE
        PUSH DE
        CALL E4F6
        POP  DE
        RET

E388:
        LD   DE, (SCREENSTART) ; DE = Number of HOME protected bytes (default=0)
        LD   HL, $01E0       ; HL = total number of characters to scroll up
.E38F:
        LD   A, E
        AND  $1F
        INC  DE
        JR   NZ, .E38F       ; DE is rounded up if row not complete
        DEC  DE
        SBC  HL, DE          ; HL=number of characters to scroll
        JR   Z, .E3DF
        JR   C, .E3DF        ; Do not scroll if all rows are protected (HL<=0)
        LD   B, H
        LD   C, L            ; BC=number of characters to scroll
        SET  3, D
        SET  5, D            ; DE=first unprotected row address (scroll from here)
        PUSH HL
        PUSH DE
        LD   HL, $0020
        ADD  HL, DE          ; HL=second unprotected row address (first to scroll up)
        LDIR                 ; Scroll unprotected rows on row up
        POP  HL              ; HL=first unprotected row address
        CALL E484            ; BC=XY character coordinates for first unprotected row
        CALL E4CA            ; HL=RAMTOP+Y
        LD   A, C            ; A=Y (LD A,&0F; SUB C, see below)
.E3B2:
        INC  HL              ; (scroll value for screen editor system variable)
        LD   B, (HL)
        DEC  HL
        LD   (HL), B
        INC  HL
        INC  A
        CP   $0F
        JR   C, .E3B2
        LD   A, (TEXTHORPOS) ; A=video mode (255=GRAPH)
        INC  A
        JR   NZ, .E3DE       ; If mode is TEXT, jump
        CALL E4CC            ; If it is GRAPH, HL=RAMTOP+16 (DE=16)
        ADD  HL, DE          ; HL==RAMTOP+32 (graphic screen start)
        PUSH HL
        CALL E58D
        POP  BC
        ADD  HL, BC
        PUSH HL
        ADD  HL, DE
        POP  DE
        EX   (SP), HL
        PUSH DE
        CALL E484
        CALL E58D
        POP  DE
        LD   B, H
        LD   C, L
        POP  HL
        LDIR
        DB $3E                ; Dummy LD A, skip next instruction
.E3DE:
        POP HL
.E3DF:
        LD   HL, $29E0
        PUSH HL
        CALL E484
        CALL E4D5
        CALL E4CC
        DEC  HL
        LD   (HL) ,A
        LD   E, $9
        ADD  HL, DE
        LD   A, (HL)
        SUB  $20
        LD   (HL), A
        JR   NC, .E3F9
        INC  HL
        DEC  (HL)
.E3F9:
        POP  HL
        RET

VideoDriver:
        PUSH AF              ; 11
        PUSH BC              ; 11
        PUSH DE              ; 11
        PUSH HL              ; 11
        EXX                  ; 4 alternate registers
        PUSH BC              ; 11
        PUSH DE              ; 11
        PUSH HL              ; 11
        LD   BC, $207F       ; 10 BC'=latch address (B'=line length, C'=$7F)
        LD   HL, (RAMTOP)    ; 16 HL'=RAMTOP
        LD   DE, $001A       ; 10 DE'=26
        ADD  HL, DE          ; 11 HL'=RAMTOP+26
        LD   D, (HL)         ; 7
        INC  HL              ; 6 HL'=RAMTOP+27
        LD   E, (HL)         ; 7 DE'=address ?
        INC  HL              ; 6 HL'=RAMTOP+28
        PUSH HL              ; 11 HL' onto stack
        LD   H, (HL)         ; 7 H'=number of visible image lines
        LD   L, $3E          ; 7 L'=$3E
        EXX                  ; 4 Main registers
        POP  HL              ; 10 HL=RAMTOP+28 from stack
        PUSH IX              ; 15 saves IX
        LD   IX, .Lines      ; 14 IX=main loop address
        INC  HL              ; 6 HL=RAMTOP+29
        LD   D, (HL)         ; 7 D=bit7 screen address (A7 bit) and latch bit1 (HIRES/LORES)
        INC  HL              ; 6 HL=RAMTOP+30
        LD   A, 9            ; 7 bit3+bit0=1
        SRL  A               ; 8 Cf=1 + bit2=1 (A=4)
        JR   C, .E426        ; 12 breaks
.E426:
        SRL  A               ; 8 Cf=0 + bit1=1 (A=2)
        LD   B, A            ; 4 B=2
.E429:
        JR   C, .E42B        ; 7 breaks
.E42B:
        DJNZ .E429           ; 13+7+13+7+8 break
        LD   B, (HL)         ; 7 B=(RAMTOP+30) for R, screen lower byte less 5 and without bit7
        INC  HL              ; 6 HL=RAMTOP+31
        LD   C, (HL)         ; 7 C=(RAMTOP+31) higher byte hires image
        LD   L, $BC          ; 7 HL=xxBC
.Lines:                      ; Line drawing main loop
        LD   A, B            ; 4 A=B
        LD   ($207F), HL     ; 16 $207F=L, $2080=H
        JP   Z, .End         ; 10 if Zf=0 end (from DEC H', number of lines)
        LD   R, A            ; 9 R=B
        LD   A, C            ; 4
        LD   I, A            ; 9 I=C
        LD   ($207E), DE     ; 20 $207E=E, $207F=D
        LD   A, B
        EXX                  ; Alternate registers
        ADD  A, B
        AND  C
        EXX                  ; Main registers
        LD   B, A
        NOP
        NOP
        XOR  A
        EXX                  ; Alternate registers
        RRC  D
        RLA
        EXX                  ; Main registers
        ADD  A, C
        LD   C, A
        NOP
        XOR  A
        EXX                  ; Alternate registers
        RRC  E
        RRA
        OR   L
        EXX                  ; Main registers
        LD   D, A
        EXX                  ; Alternate registers
        DEC  H
        EXX                  ; Main registers
        JP   (IX)
.End:                        ; End of picture
        POP  IX
        EXX                  ; Restore alternate registers
        POP  HL
        POP  DE
        POP  BC
        EXX                  ; Main registers
        JP   $00C0           ; continuation of RTC routine in ROM A

E46A:
        RST  $8              ; take first parameter
        PUSH HL              ; first parameter on stack (X)
        CALL $0005           ; get second parameter (Y)
        LD   B, L            ; B=Y
        POP  HL
        LD   C, L            ; C=X
        POP  HL              ; HL=return address
        POP  AF              ; AF=PLOT/UNPLOT value and flag
        PUSH DE              ; BASIC_pointer to stack
        PUSH AF              ; PLOT/UNPLOT value and flag on stack
        PUSH HL              ; address of return to the stack
        CALL E4CC            ; HL=RAMTOP+16
        INC  HL
        INC  HL
        INC  HL              ; HL=RAMTOP+19 (graphics indicator)
        LD   A, (HL)
        INC  A               ; Zf=1 - graphic screen reserved
        POP  HL              ; HL=return address
        JP   NZ, E0D2        ; Zf=0 - graphic screen is not reserved, return to basic
        JP   (HL)            ; continue PLOT/UNPLOT
E484:
        LD   A, $1F          ; from address on screen (HL) calculate coordinate text
        AND  L
        LD   B, A            ; B=X
        RRC  H
        LD   A, L
        RRA
        RRA
        RRA
        RRA
        RRA
        AND  $0F
        LD   C, A            ; C=Y
        RLC  H               ; HL is unchanged
        RET

InterruptLink:
        LD   A, $E0          ; Interrupt link
        LD   I, A            ; set high byte of interrupt vector
        CALL E4CC            ; HL=RAMTOP+16 (cursor blinking)
        LD   A, (HL)
        CP   $1              ; is it blinking ?
        JR   C, .E4A6        ; if not, jump
        DEC  (HL)            ; decrease counter to blink
        CALL Z, .E4A9        ; if counter is 0 change cursor state
.E4A6:
        JP   $00FD           ; end interrupt
.E4A9:
        LD   (HL), $14       ; blink counter reset (0.4s)
        INC  HL              ; HL=RAMTOP+17
E4AC:
        LD   B, (HL)         ; B=character code under cursor or cursor
        LD   DE, (CURSORPOS) ; DE=address of screen cursor
        LD   A, (DE)         ; A=at cursor or character
        LD   (HL), A         ; replace codes
        EX   DE,HL           ; HL=address of screen cursor
        LD   (HL), B
        CALL E484            ; BC=X,Y text coordinates from address (on 32x16)
        JP   CheckGraph      ; Jump to check GRAPH mode

E4BB:
        PUSH AF              ; Save character to print
        CALL E4CC            ; HL=system var. for cursor blinking (DE=&0010), RAMTOP+16
        LD   (HL), $0        ; Turn-off cursor blinking
        INC  HL              ; HL=system var. character or cursor code, RAMTOP+17
        LD   A, $BF          ; $BF is code for block cursor character
        CP   (HL)            ; Is cursor visible on the screen?
        CALL NZ, E4AC        ; If yes, replace it with character
        POP  AF              ; A=saved character for printing
        RET

E4CA:
        LD   E,C
        DB $21               ; Dummy LD HL, (will hide LD E,$10 from CALL $E4CA !)
E4CC:
        LD   E, $10
        LD   D, $0           ; DE=16
        LD   HL, (RAMTOP)
        ADD  HL, DE          ; HL=RAMTOP+16 (cursor blinking)
        RET
E4D5:
        LD   A, $20
        LD   (HL), A
        PUSH HL
        CALL CheckGraph
        INC  B
        POP  HL
        INC  HL
        LD   A, L
        AND  $1F
        JR   NZ, E4D5
        RET

E4E5:
        LD   HL, (CURSORPOS)
        CALL E484
        PUSH HL
        CALL E4CA
        LD   (HL), B
        POP  HL
        CALL E4D5
        JR   E4FC
E4F6:
        INC  HL
        LD   A, L
        AND  $1F
        JR   NZ, E4F6
E4FC:
        LD   A, H
        CP   $2A
        CALL NC, E388
        LD   (CURSORPOS), HL
        RET

CheckGraph:
        LD   A, (TEXTHORPOS) ; Is graphics mode active?
        INC  A
        RET  NZ              ; Return if not in graphics mode
        PUSH BC              ; Save X and Y text coordinates
        PUSH HL              ; Save text cursor address
        CALL E58D            ; HL = row offset
        LD   C, B
        LD   B, A            ; BC = X
        ADD  HL, BC          ; HL = Character offset
        EX   (SP), HL        ; HL=text cursor address, stack=graphic character offset
        LD   A, (HL)         ; A=character code from the text screen
        POP  HL              ; HL=graphic character offset from the stack
        LD   BC, $0020       ; (LD C,&20 because B is already zero!!)
        LD   DE, (RAMTOP)
        ADD  HL, DE
        ADD  HL, BC          ; HL=graphic character address
        CP   $5B             ; Is code lower then 91 (Č)?
        JR   C, E558         ; If yes, draw character without a caron
        CP   $5C             ; Is code 92 (Ć)?
        JR   C, E548         ; If less (91 - Č)... ???
        JR   Z, E548         ; ... or equal (92 -Ć), jump to change to "C"
        CP   $5E             ; Is code (Š)?
        JR   C, E54B         ; If less (93 - Ž), jump to change code to "Z"
        CP   $5F             ; Is code 95 ("_" - cursor)?
        JR   C, E545         ; If less (94 - Š), jump to change code to "S"
        CP   $BF             ; Is code 191 (block)?
        JR   NZ, E539        ; If not, jump
        LD   A, $5B          ; If it is 191, change it to 91 (graphic block)
        JR   E558            ; Jump to print the character
E539:
        CP   $DB             ; Is code 219?
        JR   C, E58B         ; If less (96-218 block graphic), jump to return (does not draw)
        CP   $DF             ; Is code 223?
        JR   NC, E58B        ; If equal or more then, jump to return (does not draw)
        SUB  $7F             ; A=graphic arrow codes (219...222=92...95)
        JR   E558            ; Jump to draw the character
E545:
        LD   A, $53          ; A="S"
        DB   $11             ; Dummy LD DE,
E548:
        LD   A, $43          ; A="C"
        DB   $11             ; Dummy LD DE,
E54B:
        LD   A, $5A          ; A="Z"
        LD   (HL), $D7       ; Draw 1/11 line for ČŠŽ (")
        JR   NZ, E553        ; If code is not 92 (Ć), jump
        LD   (HL), $DF       ; If it is Ć, 1/11 line is different (')
E553:
        ADD  HL, BC
        LD   (HL), $EF       ; Draw 2/11 line for all Serbian letters (')
        JR   E55D            ; Jump
E558:
        LD   (HL), $FF       ; Draw 1/11 line for all non-Serbian letters
        ADD  HL,BC
        LD   (HL), $FF       ; Draw 2/11 line for all non-Serbian letters
E55D:
        ADD  HL, BC          ; HL=character line 3/11 address
        SUB  $20             ; Is code 32 (blank - first in font) ? (SUB C - 1 byte/ 3T less)
        JR   C, E58B         ; If less, does not draw further (!?), return
        PUSH HL              ; Save line 3/11 address
        LD   E, $9
        RST  $28
        LD   H, A            ; H=code - 32
        LD   D, L            ; DE=9
        LD   A, $8           ; A=8
E56A:
        ADD  HL, HL          ; (multiply code by 9, nice but...
        JR   NC, E56E        ; ... binary multiplying is not necessary here!!!)
        ADD  HL, DE
E56E:
        DEC  A
        JR   NZ, E56A
        PUSH HL              ; Save character offset in the font on the stack
        LD   HL, (RAMTOP)
        LD   DE, $0016       ; DE=offset font system variable address
        ADD  HL, DE          ; (LD E,&16; CALL &E4CE - 2 byte less!)
        LD   E, (HL)
        INC  HL
        LD   D, (HL)         ; DE=font address (ROM or user defined)
        POP  HL              ; HL=character offset in the font
        ADD  HL, DE
        EX   DE, HL          ; DE=character address in the font
        POP  HL              ; HL=address in the graphic screen
        LD   A, $9           ; A=character byte counter
E582:
        EX   AF, AF'         ; Save the counter
        LD   A, (DE)         ; Copy byte from the font (line)...
        LD   (HL), A         ; ...to the graphic screen
        INC  DE              ; Next byte of the character
        ADD  HL, BC          ; Next graphic screen line
        EX   AF, AF'
        DEC  A               ; Decrement byte counter
        JR   NZ, E582        ; Repeat 9 times (BUGFIX: + JR Z,&E558 would solve "drawing below the text")
E58B:
        POP  BC
        RET

E58D:
        LD   DE, $01A0      ; DE=text line on graphics screen (13x32)
        RST  $28            ; HL=0
        LD   A, C           ; A=Y
        INC  A
E593:
        DEC  A
        RET  Z              ; Return if A=0
        ADD  HL, DE         ; (multiply DE by the ordinal number of the text line)
        JR   E593

CharDef: ; Character definition table. Zero bit value corresponds to white color and one translates to black pixels. Contains character codes from 32 to 95.
        DB   $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF ; BLANK
        DB   $EF, $EF, $EF, $EF, $EF, $EF, $EF, $FF, $EF ; EXCLAMATION
        DB   $93, $93, $B7, $DB, $FF, $FF, $FF, $FF, $FF ; QUOTE
        DB   $D7, $D7, $01, $D7, $D7, $D7, $01, $D7, $D7 ; HASH
        DB   $EF, $83, $ED, $ED, $83, $6F, $6F, $83, $EF ; DOLLAR
        DB   $FF, $B3, $B3, $DF, $EF, $F7, $9B, $9B, $FF ; PERCENT
        DB   $E3, $DD, $EB, $F7, $EB, $5D, $BD, $5D, $63 ; AND
        DB   $FE, $FC, $FA, $F6, $EF, $F6, $FA, $FC, $FE ; LOGO1
        DB   $DF, $EF, $F7, $F7, $F7, $F7, $F7, $EF, $DF ; OPEN PARENTHESIS
        DB   $F7, $EF, $DF, $DF, $DF, $DF, $DF, $EF, $F7 ; CLOSED PARENTHESIS
        DB   $FF, $EF, $AB, $C7, $01, $C7, $AB, $EF, $FF ; ASTERISK
        DB   $FF, $EF, $EF, $EF, $01, $EF, $EF, $EF, $FF ; PLUS
        DB   $FF, $FF, $FF, $FF, $FF, $E7, $E7, $EF, $F7 ; COMMA
        DB   $FF, $FF, $FF, $FF, $01, $FF, $FF, $FF, $FF ; MINUS
        DB   $FF, $FF, $FF, $FF, $FF, $FF, $FF, $E7, $E7 ; POINT
        DB   $7F, $7F, $BF, $DF, $EF, $F7, $FB, $FD, $FD ; /
        DB   $C7, $BB, $3D, $5D, $6D, $75, $79, $BB, $C7 ; 0
        DB   $EF, $E7, $EF, $EF, $EF, $EF, $EF, $EF, $C7 ; 1
        DB   $C7, $BB, $7D, $7F, $BF, $C7, $FB, $FD, $01 ; 2
        DB   $C7, $BB, $BF, $CF, $BF, $7F, $7D, $BB, $C7 ; 3
        DB   $BF, $DF, $EF, $F7, $BB, $BD, $01, $BF, $BF ; 4
        DB   $01, $FD, $C5, $B9, $7D, $7F, $7D, $BB, $C7 ; 5
        DB   $C7, $BB, $FD, $C5, $B9, $7D, $7D, $BB, $C7 ; 6
        DB   $01, $7D, $BF, $DF, $EF, $EF, $F7, $F7, $F7 ; 7
        DB   $C7, $BB, $BB, $C7, $BB, $7D, $7D, $BB, $C7 ; 8
        DB   $C7, $BB, $7D, $7D, $3B, $47, $7F, $BF, $C3 ; 9
        DB   $FF, $E7, $E7, $FF, $FF, $FF, $E7, $E7, $FF ; DOUBLE
        DB   $FF, $E7, $E7, $FF, $FF, $E7, $E7, $EF, $F7 ; SEMICOLON
        DB   $BF, $DF, $EF, $F7, $FB, $F7, $EF, $DF, $BF ; LESS
        DB   $FF, $FF, $FF, $01, $FF, $01, $FF, $FF, $FF ; EQUAL
        DB   $FB, $F7, $EF, $DF, $BF, $DF, $EF, $F7, $FB ; LARGER
        DB   $C7, $BB, $7D, $BF, $DF, $EF, $EF, $FF, $EF ; QUESTION
        DB   $DF, $EF, $F7, $03, $FF, $03, $F7, $EF, $DF ; LOGO2
        DB   $C7, $BB, $7D, $7D, $7D, $01, $7D, $7D, $7D ; A
        DB   $C1, $BD, $7D, $BD, $C1, $BD, $7D, $7D, $81 ; B
        DB   $C7, $BB, $7D, $FD, $FD, $FD, $7D, $BB, $C7 ; C
        DB   $C1, $BD, $7D, $7D, $7D, $7D, $7D, $BD, $C1 ; D
        DB   $01, $FD, $FD, $FD, $C1, $FD, $FD, $FD, $01 ; E
        DB   $01, $FD, $FD, $FD, $C1, $FD, $FD, $FD, $FD ; F
        DB   $87, $7B, $FD, $FD, $0D, $7D, $7D, $7B, $87 ; G
        DB   $7D, $7D, $7D, $7D, $01, $7D, $7D, $7D, $7D ; H
        DB   $C7, $EF, $EF, $EF, $EF, $EF, $EF, $EF, $C7 ; I
        DB   $01, $7F, $7F, $7F, $7F, $7F, $7D, $BB, $C7 ; J
        DB   $BD, $DD, $ED, $F5, $F9, $F5, $ED, $DD, $BD ; K
        DB   $FD, $FD, $FD, $FD, $FD, $FD, $FD, $FD, $01 ; L
        DB   $7D, $39, $55, $6D, $7D, $7D, $7D, $7D, $7D ; M
        DB   $7D, $7D, $79, $75, $6D, $5D, $3D, $7D, $7D ; N
        DB   $C7, $BB, $7D, $7D, $7D, $7D, $7D, $BB, $C7 ; O
        DB   $81, $7D, $7D, $7D, $81, $FD, $FD, $FD, $FD ; P
        DB   $C7, $BB, $7D, $7D, $7D, $7D, $5D, $BB, $47 ; Q
        DB   $81, $7D, $7D, $7D, $81, $ED, $DD, $BD, $7D ; R
        DB   $C3, $BD, $FD, $C3, $BF, $7F, $7D, $BB, $C7 ; S
        DB   $01, $EF, $EF, $EF, $EF, $EF, $EF, $EF, $EF ; T
        DB   $7D, $7D, $7D, $7D, $7D, $7D, $7D, $BB, $C7 ; U
        DB   $7D, $7D, $7D, $BB, $BB, $BB, $D7, $D7, $EF ; V
        DB   $7D, $7D, $7D, $6D, $6D, $6D, $6D, $55, $BB ; W
        DB   $7D, $7D, $BB, $D7, $EF, $D7, $BB, $7D, $7D ; X
        DB   $7D, $7D, $7D, $3B, $47, $7F, $7F, $BB, $C7 ; Y
        DB   $01, $7F, $BF, $DF, $EF, $F7, $FB, $FD, $01 ; Z
        DB   $01, $01, $01, $01, $01, $01, $01, $01, $01 ; CURSOR BLOCK
        DB   $00, $00, $10, $28, $44, $10, $10, $00, $00 ; ARROW UP
        DB   $00, $00, $10, $10, $44, $28, $10, $00, $00 ; DOWN ARROW
        DB   $00, $00, $10, $08, $64, $08, $10, $00, $00 ; LEFT ARROW
        DB   $00, $00, $10, $20, $4C, $20, $10, $00, $00 ; ARROW RIGHT

IntroScreen:
        DW $0C0C             ; Intro screen text
        DB "     *** GALAKSIJA PLUS ***"
        DW $DCDC             ; DC=down arrow - move to the next line
        DB 0

CmdLink:
        EX   (SP), HL        ; Store HL, HL=return address - command link
        PUSH DE              ; Basic pointer to stack
        LD   DE, CatchAllCmds ; Command recognition attempt
        RST  $10
        POP  DE              ; DE=basic pointer
        JR   Z, .Cmd2        ; Command is...
        LD   A, H
        CP   $20             ; below $2000?
        JR   C, .Cmd1        ; ROM-A/B command
        CP   $28             ; or above $2800?
        JR   NC, .Cmd1       ; User command
        AND  $7              ; or between $2000 and $2800 - ROM-C command
        RLCA                 ; Correct address higher byte...
        RLCA                 ; ...to the right value
        OR   $E0
        LD   H, A
.Cmd1:
        EX   (SP), HL        ; Return address to stack
        JP   $100F           ; Next round of recognition
.Cmd2:
        EX   (SP), HL
        LD   HL, CmdTable - 1
        JP   CmdRecognize    ; Recognize the command

CmdTable:
        DB "DRAW"
        DB $A0             ; $E0D8
        DB DRAW_CMD & $00ff
        DB "UNDRAW"
        DB $A0             ; $E0D5
        DB UNDRAW_CMD & $00ff
        DB "PLOT"
        DB $A0             ; $E0C6
        DB PLOT_CMD & $00ff
        DB "UNPLOT"
        DB $A0             ; $E0C3
        DB UNPLOT_CMD & $00ff
        DB "GRAPH"
        DB $A0             ; $E045
        DB GRAPH_CMD & $00ff
        DB "TEXT"
        DB $A0             ; $E0BA
        DB TEXT_CMD & $00ff
        DB "SOUND"
        DB $A0             ; $E0AE
        DB SOUND_CMD & $00ff
        DB "QSAVE"
        DB $A3             ; $EC18 -> $E930 via jump table
        DB QSAVE & $00ff
        DB "QLOAD"
        DB $A3             ; $EC1B
        DB QLOAD & $00ff
        DB "VERIFY"
        DB $A3             ; $EC1E
        DB VERIFY & $00ff
        DB "FAST"
        DB $A2             ; $E8BC
        DB FAST_CMD & $00ff
        DB "SLOW"
        DB $A2             ; $E8BF
        DB SLOW_CMD & $00ff
        DB "LINE"
        DB $A2             ; $E8C5
        DB LINE_CMD & $00ff
        DB "KILL"
        DB $A2             ; $E8D9
        DB KILL_CMD & $00ff
        DB "DESTROY"
        DB $A2             ; $E8F8
        DB DESTROY_CMD & $00ff
        DB "CLEAR"
        DB $A2             ; $E8DB
        DB CLEAR_CMD & $00ff
        DB "HLOAD"
        DB $A3             ; $EC21
        DB HLOAD & $00ff
        DB "HDUMP"
        DB $A3             ; $EC24
        DB HDUMP & $00ff
        DB "HLDUMP"
        DB $A3             ; $EC27
        DB HLDUMP & $00ff
        DB "AUTO"
        DB $A3             ; $EC2A
        DB AUTO & $00ff
        DB "UP"
        DB $A3             ; $EC30
        DB UP & $00ff
        DB "DOWN"
        DB $A3             ; $EC33
        DB DOWN & $00ff
        DB "FILL"
        DB $A3             ; $EC2D
        DB FILL & $00ff
        DB "R2"
        DB $A3             ; $EC36
        DB R2D2 & $00ff
        DB $10+$80         ; $100F (ROM-B)
        DB $0F

FAST_CMD:
        POP  AF              ; FAST command
        DI                   ; disable interrupt
        RST  $30             ; Go to the next BASIC statement.

SLOW_CMD:
        POP  AF              ; SLOW command
        EI                   ; enable interrupt
        RST  $30

ShowHowMsg:
        JP   ShowHowErr

LINE_CMD:
        POP  AF              ; LINE command
        RST  $8              ; read parameter
        LD   A, L
        CP   $D1             ; max. 208
        JR   NC, ShowHowMsg  ; if greater, error
        CP   $21             ; min. 33
        JR   C, ShowHowMsg   ; if less, error
        LD   HL, (RAMTOP)
        LD   BC, $001C
        ADD  HL, BC          ; HL=RAMTOP+28 (number of visible screen lines)
        LD   (HL), A         ; write the value
        RST  $30             ; resume basic

KILL_CMD:
        JR   E909            ; KILL command

CLEAR_CMD:
        POP  AF              ; CLEAR command
        PUSH DE              ; save basic pointer
        PUSH IX              ; save arithmetic stack pointer
        LD   B, $1A          ; 26 variables from A to Z
        LD   IX, $2A02
        LD   DE, $0004       ; length of variable in bytes
.E8E8:
        LD   (IX+1),  $40    ; characteristic is set...
        RES  $7, (IX)        ; ...-128, which represents the number 0
        ADD  IX, DE
        DJNZ .E8E8           ; clears all variables
        POP  IX              ; return arithm. stack pointer
        POP  DE              ; return basic pointer
        RST  $30             ; return to basic

DESTROY_CMD:
        POP  AF              ; DESTROY command
        RST  $8              ; read first parameter
        PUSH HL              ; store parameter on stack
        CALL $0005           ; read second parameter
        EX   DE, HL          ; DE=second parameter, HL=basic pointer
        EX   (SP), HL        ; HL=first parameter, basic stack pointer
        EX   DE, HL          ; HL=second parameter, DE=first parameter
.E901:
        XOR  A               ; A=0
        LD   (DE), A         ; delete byte
        INC  DE              ; next byte
        RST  $10             ; compare DE with HL
        JR   NC, .E901       ; continue if DE is not greater
        POP  DE              ; return basic pointer
        RST  $30             ; return to basic

E909:
        LD   A, (KBDBASEADDR + KEY_CR) ; continuation of KILL command ($2030 is RETURN key address)
        BIT  0, A            ; wait for key release...
        JR   Z, E909         ; ...RETURN
        LD   DE, .SureMsg    ; message address "SURE ?"
        CALL PrintString     ; print message
.E916:
        LD   HL, $2037       ; check all keys
.E919:
        BIT  0, (HL)
        JR   Z, .E922        ; if key pressed, check which one
        DEC  L
        JR   NZ, .E919
        JR   .E916           ; if none pressed, repeat all
.E922:
        LD   A, L
        CP   KEY_Y           ; if the key is not "Y"...
        JP   NZ, $0066       ; ...only HARD BREAK
        RST  $0              ; if key is "Y", RESET

.SureMsg:
        DB "SURE ?", 13

QSAVE_CMD:
        POP  AF              ; QSAVE command
        CALL InitSound       ; initialize AY-3-8910 ()
        RST  $18
        DB '"'               ; does quotation mark follow the command (ASCII code $22)?
        DB .E940-$-1         ; if not, error WHAT?
        LD   ($2B00), DE     ; record the address of the beginning of the name
        LD   B, $15          ; find the next quotation mark in the next 15 characters
.E93D:
        INC  DE
        DJNZ .E943
.E940:
        JP   ShowWhatErr     ; if there is no 2x" or the name is longer than 15. WHAT?
.E943:
        RST  $18
        DB '"'
        DB .E946-$-1         ; same continuation regardless of the result
.E946:
        JR NZ, .E93D         ; if not "search further
        CALL EA9C            ; is it followed by ENTER or . ? (are there parameters?)
        JR   Z, .E982        ; if ENTER or ., no parameters. jump (it's basic)
        LD   HL, LineMsg     ; HL=text address "LINE"
        PUSH DE              ; save basic pointer (byte address after name)
        CALL EA6A            ; is the parameter LINE ?
        JR   Z, .E99A        ; if so, read the LINE number (autostart line number)
        LD   HL, CodeMsg     ; if not, HL=address of text "CODE"
        POP  DE              ; return basic pointer (byte address after the name)
        CALL EA6A            ; is the parameter CODE ?
        JR   NZ, .E940       ; if not, WHAT?
        RST  $28             ; Clear HL
        LD   ($2B02), HL     ; if CODE, LINE address is 0
.E963:
        RST  $8              ; get 1st parameter for CODE
        PUSH HL
        CALL $0005           ; get 2nd parameter for CODE
        PUSH HL
        RST  $18             ; any more parameters ?
        DB ','               ; (is the next character a comma?)
        DB .E96E-$-1         ; if not, skip taking the 3rd parameter
        RST  $8              ; if yes, take the 3rd parameter (relocation)
        DB $3E               ; Dummy LD A, if there is also a 3rd parameter
.E96E:
        RST  $28             ; HL=0 if there is no 3rd parameter
        LD   ($2B04), DE     ; save basic pointer
        LD   B, H            ; BC=3. parameter (reloc, $0 or value)
        LD   C, L
        POP  HL              ; HL=2. parameter (end)
        LD   ($2B08), HL
        ADD  HL, BC          ; HL=relocated end
        EX   DE, HL          ; DE=relocated end
        POP  HL              ; HL=1. parameter (start)
        LD   ($2B06), HL
        ADD  HL, BC          ; HL=relocated start
        JR   .E9A6           ; record leader and header at 300bps
.E982:
        RST  $28             ; Clear HL
        LD   ($2B02), HL     ; LINE number for basic
.E986:
        LD   HL, BASICSTART  ; HL=start of data block
        LD   ($2B04), DE     ; save basic pointer
        LD   DE, (BASICEND)  ; DE=end of data block
        LD   ($2B06), HL
        LD   ($2B08), DE
        JR   .E9A6           ; record leader and header at 300bps
.E99A:
        POP  AF
        RST  $8              ; get LINE parameter (basic line number for autostart)
        LD   ($2B02), HL     ; remember it
        RST  $18             ; any more parameters?
        DB ','               ; (is there a comma?)
        DB .E9A4-$-1         ; if not, just basic
        JR   .E963           ; if yes, take other parameters (start, end, [relocate])
.E9A4:
        JR   .E986           ; set header for "basic only"
.E9A6:
        DI                   ; deny interrupts - QSAVE 300bps header
        LD   B, $64          ; counter leader bytes
.E9A9:
        XOR  A               ; leader bytes are zero
        CALL TapeSaveByte    ; Save leader byte
        DJNZ .E9A9           ; ...all 100
        LD   A, $A5          ; header ID (and base for CRC in B register)
        CALL TapeSaveByte    ; Save header ID byte
        LD   A, $FF          ; indicator byte ??
        CALL TapeSaveByte    ; Save indicator
        CALL TapeSaveWord    ; Save HL
        EX   DE, HL
        CALL TapeSaveWord    ; Save DE (better to call TapeSaveExWord here and spare previous EX DE,HL instruction)
        LD   HL, ($2B02)
        CALL TapeSaveWord    ; Save LINE number (autostart line)
        LD   DE, ($2B00)     ; DE=beginning of name (first letter after the first ")
.E9CA:
        LD   A, (DE)
        CP   '"'             ; is the character "
        JR   NZ, .E9D1       ; if not, record it
        JR   .E9D7           ; if " , jump
.E9D1:
        CALL TapeSaveByte    ; write name letter
        INC  DE              ; next letter
        JR   .E9CA           ; check this sign too
.E9D7:
        LD   A, $FF          ; indicator byte ??
        CALL TapeSaveByte    ; save indicator byte
        LD   A, B            ; A=CRC of bytes recorded so far
        CPL                  ; complement CRC byte
        CALL TapeSaveByte    ; Save CRC byte

        LD   B, $0F          ; pause ~4 seconds
.E9E3:
        LD   HL, $8000
.E9E6:
        DEC  HL
        BIT  7, H
        JR   Z, .E9E6
        DJNZ .E9E3
.E9ED:
        XOR  A               ; leader byte 0
        CALL EBE5            ; Save TURBO leader byte...
        DJNZ .E9ED           ; ...256 times (initial B is 0 !)
        LD   A, $A5          ; header ID
        CALL EBE5            ; Save TURBO header ID
        XOR  A               ; indicator 0 ??
        CALL EBE5            ; Save TURBO indicator
        LD   HL, ($2B06)     ; HL=start of data block
        LD   DE, ($2B08)     ; DE=end of data block
        INC  DE              ; DE=end of data block +1 (for RST $10)
.EA04:
        LD   A, (HL)         ; read data byte
        INC  HL              ; next address
        CALL EBE5            ; Save TURBO data byte
        JR   C, .EA04        ; write all bytes to end
        LD   A, B
        CPL                  ; complement CRC
        CALL EBE5            ; record TURBO CRC BYTE (not WORD)
        LD   DE, ($2B04)     ; restore basic pointer
        EI                   ; enable interrupt
        CALL MuteSound       ; mute AY sound
        RST  $30             ; continue t0 basic
EA19:
        DB "SEARCHING", 13

EA23:
        LD   A, ($2000)      ; A=state of port for tape recorder (WAITING FOR IMPULSE)
        RRCA                 ; C=state of input port (bit 0)
        RET  NC              ; if Cf=0, pulse detected, return
        JR   EA23            ; if there is no impulse, wait for it further
EA2A:
        DB "FOUND ", 0
EA31:
        DB "LOADING", 13

InitSound:
        XOR  A               ; INITIALIZE AY SOUND
        OUT  ($0), A         ; R0
        OUT  ($1), A         ; channel A frequency (fine - 0)
        LD   A, $7
        OUT  ($0), A         ; R7
        LD   A, $FE
        OUT  ($1), A         ; tone on channel A only
        LD   A, $8
        OUT  ($0), A         ; R8
        LD   A, $0F
        OUT  ($1), A         ; volume on channel A is maximum (15)
        XOR  A
        OUT  ($0), A         ; R0 prepared for further writing
        RET                  ; return with A=0

MuteSound:
        LD   A, $8
        OUT  ($0), A         ; Register number 8
        XOR  A
        OUT  ($1), A         ; volume on channel A = 0 (none)
        LD   A, $7
        OUT  ($0), A         ; Register number 7
        LD   A, $FF
        OUT  ($1), A         ; exclusion of all channels
        RET                  ; return with A = 255

LineMsg:
        DB "LINE"
CodeMsg:
        DB "CODE"

EA6A:
        LD   B, $4           ; RECOGNITION OF "LINE" AND "CODE" WORDS
        CALL SkipSpaces      ; skip blanks
.EA6F:
        LD   A, (DE)         ; get byte from BASIC
        CP   (HL)            ; compare with given text
        INC  HL              ; increase pointer
        INC  DE
        RET  NZ              ; return with Zf=0 if they are not the same
        DJNZ .EA6F           ; if they are the same, check all 4 letters
        RET                  ; return with Zf=1 if the words are the same

QLOAD_CMD:
        POP  AF              ; Remove return address
        LD   ($2B00), DE     ; store basic pointer (address names)
        CALL InitSound       ; initialize AY sound (A=0 on return)
        INC  A               ; A=1 , Zf=0
        PUSH AF              ; $XX01 onto stack (1=LOAD mode, 0=VERIFY mode)
EA81:
        EI                   ; enable interrupts (exit FAST mode to see messages)
        LD   A, $FF
        PUSH AF              ; $XXFF onto stack (ie name not specified)
        RST  $18
        DB '"'               ; is the QLOAD command followed by a quotation mark ?
        DB EAA3-$-1          ; if not, jump to further checks
        EX   DE, HL          ; HL=address of the character after the first quotation mark (A=character of the first quotation mark)
        CP   (HL)            ; is the name given? (or just two quotes)
        EX   DE, HL          ; DE=basic pointer (points to second quote or first letter of name)
        JR   Z, EAAB         ; if there is no name, jump to check further parameters
        POP  AF              ; pop $XXFF off stack
        PUSH DE              ; start address of the name of the requested image on the stack
        XOR  A
        PUSH AF              ; $XX00 onto stack (means name is specified)
EA91:
        LD   B, $15          ; find another quote (from here QLOAD and VERIFY are the same)
EA93:
        INC  DE
        DJNZ .EA96
.EA96:
        RST  $18
        DB '"'
        DB EAA9-$-1          ; if it is not a quote, search further (to 15 places)
        DEC  DE              ; second quote found, jump compensation (why?)
        JR   EAAB            ; jump (why not JR $EAAC here without DEC DE ?)
EA9C:
        LD   A, (DE)         ; A=character text (basic) (Why is this pinched here ???)
        CP   CR              ; is it ENTER?
        RET  Z               ; if so, return with Zf=1
        CP   ':'             ; is it a colon?
        RET                  ; return with Zf=0 if none
EAA3:
        CALL EA9C            ; no quotes after QLOAD, is there . or ENTER ?
        RST  $28             ; HL=0
        JR   Z, EAB3         ; if any, jump
EAA9:
        JR   EA93            ; if there is no . or ENTER, search further for quotation marks (?)
EAAB:
        INC  DE              ; return the pointer to the end of the name
        RST  $28             ; HL=0 (RELOC parameter in case it is not specified)
        CALL EA9C            ; is the name followed by . or ENTER ?
        JR   Z, EAB3         ; if followed by . or ENTER, skip reading the RELOC parameter
        RST  $8              ; HL=RELOC parameter
EAB3:
        LD   ($2B04), DE     ; save basic pointer (address of continuation of basic)
        PUSH HL              ; RELOC parameter to stack
        LD   DE, EA19        ; message address "SEARCHING"
        CALL PrintString     ; print message + new line
        CALL EA23            ; wait for an impulse from the tape recorder
        DI                   ; pulse detected, turn off image
.EAC2:
        LD   B, $14          ; B=20 - WAITING FOR LEADER RECORD, at least 20 consecutive zeros)
.EAC4:
        PUSH BC              ; keep B counter on stack
        CALL TapeLoadByte    ; load byte from cassette (300bps)
        LD   A,C             ; A=loaded byte
        POP  BC              ; return B counter from stack
        OR   A               ; is byte 0 (leader) loaded
        JR   NZ, .EAC2       ; if not, reset the counter and wait for 20 leaders
        DJNZ .EAC4           ; detect 20 consecutive leader bytes
.EACF:
        CALL TapeLoadByte    ; load next byte from cassette - WAIT FOR HEADER ID
        LD   A, C
        CP   $A5             ; is byte header id ?
        JR   NZ, .EACF       ; if not, wait for it further
        LD   B, A            ; B=$A5 (CRC basis)
        CALL TapeLoadByte    ; load next BYTE
        LD   A, C
        INC  A               ; is byte $FF (TURBO header indicator) ?
        JR   NZ, .EB55       ; if not, jump (stack=RRRR[XX00XXXX]/[XXFFXX01] !!!)
        CALL TapeLoadWord    ; if yes, load start address (WORD)
        LD   H, C
        EX   DE, HL          ; DE=start address
        CALL TapeLoadWord    ; load end address (WORD)
        LD   H, C            ; HL=end address
        LD   A, B            ; A=CRC of loaded bytes (effectively only the last 5)
        POP  BC              ; BC=RELOC number from stack
        ADD  HL, BC
        EX   DE, HL          ; DE=relocated end address of load data
        ADD  HL, BC          ; HL=relocated start address of load data
        LD   B, A            ; B=CRC again
        LD   ($2B06), HL     ; remembers actual initial and...
        LD   ($2B08), DE     ; ...actual end address to load
        CALL TapeLoadWord    ; load AUTOSTART line number (WORD)
        LD   H,C
        LD   ($2B02), HL     ; remember AUTOSTART line number
        LD   DE, EA2A        ; message address "FOUND "
        PUSH BC              ; store CRC on stack (PRINTSTR dirty BC)
        CALL PrintString     ; print message "FOUND " (cursor remains in the same row)
        POP  BC              ; B=CRC from stack
        LD   HL, (CURSORPOS) ; HL=cursor address (beginning of the name found on the screen)
.EB07:
        CALL TapeLoadByte    ; load next byte (name letter)
        LD   A, C            ; A=letter of name
        INC  C               ; is byte $FF loaded (end of name)
        JR   Z, .EB11        ; if end of name jump to load CRC
        RST  $20             ; if letter, print to screen
        JR   .EB07           ; load and print all letters of image name (if any)
.EB11:
        CALL TapeLoadByte    ; load CRC BYTE header (B=calculated CRC + loaded CRC !)
        LD   A, CR
        RST  $20             ; goes to a new line on the screen
        INC  B               ; (CRC is recorded in complemented form)
        JP   NZ, ShowWhatErr ; if CRC + loaded byte is not $FF , WHAT? mistake
        LD   A, H            ; CRC OK, A=higher byte of cursor address (FIND SCREEN NAME)
        CP   $28             ; does the name start at the top of the screen?
        JR   Z, .EB28        ; if in top half of screen, jump to check name
        LD   A, L
        CP   $E6             ; does the name start on line 16?
        JR   NZ, .EB28       ; if not, jump (not in last row, $0D didn't move it)
        SUB  $20             ; if in line 16, address in line 15 of screen (due to $0D)
        LD   L, A            ; HL=address of screen name
.EB28:
        LD   A, '%'          ; A=character %
        CP   (HL)            ; does name start with % (???)
        JR   NZ, .EB44       ; if not, jump
        PUSH HL              ; if yes, store name address on stack (I don't understand this part !!!)
        OR   $30             ; A=$55 (character U)
        LD   ($2C34), SP     ; store stack pointer at end of input buffer
        LD   SP, CLOCKSTATE-1
        INC  SP              ; StackPointer=$2BAF (system variable for clock state)
        RST  $28             ; HL=0
        LD   H,A             ; HL=$5500
        PUSH HL              ; START_RTC=$55, VIDEO_LINK=$C39500 (CALL $0095 ????)
        LD   SP, ($2C34)     ; restore StackPointer
        POP  HL              ; HL=address of found name
        LD   A, $20
        LD   (HL), A         ; blank in place of the first letter (instead of % ?)
        INC  HL              ; HL=address of the second letter of the screen name
.EB44:
        POP  AF              ; A=name indicator from stack
        INC  A               ; if the name is not specified (indicator is $XXFF)...
        JR   Z, .EB62        ; ...jump
        POP  DE              ; otherwise, $DE=address of the name of the requested image
.EB49:
        LD   A, (DE)         ; A=letter of the name of the requested image
        CP   '"'             ; is there a quotation mark at the end of the name
        JR   Z, .EB62        ; if so, jump
        CP   (HL)            ; compare the letter of the searched and found name
        INC  HL              ; next letter found (screen)
        INC  DE              ; next letter requested (stack pointer)
        JR   Z, .EB49        ; if the letters are the same, compare further
        JR   .EB5B           ; if they are different, it is not that shot - jump
.EB55:
        POP  AF             ; THE VIDEO IS NOT A TURBO HEADER !! (remove YYYY address)
        POP  AF              ; pop 4 bytes off stack (remove XX00 or XXFF)
        INC  A               ; (stack was RRRRXX00NNNN OR XXFFXX01)
        JR   Z, .EB5B        ; if the last one is not $XXFF (but NNNN)...
        POP  AF              ; ...remove 2 more bytes (to leave only XX01)
.EB5B:
        LD   DE, ($2B00)     ; DE=saved basic pointer (pointer before the name)
        JP   EA81            ; find the name of the requested recording again (and why ???)
.EB62:
        POP  AF
        PUSH AF              ; A=load mode (1=LOAD, 0=VERIFY)
        JR   Z, .EB6C        ; if Zf=1, jump to pause (requested clip not found)
        LD   DE, EA31        ; if Zf=0, the requested recording is found, print...
        CALL PrintString     ; ...messages "LOADING"
.EB6C:
        EI                   ; enable interapt (to see messages)
        LD   B, $5           ; pause ~1.3 seconds
.EB6F:
        LD   HL, $8000
.EB72:
        DEC  HL
        BIT  7, H
        JR   Z, .EB72
        DJNZ .EB6F
        CALL EA23            ; wait for an impulse from the tape recorder
        DI                   ; disable interapt (and image)
        LD   DE, ($2B06)     ; DE=load start address
        LD   HL, ($2B08)     ; HL=loading end address
.EB84:
        LD   B, $14          ; B=20 (WAITING FOR LEADER TURBO RECORD, at least 20 zeros in a row)
.EB86:
        PUSH BC              ; keep counter
        CALL EC3C            ; load TURBO byte in C (and change AY sound, $A on return $7A/$B7)
        LD   A, C            ; A=loaded byte
        POP  BC              ; return counter
        OR   A               ; is byte 0?
        JR   NZ, .EB84       ; if not 0, reset counter and look for leader next
        DJNZ .EB86           ; if zero, load all 20
.EB91:
        CALL EC3C            ; load next byte into C
        LD   A, C
        CP   $A5             ; is byte header ID loaded?
        JR   NZ, .EB91       ; if not, load next byte
        LD   B, A            ; if so, B=$A5 - basis for CRC
        CALL EC3C            ; load next byte into C
        LD   A, C
        OR   A
        JR   NZ, .EBCC       ; if header ID does not follow byte 0, report WHAT?
.EBA1:
        EX   DE, HL          ; HL=start address, DE=end
        CALL EC3C            ; Load data byte into C
        EX   AF, AF'         ; keep flag C (from comparing HL with DE)
        LD   A, C            ; A=loaded byte
        CP   (HL)            ; compare loaded byte with byte in memory (VERIFY ?)
        JR   Z, .EBAF        ; if same, continue loading
        POP  AF              ; if not, A=load mode from stack
        JR   Z, .EBCC        ; if VERIFY ($00), report WHAT?
        PUSH AF              ; if LOAD ($01), return A to stack
        LD   (HL), C         ; write loaded byte into memory
.EBAF:
        INC  HL              ; mext memory address
        EX   DE, HL          ; DE=start address, HL=end
        EX   AF, AF'         ; are all data bytes loaded?
        JR   C, .EBA1        ; if not yet, continue loading
        CALL EC3C            ; load TURBO CRC byte
        POP  AF              ; A=remove load mode from stack
        INC  B               ; is the loaded CRC equal to the calculated one?
        JR   NZ, .EBCC       ; if not, state WHAT?
        EI                   ; enable interapt (include image)
        CALL MuteSound       ; turn of sound
        LD   DE, ($2B04)     ; restore DE (basic pointer)
        LD   HL, ($2B02)     ; HL=AUTOSTART line number
        LD   A, H
        OR   L               ; if line number is not 0...
        JP   NZ, $040E       ; ...RUN of loaded BASIC from line from HL
        RST  $30             ; if 0, return to basic
.EBCC:
        JP   ShowWhatErr     ; jump to print message "WHAT?" (vector)

VERIFY_CMD:
        POP  AF              ; Remove return address - TURBO VERIFY command
        LD   ($2B00), DE     ; remember basic pointer (address before name - quotes)
        CALL InitSound       ; initialize AY sound
        XOR  A               ; A=$00 - loading mode (VERIFY - XX00)
        PUSH AF              ; stack load mode
        RST  $18
        DB '"'               ; is the command followed by a quotation mark ?
        DB .EBE2-$-1         ; if not, report WHAT?
        PUSH DE              ; address of name on stack (NNNN)
        XOR  A
        PUSH AF              ; name indicator on stack (XX00)
        JP   EA91            ; continue as that QLOAD is a command
.EBE2:
        JP   ShowWhatErr     ; jump to print message "WHAT?" (vector)

EBE5:
        EXX                  ; TURBO BYTE RECORDING FROM A (with AY sound and patterns?)
        LD   HL, $2038       ; HL=cassette recorder output port
        LD   C, $8
.EBEB:
        RRCA
        LD   (HL), $FC
        LD   B, $1E
        JR   C, .EBF4
        LD   B, $64
.EBF4:
        DJNZ .EBF4
        LD   (HL), $B8
        LD   B, $1E
        JR   C, .EBFE
        LD   B, $64
.EBFE:
        DJNZ .EBFE
        LD   (HL), $BC
        DEC  C
        JR   NZ, .EBEB
        LD   B, 0
.EC07:
        DJNZ .EC07
        EXX
EC0A:
        ADD  A, B            ; add byte to CRC - COMMON CRC AND AY SOUND FOR QLOAD AND QSAVE
        LD   B, A            ; B=CRC
        LD   A, $7A          ; A=value for even CRC is 784Hz
        BIT  0, B            ; basis for AY sound is CRC parity (bit 0)
        JR   Z, .EC14        ; if even, sound is 784Hz
        LD   A, $B7          ; A=value for odd CRC is 523Hz
.EC14:
        OUT  ($1), A         ; write in R0 AY chip (fine frequency in Hz)
        RST  $10
        RET

; Next jump table is intentionally placed in address region of $ECxx,
; so that these commands can be found with value $A3 as higher command address byte in CmdTable
QSAVE:  JP   QSAVE_CMD       ; $E930 QSAVE
QLOAD:  JP   QLOAD_CMD       ; $EA77 QLOAD
VERIFY: JP   VERIFY_CMD      ; $EBCF VERIFY
HLOAD:  JP   HLOAD_CMD       ; $EEF4 HLOAD
HDUMP:  JP   HDUMP_CMD       ; $EEC0 HDUMP
HLDUMP: JP   HLDUMP_CMD      ; $EEBD HLDUMP
AUTO:   JP   AUTO_CMD        ; $ECF4 AUTO
FILL:   JP   FILL_CMD        ; $EE02 FILL
UP:     JP   UP_CMD          ; $EF93 UP
DOWN:   JP   DOWN_CMD        ; $EFC8 DOWN
R2D2:   CALL R2_CMD          ; $ECB5 hidden command "R2"
        JP   $0066           ; HARD-BREAK ("farm" - BASIC reset)

EC3C:
        EXX                  ; TURBO load byte into A
        LD   HL, $2000
.EC40:
        LD   B, $55
.EC42:
        BIT  0, (HL)
        JR   Z, .EC4C
        DJNZ .EC42
        EXX
        LD   A, C
        JR   EC0A            ; byte loaded into A, jump to CRC and AY sound
.EC4C:
        LD   A, $E4
.EC4E:
        INC  A
        BIT  0, (HL)
        JR   Z, .EC4E
        RLA
        EXX
        RR   C
        EXX
        JR   .EC40
EC5A:
        CP   H
        JR   NZ, .EC5F
        LD   H, 0
.EC5F:
        CP   L
        JR   NZ, EC64
        LD   L, 0
EC64:
        DEC  E
        JR   NZ, EC72        ; key not pressed, check next
        JR   EC6F            ; no key pressed, repeat the whole check
EC69:
        EXX                  ; REPLACE FOR "KEY_0" IN SCREEN EDITOR
        LD   HL, (KBDDIFF)   ; HL=sis. var. keyboard differentiator
        LD   C, $0E          ; C=14, number of keys to check (from "STOP/LIST" to "7")
EC6F:
        LD   DE, KBDBASEADDR + KEY_LIST ; DE=address of STOP/LIST key
EC72:
        LD   A, (DE)         ; A=key state
        RRCA                 ; Cf=key state
        LD   A, E            ; A=key number (address)
        JR   C, EC5A         ; if the key is not pressed, check if it has been pressed before
        CP   KEY_RPT         ; Is it REPT key?
        JR   NZ, .EC84       ; if not, jump
        DEC  C               ; next key
        JR   NZ, EC5A        ; if it's not the last one, check if it's already pressed before
        LD   A, (REPEATKEY)  ; A=REPT status (contents of system register for REPT)
.EC81:
        JP   $0D54           ; end in ROM-A (to shorten the code by 2 bytes!)
.EC84:
        CP   H
        JR   Z, EC64
        CP   L
        JR   Z, EC64
        LD   B, 0            ; B=0 (counter 256) - DELAY FOR REPT (repetition rate)
.EC8C:
        RST  $10             ; pause
        LD   A, (DE)
        RRCA                 ; is the key still pressed
        JR   C, EC5A         ; if not, continue with other keys
        DJNZ .EC8C           ; if pressed, do pause
        LD   A, H
        OR   A
        JR   NZ, .EC9A
        LD   H, E
        JR   .EC9F
.EC9A:
        LD   A, L
        OR   A
        JR   NZ, EC72
        LD   L,E
.EC9F:
        LD   (KBDDIFF), HL
        RST  $28
        LD   A, E
        CP   $34
        JR   NZ, .ECAC
        LD   A, $2
        JR   .EC81
.ECAC:
        CP   $31
        JP   NZ, $0D39
        LD   A, $1
        JR   .EC81
R2_CMD:
        LD   A, FF           ; HIDDEN COMMAND "R2" TO RETURN TO MINUS MODE
        RST  $20             ; clear the screen
        IM   1               ; interapt mode 1
        EXX
        CALL $1023           ; arrange links in ROM-B for ROM-A+B
        EXX
        RET                  ; go back, and jump to the FARM !!!
ECC0:
        LD   L, C            ; L=X
        PUSH BC              ; Save YX
        LD   A, B            ; A=Y
        CPL
        SUB  $30
        LD   H, A            ; H=Y turnaround
        LD   A, L
        AND  $7              ; A=X % 8, dot position in byte backword
        LD   B, $3
.ECCC:
        SRL  H
        RR   L
        DJNZ .ECCC           ; HL=HL/8, dot byte index
        PUSH HL              ; Save index
        LD   H, B
        LD   L, A
        LD   BC, BitMaskTable ; BC=mask table address
        ADD  HL, BC          ; mask address for dot position
        LD   A, (HL)         ; A=dot mask, turnaround and inverted
        LD   HL, (RAMTOP)
        LD   BC, $0020
        ADD  HL, BC          ; HL=graphic memory address
        POP  BC
        ADD  HL,BC           ; HL=dot address
        POP  BC              ; BC=saved YX from the stack
        RET

ECE5: ; These 15 bytes are probably remnants of an old FILL command implementation, because it is not called from anywhere - neither directly nor via the stack.
        PUSH HL
        CALL ECC0
        AND  (HL)
        LD   (HL), A
        POP  HL
        RET
        PUSH HL
        CALL ECC0
        AND  (HL)
        POP  HL
        RET

AUTO_CMD:
        POP  AF
        RST  $8              ; HL=first parameter (start line number)
        LD   ($2C34), HL
        BIT  7, H            ; Number is greater then 32767?
.ECFB:
        JP   NZ, ShowWhatErr ; If yes - WHAT?
        CALL $0005           ; HL=second parameter (increase step)
        LD   ($2C32), HL
        BIT  7, H            ; Is it greater then 32767?
        JR   NZ, .ECFB       ; If yes - WHAT?
        CALL R2_CMD          ; Turn-off ROM-C (R2 - return to basic Galaksija mode!)
.ED0B:
        LD   HL, ($2C34)     ; HL=line number
        LD   (INPUTBUFFER), HL ; Line number to the beginning of INPUT buffer
        CALL $07F2           ; Find program line with number in HL (DE=address)
        JP   Z, .EDAF        ; If already exists, print the message
        CALL PrintHLAsASCII  ; If doesn't exist, print number in HL
        LD   DE, $2BB8       ; Input starts after the line number
.ED1D:
        CALL .EDE6           ; Program line character input
.ED20:
        RST  $20             ; Print the character on the screen...
        EXX
        LD   (HL), $5F       ; ... and cursor after the character...
        EXX
        LD   (DE), A         ; ... and save it in the INPUT buffer
        INC  DE              ; DE=INPUT buffer next byte address
        LD   A, D            ; Is address &2C31? (end)
        CP   $2C
        JR   NZ, .ED1D
        LD   A, E
        CP   $31
        JR   NZ, .ED1D       ; If not, wait for the next input
.ED31:
        CALL .EDE6           ; If it is the end, all entries are ignored
        JR   .ED31           ; (only control codes are processed)
.ED36:
        LD   A, D            ; Process arrow left - deleting
        CP   $2B             ; Is buffer address &2BB8?
        JR   NZ, .ED40       ; If bigger, delete last character
        LD   A,E
        CP   $B8
        JR   Z, .ED1D        ; If equal, ignore the key pressed
.ED40:
        DEC  DE              ; DE=address of the previously entered character
        LD   A, $1D          ; A=control code for deleting
        RST  $20             ; Delete the character (cursor) from the screen...
        EXX
        LD   (HL), $5F       ; ...and set the cursor one position to the left
        EXX
        JR   .ED1D           ; Wait for the next character
.ED4A:
        LD   (DE), A         ; PROCESSING ENTER KEY - write ENTER code to the buffer
        RST  $20             ; Print ENTER on the screen
        INC  DE              ; DE=address after the line end in the buffer
        LD   B, D
        LD   C, E            ; BC=address after the line end in the buffer
        LD   DE, INPUTBUFFER ; DE=INPUT buffer start address (with line number)
        LD   HL, ($2C34)     ; HL=line number
        PUSH BC              ; End address and...
        PUSH DE              ; ...start address onto the stack
        LD   A, C            ; (higher byte???)
        SUB  E               ; A=entered line length...
        PUSH AF              ; ... onto the stack
        CALL $07F2           ; find HL program line
        PUSH DE              ; Address of (at the end) found line on the stack (insertion beginning)
        JR   NZ, .ED70       ; If HL line not found, process entered line
        PUSH DE              ; Address of the found line to the stack one more time
        CALL $0811           ; DE=find start of the next program line
        POP  BC              ; BC=start of the found program line
        LD   HL, (BASICEND)  ; HL=BASIC end+1
        CALL $0944
        LD   H, B
        LD   L, C
        LD   (BASICEND), HL
.ED70:
        POP  BC
        LD   HL, (BASICEND)
        POP  AF
        PUSH HL
        CP   $3
        JR   Z, .ED92
        LD   E, A
        LD   D, $0
        ADD  HL, DE
        LD   DE, (RAMTOP)
        RST  $10
        JP   NC, $0153
        LD   (BASICEND), HL
        POP  DE
        CALL $094C
        POP  DE
        POP  HL
        CALL $0944
.ED92:
        LD   HL, ($2C34)
        LD   DE, ($2C32)
        ADD  HL, DE
        BIT  7, H
        JP   NZ, $0153
        LD   ($2C34), HL
        JP   .ED0B
.EDA5:
        DB "WARNING !", 13
.EDAF:
        PUSH DE
        CALL InitSound
        LD   A, $C8
        OUT  ($1), A
        LD   DE, .EDA5
        CALL PrintString
        POP  DE
        CALL $0931
        LD   B, $0
.EDC3:
        DJNZ .EDC3
        CALL MuteSound
.EDC8:
        CALL EC69
        CP   $1
        JP   Z, EF7F
        CP   $2
        JR   Z, .EDC8
        CP   CR
        JR   Z, .ED92
        LD   HL, ($2C34)
        PUSH AF
        CALL PrintHLAsASCII
        POP  AF
        LD   DE, $2BB8
        JP   .ED20
.EDE6:
        POP  HL              ; HL=return address from the stack
.EDE7:
        CALL EC69            ; Wait for the key press (KEY0)
        CP   $1              ; If it is BRK...
        JP   Z, EF7F         ; ... back to Plus mode without processing the input
        CP   $2              ; If it is STOP/LIST... (OR A; JR Z,&ED36 for DEL)
        JR   Z, .EDE7        ; ... ignore it (unnecessary check -4 bytes)
        CP   CR              ; If it is ENTER...
        JP   Z, .ED4A        ; ... process entered data
        CP   $1D             ; If it is arrow left...
        JP   Z, .ED36        ; ... delete last character
        CP   $20             ; If it is any other control code (??)...
        JR   C, .EDE7        ; ... ignore it
        JP   (HL)            ; If it is any character, return

FILL_CMD:
        POP  AF              ; (Does not work in TEXT mode, like PLOT and DRAW ???)
        RST  $8              ; Take first parameter (X)
        LD   C, L            ; C=X
        PUSH BC              ; X to the stack
        CALL $0005           ; HL=second parameter (Y)
        LD   A, (TEXTHORPOS) ; A=graphic mode indicator
        INC  A               ; Is it the GRAPH mode (=&FF)
        POP  BC              ; X from the stack
        JR   Z, .EE11        ; If GRAPH mode, continue with FILL
        RST  $30             ; If TEXT mode, go back to BASIC
.EE11:
        LD   B,L             ; BC=YX
        PUSH DE              ; BASIC_POINTER to the stack
        LD   ($2C32), SP     ; Save stack pointer (in INPUT buffer)
        LD   HL, (RAMTOP)
        LD   DE, ($2A99)     ; DE=memory amount reserved for alphanumeric array
        BIT  7, H            ; Is the RAMTOP above &8000?
        JR   Z, .EE25        ; If it is not, jump
        ADD  HL, DE          ; If it is, BUG!!!
        JR   .EE28
.EE25:
        XOR  A               ; Cf=0 if RAMTOP<&8000
        SBC  HL, DE          ; HL=start address for alphanumeric arrays (end, because they are written backward)
.EE28:
        DEC  HL              ; HL=first free RAM address
        LD   A, $CF
        SUB  B               ; Is X greater then 207?
        JP   C, ShowHowErr   ; If it is, HOW?
        LD   SP, HL          ; Stack bellow the arrays
        EXX
        LD   HL, (BASICEND)  ; HL'=BASIC end +1
        EXX
        LD   HL, .EE5C       ; HL=FILL command end address (restore stack and back to BASIC)
        PUSH HL              ; First address (&EE5C) on the stack is a return address
        LD   H, $FF          ; HL=&FF5C
        DEC  SP              ; One more byte between on the stack
        PUSH HL              ; &FF5C to the stack
        CALL EE74
.EE40:
        POP  BC
        DEC  SP
        POP  DE
        CALL .EE67           ; Check BRK and DEL keys (DEL pause, BRK stops FILL)
.EE46:
        INC  B
        RET  Z
        LD   A, B
        SUB  $D0
        CALL C, EE74
        DEC  B
        JR   Z, .EE56
        DEC  B
        CALL EE74
        INC  B
.EE56:
        INC  C
        DEC  D
        JR   NZ, .EE46
        JR   .EE40
.EE5C:
        LD   SP, ($2C32)     ; Restore stack pointer (FILL ends successfully)
        POP  DE              ; Return BASIC_POINTER from the stack
        RST  $30             ; Continue with BASIC program
.EE62:
        LD   A, ($2033)      ; DEL pressed?
        RRCA
        RET  C               ; Return if not
.EE67:
        LD   A, ($2031)      ; BRK pressed?
        RRCA
        JR   C, .EE62        ; If not pressed, repeat the test for both keys
        LD   SP, ($2C32)     ; If BRK pressed, restore stack pointer
        JP   $0305           ; Jump to ROM-A to cancel BASIC program execution

EE74:
        LD   H, $0
        CALL EEAD
        RET  NC
        LD   E, C
.EE7B:
        LD   A, C
        AND  A
        JR   Z, .EE86
        DEC  C
        CALL EEAD
        JR   C, .EE7B
        INC  C
.EE86:
        LD   L, C
        LD   C, E
.EE88:
        INC  C
        JR   Z, .EE90
        CALL EEAD
        JR   C, .EE88
.EE90:
        LD   C, L
        EXX
        LD   ($2C34), SP
        LD   DE, ($2C34)
        DEC  DE
        DEC  DE
        DEC  DE
        RST  $10
        JR   NC, .EEA6
        EXX
        EX   (SP), HL
        INC  SP
        PUSH BC
        LD   C, E
        JP   (HL)
.EEA6:
        LD   SP, ($2C32)     ; Restore stack pointer
        JP   ShowSorryErr    ; Print SORRY message

EEAD:
        PUSH HL
        PUSH DE              ; Unnecessary (+10T, &ECC0 does not use DE!!)
        CALL ECC0            ; HL=dot address from BC (YX), A=dot mask
        AND  (HL)            ; Is dot turned-on? (Cf=0, A=0 -> Zf=1)
        CP   (HL)            ; Cf=1 -> there is more to fill
        JR   Z, .EEB7        ; If it is turned-on, return with Cf
        LD   (HL), A         ; If not, turn it on
.EEB7:
        POP  DE              ; Unnecessary (+10T, &ECC0 does not use DE!!)
        POP  HL
        RET  Z
        INC  H
        SCF
        RET

HLDUMP_CMD:
        CALL $1060           ; Turn-on printing flag - HLDUMP command (HDUMP to printer)
HDUMP_CMD:
        POP  AF              ; Remove return address - HDUMP command
        RST  $8              ; Read first parameter (start address)
        PUSH HL
        CALL $0005           ; Read second parameter (end address)
        EX   DE, HL          ; DE=end address
        EX   (SP), HL        ; BASIC_POINTER to stack, HL=start address
.EEC8:
        LD   A, H
        ADD  A, L            ; A=CRC base (H+L address for 1. of 9 bytes)
        PUSH HL              ; Address to stack
        LD   B, $8           ; Read 8 more bytes
.EECD:
        ADD  A, (HL)         ; Add them to CRC
        INC  HL
        DJNZ .EECD
        POP  HL              ; Start address 1. of 8 bytes from stack
        PUSH AF              ; CRC to stack
        CALL $134F           ; Print address in HEX, without '&''
        LD   B, $8           ; Read 8 more bytes
.EED8:
        LD   A, $20
        RST  $20             ; Print space infront each HEX number
        LD   A, (HL)         ; Read byte to A
        CALL PrintAHex8      ; Print byte in A as HEX number
        INC  HL              ; Next address
        DJNZ .EED8
        LD   A, $20
        RST  $20             ; Print space infont of CRC
        POP  AF              ; A=CRC
        CALL PrintAHex8      ; Print CRC as HEX number
        CALL CheckBrkKey     ; Check BRK and DEL (DEL pauses, BRK stops H(L)DUMP)
        LD   A, CR
        RST  $20             ; New line
        RST  $10             ; Are all bytes printed? (HL<DE ?)
        JR   C, .EEC8        ; If not, continue with new line
        POP  DE              ; If everything is printed, take BASIC_POINTER from stack
        RST  $30             ; Continue with BASIC program

HLOAD_CMD:
        POP  AF              ; HLOAD command
        RST  $8              ; get parameter (address of input start)
        CALL R2_CMD          ; turn off ROM-C (back to line editor !!!)
.EEF9:
        PUSH HL              ; (BUG. in case of gross error ROM-C remains off !!!)
        PUSH HL              ; start address on stack 2x
.EEFB:
        POP  HL              ; HL=address from stack
        CALL $134F           ; print HEX address
        PUSH HL              ; address back on stack
        LD   A, $20          ; A=ASCII blank
        LD   DE, INPUTBUFFER ; DE=address of input buffer
        LD   (DE), A         ; the first character of the input buffer is blank
        INC  DE              ; DE=cursor address in input buffer
.EF07:
        RST  $20             ; on the screen after the address, the same blank
        EXX
        LD   (HL), $5F       ; print cursor on screen (block) after blank
        EXX
.EF0C:
        CALL EC69            ; wait for key press (new KEY(0))
        CP   $1              ; is BRK pressed?
        JR   Z, EF7F         ; end of entry, jump to turn-on ROM-C
        CP   $2              ; is STOP/LIST pressed?\
        JR   Z, .EF0C        ; wait for next key /(unnecessary)
        CP   $1D             ; is the left arrow pressed (delete)?
        JR   Z, .EF2E        ; if so, jump to delete processing
        CP   CR              ; has ENTER been pressed?
        JR   Z, .EF38        ; if so, jump to processing input
        CP   $20             ; is any other control key pressed?
        JR   C, .EF0C        ; if so, wait for the next key
        EX   AF, AF'         ; save character code in A'
        LD   A, E
        CP   $D1             ; is the cursor at the end of the line?
        JR   Z, .EF0C        ; if it is, there is no printout, wait for the key
        EX   AF, AF'         ; A=printable character
        LD   (DE), A         ; write a character into the input buffer
        INC  DE              ; DE=next location of input buffer
        JR   .EF07           ; jump to print character on screen and wait for key
.EF2E:
        LD   A, E            ; delete processing
        CP   $B7             ; is the cursor in the buffer at the 2nd position (address+blank is not deleted)
        JR   Z, .EF0C        ; if so, no deletion, wait for another key
        DEC  DE              ; if not, cursor in buffer one character back
        LD   A, $1D          ; A=erasure control code (left arrow - line editor !!)
        JR   .EF07           ; jump to print character on screen and wait for key
.EF38:
        LD   (DE), A         ; enter ENTER at the end of the buffer - processing the input
        RST  $20             ; print ENTER to screen (new line)
        LD   DE, INPUTBUFFER ; DE=start of input buffer (entry)
.EF3D:
        CALL SkipSpaces      ; skip blanks (A=first character in buffer)
        CP   CR              ; is the sign ENTER?
        JR   Z, .EF4E        ; if yes, jump to end of line processing
        CALL ReadHexByte     ; read HEX number in HL (if not HEX number, HOW? and ROM-C remains off)
        LD   A, L            ; A=number
        POP  HL              ; HL=address for number
        LD   (HL), A         ; entry of number to address
        INC  HL              ; next address
        PUSH HL              ; keep recording address still
        JR   .EF3D           ; process next HEX number (8 + CRC)
.EF4E:
        POP  HL              ; Remove the last entry address - end of line processing
        POP  HL
        PUSH HL              ; HL=address of the first entry in the line
        LD   B, $8           ; B=number of entered HEX digits in the line (if there are less, BUG?)
        LD   A, H            ; A=CRC basis (higher byte of starting address)
        ADD  A, L            ; CRC+lower byte of address
.EF55:
        ADD  A, (HL)         ; CRC+written byte
        INC  HL              ; address of next byte
        DJNZ .EF55           ; add all eight bytes
        CP   (HL)            ; is the CRC equal to the ninth written byte (BUG again !!!)
        JR   Z, .EF7B        ; if equal, jump to next line entry
        POP  HL              ; set stack as...
        PUSH HL              ; ...as at the beginning of the line
        PUSH HL              ; (will be repeated !!)
        LD   DE, .EF75       ; DE=address of error message "ERROR"
        CALL PrintString     ; print error message
        CALL InitSound       ; initialize AY sound
        LD   A, $AA          ; A=frequency ~560Hz fine
        OUT  ($1), A         ; write to register R0 for channel A
        LD   B, $0
.EF6E:
        DJNZ .EF6E           ; short pause (from .1s to .21s)
        CALL MuteSound       ; mute sound
        JR   .EEFB           ; expect the same line again
.EF75:
        DB "ERROR", 13
.EF7B:
        POP  AF              ; Remove line start address
        JP   .EEF9           ; expect next line

EF7F:                        ; Reinitialize ROM C
        DI                   ; disable interrupts
        CALL $E000           ; initialize ROM-C (and set 32 system variables)
        LD   HL, (RAMTOP)    ; HL=new RAMTOP
        LD   DE, $0020       ; DE=number of system variables above RAMTOP
        ADD  HL, DE          ; HL=old RAMTOP (with old system variables)
        LD   (RAMTOP), HL    ; set system variable RAMTOP
        LD   A, FF
        RST  $20             ; clear the screen
        JP   $0066           ; jump to HARD-BREAK ("farm")

UP_CMD:
        POP  AF              ; COMMAND UP
        RST  $8              ; read the parameter (how many bytes to raise the basic up)
        PUSH DE              ; save basic pointer
        PUSH HL              ; save parameter
        BIT  7, H            ; is the parameter greater than 32767 ?
        JR   NZ, EFC5        ; if bigger HOW? (BUG. with ROM-D it will be stuck or RESET!!!)
        LD   DE, (BASICEND)  ; DE=end of basic +1
        PUSH DE
        ADD  HL, DE          ; HL=new end of basic (end + parameter)
        LD   DE, (RAMTOP)    ; DE=RAMTOP
        RST  $10             ; is there room to move the base
        JP   NC, ShowSorryErr ; if none, SORRY error message
        EX   (SP), HL        ; new end of basic to stack
        PUSH HL              ; HL=old end of basic, and onto stack
        LD   DE, (BASICSTART); DE=start of basic
        CALL EFEF            ; is there a basic at all?
        LDDR                 ; if any, move the base
EFB4:
        POP  DE              ; DE=saved parameter from stack
        LD   HL, (BASICEND)  ; HL=BASIC_END (end of BASIC system variable)
        ADD  HL, DE          ; HL=new end of basic
        LD   (BASICEND), HL  ; update system variable
        LD   HL, (BASICSTART) ; HL=BASIC_START (basic start system variable)
        ADD  HL, DE          ; HL=new beginning of BASIC
        LD   (BASICSTART), HL ; update system variable
        POP  DE              ; DE=saved basic pointer
        RST  $30             ; continue to basic (after changing the address ??? but it works!)
EFC5:
        JP   ShowHowErr      ; print "HOW?" message

DOWN_CMD:
        POP  AF              ; COMMAND DOWN
        RST  $8              ; read the parameter (how many bytes to lower the basic down)
        PUSH DE              ; save basic pointer
        BIT  7, H            ; is the parameter greater than 32767?
        JR   NZ, EFC5        ; if greater, HOW? (BUG. with ROM-D it will be stuck or RESET!!!)
        EX   DE, HL          ; DE=parameter
        RST  $28             ; HL=0
        XOR  A               ; Cf=0
        SBC  HL, DE          ; HL= negative parameter
        PUSH HL              ; negative parameter on stack
        LD   DE, (BASICSTART) ; DE=BASIC_START (start of basic)
        PUSH DE              ; start of basic on stack
        ADD  HL, DE          ; HL=new start of basic (practical. start of basic - shift)
        LD   DE, $2C3A       ; DE=start of BASIC RAM
        RST  $10             ; is the new start of basic still in RAM?
        JP   C, ShowSorryErr ; if not, error message SORRY
        POP  DE              ; DE=old beginning of BASIC
        PUSH HL              ; new start of BASIC on stack
        PUSH DE              ; old start of BASIC on stack
        LD   HL, (BASICEND)  ; HL=old end of basic
        CALL EFEF            ; is there a basic at all?
        LDIR                 ; if there is, put it down
        JR   EFB4            ; update system variables BASIC_START and BASIC_END
EFEF:
        RST  $10             ; are the beginning of the basic and the end of the basic the same? (SUBROUTINE !)
        JP   Z, ShowWhatErr  ; if nothing to move
        XOR  A               ; Cf=0
        SBC  HL, DE          ; HL=base length
        LD   B, H
        LD   C, L
        INC  BC              ; BC=length of base +1
        POP  AF              ; AF=return address
        POP  HL              ; HL=old end of basic
        POP  DE              ; DE=new end of basic
        PUSH AF              ; return address on stack
        RET

        DB "G+"              ; Free space in ROM.