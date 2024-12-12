;--------------------------------------------------------
;
;  Galaksija - ROM A V29
;
;--------------------------------------------------------

BUF = $2BB6 ; INPUTBUFFER
HOR = 11 ; Initial horizontal position of the screen
STACK = $2BA8 ; Value of the other end of arithmetic stack area
BASIC = $2C3A
BASPTR = BASIC - 4 ; BASICSTART
BASEND = BASIC - 2 ; BASICEND
IXPOS  = $2AAC ; ARITHMACC, arithmetic stack start address, for IX register
BSTR = $2A80

  .ORG 0

  di
  sub   a
  jp    START
ZAREZ:
  rst   Z8
  db    ','
  db    GO8C9-$-1
Z807:
  call  Z24
  jp    ZC0B
FAST:
  di
  ret
Z32:                            ; Compare HL and DE registers and set Z and C flags (rst $10)
  ld    a, h
  cp    d
  ret   nz
  ld    a, l
  cp    e
  ret
SLOW:
  ei
  ret
Z8:                             ; Read parameter pointed by DE (rst $18)
  ex    (sp), hl
  call  Z40
  cp    (hl)
  jp    Z98
Z16:                            ; Print character in A to screen at the current cursor position (rst $20)
  exx
  cp    $20
  call  ZACB
  exx
  ret
HL0:                            ; Clear HL (rst $28)
  ld    hl, 0
  ret
ZEB9:
  dw    $CCCC                   ; Floating point constant
  dw    $7ECC
Z48:                            ; rst $30, BASIC commands call this at the end to continue to next command execution
  pop   af
  call  Z8B3                    ; Continue to next BASIC command
GO8C9:
  jp    Z8C9                    ; Jump to WHAT? message handler

NUMBER:
  db    29                      ; ROM A version number (address $37)

;--------------------------------------------------------------------------
;
;                       Video interrupt routine
;
; Called 50 times per second by hardware counter on vertical sync impulse.
;
;--------------------------------------------------------------------------
; The address of a character on the screen:
;
;					                        A7 from latch
;                                       |
;                    <-- I register |   | | R register -->
;              ||                   ||  v |              ||
; Address bits || 11 | 10 |  9 |  8 ||  7 |  6 |  5 |  4 ||  3 |  2 |  1 |  0
;              ||              |    ||              |    ||
;                              |                    |
;     <-- Base address (2800h) |  Row (4 bits)      | Column (5 bits)

  push  af                      ; 11T
  push  bc
  push  de
  push  hl
  ld    hl, $2BB0               ; 10T - SCROLLCNT
  ld    a, $C0                  ; 7T - $C0 = 192
  sub   (hl)                    ; 7T
  sub   (hl)
  sub   (hl)                    ; Subtract 3 * SCROLLCNT from A
  ld    e, a                    ; 4T
  ld    a, (hl)                 ; 7T
  rrca                          ; 4T
  rrca
  rrca
  ld    b, a                    ; 4T
  or    a                       ; 4T - Set Z flag if A = 0, reset C flag
; The following code is a pause of (24 + B * 18) T states. This determines the vertical position on the screen.
  jr    z, $ + 2                ; 12/7T Jump to next instruction
  jr    z, NIJE                 ; 12/7T
  dec   (hl)                    ; 11T Decrement SCROLLCNT
  xor   a                       ; 4T
SPECL:
  ret   c                       ; 5T (C flag always reset)
  djnz  SPECL                   ; 13/8T
NIJE:
  inc   hl                      ; HL now points to SCROLLFLAG
  ld    (hl), a                 ; SCROLLFLAG = 0
  ld    b, e                    ; Set B = 192 - 3 * SCROLL_CNT
  ld    hl, $207F               ; HL = latch address
  ld    c, l                    ; C = $7F
  ld    a, (STACK)              ; A = value from TEXTHORPOS
  rra                           ; Divide A by 2 (C flag always reset)
  jr    c, RED                  ; Wait 5T if TEXTHORPOS is odd
RED:                            ; Video display loop
  dec   a
  jr    nz, RED                 ; Loop A times
  jr    OVER
  di                            ; Address $66 - NMI, hard break routine, resets BASIC interpreter
SP1C9:
  ld    sp, STACK               ; Clear the stack
  jp    Z1C9
OVER:                           ; Video display loop continuation
  inc   c                       ; C = $80
  ld    a, c
  and   8
  rrca
  rrca
  rrca
  or    $28
  ld    i, a                    ; I has upper 8 bits of the address for the line that will be drawn on the sceeen (either $28	or $29)
  inc   de                      ; NOP
  ld    de, $80C
  ld    a, c
  rrca
  rrca
  rrca
  ccf
  rr    d                       ; After this instruction, D has value $84 or $04. The MSB determines whether the RAM address line A7 will be forced to 1.
  or    $1F
  rlca
  sub   $40
  rrca
  ld    r, a
LINIJE:                         ; E = $C - number of scan lines to be drawn for a character. Here starts a line loop.
  ld    (hl), d                 ; Write D value to latch
  inc   d
  inc   d
  inc   d
  inc   d
  xor   a
  scf
  rra
  rra
  xor   d
  ld    d, a
  ld    h, c
  ld    a, b
BRK:
  dm    'BREAK'                 ; ld b,d : ld d,d : ld b,l : ld b,c : ld c,e
  nop                           ; This is ending zero for the string.
  ld    b, a
  ld    c, h
ZEB8:                           ; Next three lines (4 bytes) also serves as a 32 bit floating point constant 1.0.
  dw    0
  add   a, b
  nop
  xor   a
  scf
  rra
  rra
  rra
  ld    h, a
  rla
; At the end of line drawing:
; A = $40
;	B remains unmodified
;	C remains unmodified
;	D = $40 XOR (D + 4)
;	E remains unmodified
; HL remains unmodified ($207f)
  ld    (hl), a                 ; During the last character we clear the register so nothing gets	drawn outside the screen (character	generator line 0)
  dec   b
  jr    z, BLK
  ld    a, r
  sub   39
  and   l
  ld    r, a
  dec   e
  jp    nz, LINIJE
  ld    a, 3
  jr    RED
; End of screen drawing
BLK:
  ld    (hl), $bc               ; Disables A7 clamp and sets character generator to an empty line 15 so that nothing gets drawn outside of the screen.
; The following code increments the real-time clock value in BASIC string Y$.
  ld    a, (BSTR + 2)
  cp    ':'
  jr    nz, NESAT               ; Jump if Y$ does not contain clock string
  ld    a, ($2BAF)              ; CLOCKSTATE Clock is active if bit 7 is set
  rlca
  jr    nc, NESAT               ; Jump if clock is not active
  ld    hl, BSTR + 10
  ld    de, $3930               ; D = '9', E = '0'
  ld    b, 8
  ld    a, d
  inc   (hl)
  inc   (hl)
  cp    (hl)
  jr    OVER1
X7:
  inc   (hl)
  cp    (hl)
  ld    a, $35                  ; A = '5'
OVER1:
  jr    nc, NEOVF
  ld    (hl), e
  dec   hl
  bit   0, b
  jr    z, UZ
  dec   hl
  ld    a, d
UZ:
  djnz X7
NEOVF:
  dec   b
  djnz  NESAT
  ld    a, (hl)
  cp    $34
  jr    c, NESAT
  dec   hl
  bit   1, (hl)
  jr    z, NESAT
  ld    (hl), e
  inc   hl
  ld    (hl), e
NESAT:
  jp    (iy)

LINK3:
  pop   hl
  pop   de
  pop   bc
  pop   af
  ei
  reti

NOV40:
  inc   de
Z40:                            ; Skip spaces in a string pointed by DE. A contains first non-space character.
  ld    a, (de)
  cp    $20
  jr    z, NOV40
  ret

DIM:
  inc   hl
  xor   a
  call  HLX4
  ld    ($2A99), hl             ; 16 * ARR$ + 16
  rst   Z48
STRMAT:
  rst   Z807
  inc   hl
  xor   a
  call  HLX4
  push  de
  ld    de, ($2A99)
  inc   de
  rst   Z32
  jr    nc, SORRY2
  jr    Z51
Z56:
  call  Z40
  sub   $41
  ret   c
  cp    $1A
  ccf
  ret   c
  inc   de
  and   a
  jr    nz, Z82
  rst   Z8
  db    '('
  db    Z81-$-1
  rst   Z807
  inc   hl
  add   hl, hl
  add   hl, hl
  push  de
  jr    c, SORRY2
  ld    de, ($2A99)
  add   hl, de
  pop   de
  push  de
  jr    c, SORRY
Z51:
  pop   de
  rst   Z8
  db    ')'
  db    SORRY-$-1
  push  de
  ex    de, hl
  call  X825
  rst   Z32
  jr    nc, X82A
  db    '>'
SORRY:
  push  de
SORRY2:
  call  Z8CD
  dm    "SORRY", $0D
Z81:
  xor   a
Z82:
  ld    h, $2A
  rla
  rla
  ld    l, a
  xor   a
  ret

HEXCIF:
  call  Z8C
  ret   nc
  cp    $41
  ret   c
  add   a, 9
  cp    $50
  jr    ASK4
