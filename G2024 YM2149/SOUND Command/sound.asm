
; ROM routines
CmdRecognize = $039A
CatchAllCmds = $075B

BASICLINK    = $2BA9
RAMTOP       = $2A6A
RAM_END      = $7000;$9DFE - 60

  .org $7000

Init:
  ld    a, $C3                  ; Unconditional JMP instruction opcode
  ld    (BASICLINK), a
  ld    hl, CmdHandler          ; New BASIC command link
  ld    (BASICLINK + 1), hl
  ld    hl, RAM_END             ; Move RAMTOP lower
  ld    (RAMTOP), hl            ; Set new RAMTOP  
  ret

CmdHandler:
  ex    (sp), hl
  push  de
  ld    de, CatchAllCmds
  rst   $10
  pop   de
  jr    z, .Cmd2
  ld    a, h
  cp    $20                     ; Check address range $20xx - $28xx. This is a trick, because officially commands can be only at addresses up to $4000.
  jr    c, .Cmd1
  cp    $28
  jr    nc, .Cmd1
  ; This is our command - transform address higher byte to correct one
  ld    h, $70                  ; Set correct higher byte (program start address higher byte)
  ex    (sp), hl
  ret
.Cmd1:                          ; If address not in range $20xx - $28xx - command not recognized
  ex    (sp), hl
  jp    $100F                   ; Goto ROM B command handler
.Cmd2:                          ; If CmdHandler is called by CatchAllCmds
  ex    (sp), hl
  ld    hl, CmdTable - 1
  jp    CmdRecognize
  
CmdTable:
  BYTE "SOUND"
  BYTE $A0                      ; Higher byte (fake)
  BYTE CMD_SOUND & $00FF        ; Lower byte
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
