; ShowRegisters:              ; Reassembled routine from ROM address $1978 because it waits for key to be pressed
;   ld (STACK_TOP), sp ; Save SP and set it to end of input buffer
;   ld sp, STACK_TOP
;   push af
;   push bc
;   push de
;   push hl
;   push ix
;   ld hl, (STACK_TOP)
;   inc hl
;   inc hl
;   push hl                   ; HL is SP + 2, this is SP value before this subroutine call
;   ld e, (hl)
;   inc hl
;   ld d, (hl)                ; DE has last two bytes from original stack
;   exx
;   ex af, af'
;   push af
;   push bc
;   push de
;   push hl
;   push iy
;   exx
;   push de                   ; Last value from stack
;   ; Print two rows of values from stack
;   ld de, STACK_TOP - 1 ; Points to stack memory
;   ld b, 2                   ; Two rows to print
; .Row:
;   push bc
;   ld b, 6                   ; Six values to print
; .Value:
;   ld a, ' '
;   rst $20
;   ld a, (de)
;   dec de
;   ld h, a
;   ld a, (de)
;   dec de
;   ld l, a
;   call PrintHex16
;   djnz .Value
;   ld a, CR
;   rst $20
;   pop bc
;   djnz .Row
;   ; Restore registers from stack
;   pop af ; Pop stack value
;   pop af ; Instead to iy
;   pop hl
;   pop de
;   pop bc
;   pop af
;   ex af, af'
;   exx
;   pop af
;   pop af ; Instead to ix
;   pop hl
;   pop de
;   pop bc
;   ; Print "F:"
;   ld a, 'F'
;   rst $20
;   ld a, ':'
;   rst $20
;   pop af
;   ld sp, (STACK_TOP) ; Restore stack pointer
;   ;ld sp, (SP_REG)
;   ret

; -------------------------------------------------------------------------------------------------

; In: D = x (relative to window top/left), E = y
; Out: HL = address in screen RAM
; WinCursorPos:
;   push af
;   ld a, e                   ; A = y
;   add a, a                  ; *2
;   add a, a                  ; *4
;   add a, a                  ; *8
;   ld h, 0
;   add a
;   rl h                      ; *16
;   add a
;   rl h                      ; *32
;   add d                     ; +x
;   ld l,a
;   ld a,h
;   adc $28                   ; HL = $2800 + y*40 + x
;   ld h,a
;   pop af
;   ret

; ShowDbgRegisters:
;   push af
;   push bc
;   push de
;   push hl

;   ld hl, (CURSORPOS) ; Save current cursor position
;   ld (TMP_CURSOR_POS), hl ; Temp location for old cursor position

;   ld de, REGS_CURSOR_POS
;   call SetCursorPos

;   pop hl                  ; Load back original register values at start of the subroutine
;   pop de
;   push de
;   push hl

;   call ShowRegisters
;   ;call ReadKey

;   ld hl, (TMP_CURSOR_POS) ; Restore old cursor position
;   ld (CURSORPOS), hl
;   pop hl
;   pop de
;   pop bc
;   pop af
;   ret

; TODO Change or remove MSG_LINE_CPOS
MSG_LINE_CPOS = $2FF0;VIDEORAM + $1E0

InitHelper:
  ld a, $01
  ld (ASMOPTFLAG), a
  ld (ASMPASSNO), a
  ld hl, VIDEORAM + $1E0
  ld (MSG_LINE_CPOS), hl
  ret

SetCursorPos:
  ld hl, CURSORPOS
  ld (hl), e                ; ld (hl), de
  inc hl
  ld (hl), d
  ret

ShowDbgWord:                ; BC = value to print
  push af
  push hl
  push de
  ld hl, (CURSORPOS)        ; Save current cursor position
  push hl
  ld hl, (MSG_LINE_CPOS)
  call ClearLine            ; Clear msg line before executing the command

  ld de, (MSG_LINE_CPOS)
  call SetCursorPos

  ld h, b                   ; HL = BC
  ld l, c
  call PrintHex16
  call ReadKey
  pop hl
  ld (CURSORPOS), hl
  pop de
  pop hl
  pop af
  ret

ShowDbgByte:                ; A = value to print
  push bc
  push hl
  ld hl, (CURSORPOS)        ; Save current cursor position
  push hl                   ; Save cursor position
  push de
  push af
  ld hl, (MSG_LINE_CPOS)
  call ClearLine            ; Clear msg line before executing the command

  ld de, (MSG_LINE_CPOS)
  call SetCursorPos

  pop af
  call PrintAHex8
  pop de
  pop hl                    ; Restore cursor position
  ld (CURSORPOS), hl
  pop hl
  pop bc
  ret

  MACRO ShowByte value
    push af
    ld a, value
    call ShowDbgByte
    pop af
  ENDM

  MACRO ShowByte2
    push af
    call ShowDbgByte
    pop af
  ENDM

  MACRO ShowByteInc
    push af
    push hl
    call ShowDbgByte
    ld hl, (MSG_LINE_CPOS)
    inc hl
    inc hl
    ld (MSG_LINE_CPOS), hl
    pop hl
    pop af
  ENDM
;-------------------

  ; push bc
  ; ld bc, hl
  ; call ShowDbgWord
  ; pop bc

  ; call ShowDbgByte
  ; call ReadKey

; Usage example:

  ;include "gad-helper.asm"

  ; call InitHelper
  ; call usb__get_version
  ; call ShowDbgByte
  ; ret