Z8C:
  ld    a, (de)
  cp    '0'
  ret   c
  cp    $3A                     ; ':' after '9'
ASK4:
  ccf
  ret   c
  inc   de
SKRS:
  and   $0F
  ret

STRSUB:
  ld    (hl), a
SKRASC:
  inc   hl
  ld    a, l
  jr    SKRS

X825:
  push  de
  ld    de, (BASEND)
X82A:
  ld    hl, ($2A6A)             ; RAMTOP
  ld    a, l
  and   $F0
  ld    l, a
  sbc   hl, de
  pop   de
  xor   a
  ret

Z98:
  inc   hl
  jr    z, ZA2
  push  bc
  ld    c, (hl)
  ld    b, 0
  add   hl, bc
  pop   bc
  dec   de
ZA2:
  inc   de
  inc   hl
  ex    (sp), hl
  ret
ZA6:
  call  Z155
  ld    b, 0
  ld    c, b
  call  Z40
ZAD:
  call  ZB2
  jr    ZAD
ZB2:
  call  Z8C
  jr    c, ZD7
  set   6, b
  bit   7, b
  jr    nz, ZD2
  call  ZC5
  bit   0, b
  ret   z
  dec   c
  ret
ZC5:
  call  Z15E
  ret   z
  exx
  ld    h, d
  ld    l, e
  ex    af, af'
  ld    c, a
  exx
  set   7, b
  pop   af
ZD2:
  bit   0, b
  ret   nz
  inc   c
  ret
ZD7:
  rst   Z8
  db    '.'
  db    ZDF-$-1
  bit   0, b
  set   0, b
  ret   z
ZDF:
  pop   af
  bit   6, b
  ret   z
  ld    hl, $18
  push  bc
  push  de
  exx
  call  ZE10IX
  pop   de
  ld    bc, ZFB
  push  bc
  push  de
  jp    ZD0F
ZFB:
  pop   bc
  push  de
  rst   Z8
  db    'E'
  db    Z11C-$-1
  rst   Z8
  db    '+'
  db    2
  jr    Z10A
  rst   Z8
  db    '-'
  db    2
  set   1, b
Z10A:
  call  Z157
Z10D:
  call  Z8C
  jr    c, Z120
  set   5, b
  call  Z15E
  jr    nz, Z12E
  jr    Z10D
Z11C:
  pop   de
  xor   a
  jr    Z137
Z120:
  bit   5, b
  jr    z, Z11C
  pop   af
  exx
  ld    a, c
  or    h
  ld    a, l
  exx
  jr    nz, Z12E
  bit   7, a
Z12E:
  jp    nz, Z1A2
  bit   1, b
  jr    z, Z137
  neg
Z137:
  add   a, c
Z138:
  and   a
  jr    z, Z14E
Z13B:
  bit   7, a
  jr    z, Z146
  inc   a
  push  af
  call  ZC95
  jr    Z14B
Z146:
  dec   a
  push  af
  call  ZC84
Z14B:
  pop   af
  jr    Z138
Z14E:
  bit   6, b
  ret
Z155:
  res   6, b
Z157:
  exx
  rst   HL0
  ld    c, l
  exx
  ret
Z15E:
  ex    af, af'
  exx
  ld    d, h
  ld    e, l
  ld    a, c
  ld    b, 0
  push  af
  add   hl, hl
  rl    c
  rl    b
  add   hl, hl
  rl    c
  rl    b
  add   hl, de
  adc   a, c
  ld    c, a
  ld    a, 0
  adc   a, b
  ld    b, a
  pop   af
  push  de
  ld    d, 0
  add   hl, hl
  rl    c
  rl    b
  ex    af, af'
  ld    e, a
  add   hl, de
  ld    a, d
  adc   a, c
  ld    c, a
  ld    a, d
  adc   a, b
  ld    b, a
  pop   de
  exx
  ret

BRISI:                          ; EDIT command - delete character at cursor position
  ld    e, l
  ld    d, h
ERASE:
  inc   de
  ld    a, (de)
  dec   de
  ld    (de), a
  inc   de
  cp    $0D                     ; CR
  jr    nz, ERASE
  jr    OPET
BKSP:
  ld    a, l
  cp    BUF & $FF               ; Is cursor at the beginning of the buffer?
  jr    z, OPET
  dec   hl
  jr    OPET
ADV:
  ld    a, (hl)
  cp    $0D
  jr    z, OPET
  jr    INCOP
EDIT:                           ; EDIT command entry point
  call  BEC4                    ; Read parameter pointed by DE and convert it to integer in HL
  call  Z92A                    ; Find BASIC line with line number equal to HL
  jp    c, Z1A2                 ; If not found show HOW?
  ld    a, $0C
  rst   Z16                     ; Clear screen
  ld    hl, BUF
  ld    ($2A68), hl             ; Set CURSORPOS to the beginning of the buffer
  call  ZA63                    ; Copy BASIC line to the input buffer
  exx
OPET:
  ld    de, $2800
  ld    ($2A68), de             ; Set cursor position to the top left corner of the screen
; Print the BASIC line in buffer on the screen with the '_' cursor inserted at HL'
  ld    de, BUF
  ld    c, (hl)
  ld    (hl), 0
  call  Z94F                    ; Print the BASIC line pointed by DE to the screen
  ld    a, '_'
  call  SPEC
  call  TASTAT                  ; Wait fot keypress
  cp    $0D                     ; CR
  jr    z, IZLAZ1               ; Process entered line of text
  or    a
  jr    z, BRISI
  cp    $1D
  jr    z, BKSP                 ; Backspace (arrow left)
  cp    $1E
  jr    z, ADV                  ; Arrow right
  jr    c, OPET
; Alphanumeric key pressed
  ld    b, a
  push  hl
  ld    hl, BASIC - 6           ; Check if input buffer is full
  rst   Z32
  pop   hl
  jr    c, OPET
INSERT:                         ; Make space for the inserted character by moving all characters on the right side to the right.
  dec   de
  ld    a, (de)
  inc   de
  ld    (de), a
  dec   de
  rst   Z32
  jr    nz, INSERT
  ld    (hl), b
INCOP:
  inc   hl                      ; Move '_' cursor for one place to the right
  jr    OPET

IFNR:                           ; Move cursor to new line
  ld    a, ($2A68)              ; CURSORPOS
  and   31                      ; Is it at the end of line?
  ld    a, $0D
  ld    ($2bb5), a              ; FIXME INPUTBUFFER start address is $2BB6!?!
  ret   z
  rst   Z16                     ; Print CR if Zf not set
  ret

TESTB:                          ; Check if BRK key has been pressed. If true execute the BREAK routine.
  ld    a, ($2033)              ; DEL key
  rrca
  ret   c
IFBRK:
  ld    a, ($2031)              ; BRK key
  rrca
  jr    c, TESTB

STOP:
  call  IFNR
  ld    de, BRK
  call  Z94F
  ld    de, ($2A9F)             ; Current line position
  ld    a, d
  or    e
  call  nz, X96D

Z1C9:
  ei
  call  IFNR
  ld    de, Z1AE
  call  Z94F
Z1D8:
  rst   HL0
  ld    de, $3031               ; BRK and RETURN key codes set initially to KBDDIFF
  ld    sp, $2AA7
  push  de
  push  hl
  push  hl
  push  hl
  ld    hl, (BASPTR)
  inc   hl
  inc   hl
  push  hl                      ; Restore
  ld    sp, STACK
  ld    ix, IXPOS
  call  Z8FA
IZLAZ1:
  push  de
  ld    de, BUF
  call  BEC4                    ; Read parameter pointed by DE and convert it to integer in HL
  pop   bc
  jp    z, X340
  dec   de
  ld    a, h
  ld    (de), a
  dec   de
  ld    a, l
  ld    (de), a
  push  bc
Z1F9:
  push  de
  ld    a, c
  sub   e
  push  af
  call  Z92A
  push  de
  jr    nz, Z213
  push  de
  call  Z945
  pop   bc
  ld    hl, (BASEND)
  call  ZA6F
  ld    h, b
  ld    l, c
  ld    (BASEND), hl
Z213:
  pop   bc
  ld    hl, (BASEND)
  pop   af
  push  hl
  cp    3
  jr    z, Z1D8
  ld    e, a
  ld    d, 0
  add   hl, de
  ld    de, ($2A6A)             ; Memory end address
  rst   Z32
  jp    nc, SORRY
  ld    (BASEND), hl
  pop   de
  call  ZA77
  pop   de
  pop   hl
  call  ZA6F
  jr    Z1D8

X340:
  ld    hl, Z1C9
  push  hl
  ld    l, Z248 & $FF
  db    1
Z7ED:
  ld    l, Z2EE & $FF
  db    1
IFCHR:
  ld    l, ZACHR-1 & $FF
Z343:
  ld    h, $0F
X343:                           ; Recognize the BASIC command
  call  Z40
  push  de
  inc   de
  inc   hl
  cp    (hl)
  jr    z, Z351
  bit   7, (hl)
  jr    nz, Z35B
  jr    Z362
Z351:
  ld    a, (de)
  inc   de
  inc   hl
  cp    (hl)
  jr    z, Z351
  bit   7, (hl)
  jr    z, Z35E
