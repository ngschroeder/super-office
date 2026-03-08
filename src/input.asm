; ============================================================================
; input.asm — Mouse Protocol + Joypad Fallback Input System
;
; Provides a unified interface:
;   cursor_x (16-bit), cursor_y (16-bit)
;   click_new (flag), click_held (flag)
;   input_device (0=joypad, 1=mouse)
;
; Auto-joypad is DISABLED. All reads are manual via serial latch+clock.
; This avoids Mesen emulation issues with serial state after auto-joypad.
;
; Reference: Mario Paint bank1.asm L00D9E1, input-peripherals.md §2-§3
; ============================================================================

; ============================================================================
; read_input — Main input entry point. Called from main loop.
; Manually latches and reads the serial port. Detects mouse vs joypad
; and dispatches accordingly.
; Assumes: 8-bit A/X/Y (sep #$30)
; ============================================================================
read_input:
    .ACCU 8
    .INDEX 8
    ; --- Manual latch strobe ---
    lda #$01
    sta JOYSER0.w                ; Latch high — capture controller state
    stz JOYSER0.w                ; Latch low — begin serial clocking

    ; --- Read 16 serial bits into joy_current_h (byte 1) / joy_current_l (byte 2) ---
    ; First 8 serial reads → joy_current_h (equivalent to JOY1H)
    ; Next 8 serial reads → joy_current_l (equivalent to JOY1L)
    stz joy_current_h.w
    stz joy_current_l.w

    ldy #$08
@read_byte1:
    lda JOYSER0.w                ; Read serial bit (bit 0 = Data1)
    lsr A                        ; Shift bit 0 into carry
    rol joy_current_h.w          ; Rotate carry into result MSB-first
    dey
    bne @read_byte1

    ldy #$08
@read_byte2:
    lda JOYSER0.w
    lsr A
    rol joy_current_l.w
    dey
    bne @read_byte2

    ; --- Check device signature in byte 2 (joy_current_l) ---
    ; Joypad: JOY1L = AXlr 0000  → low nibble = $0
    ; Mouse:  JOY1L = RL SS 0001 → low nibble = $1
    lda joy_current_l.w
    and #$0F
    cmp #MOUSE_SIGNATURE         ; $01 = mouse
    beq @mouse_detected

    ; --- No mouse: use joypad ---
    lda #INPUT_JOYPAD
    sta input_device.w
    jsr read_joypad
    jmp @update_click

@mouse_detected:
    lda #INPUT_MOUSE
    sta input_device.w
    jsr read_mouse

@update_click:
    ; --- Update unified click flags ---
    lda input_device.w
    bne @mouse_click

    ; Joypad: A button = click
    lda joy_new_l.w
    and #JOY_A
    beq @no_new_click_jp
    lda #$01
    sta click_new.w
    bra @check_held_jp
@no_new_click_jp:
    stz click_new.w
@check_held_jp:
    lda joy_current_l.w
    and #JOY_A
    beq @no_held_jp
    lda #$01
    sta click_held.w
    rts
@no_held_jp:
    stz click_held.w
    rts

@mouse_click:
    ; Mouse: left button from mouse_buttons bit 0
    lda mouse_buttons.w
    and #$01                     ; Left button
    beq @no_held_mouse
    lda #$01
    sta click_held.w
    bra @check_new_mouse
@no_held_mouse:
    stz click_held.w
@check_new_mouse:
    ; New click = current AND NOT previous
    lda mouse_buttons.w
    and #$01
    tax                          ; X = current left button state
    lda mouse_old_btns.w
    and #$01
    eor #$01                     ; Invert: 1 if was NOT pressed
    stx $00                      ; temp
    and $00                      ; AND with current = newly pressed
    sta click_new.w
    rts

; ============================================================================
; read_joypad — Process standard joypad input with edge detection
; Updates cursor position based on d-pad with acceleration.
; Reference: B.O.B. joystick.a, WW2 bank0.asm L0005A4
; Assumes: 8-bit A/X/Y
; ============================================================================
read_joypad:
    .ACCU 8
    .INDEX 8
    ; --- Edge detection: new = (current XOR previous) AND current ---
    lda joy_current_l.w
    eor joy_previous_l.w
    and joy_current_l.w
    sta joy_new_l.w

    lda joy_current_h.w
    eor joy_previous_h.w
    and joy_current_h.w
    sta joy_new_h.w

    ; --- Save current as previous for next frame ---
    lda joy_current_l.w
    sta joy_previous_l.w
    lda joy_current_h.w
    sta joy_previous_h.w

    ; --- Determine cursor speed (acceleration after holding d-pad) ---
    ; Check if any d-pad direction is held
    lda joy_current_h.w
    and #(JOY_UP | JOY_DOWN | JOY_LEFT | JOY_RIGHT)
    beq @reset_hold
    ; D-pad is held — increment hold counter
    lda dpad_hold_count.w
    cmp #CURSOR_ACCEL_DELAY
    bcs @use_fast                ; Already past threshold
    inc dpad_hold_count.w
    bra @use_slow
@reset_hold:
    stz dpad_hold_count.w
@use_slow:
    lda #CURSOR_SPEED_SLOW       ; 2 px/frame
    bra @move_cursor
@use_fast:
    lda #CURSOR_SPEED_FAST       ; 4 px/frame

@move_cursor:
    ; A = speed (2 or 4)
    sta $00                      ; temp: speed

    ; --- Move cursor based on d-pad ---
    ; Right
    lda joy_current_h.w
    and #JOY_RIGHT
    beq @check_left
    rep #$20                     ; 16-bit A
    .ACCU 16
    lda cursor_x.w
    clc
    adc $00                      ; Add speed (8-bit value, zero-extended)
    cmp #CURSOR_MAX_X+1
    bcc @store_x
    lda #CURSOR_MAX_X            ; Clamp to max
@store_x:
    sta cursor_x.w
    sep #$20                     ; 8-bit A
    .ACCU 8
    bra @check_up

@check_left:
    lda joy_current_h.w
    and #JOY_LEFT
    beq @check_up
    rep #$20                     ; 16-bit A
    .ACCU 16
    lda cursor_x.w
    sec
    sbc $00
    bpl @store_x2                ; If >= 0, store
    lda #CURSOR_MIN_X            ; Clamp to min
@store_x2:
    sta cursor_x.w
    sep #$20                     ; 8-bit A
    .ACCU 8

@check_up:
    lda joy_current_h.w
    and #JOY_UP
    beq @check_down
    rep #$20                     ; 16-bit A
    .ACCU 16
    lda cursor_y.w
    sec
    sbc $00
    bpl @store_y
    lda #CURSOR_MIN_Y
@store_y:
    sta cursor_y.w
    sep #$20                     ; 8-bit A
    .ACCU 8
    rts

@check_down:
    lda joy_current_h.w
    and #JOY_DOWN
    beq @done_joypad
    rep #$20                     ; 16-bit A
    .ACCU 16
    lda cursor_y.w
    clc
    adc $00
    cmp #CURSOR_MAX_Y+1
    bcc @store_y2
    lda #CURSOR_MAX_Y
@store_y2:
    sta cursor_y.w
    sep #$20                     ; 8-bit A
    .ACCU 8

@done_joypad:
    rts

; ============================================================================
; read_mouse — Read mouse displacement from serial port (bytes 3-4)
;
; Called after read_input has already latched and read bytes 1-2.
; The serial port is at bit 16. We read 16 more bits for displacement.
;
; Also extracts button state from joy_current_l (byte 2).
;
; Reference: Mario Paint bank1.asm L00DA4C, input-peripherals.md §3
; Assumes: 8-bit A/X/Y
; ============================================================================
read_mouse:
    .ACCU 8
    .INDEX 8
    ; --- Save previous button state ---
    lda mouse_buttons.w
    sta mouse_old_btns.w

    ; --- Extract button state from byte 2 (joy_current_l) ---
    ; joy_current_l = RL SS 0001
    ; Bit 7 = right button, bit 6 = left button
    stz mouse_buttons.w
    lda joy_current_l.w
    and #$40                     ; Left button (bit 6)
    beq @no_left
    lda #$01                     ; Set bit 0 = left
    sta mouse_buttons.w
@no_left:
    lda joy_current_l.w
    and #$80                     ; Right button (bit 7)
    beq @no_right
    lda mouse_buttons.w
    ora #$02                     ; Set bit 1 = right
    sta mouse_buttons.w
@no_right:

    ; --- Read 8 serial bits: Y displacement (byte 3) ---
    ; Format: [sign] [6:0 magnitude] (signed-magnitude, MSB first)
    stz mouse_dy.w               ; Clear delta accumulators
    stz mouse_dy+1.w

    ldy #$08
@read_y_bit:
    lda JOYSER0.w                ; Read one serial bit (bit 0 = Data1)
    lsr A                        ; Shift bit 0 into carry
    rol mouse_dy.w               ; Rotate carry into result
    dey
    bne @read_y_bit

    ; --- Read 8 serial bits: X displacement (byte 4) ---
    stz mouse_dx.w
    stz mouse_dx+1.w

    ldy #$08
@read_x_bit:
    lda JOYSER0.w
    lsr A
    rol mouse_dx.w
    dey
    bne @read_x_bit

    ; --- Convert signed-magnitude to two's complement ---
    ; Bit 7 = direction (1 = negative: up for Y, left for X)
    ; Bits 6-0 = magnitude

    ; Convert Y delta
    lda mouse_dy.w
    bpl @y_positive              ; Bit 7 clear = positive (down)
    ; Negative (up): magnitude in bits 6-0, negate it
    and #$7F                     ; Mask to magnitude
    beq @y_zero                  ; Magnitude 0 = no movement (avoid -256 bug)
    eor #$FF                     ; One's complement
    inc A                        ; Two's complement
    sta mouse_dy.w
    lda #$FF                     ; Sign-extend to 16-bit
    sta mouse_dy+1.w
    bra @convert_x
@y_zero:
    stz mouse_dy.w
    bra @convert_x
@y_positive:
    and #$7F
    sta mouse_dy.w
    stz mouse_dy+1.w

@convert_x:
    lda mouse_dx.w
    bpl @x_positive
    and #$7F
    beq @x_zero                  ; Magnitude 0 = no movement
    eor #$FF
    inc A
    sta mouse_dx.w
    lda #$FF
    sta mouse_dx+1.w
    bra @apply_deltas
@x_zero:
    stz mouse_dx.w
    bra @apply_deltas
@x_positive:
    and #$7F
    sta mouse_dx.w
    stz mouse_dx+1.w

@apply_deltas:
    ; --- Accumulate deltas into cursor position with clamping ---
    rep #$20                     ; 16-bit A
    .ACCU 16

    ; X position += dx
    lda cursor_x.w
    clc
    adc mouse_dx.w
    bmi @clamp_x_low             ; Negative = off left edge
    cmp #CURSOR_MAX_X+1
    bcc @x_ok
    lda #CURSOR_MAX_X            ; Clamp to right edge
    bra @x_ok
@clamp_x_low:
    lda #CURSOR_MIN_X            ; Clamp to left edge
@x_ok:
    sta cursor_x.w

    ; Y position += dy
    lda cursor_y.w
    clc
    adc mouse_dy.w
    bmi @clamp_y_low
    cmp #CURSOR_MAX_Y+1
    bcc @y_ok
    lda #CURSOR_MAX_Y
    bra @y_ok
@clamp_y_low:
    lda #CURSOR_MIN_Y
@y_ok:
    sta cursor_y.w

    sep #$20                     ; 8-bit A
    .ACCU 8

    ; --- Sensitivity management: cycle to "slow" for next frame ---
    ; joy_current_h = byte 1 = 0000 SS01 (SS = sensitivity in bits 3-2)
    ; Our latch already advanced sensitivity by 1. We need additional
    ; latches so that the NEXT frame's latch will read at "slow" (SS=00).
    ;
    ; After our latch, sensitivity advanced: slow->med, med->fast, fast->slow
    ; If we read slow (00): now at med, need 2 more -> fast->slow  (target)
    ; If we read med  (01): now at fast, need 1 more -> slow       (target)
    ; If we read fast (10): now at slow, need 0 more               (target)
    lda joy_current_h.w
    and #$0C                     ; Mask sensitivity bits 3-2
    beq @sens_2                  ; $00 = slow: need 2 extra latches
    cmp #$04
    beq @sens_1                  ; $04 = medium: need 1 extra latch
    bra @sens_done               ; $08 = fast: already heading to slow

@sens_2:
    lda #$01
    sta JOYSER0.w
    stz JOYSER0.w
@sens_1:
    lda #$01
    sta JOYSER0.w
    stz JOYSER0.w
@sens_done:

    rts
