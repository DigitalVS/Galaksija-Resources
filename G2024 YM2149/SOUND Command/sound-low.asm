
; ROM routines
CmdRecognize = $039A
CatchAllCmds = $075B

BASICLINK    = $2BA9
BASICSTART   = $2C36
BASICEND     = $2C38
; RAM_END       = $9DFE

  .org $2C36

  dw  $2C6E, $2C6E              ; Initialize new BASIC start and end address after the last byte of this program

Init:
  ld    a, $C3                  ; Unconditional JMP instruction opcode
  ld    (BASICLINK), a
  ld    hl, CmdHandler          ; New BASIC command link
  ld    (BASICLINK + 1), hl
  ret

CmdHandler:
  ex    (sp), hl
  push  de
  ld    de, CatchAllCmds
  rst   $10                     ; Compare HL and DE
  pop   de
  jr    z, .Cmd
  ex    (sp), hl
  ;ret
  jp    $100F                   ; Goto ROM B command handler
.Cmd :                          ; If CmdHandler is called by CatchAllCmds
  ;ex    (sp), hl
  ld    hl, CmdTable - 1
  jp    CmdRecognize

CmdTable:
  BYTE "SOUND"
  BYTE (CMD_SOUND>>8 & $FF) + $80 ; Higher byte
  BYTE CMD_SOUND & $FF          ; Lower byte
  BYTE $10 + $80                ; 100F (ROM B)
  BYTE $0F
  
CMD_SOUND:
  pop   af                      ; SOUND command code, same as in Galaksija Plus ROM
  rst   $8                      ; Read first parameter
  ld    a, l                    ; A = sound chip register number
  out   ($00), a                ; Send to port $00
  call  $0005                   ; Read second parameter
  ld    a, l                    ; A = data byte to be written to the register
  out   ($01), a                ; Send to port $01
  rst   $30                     ; Return to BASIC