Z35B:
  dec   de
  jr    Z370
Z35E:
  cp    $2E
  jr    z, Z36B
Z362:
  inc   hl
  bit   7, (hl)
  jr    z, Z362
  inc   hl
  pop   de
  jr    X343
Z36B:
  inc   hl
  bit   7, (hl)
  jr    z, Z36B
Z370:
  ld    a, (hl)
  inc   hl
  ld    l, (hl)
  and   $7F
  ld    h, a
  pop   af
  bit   6, h
  res   6, h
  push  hl
  call  nz, Z814
  jp    STACK + 1               ; BASIC link

START:                          ; Initialization code executed while booting
  im    1
  ld    iy, LINK3               ; IY holds pointer to additional user interrupt routine, default is LINK3. Any interrupt routine has to finish with jump to LINK3.
  ld    hl, $27FF
  ld    (hl), l                 ; Initial latch value is $FF
  ld    b, l
GOONCP:                         ; Initialize complete RAM to zeros
  inc   hl
  ld    (hl), b
  inc   (hl)
  jr    nz, DONE                ; End if reached the end of RAM
  or    (hl)
  jr    z, GOONCP
DONE:
  ld    ($2A6A), hl             ; Memory end address register (RAMTOP + 1)
  ld    sp, STACK + 5           ; Initial stack value
  ld    hl, $C900 + HOR         ; Horizontal position initialized to HOR value (not the cleanest way to do it!)
  push  hl                      ; Video and BASIC links initialized to RET instruction (value $C9)
  dec   sp
  push  hl
  call  $1000                   ; Call to ROM B initialization code
NEW:                            ; BASIC NEW command
  call  BEC4                    ; Read optional parameter pointed by DE and convert it to integer in HL
  ld    de, BASIC
  add   hl, de                  ; Move BASIC start address by value in HL
  ld    sp, BASIC
  push  hl                      ; Set BASIC end address to the same value as start address
  push  hl                      ; Set BASIC start address
Z384:
  jp    SP1C9                   ; Execute BASIC reset as for NMI routine

RUN:                            ; BASIC RUN command
  call  BEC4                    ; Read parameter pointed by DE and convert it to integer in HL
  ld    de, (BASPTR)
  jr    Z397

Z8B3:
  ld    ($2bb5), a              ; FIXME INPUTBUFFER start address is $2BB6!?!
  rst   Z8
  db    ':'
  db    AS3-$-1
OVERPL:
  pop   af
  jr    Z3A2
AS3:
  rst   Z8
  db    $0D
  db    ASRET-$-1
  pop   af
Z394:
  rst   HL0
Z397:
  call  Z92D
  jr    c, Z384
Z39C:
  ld    ($2A9F), de
  inc   de
  inc   de
Z3A2:
  call  IFBRK
  ld    ix, IXPOS
  ld    l, Z26C & $FF
  jp    Z343
Z799:
  call  Z7AD                    ; Compare next expression with IX
  call  ZCB1
  rst   HL0
ASRET:
  ret

Z5FB:
  rst   Z807                    ; IF
  ld    a, h
  or    l
  jr    nz, Z3A2
  call  X947
ASIF:
  jr    nc, Z39C
  jr    Z384
Z5F6:
  rst   HL0                     ; #,!,ELSE
  call  Z947
  jr    ASIF

Z3B5:
  rst   Z807                    ; GOTO
X3BC:
  push  de
Z3BC:
  call  Z92A
  jp    nz, Z1A3
  pop   af
  jr    Z39C

Z401:                           ; LIST
  call  BEC4                    ; Read parameter pointed by DE and convert it to integer in HL
LIST2:
  call  IFNR
  call  Z92A
GOFARM:
  jr    c, Z384
LISTIT:
  call  ZA63
  call  Z92D
  jr    c, GOFARM
LOOPL:
  call  IFBRK
  ld    a, ($2030)
  ld    hl, $2034
  and   (hl)
  rrca
  jr    nc, LISTIT
  jr    LOOPL

Z42F:
  rst   Z8                      ; PRINT
  db    ':'
  db    Z443-$-1
  ld    a, $0D
  rst   Z16
  jr    Z3A2
Z443:
  rst   Z8
  db    $0D
  db    Z44C-$-1
  rst   Z16
ZA394:
  jr    Z394
Z452:
  rst   Z8
  db    '"'
  db    Z499-$-1
  call  Z950
  jr    nz, ZA394
  jr    Z464
Z459:
  ld    l, 92                   ; X$
  db    1 ; Dummy: LD BC,
Z45E:
  ld    l, 96                   ; Y$
Z460:
  ld    h, $2A
  call  Z6A4
Z461:
  ld    a, (hl)
  inc   hl
  or    a
  jr    z, Z464
  rst   Z16
  ld    a, l
  and   $0F
  jr    nz, Z461
Z464:
  rst   Z8
  db    $2C
  db    Z48D-$-1
Z467:
  ld    a, ($2A68)              ; CURSORPOS
  and   $07
  jr    z, Z490
ZAREZ2:
  ld    a, $20
  rst   Z16
  jr    Z467
Z473:
  rst   Z807                    ; AT
  ld    a, h
  or    $28
  and   $29
  ld    h, a
  ld    ($2A68), hl             ; CURSORPOS
  rst   Z8
  db    ','
  db    2
  jr    Z490
Z48D:
  rst   Z8
  db    ';'
  db    Z495-$-1
Z490:
  call  Z8B3
Z44C:
  ld    l, Z319 & $FF
  jp    Z343
HOME:
  call  BEC4                    ; Read parameter pointed by DE and convert it to integer in HL
  ld    ($2A6C), hl             ; SCREENSTART
  jr    nz, SKRSC
Z4B5:
  ld    a, $0C                  ; HOME
  db    1 ; Dummy LD BC,
Z495:
  ld    a, $0D
  rst   Z16
SKRSC:
  rst   Z48
Z499:
  call  IFCHR
  jr    nz, DACHR
  call  Z24
  call  Z970
  db    $3E ; Dummy LD A,
DACHR:
  rst   Z16
  jr    Z464
Z4C4:                           ; CALL
  call  ZA9F
  rst   Z807
Z4CA:
  push  de
  call  Z92A
  jp    nz, Z1A3
  ld    hl, ($2A9F)
  push  hl
  ld    hl, ($2AA3)             ; Temp SP for current CALL
  push  hl
  rst   HL0
  ld    ($2AA1), hl             ; Register for active FOR-NEXT loop
  add   hl, sp
  ld    ($2AA3), hl
  jp    Z39C
Z4E6:                           ; RETURN
  ld    hl, ($2AA3)
  ld    a, h
  or    l
  jp    z, Z1A2
  ld    sp, hl
  pop   hl
  ld    ($2AA3), hl
  pop   hl
  ld    ($2A9F), hl
  pop   de
Z5F2:
  call  ZA84
  rst   Z48
Z560:
  rst   Z807                    ; STEP
  db    1 ; Dummy LD BC,
Z565:
  rst   HL0                     ; No STEP
  inc   hl
Z568:
  ld    ($2A91), hl             ; Current loop stack
  ld    hl, ($2A9F)
  ld    ($2A93), hl
  ex    de, hl
  ld    ($2A95), hl
  ld    bc, $0A
  ld    hl, ($2AA1)
  ex    de, hl
  rst   HL0
  add   hl, sp
  db    $3E ; Dummy LD A,
Z580:
  add   hl, bc
  ld    a, (hl)
  inc   hl
  or    (hl)
  jr    z, Z59E
  ld    a, (hl)
  dec   hl
  cp    d
  jr    nz, Z580
  ld    a, (hl)
  cp    e
  jr    nz, Z580
  ex    de, hl
  rst   HL0
  add   hl, sp
  ld    b, h
  ld    c, l
  ld    hl, $0A
  add   hl, de
  call  ZA77
  ld    sp, hl
Z59E:
  ld    hl, ($2A95)
  ex    de, hl
  rst   Z48
Z5A3:
  call  IF56                    ; NEXT
  ld    ($2A9B), hl
Z5AA:
  push  de
  ex    de, hl
  ld    hl, ($2AA1)
  ld    a, h
  or    l
  jp    z, Z1A3
  rst   Z32
  jr    z, Z5C0
  pop   de
  call  ZA84
  ld    hl, ($2A9B)
  jr    Z5AA
Z5C0:
  call  ZBC3
  call  ZC0B
  ex    de, hl
  ld    hl, ($2A91)
  push  hl
  add   hl, de
  push  hl
  call  ZC59
  ld    hl, ($2AA1)
  call  ZBE9
  pop   de
  ld    hl, ($2A6E)
  pop   af
  rlca
  jr    nc, Z5E0
  ex    de, hl
Z5E0:
  ld    a, h
  xor   d
  jp    p, Z5E6
  ex    de, hl
Z5E6:
  rst   Z32
  pop   de
  jp    c, Z5F2
  ld    hl, ($2A93)
  ld    ($2A9F), hl
  jr    Z59E

Z654:
  jp    z, Z8AE
AGN:
  push  hl                      ; Accepts string
  call  Z694
  jr    c, NES
  jr    z, CM
  ex    (sp), hl
  pop   bc
TRANS:
  ld    a, (bc)
  or    a
  jr    z, NULE2
  inc   bc
  call  STRSUB
  jr    nz, TRANS
  ret
NES:
  pop   hl
  rst   Z8
  db    '"'
  db    0
NENAV:
  call  X68A
  jr    z, NULE2
  inc   de
  call  STRSUB
  jr    nz, NENAV
X68A:
  ld    a, (de)
  cp    $0D                     ; CR
  ret   z
  cp    $22
  ret   nz
  inc   de
  ret
CM:
  dec   de
  call  IFCHR
  jr    z, NES
CH:
  pop   hl
  call  STRSUB
  ret   z
NULE2:
  rst   Z8
  db    '+'
  db    NULE-$-1
  jr    AGN
NULE:
  ld    (hl), 0
ASC0:
  call  SKRASC
  ret   z
  ld    (hl), $30
  jr    ASC0
Z694:
  call  Z56                     ; Locate variable (Cy - no variable, A=0 Z - numeric, A>0 nz - string)
  ret   c
  dec   de
  ld    a, (de)
  inc   de
  cp    $29
  ret   z
  ld    a, (de)
  cp    $24
  jr    z, Z6A3
Z749:
  xor   a
  ret
Z6A3:
  inc   de
Z6A4:
  ld    a, l
  sub   92
  jr    nz, BS
  ld    l, $70
  rst   Z8
  db    '('
  db    3
  call  STRMAT
  or    h
  ret
BS:
  cp    7
  jp    nc, Z8C9                ; WHAT?
  ld    l, $80
  or    h
  ret

TAKE:
  call  Z694
  jr    c, CIFRE
  push  de
  push  af
  push  hl
  ld    de, ($2A9D)             ; TAKE pointer
  ld    hl, (BASEND)
SRCHT:
  rst   Z8
  db    '#'
  db    NETAR1-$-1
  jr    FOUNDT
NETAR1:
  rst   Z8
  db    ','
  db    NETAR-$-1
FOUNDT:
  pop   hl
  pop   af
  call  Z654
SKRT:
  ld    ($2A9D), de
  pop   de
  rst   Z8
  db    ','
  db    SEE48-$-1
  jr    TAKE
NETAR:
  ld    a, (de)
  inc   de
  cp    $0D
  jr    nz, NETAR
  inc   de
  inc   de
  rst   Z32
  jr    nc, SRCHT
  pop   hl
Z745:
  pop   af
  db    $0E ; Dummy LD C,
Z1A2:                           ; HOW? entry point
  push  de
Z1A3:
  call  Z8CD
  dm    'HOW?'
  db    $0D

CIFRE:
  rst   Z807
  push  de
  call  Z92A
  inc   de
  inc   de
  jr    SKRT

Z623:                           ; INPUT
  push  de
  ld    a, $3F
  call  Z8FC
  ld    de, BUF
  RST   Z8
  db    $0D
  db    INPOK-$-1
  pop   de
  call  Z694
  rst   Z48
INPOK:
  pop   de
  push  de
Z6D4:
  call  Z694
  jr    c, Z1A3
  push  de
  ld    de, BUF
  call  Z654
  pop   de
  pop   af
SEE48:
  rst   Z48

Z7AD:
  rst   Z8
  db    '-'
  db    Z7B8-$-1
  rst   HL0
  call  ZC59
  jr    Z7CC
Z7B8:
  rst   Z8
  db    '+'
  db    0
  call  Z7D4
Z7BE:
  rst   Z8
  db    $2B
  db    Z7C9-$-1
  call  Z7D4
  call  ZCD3
  jr    Z7BE
Z7C9:
  rst   Z8
  db    $2D
  db    Z803-$-1
Z7CC:
  call  Z7D4
  call  ZCBF
  jr    Z7BE
Z7D4:
  call  Z7ED
Z7D7:
  rst   Z8
  db    '*'
  db    Z7E2-$-1
  call  Z7ED
  call  ZC87
  jr    Z7D7
Z7E2:
  rst   Z8
  db    '/'
  db    Z803-$-1
  call  Z7ED
  call  ZC98
  jr    Z7D7
Z838:                           ; UNDOT
  ld    a, 1                    ; Bit 7 reset
  db    1 ; Dummy LD BC,
Z83C:                           ; DOT
  ld    a, $80                  ; Bit 7 set
  push  af
  rst   Z8                      ; DOT* and UNDOT* versions of command turn clock on and off
  db    '*'
  db    NOCLK-$-1
  pop   af
  ld    ($2BAF), a              ; Save if clock is active. It is active if bit 7 is set.
  rst   Z48
NOCLK:
  pop   af
  db    6 ; Dummy LD B,
Z840:                           ; If DOT
  xor   a
  and   a
  push  af
  rst   Z807
  push  hl
  call  ZAREZ
  push  de
CONTXY:
  ex    de, hl
  ld    bc, $20
  inc   e
  ld    hl, $2800
GOY:
  ld    d, 3
  ld    a, 1
Y3:
  dec   e
  jr    z, GOTY
  rlca
  rlca
  dec   d
  jr    nz, Y3
  add   hl, bc
  res   1, h
  jr    GOY
GOTY:
  ld    b, a
  pop   de
  ex    (sp), hl
  res   7, l
  res   6, l
  srl   l
  jr    nc, PARNI
  rlca
PARNI:
  ld    h, 0
  pop   bc
  add   hl, bc
  ld    b, a
  pop   af
  ld    a, b
  jr    nz, SETRES
  bit   7, (hl)
  jr    z, NISTA
  and   (hl)
NISTA:
  rst   HL0
  jr    z, OSTA0
  inc   hl
OSTA0:
  jp    ZC59
SETRES:
  push  af
  bit   7, (hl)
  jr    nz, SR
  ld    (hl), $80
SR:
  pop   af
  jp    m, SETXY
  cpl
  and   (hl)
  db    6 ; LD B,
SETXY:
  or    (hl)
  ld    (hl), a
  rst   Z48

Z8A8:
  call  IF56
  rst   Z8
  db    '='
  db    Z8C9-$-1
Z8AE:
  push  hl
  call  Z24
Z8E8:
  pop   hl
ZBE9:
  call  IXFFFB                  ; (IX) -> (HL)
  ld    bc, 4
  push  de
  push  hl
  ex    de, hl
  push  ix
  pop   hl
  ldir
  ex    de, hl
  dec   hl
  dec   hl
  rl    (hl)
  inc   hl
  ld    a, (ix + 4)
  rla
  rr    (hl)
  dec   hl
  rr    (hl)
  pop   hl
  pop   de
  ret

Z6B3:                           ; Last chance, same as LET. BASIC so far didn't recignized the command.
  call  Z694
  jr    c, GOTO48
  push  af
  rst   Z8
  db    '='
  db    Z8C9-$-1
  pop   af
  call  Z654
GOTO48:
  rst   Z48

PTR:
  ld    h, d
  ld    l, e
  call  Z694
  jr    OSTA0

VAL:
  push  de
  ex    de, hl
  call  Z24
  pop   de
  ret

Z7F2:
  call  Z56
  jp    nc, ZBC3
  call  ZA6
  ret   nz
Z7FC:
  rst   Z8
  db    '('
  db    Z8C9-$-1
  call  Z24
  rst   Z8
  db    ')'
  db    1
Z803:
  ret

IF56:
  call  Z56
  ret   nc
Z8C9:
  push  de                      ; WHAT?
Z8CA:
  call  Z8CD
  dm    'WHAT?', $0D
Z8CD:                           ; Pointer to error message is on the stack
  pop   de
  call  Z94F                    ; Print the error message
  ld    de, ($2A9F)             ; Current BASIC line position
  ld    a, e
  or    d
AS1C9:
  ld    hl, Z1C9
  ex    (sp), hl
  ret   z
  rst   Z32
  ret   c
  ld    c, (hl)
  push  bc
  ld    (hl), 0
  push  hl
  call  ZA63
  pop   hl
  pop   bc
  ld    a, '?'
SPEC:
  dec   de
  ld    (hl), c
  jp    S94F

Z8FA:                           ; Input buffer subroutine, reads string from keyboard into the input buffer
  ld    a, '>'
Z8FC:
  ld    de, BUF
  rst   Z16                     ; Print prompt character
Z900X:
  exx
  ld    (hl), '_'
  exx
Z900:
  call  TASTAT                  ; Wait for key to be pressed and print it
  rst   Z16
  exx
  ld    (hl), '_'
  exx
  cp    $0D
  jr    z, Z915                 ; CR pressed
  cp    $1D
  jr    z, Z922
  cp    $0C
  jr    z, Z8FA                 ; Arrow-left pressed
  cp    $20
  jr    c, Z900                 ; If code is less then $20, ignore it
Z915:
  ld    (de), a                 ; Store the ASCII key code to the input buffer
  inc   de
  cp    $0D
  ret   z                       ; If key is CR, this is the end of the input
  ld    a, e
  cp    BASIC-6 & $FF           ; Check for end of buffer
  jr    nz, Z900
  ld    a, $1D
  rst   Z16
Z922:                           ; Delete character from buffer
  ld    a, e
  cp    BUF & $FF               ; Check it it is at the start of the buffer
  jr    z, Z8FA                 ; If it is, do nothing, loop again
  dec   de                      ; Move the current character pointer for one place back
  jr    Z900X

Z92A:                           ; Finds BASIC line with line number equal or greater than HL in the entire BASIC code.
  ld    de, (BASPTR)
Z92D:
  push  hl
  ld    hl, (BASPTR)
  dec   hl
  rst   Z32
  jp    nc, Z1C9
  ld    hl, (BASEND)
  dec   hl
  rst   Z32
  pop   hl
  ret   c
  ld    a, (de)
  sub   l
  ld    b, a
  inc   de
  ld    a, (de)
  sbc   a, h
  jr    c, Z946
  dec   de
  or    b
  ret

Z945:
  inc   de
Z946:
  inc   de
Z947:
  ld    a, (de)
  cp    $0D
  jr    nz, Z946
YES0D:
  inc   de
  jr    Z92D

NOTE0D:
  inc   de
X947:
  ld    a, (de)
  rst   HL0
  cp    $0D
  jr    z, YES0D
  cp    '!'
  jr    z, Z946
  cp    '"'
  jr    nz, IGN
GONAV:
  inc   de
  ld    a, (de)
  cp    $0D
  jr    z, YES0D
  cp    '"'
  jr    nz, GONAV
IGN:
  cp    'E'
  jr    nz, NOTE0D
  ld    l, XELSE & $FF - 1
  jp    Z343

Z983:
  ld    a, (ix - 1)
  and   a
  ld    a, $20
  jr    z, Z98D
  ld    a, $2D
Z98D:
  rst   Z16
  xor   a
  ld    (ix - 1), a
  dec   a
Z994:
  push  af
  ld    hl, ZEB9
  call  ZCA6
  jr    nc, Z9A4
  call  ZC84
  pop   af
  dec   a
  jr    Z994

LOOP:
  call  ZC95
  pop   af
  inc   a
  push  af
Z9A4:
  ld    hl, ZEB8
  call  ZCA6
  jr    nc, LOOP

Z9B4:
  ld    a, (ix - 2)
  neg
Z9B9:
  jr    z, Z9C6
  exx
  srl   c
  rr    h
  rr    l
  exx
  dec   a
  jr    Z9B9

Z9C6:
  ld    b, 7
  push  ix
  pop   hl
  ld    (hl), 0
  inc   hl
Z9CE:
  xor   a
  call  Z15E
  exx
  ld    a, b
  exx
  ld    (hl), a
  inc   hl
  djnz  Z9CE
  ld    bc, $600
  dec   hl
  ld    a, (hl)
  cp    5
Z9E2:
  ccf
  ld    a, 0
  dec   hl
  adc   a, (hl)
  sla   c
  cp    $0A
  jr    c, Z9EF
  ld    a, 0
Z9EF:
  ld    (hl), a
  push  af
  and   a
  jr    z, Z9F6
  set   0, c
Z9F6:
  pop   af
  djnz  Z9E2
  ld    a, c
  pop   bc
  jr    c, ZA03
  inc   b
  push  bc
  ld    b, 1
  jr    Z9E2
ZA03:
  ld    c, a
  ld    a, b
  inc   a
  jp    m, ZA13
  cp    7
  jr    nc, ZA13
  ld    b, a
  call  ZA4D
  jr    ZA41

ZA13:
  push  bc
  ld    b, 1
  call  ZA4D
  ld    a, $45
  rst   Z16
  pop   bc
  bit   7, b
  ld    a, $2B
  jr    z, ZA2B
  ld    a, $2D
  rst   Z16
  ld    a, b
  neg
  jr    ZA2D

ZA2B:
  rst   Z16
  ld    a, b
ZA2D:
  ld    b, $30
ZA2F:
  cp    $0A
  jr    c, ZA38
  add   a, $F6
  inc   b
  jr    ZA2F
X96D:
  ld    a, (de)
  ld    l, a
  inc   de
  ld    a, (de)
  ld    h, a
  inc   de
Z96D:
  call  ZC59                    ; Print number in HL
Z970:
  push  de
  push  bc
  push  hl
  ld    a, (ix - 2)
  cp    $80
  jp    nz, Z983
  xor   a
  ld    b, $20
ZA38:
  or    $30
  ld    c, a
  ld    a, b
RA41:
  rst   Z16
  ld    a, c
  rst   Z16
ZA41:                           ; Space after a number
  pop   hl
  pop   bc
DEIXBC:
  pop   de
IXFFFB:
  ld    bc, $FFFB
ZAIX:
  add   ix, bc
  ret

ZE10IX:
  call  ZE00
BC10IX:
  ld    bc, $0A
  jr    ZAIX

ZA4D:
  inc   b
ZA4E:
  djnz  ZA54
  ld    a, $2E
  rst   Z16
ZA54:
  ld    a, (hl)
  or    $30
  rst   Z16
  inc   hl
  srl   c
  jr    nz, ZA4E
  dec   b
  dec   b
  ret   m
  inc   b
  jr    ZA4D
ZA63:
  call  X96D
  ld    a, $20
S94F:
  rst   Z16
Z94F:                           ; Print string pointed by DE to screen at current cursor position.
  xor   a
Z950:
  ld    b, a
Z951:
  ld    a, (de)
  inc   de
  cp    b
  ret   z                       ; Ends if character is zero
  rst   Z16                     ; rst $20
  cp    $0D                     ; Ends if character is CR
  jr    nz, Z951
  inc   a                       ; Reset Z flag
  ret

;--------------------------------
; MOVE MEMORY BLOCK
;
; -------------     -------------
; |source     |     |destination|
; -------------     -------------
; ^            ^    ^
; |            |    |
; DE           HL   BC
;
ZA6F:
  rst   Z32
  ret   z
  ld    a, (de)
  ld    (bc), a
  inc   de
  inc   bc
  jr    ZA6F
ZA77:
  ld    a, b
  sub   d
  jr    nz, ZA7E
  ld    a, c
  sub   e
  ret   z
ZA7E:
  dec   de
  dec   hl
  ld    a, (de)
  ld    (hl), a
  jr    ZA77
ZA84:
  pop   bc
  pop   hl
  ld    ($2AA1), hl
  ld    a, h
  or    l
  jr    z, ZA9D
  pop   hl
  ld    ($2A91), hl
  pop   hl
  ld    ($2A6E), hl
  pop   hl
  ld    ($2A93), hl
  pop   hl
  ld    ($2A95), hl
ZA9D:
  push  bc
  ret
ZA9F:
  ld    hl, $FFFF - STACK + 113
  pop   bc
  add   hl, sp
  jp    nc, SORRY
  ld    hl, ($2AA1)
  ld    a, h
  or    l
  jr    z, ZAC8
  ld    hl, ($2A95)
  push  hl
  ld    hl, ($2A93)
  push  hl
  ld    hl, ($2A6E)
  push  hl
   ld    hl, ($2A91)
  push  hl
  ld    hl, ($2AA1)
ZAC8:
  push  hl
  push  bc
  ret

Z7A7:                           ; Evaluate relational operators
  rst   Z8
  db    '>'
  db    NFOUNV-$-1
  call  Z799
  ret   z
  ret   c
  inc   hl
  ret
NFOUNV:
  rst   Z8
  db    '='
  db    NFOUNJ-$-1
  call  Z799
  ret   nz
  inc   hl
  ret
NFOUNJ:
  rst   Z8
  db    '<'
  db    Z797-$-1
  call  Z799
  ret   nc
  inc   hl
  ret

ZACB:                           ; Print a character in A to the screen at the current cursor position
  push  af
  call  STACK + 4               ; Call video link
  ld    hl, ($2A68)             ; CURSORPOS
  jr    c, ZB11                 ; Jump if special character
  ld    (hl), a                 ; Print a character
  inc   hl
ZAF2:
  ld    a, $2A
  cp    h
  jr    nz, ZB09
; HL points outside of screen memory, scroll the screen for one line up
  ld    hl, $2BB0               ; SCROLLCNT
  call  WAIT                    ; Wait until scroll ends
  push  hl
  inc   hl                      ; HL = SCROLLFLAG
  inc   (hl)                    ; Set SCROLLFLAG
  call  WAIT                    ; For one whole screen, to sync with video
  or    a
  ld    de, ($2A6C)             ; SCREENSTART
  res   1, d
  ld    hl, $1E0                ; 480 (32 characters * 15 lines)
  sbc   hl, de
  jr    z, IGNSCR               ; Jump if result is zero or less
  jr    c, IGNSCR
  ld    b, h                    ; BC = HL
  ld    c, l
  set   3, d                    ; D = D | 28h (with next line)
  set   5, d                    ; DE points to video memory
  ld    hl, $20
  add   hl, de                  ; HL points to next line
  ldir                          ; Row up
IGNSCR:                         ; Soft scroll screen one line up
  ld    hl, ($2A6C)             ; SCREENSTART
  ld    a, h
  or    l
  pop   hl
  jr    nz, NOT3
  ld    (hl), 3                 ; Three phase scroll
NOT3:                           ; Clear bottom line
  ld    hl, $29E0               ; Last row
  push  hl
  call  ZB37                    ; Clear bottom row
  pop   hl
ZB09:
  ld    ($2a68), hl             ; Update cursor position at CURSORPOS
Z797:
  pop   af
  ret
ZB11:                           ; Interpret special character
  cp    $0D
  jr    nz, ZB1A
CRET:                           ; Put cursor on the next line
  ld    a, h
  cp    $2B                     ; Is cursor on screen?
  jr    c, NEDITM
  ld    (hl), $0D               ; Just put the CR on the screen
  jr    ZB09
NEDITM:
  call  ZB37                    ; Clear to end of line
  jr    ZAF2                    ; Jump to scroll the screen by one line
ZB1A:
  cp    $0C                     ; FF (Form feed)
  jr    nz, ZB2E
  ld    hl, $29FF               ; Address of the last character of the screen
GOCLR:                          ; Clear the screen
  ld    (hl), $20
  dec   hl
  bit   1, h
  jr    z, GOCLR
ADJUST:
  inc   hl
  jr    ZB09
ZB2E:                           ; Clear current character and move cursor one position back
  cp    $1D                     ; GS ASCII character
  jr    nz, ZB09
  ld    (hl), $20
  dec   hl
  bit   1, h
  jr    nz, ADJUST
  jr    ZB09

ZB37:                           ; Clear character row to the end from character pointed by HL
  ld    (hl), ' '
  inc   hl
  ld    a, l
  and   $1F
  jr    nz, ZB37
  ret

WAIT:                           ; Wait for video interrupt routine to reset the SCROLLFLAG or to SCROLLCNT becomes zero if HL points to it
  ld    a, i
  ret   po                      ; Return if interrupts are disabled
WAIT2:
  ld    a, (hl)
  or    a
  jr    nz, WAIT2
  ret

ZBC3:                           ; Push floating point number on the stack
  push  de
  push  hl
  push  af
  ld    bc, 4
  push  ix
  pop   de
  ldir
  rl    (ix + 2)
  rl    (ix + 3)
  ld    a, b
  rra
  ld    (ix + 4), a
  scf
  rr    (ix + 2)
  ld    c, 5
  add   ix, bc
  pop   af
  pop   hl
  pop   de
  ret
Z814:
  call  Z7FC
ZC0B:
  exx
  call  IXFFFB
  ld    de, 0
  ld    a, (ix + 3)
  ld    c, (ix + 4)
  cp    $80
  jr    z, ZC52
  cp    1
  jp    m, ZC2C
  cp    $10
  exx
  jp    p, Z1A2
  exx
ZC30:
  ld    b, a
  ld    a, (ix + 0)
  ld    l, (ix + 1)
  ld    h, (ix + 2)
ZC3A:
  sla   a
  adc   hl, hl
  rl    e
  rl    d
  djnz  ZC3A
ZC46:
  sla   c
  jr    nc, ZC52
  or    h
  or    l
  jr    z, ZC4F
  inc   de
ZC4F:
  call  ZC78
ZC52:
  push  de
  exx
  pop   hl
  ret

ZC2C:
  ld    a, $FF
  jr    ZC46
Z24:
  call  Z7AD                    ; +, -, / , *
Z75D:
  call  Z7A7
  db    1 ; Dummy LD BC,
ZC56:
  ld    hl, $0A
ZC59:
  push  de
ZC5A:
  ex    de, hl
  call  BC10IX
  call  ZC75
  push  de
  ld    hl, $10
  rr    h
  exx
  pop   de
  rst   HL0
  ld    h, e
  ld    c, d
  call  ZE00
  jr    ZCA4
ZC75:
  xor   a
  add   a, d
  ret   p
ZC78:
  ld    a, e
  neg
  ld    e, a
  ld    a, d
  cpl
  ccf
  adc   a, 0
  ld    d, a
  scf
  ret
ZC84:
  call  ZC56
ZC87:
  call  ZE1E
  jr    z, ZCCA
  cp    e
  jp    z, ZD0D
  call  ZD27
  jr    ZCA4
ZC95:
  call  ZC56
ZC98:
  call  ZE1E
  jr    z, ZCCA
  cp    e
  jp    z, Z1A3
  call  ZD5C
ZCA4:
  jr    ZD0F
ZCA6:
  call  ZBC3
  call  ZE1E
  ld    bc, $FFFB
  jr    ZCB7
ZCB1:
  call  ZE1E
  ld    bc, $FFF6
ZCB7:
  add   ix, bc
  cp    l
  call  ZD94
  pop   de
  ret
ZCBF:
  call  ZE1E
  jr    nz, ZCC9
  call  ZD03
  jr    ZCF9
ZCC9:
  cp    e
ZCCA:
  jr    z, ZD20
ZCCC:
  xor   d
  ld    d, a
  jr    ZCDB
  call  ZBC3
ZCD3:
  call  ZE1E
  jr    z, ZD04
  cp    e
  jr    z, ZD20
ZCDB:
  call  ZDB3
  jr    z, ZCEE
  jr    nc, ZCE9
  ex    de, hl
  exx
  ex    de, hl
  ld    a, c
  ld    c, b
  ld    b, a
  exx
ZCE9:
  call  ZDCB
  jr    ZD0F
ZCEE:
  ld    a, h
  xor   d
  jr    nz, ZD0D
  ld    e, 1
  call  ZDF3
  jr    ZD0F
ZCF9:
  ld    a, (ix - 1)
  xor   $80
  ld    (ix - 1), a
  pop   de
  ret
ZD03:
  push  de
ZD04:
  ld    h, d
  ld    l, e
  exx
  ld    l, e
  ld    h, d
  ld    c, b
  exx
  db    1 ; Dummy LD BC,
ZD0D:
  ld    l, $80
ZD0F:
  ld    (ix - 6), h
  ld    (ix - 7), l
  exx
  ld    (ix - 10), l
  ld    (ix - 9), h
  ld    (ix - 8), c
  exx
ZD20:
  jp    DEIXBC
ZD27:
  ld    a, h
  xor   d
  ld    h, a
  dec   e
  push  hl
  push  bc
  ld    b, $18
  call  ZE39
  xor   a
  rst   HL0
  ld    c, a
ZD3D:
  exx
  srl   c
  rr    h
  rr    l
  exx
  jr    nc, ZD4B
  add   hl, de
  ld    a, c
  adc   a, b
  ld    c, a
ZD4B:
  exx
  djnz  ZD53
  pop   bc
  pop   hl
  exx
  jr    ZD83
ZD53:
  exx
  rr    c
  rr    h
  rr    l
  jr    ZD3D
ZD5C:
  ld    a, e
  neg
  ld    e, a
  ld    a, h
  xor   d
  ld    h, a
  push  hl
  push  bc
  ld    b, $19
  exx
ZD68:
  sbc   hl, de
  ld    a, c
  sbc   a, b
  ld    c, a
  jr    nc, ZD72
  add   hl, de
  adc   a, b
  ld    c, a
ZD72:
  exx
  ccf
  adc   hl, hl
  rl    c
  djnz  ZD85
  push  hl
  push  bc
  exx
  pop   bc
  pop   hl
  exx
  pop   bc
  pop   hl
  exx
ZD83:
  jr    ZDE9
ZD85:
  exx
  add   hl, hl
  rl    c
  jr    nc, ZD68
  ccf
  sbc   hl, de
  ld    a, c
  sbc   a, b
  ld    c, a
  or    a
  jr    ZD72
ZD94:
  jr    z, ZDA0
  cp    e
  jr    z, ZDA8
  ld    a, h
  xor   d
  call  z, ZDB3
  jr    ZDA7
ZDA0:
  cp    e
  ret   z
  scf
  bit   7, d
  jr    ZDAA
ZDA7:
  ret   z
ZDA8:
  bit   7, h
ZDAA:
  ccf
  ret   nz
  ccf
  rra
  scf
  rl    a
  ret
ZDB3:
  ld    a, l
  sub   e
  jr    z, ZDBE
  jp    po, ZDBC
  neg
ZDBC:
  rlca
  ret
ZDBE:
  exx
  ld    a, c
  cp    b
  jr    nz, ZDC9
  rst   Z32
ZDC9:
  exx
  ret
ZDCB:
  ld    a, l
  sub   e
  jr    z, ZDDD
  cp    $18
  ret   nc
  exx
ZDD3:
  srl   b
  rr    d
  rr    e
  dec   a
  jr    nz, ZDD3
  exx
ZDDD:
  ld    e, 0
  ld    a, h
  xor   d
  jp    m, ZDFA
  exx
  add   hl, de
  ld    a, c
  adc   a, b
  ld    c, a
ZDE9:
  jr    nc, ZDF2
  rr    c
  rr    h
  rr    l
  scf
ZDF2:
  exx
ZDF3:
  ld    a, l
  adc   a, e
ZDF5:
  jp    pe, ZE15
  ld    l, a
  ret
ZDFA:
  exx
  sbc   hl, de
  ld    a, c
  sbc   a, b
  ld    c, a
ZE00:
  ld    b, $18
  xor   a
  inc   c
  dec   c
ZE05:
  jp    m, ZE11
  dec   a
  add   hl, hl
  rl    c
  djnz  ZE05
ZE0E:
  ld    l, $80
  ret
ZE11:
  exx
  add   a, l
  jr    ZDF5
ZE15:
  ld    a, h
  or    a
  jp    p, Z745
  jr    ZE0E
ZE1E:
  pop   hl
  push  de
  push  hl
  ld    d, (ix - 1)
  ld    e, (ix - 2)
  ld    h, (ix - 6)
  ld    l, (ix - 7)
  exx
  ld    e, (ix - 5)
  ld    d, (ix - 4)
  ld    b, (ix - 3)
ZE39:
  ld    l, (ix - 10)
  ld    h, (ix - 9)
  ld    c, (ix - 8)
  exx
  ld    a, $80
  cp    l
  ret
RND:                            ; RND
  push  de
  exx
  ld    hl, $2AA7               ; RND seed register
  push  hl
  ld    e, (hl)
  inc   hl
  ld    d, (hl)
  inc   hl
  ld    b, (hl)
  exx
  call  Z155
  rst   HL0
  ld    c, 3
ZE77:
  ld    b, 8
  ld    d, (hl)
ZE7A:
  exx
  add   hl, hl
  rl    c
  exx
  rl    d
  jr    nc, ZE89
  exx
  add   hl, de
  ld    a, c
  adc   a, b
  ld    c, a
  exx
ZE89:
  djnz  ZE7A
  inc   hl
  dec   c
  jr    nz, ZE77
  rst   HL0
  exx
  pop   de
  ld    a, l
  add   a, $65
  ld    (de), a
  inc   de
  ld    l, a
  ld    a, h
  adc   a, $B0
  ld    (de), a
  inc   de
  ld    h, a
  ld    a, c
  adc   a, 5
  ld    (de), a
  ld    c, a
  call  ZE10IX
  jp    ZD0F

BEC4:                           ; Convert string pointed by DE to integer. Returns converted integer in HL or 0 on error. Zf set on error or cleared on success.
  rst   HL0
  call  Z40
  call  Z8C
  jr    c, ALPHA
  dec   de
  call  ZA6
  call  ZC0B
ALPHA:
  ld    a, h
  or    l
  ret

GO1:
  cp    h
  jr    nz, NOTH
  ld    h, 0
NOTH:
  cp    l
  jr    nz, NOTL
  ld    l, 0
NOTL:
  dec   e
  jr    nz, TAST3
  jr    TAST2

TASTAT:                         ; Wait for key to be pressed and return it in A register
  exx                           ; Save BC, DE and HL registers
  ld    hl, ($2AA5)             ; KBDDIFF
  ld    c, 14                   ; Autorepeat speed
TAST2:
  ld    de, $2034               ; Address of the last key on the keyboard (LIST key), except SHIFT key
TAST3:
  ld    a, (de)
  rrca                          ; Rotate A to set/reset C flag
  ld    a, e
  jr    c, GO1
  cp    $32                     ; Code for repeat key
  jr    nz, NORPT
  dec   c                       ; Repeat key is pressed
  jr    nz, GO1
  ld    a, ($2BB4)              ; REPEATKEY
  jr    IZLAZ
NORPT:
  cp    h
  jr    z, NOTL
  cp    l
  jr    z, NOTL
  ld    b, 0
X200:                           ; Wait for 256 cycles for key release (debouncing)
  rst   Z32
  ld    a, (de)
  rrca
  jr    c, GO1
  djnz  X200
  ld    a, h                    ; Fill in an empty position in KBDDIFF (HL)
  or    a
  jr    nz, ZAUZET
  ld    h, e
  jr    UPISAN
ZAUZET:
  ld    a, l
  or    a
  jr    nz, TAST3
  ld    l, e
UPISAN:
  ld    ($2AA5), hl             ; KBDDIFF
  rst   HL0
  ld    a, e
  cp    $34                     ; LIST key
  jp    z, LIST2
  cp    $31                     ; BRK key
  jp    z, STOP
  cp    $1B                     ; Up arrow
  ld    hl, $2035               ; Last key (SHIFT)
  jr    c, IZLAZ2               ; Jump if letter character (less then $1B)
  cp    $1F
  jr    c, IZLAZ                ; Jump if arrows (less then $1F)
; Codes for numerical and symbol keys are looked up in TABELA
  sub   $1F
  rr    (hl)                    ; Since HL contains the address of the "shift" key, this moves that status of the "shift" key	into carry flag.
  rla
  ld    c, a
  ld    hl, TABELA
  add   hl, bc
  ld    a, r
  ld    ($2AA8), a              ; Use it as RND seed, as a second byte
  ld    a, (hl)
IZLAZ:
  ld    ($2BB4), a              ; Save last pressed key code to REPEATKEY
  exx
  ret

IZLAZ2:
  add   a, $40                  ; Add ASCII offset for letter characters
  rr    (hl)                    ; Since HL contains the address of the "shift" key, this moves that status of the "shift" key	into carry flag.
  jr    c, IZLAZ
  ld    hl, TAB3                ; Shift table for letter keys
  ld    bc, $45B                ; B = 4 byte table length, C = first ASCII code for Yugoslavian character set.
NFND:
  cp    (hl)
  jr    z, FNDSL
  inc   hl
  inc   c
  djnz  NFND
  db    $0E ; Dummy LD C,
FNDSL:
  ld    a, c
  jr    IZLAZ

TABELA: ; Key codes remaped to match standard keycaps! Old values are commented out on the rigth side.
  dw $2020 ; SPACE   ; dw $2020 ; SPACE
  dw $3029 ; ) 0     ; dw $305F ; Cursor 0
  dw $3121 ; ! 1     ; dw $3121 ; ! 1
  dw $3222 ; " 2     ; dw $3222 ; " 2
  dw $3323 ; # 3     ; dw $3323 ; # 3
  dw $3424 ; $ 4     ; dw $3424 ; $ 4
  dw $3525 ; % 5     ; dw $3525 ; % 5
  dw $36BF ; Block 6 ; dw $3626 ; & 6
  dw $3726 ; & 7     ; dw $37BF ; Block 7
  dw $382A ; * 8     ; dw $3828 ; ( 8
  dw $3928 ; ( 9     ; dw $3929 ; ) 9
  dw $3B3A ; : ;     ; dw $3B2B ; + ;
  dw $2D5F ; _ -     ; dw $3A2A ; * :
  dw $2C3C ; < ,     ; dw $2C3C ; < ,
  dw $3D2B ; + =     ; dw $3D2D ; - =
  dw $2E3E ; > .     ; dw $2E3E ; > .
  dw $2F3F ; ? /     ; dw $2F3F ; ? /
  dw $0D0D ; RET     ; dw $0D0D ; RET

TAB3:
  db $58 ; X
  db $43 ; C
  db $5A ; Z
  db $53 ; S

  dw $000C ; STOP DEL

Z821:                           ; MEM BASIC function
  call  X825
  ld    bc, ($2A99)             ; 16*ARR$+16
  sbc   hl, bc
  jr    FORC59

WORD2:                          ; WORD BASIC function
  ld    c, (hl)                 ; Read 2 bytes
  inc   hl
  ld    h, (hl)
  ld    l, c
  jr    FORC59

KEY:                            ; KEY BASIC function
  ld    a, h
  or    l
  jr    nz, NOWAIT
  call  TASTAT
  jr    LA
NOWAIT:
  set   5, h
  ld    a, (hl)
ARCPL:
  cpl
AREZ:
  and   1
LA:
  ld    l, a
  db    $3E                     ; Dummy LD, skip next instruction

BYTE2:                          ; BYTE BASIC function
  ld    l, (hl)                 ; Read byte
ASK2:
  ld    h, 0
FORC59:
  jp    ZC59

EQUS:
  call  Z694
  push  hl
  rst   Z8
  db    ','
  db    0
  call  Z694
  pop   bc
POREDI:
  ld    a, (bc)
  cp    (hl)
  jr    nz, NEQ
  or    a
  jr    z, ENDEQ
  inc   hl
  inc   bc
  ld    a, l
  and   15
  jr    nz, POREDI
ENDEQ:
  db    $3E                     ; Dummy LD, skip next instruction
NEQ:
  xor   a
  jr    AREZ

HEX:
  call  HEXCIF
  jr    c, ZAHOW
  dec   de
  rst   HL0
GOCONV:
  call  HEXCIF
  jr    c, FORC59
  rlca
  rlca
  rlca
  rlca
  ld    bc, GOCONV
  push  bc
HLX4:
  ld    b, 4
HEX4:
  rlca
  adc   hl, hl
ZAHOW:
  jp    c, Z1A2
  djnz  HEX4
  ret

WORD1:                          ; WORD BASIC command
  db    $F6                     ; Dummy 'OR n', skip next instruction
BYTE1:                          ; BYTE BASIC command
  xor   a
  push  af
  rst   Z807
  push  hl
  call  ZAREZ
  ex    (sp), hl
  pop   bc
  ld    (hl), c
  pop   af
  jr    z, NOVINS
  inc   hl
  ld    (hl), b
NOVINS:
  rst   Z48

USR:                            ; USR
  push  de
  ld    de, ZC5A
  push  de
  jp    (hl)

CHRS:
  or    d
  ld    a, l
  ret

Z546:                           ; FOR
  call  ZA9F
  call  Z8A8
  ld    ($2AA1), hl             ; FOR-NEXT register
  rst   Z8
  db    'T'
  db    WHAT2-$-1
  rst   Z8
  db    'O'
  db    WHAT2-$-1
  rst   Z807
  ld    ($2A6E), hl             ; TO register, exit for FOR-NEXT
  ld    l, Z311 & $FF
  jp    Z343

ZF3B:                           ; SAVE
  ld    hl, BASIC - 4
  push  hl
  ld    hl, (BASEND)
  rst   Z8
  db    $0D
  db    2
  jr    NODIM
  rst   Z807
  ex    (sp), hl
  call  ZAREZ
  inc   hl
NODIM:
  pop   de
  ld    b, $60
  di
LEADER:
  xor   a
  call  BYTEX
  djnz  LEADER
  ld    a, $A5
  call  BYTEX
  call  EXWORD
  call  EXWORD
  dec   hl
REC:
  ld    a, (de)
  inc   de
  call  BYTEX
  jr    nc, REC
  ld    a, b
  cpl
  ld    e, a

EXWORD:
  ex    de, hl
WORD:
  ld    a, l
  call  BYTEX
  ld    a, h
BYTEX:
  exx
  ld    c, $10
  ld    hl, $2038
GO16:
  bit   0, c
  jr    z, PULSE
IFPUL:
  rrca
  ld    b, 100
  jr    nc, NOPUL
PULSE:
  ld    (hl), $FC               ; HI
  ld    b, 50
  djnz  $
  ld    (hl), $B8               ; LOW
  ld    b, 50
  djnz  $
  ld    (hl), $BC               ; NORMAL
  inc   b
NOPUL:
  djnz  $
  djnz  $
  dec   c
  jr    nz, GO16
VVP:
  inc   bc ; 13312 T
  bit   1, b
  jr    z, VVP
  exx
ABHLDE:
  add   a, b
  ld    b, a
  rst   Z32
  ret

ZEE9:                           ; LOAD (OLD)
  rst   Z8
  db    '?'
  db    0
  push  af                      ; If verify, Z set
  rst   Z8
  db    $0d
  db    2
  rst   HL0
  db    $3E
  rst   Z807
  push  hl
  di
GOA5:
  call  RXBYTE                  ; Synchro byte A5
  ld    a, c
  cp    $A5
  jr    nz, GOA5
  ld    b, a
  call  RX2
  ld    h, c
  pop   de
  push  de
  add   hl, de
  ex    de, hl
  call  RX2
  ld    h, c
  dec   hl
  ld    a, b
  pop   bc
  add   hl, bc
  ld    b, a
PUNI:
  ex    de, hl
  call  RXBYTE
  ex    af, af'
  ld    a, c
  cp    (hl)
  jr    z, EQUAL
  pop   af
  jr    z, WHAT2
  push  af
  ld    (hl), c
EQUAL:
  inc   hl
  ex    de, hl
  ex    af, af'
  jr    c, PUNI
  call  RXBYTE
  pop   af
  inc   b
  ret   z
WHAT2:
  jp    Z8C9                    ; Checksum error
RX2:
  call  RXBYTE
  ld    l, c
RXBYTE:
  exx
  ld    b, 1
RXBY:
  ld    a, 167
SYNC2:
  add   a, b
  ld    hl, $2000
  bit   0, (hl)
  jr    z, FOUND
  dec   a
  jr    nz, SYNC2
  exx
  ld    a, c
  jr    ABHLDE
FOUND:
  ld    b, 0 - 38
VPPLUS:
  ld    a, 256 - 87
  djnz  VPPLUS
  ld    b, 90
RCV:
  ld    c, (hl)
  rr    c
  adc   a, 0
  djnz  RCV
  rlca
  exx
  rr    c
  exx
  jr    RXBY

Z1AE:
  dw    $2740                   ; Logo at the beginning of the line
  db    'READY', $0D

  .org $0F0F

Z248 = $-1
  dm 'LIST'
  db (Z401>>8 & 00ffh) + 80h
  db Z401 & $FF
  dm 'RUN'
  db (RUN>>8 & $00FF) + $80
  db RUN & $FF
  dm 'NEW'
  db (NEW>>8 & $00FF) + $80
  db NEW & $FF
  dm 'SAVE'
  db (ZF3B>>8 & $00FF) + $80
  db ZF3B & $FF
  dm 'OLD'
  db (ZEE9>>8 & $00FF) + $80
  db ZEE9 & $FF
  dm 'EDIT'
  db (EDIT>>8 & $00FF) + $80
Z26C:
  db EDIT & $FF
  dm 'NEXT'
  db (Z5A3>>8 & $00FF) + $80
  db Z5A3 & $FF
  dm 'INPUT'
  db (Z623>>8 & $00FF) + $80
  db Z623 & $FF
  dm 'IF'
  db (Z5FB>>8 & $00FF) + $80
  db Z5FB & $FF
  dm 'GOTO'
  db (Z3B5>>8 & $00FF) + $80
  db Z3B5 & $FF
  dm 'CALL'
  db (Z4C4>>8 & $00FF) + $80
  db Z4C4 & $FF
  dm 'UNDOT'
  db (Z838>>8 & $00FF) + $80
  db Z838 & $FF
  dm 'RET'
  db (Z4E6>>8 & $00FF) + $80
  db Z4E6 & $FF
  dm 'TAKE'
  db (TAKE>>8 & $00FF) + $80
  db TAKE & $FF
  dm '!'
  db (Z5F6>>8 & $00FF) + $80
  db Z5F6 & $FF
  dm '#'
  db (Z5F6>>8 & $00FF) + $80
  db Z5F6 & $FF
  dm 'FOR'
  db (Z546>>8 & $00FF) + $80
  db Z546 & $FF
  dm 'PRINT'
  db (Z42F>>8 & $00FF) + $80
  db Z42F & $FF
  dm 'DOT'
  db (Z83C>>8 & $00FF) + $80
  db Z83C & $FF
  dm 'ELSE'
  db (Z5F6>>8 & $00FF) + $80
  db Z5F6 & $FF
  dm 'BYTE'
  db (BYTE1>>8 & $00FF) + $80
  db BYTE1 & $FF
  dm 'WORD'
  db (WORD1>>8 & $00FF) + $80
  db WORD1 & $FF
  dm 'ARR$'
  db (DIM>>8 & $00FF) + $80 + $40
  db DIM & $FF
  dm 'STOP'
  db (Z1C9>>8 & $00FF) + $80
  db Z1C9 & $FF
  dm 'HOME'
  db (HOME>>8 & $00FF) + $80
  db HOME & $FF
  db (Z6B3>>8 & $00FF) + $80
Z2EE:
  db Z6B3 & $FF
  dm 'RND'
  db (RND>>8 & $00FF) + $80
  db RND & $FF
  dm 'MEM'
  db (Z821>>8 & $00FF) + $80
  db Z821 & $FF
  dm 'KEY'
  db (KEY>>8 & $00FF) + $80 + $40
  db KEY & $FF
  dm 'BYTE'
  db (BYTE2>>8 & $00FF) + $80 + $40
  db BYTE2 & $FF
  dm 'WORD'
  db (WORD2>>8 & $00FF) + $80 + $40
  db WORD2 & $FF
  dm 'PTR'
  db (PTR>>8 & $00FF) + $80
  db PTR & $FF
  dm 'VAL'
  db (VAL>>8 & $00FF) + $80 + $40
  db VAL & $FF
  dm 'EQ'
  db (EQUS>>8 & $00FF) + $80
  db EQUS & $FF
  dm 'INT'
  db (ZC59>>8 & $00FF) + $80 + $40
  db ZC59 & $FF
  dm '&'
  db (HEX>>8 & $00FF) + $80
  db HEX & $FF
  dm 'USR'
  db (USR>>8 & $00FF) + $80 + $40
  db USR & $FF
  dm 'DOT'
  db (Z840>>8 & $00FF) + $80
  db Z840 & $FF
  db (Z7F2>>8 & $00FF) + $80
Z311:
  db Z7F2 & $FF
  dm 'STEP'
  db (Z560>>8 & $00FF) + $80
  db Z560 & $FF
  db (Z565>>8 & $00FF) + $80
Z319:
  db Z565 & $FF
  dm 'AT'
  db (Z473>>8 & $00FF) + $80
  db Z473 & $FF
  dm 'X$'
  db (Z459>>8 & $00FF) + $80
  db Z459 & $FF
  dm 'Y$'
  db (Z45E>>8 & $00FF) + $80
  db Z45E & $FF
  db (Z452>>8 & $00FF) + $80
  db Z452 & $FF
ZACHR:
  dm 'CHR$'
  db (CHRS>>8 & $00FF) + $80 + $40
  db CHRS & $FF
  db (Z749>>8 & $00FF) + $80
  db Z749 & $FF
XELSE:
  dm 'ELSE'
  db (OVERPL>>8 & $00FF) + $80
  db OVERPL & $FF
  db (NOTE0D>>8 & $00FF) + $80
  db NOTE0D & $FF
  db 0

  .end
