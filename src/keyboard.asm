; ============================================================================
; keyboard.asm — On-Screen Keyboard Overlay (BG3)
;
; 16x16 graphical keys with 3D raised look (white face, gray shadow).
; Characters are 2x horizontally scaled for readability.
; Show/hide via kbd_show / kbd_hide. Per-frame update via kbd_update.
; Mouse click selects keys, hover highlights (yellow). Output: kbd_char_out.
;
; SHIFT toggles case output; display always shows uppercase letters.
; Shift only visually changes digit/symbol keys.
;
; 4 sub-palettes: 0=normal, 1=hover, 2=shift-active, 3=spacebar.
; ============================================================================

; ============================================================================
; kbd_show — Upload tiles, build tilemap, enable BG3
; Assumes: 8-bit A/X/Y
; ============================================================================
kbd_show:
    .ACCU 8
    .INDEX 8

    lda kbd_visible.w
    beq @do_show
    rts
@do_show:

    ; === Force blank for VRAM uploads ===
    lda #$8F
    sta INIDISP.w

    ; === Upload ALL keyboard tiles (old 8x8 + new 16x16) to VRAM_BG3_CHR ===
    lda #$80
    sta VMAIN.w
    lda #$01                     ; DMA mode 1 (two regs)
    sta DMAP0.w
    lda #$18
    sta BBAD0.w
    lda #:kbd_tiles
    sta A1B0.w

    rep #$20
    .ACCU 16
    lda #VRAM_BG3_CHR
    sta VMADDL.w
    lda #kbd_tiles
    sta A1T0L.w
    lda #kbd_tiles_end - kbd_tiles
    sta DAS0L.w
    sep #$20
    .ACCU 8
    lda #$01
    sta MDMAEN.w

    ; === Build BG3 tilemap ===
    jsr _kbd_build_tilemap

    ; === Upload keyboard palette to CGRAM 0-15 (4 sub-palettes, 32 bytes) ===
    stz CGADD.w
    lda #$00
    sta DMAP0.w                  ; Mode 0 (single reg)
    lda #$22
    sta BBAD0.w                  ; CGDATA
    lda #:kbd_palette
    sta A1B0.w
    rep #$20
    .ACCU 16
    lda #kbd_palette
    sta A1T0L.w
    lda #kbd_palette_end - kbd_palette
    sta DAS0L.w
    sep #$20
    .ACCU 8
    lda #$01
    sta MDMAEN.w

    ; === Enable BG3 on main screen ===
    lda SHADOW_TM.w
    ora #%00000100               ; Bit 2 = BG3
    sta SHADOW_TM.w
    sta TM.w

    ; === Set Mode 1 with BG3 priority ===
    lda #$09                     ; Mode 1 + BG3 priority
    sta SHADOW_BGMODE.w
    sta BGMODE.w

    ; === Initialize keyboard state ===
    stz kbd_cursor_col.w
    stz kbd_cursor_row.w
    stz kbd_old_col.w
    stz kbd_old_row.w
    stz kbd_shift.w
    stz kbd_char_out.w
    lda #$01
    sta kbd_dirty.w              ; Force initial highlight

    lda #$01
    sta kbd_visible.w

    ; === Restore display ===
    lda SHADOW_INIDISP.w
    sta INIDISP.w

    rts


; ============================================================================
; kbd_hide — Disable BG3, restore BG mode
; Assumes: 8-bit A/X/Y
; ============================================================================
kbd_hide:
    .ACCU 8
    .INDEX 8

    lda kbd_visible.w
    beq @already_hidden

    ; Disable BG3
    lda SHADOW_TM.w
    and #%11111011               ; Clear bit 2
    sta SHADOW_TM.w

    ; Restore standard Mode 1 (no BG3 priority)
    lda #$01
    sta SHADOW_BGMODE.w

    stz kbd_visible.w
    stz kbd_char_out.w

@already_hidden:
    rts


; ============================================================================
; kbd_update — Per-frame keyboard input processing
; Assumes: 8-bit A/X/Y
; ============================================================================
kbd_update:
    .ACCU 8
    .INDEX 8

    lda kbd_visible.w
    bne @visible
    rts
@visible:

    stz kbd_char_out.w           ; Clear output each frame

    ; --- Check for mouse click on keyboard ---
    lda click_new.w
    beq @check_mouse_hover
    jsr _kbd_check_click
    lda kbd_char_out.w
    bne @update_highlight        ; Got a key press from click

@check_mouse_hover:
    jsr _kbd_mouse_to_grid

@update_highlight:
    ; --- Update tilemap highlight if cursor moved ---
    lda kbd_dirty.w
    beq @done
    jsr _kbd_update_highlight
    stz kbd_dirty.w

@done:
    rts


; ============================================================================
; _kbd_check_click — Check if mouse click hits a keyboard key
; 16x16 keys: row = (Y-160)/16, col = X/16
; Rows 0-2: Y 160-207. Row 3 (spacebar): Y 208-223.
; Assumes: 8-bit A/X/Y
; ============================================================================
_kbd_check_click:
    .ACCU 8
    .INDEX 8

    ; Check Y bounds: must be in keyboard area (>= 160)
    lda cursor_y+1.w            ; High byte of 16-bit cursor_y
    bne @miss                    ; > 255 impossible, but safety check
    lda cursor_y.w
    cmp #KBD_PIXEL_Y             ; 160
    bcc @miss
    ; Compute row = (cursor_y - 160) / 16
    sec
    sbc #KBD_PIXEL_Y
    lsr A
    lsr A
    lsr A
    lsr A                        ; / 16
    cmp #4
    bcs @miss                    ; Row >= 4 means below keyboard
    sta kbd_cursor_row.w

    ; Compute col = cursor_x / 16
    lda cursor_x.w
    lsr A
    lsr A
    lsr A
    lsr A                        ; / 16
    sta kbd_cursor_col.w

    lda #$01
    sta kbd_dirty.w

    ; Press the key
    jsr _kbd_press_key
    rts

@miss:
    rts


; ============================================================================
; _kbd_mouse_to_grid — Update keyboard highlight from mouse position
; 16x16 keys: row = (Y-160)/16, col = X/16
; Assumes: 8-bit A/X/Y
; ============================================================================
_kbd_mouse_to_grid:
    .ACCU 8
    .INDEX 8

    ; Check Y bounds
    lda cursor_y+1.w
    bne @out
    lda cursor_y.w
    cmp #KBD_PIXEL_Y             ; 160
    bcc @out
    ; Compute row
    sec
    sbc #KBD_PIXEL_Y
    lsr A
    lsr A
    lsr A
    lsr A
    cmp #4
    bcs @out
    ; Check if row changed
    cmp kbd_cursor_row.w
    beq @check_col
    sta kbd_cursor_row.w
    lda #$01
    sta kbd_dirty.w

@check_col:
    ; Compute col = cursor_x / 16
    lda cursor_x.w
    lsr A
    lsr A
    lsr A
    lsr A
    cmp kbd_cursor_col.w
    beq @same
    sta kbd_cursor_col.w
    lda #$01
    sta kbd_dirty.w
@same:
    rts

@out:
    rts


; ============================================================================
; _kbd_press_key — Look up character for current cursor position
; Handles SHIFT toggle. Row 3 = spacebar.
; Assumes: 8-bit A/X/Y
; ============================================================================
_kbd_press_key:
    .ACCU 8
    .INDEX 8

    ; Validate cursor position
    lda kbd_cursor_row.w
    cmp #4
    bcs @done
    lda kbd_cursor_col.w
    cmp #16
    bcs @done

    ; Compute table offset = row * 16 + col
    lda kbd_cursor_row.w
    asl A
    asl A
    asl A
    asl A                        ; row * 16
    ora kbd_cursor_col.w         ; + col
    tax

    ; Pick lowercase or uppercase char table
    lda kbd_shift.w
    bne @shift_table

    lda kbd_char_lo_row0.w,X
    bra @got_char

@shift_table:
    lda kbd_char_hi_row0.w,X

@got_char:
    ; $00 = no action (blank spacebar positions)
    beq @done

    ; Check for SHIFT toggle code
    cmp #KEY_SHIFT
    beq @toggle_shift

    ; Store character output
    sta kbd_char_out.w
    ; Play key click sound effect
    lda #SFX_KEY_CLICK
    jsr play_sfx

@done:
    rts

@toggle_shift:
    lda kbd_shift.w
    eor #$01
    sta kbd_shift.w
    ; Rebuild tilemap to show new key labels
    jsr _kbd_rebuild_keys
    stz kbd_char_out.w           ; No character output for toggle
    rts


; ============================================================================
; _kbd_build_tilemap — Build the full BG3 tilemap in VRAM
; Must be called during force blank.
; Assumes: 8-bit A/X/Y
; ============================================================================
_kbd_build_tilemap:
    .ACCU 8
    .INDEX 8

    lda #$80
    sta VMAIN.w

    ; --- Zero the entire BG3 tilemap ---
    rep #$20
    .ACCU 16
    lda #VRAM_BG3_MAP
    sta VMADDL.w
    sep #$20
    .ACCU 8

    stz $00
    lda #$09                     ; Fixed source, mode 1
    sta DMAP0.w
    lda #$18
    sta BBAD0.w
    stz A1T0L.w
    stz A1T0H.w
    stz A1B0.w
    rep #$20
    .ACCU 16
    lda #2048
    sta DAS0L.w
    sep #$20
    .ACCU 8
    lda #$01
    sta MDMAEN.w

    ; --- Write key rows (16x16 tiles, 2 tilemap rows per key row) ---
    jsr _kbd_write_key_rows

    ; --- Apply shift key palette if shift is active ---
    jsr _kbd_apply_shift_pal

    rts


; ============================================================================
; _kbd_write_key_rows — Write all 4 key rows to BG3 tilemap VRAM
; Each key row uses 2 tilemap rows (top: TL/TR shared, bottom: BL/BR unique).
; Rows 0-2: letter/symbol keys. Row 3: spacebar (hardcoded).
; Must be called during force blank or VBlank.
; Assumes: 8-bit A/X/Y
; ============================================================================
_kbd_write_key_rows:
    .ACCU 8
    .INDEX 8

    ; ===================== Key Row 0: tilemap rows 20-21 =====================

    ; --- Top tiles (row 20): alternating TL/TR for 16 keys = 32 tiles ---
    rep #$20
    .ACCU 16
    lda #VRAM_BG3_MAP + (20 * 32)
    sta VMADDL.w
    sep #$20
    .ACCU 8

    ldx #16                      ; 16 keys
@r0_top:
    lda #KBD16_TL
    sta VMDATAL.w
    lda #$00                     ; Priority=0, PPP=0
    sta VMDATAH.w
    lda #KBD16_TR
    sta VMDATAL.w
    lda #$00
    sta VMDATAH.w
    dex
    bne @r0_top

    ; --- Bottom tiles (row 21): BL/BR per key from tile table ---
    rep #$20
    .ACCU 16
    lda #VRAM_BG3_MAP + (21 * 32)
    sta VMADDL.w
    sep #$20
    .ACCU 8

    lda kbd_shift.w
    bne @r0_bot_hi
    ldy #0
@r0_bot_lo:
    lda kbd_tile_lo_row0.w,Y    ; BL tile index
    sta $00                      ; save BL
    sta VMDATAL.w
    lda #$00
    sta VMDATAH.w
    lda $00
    clc
    adc #1                       ; BR = BL + 1
    sta VMDATAL.w
    lda #$00
    sta VMDATAH.w
    iny
    cpy #KBD_COLS
    bne @r0_bot_lo
    bra @row1

@r0_bot_hi:
    ldy #0
@r0_bot_hi_lp:
    lda kbd_tile_hi_row0.w,Y
    sta $00
    sta VMDATAL.w
    lda #$00
    sta VMDATAH.w
    lda $00
    clc
    adc #1
    sta VMDATAL.w
    lda #$00
    sta VMDATAH.w
    iny
    cpy #KBD_COLS
    bne @r0_bot_hi_lp

    ; ===================== Key Row 1: tilemap rows 22-23 =====================
@row1:
    ; --- Top tiles (row 22) ---
    rep #$20
    .ACCU 16
    lda #VRAM_BG3_MAP + (22 * 32)
    sta VMADDL.w
    sep #$20
    .ACCU 8

    ldx #16
@r1_top:
    lda #KBD16_TL
    sta VMDATAL.w
    lda #$00
    sta VMDATAH.w
    lda #KBD16_TR
    sta VMDATAL.w
    lda #$00
    sta VMDATAH.w
    dex
    bne @r1_top

    ; --- Bottom tiles (row 23) ---
    rep #$20
    .ACCU 16
    lda #VRAM_BG3_MAP + (23 * 32)
    sta VMADDL.w
    sep #$20
    .ACCU 8

    lda kbd_shift.w
    bne @r1_bot_hi
    ldy #0
@r1_bot_lo:
    lda kbd_tile_lo_row1.w,Y
    sta $00
    sta VMDATAL.w
    lda #$00
    sta VMDATAH.w
    lda $00
    clc
    adc #1
    sta VMDATAL.w
    lda #$00
    sta VMDATAH.w
    iny
    cpy #KBD_COLS
    bne @r1_bot_lo
    bra @row2

@r1_bot_hi:
    ldy #0
@r1_bot_hi_lp:
    lda kbd_tile_hi_row1.w,Y
    sta $00
    sta VMDATAL.w
    lda #$00
    sta VMDATAH.w
    lda $00
    clc
    adc #1
    sta VMDATAL.w
    lda #$00
    sta VMDATAH.w
    iny
    cpy #KBD_COLS
    bne @r1_bot_hi_lp

    ; ===================== Key Row 2: tilemap rows 24-25 =====================
@row2:
    ; --- Top tiles (row 24) ---
    rep #$20
    .ACCU 16
    lda #VRAM_BG3_MAP + (24 * 32)
    sta VMADDL.w
    sep #$20
    .ACCU 8

    ldx #16
@r2_top:
    lda #KBD16_TL
    sta VMDATAL.w
    lda #$00
    sta VMDATAH.w
    lda #KBD16_TR
    sta VMDATAL.w
    lda #$00
    sta VMDATAH.w
    dex
    bne @r2_top

    ; --- Bottom tiles (row 25) ---
    rep #$20
    .ACCU 16
    lda #VRAM_BG3_MAP + (25 * 32)
    sta VMADDL.w
    sep #$20
    .ACCU 8

    lda kbd_shift.w
    bne @r2_bot_hi
    ldy #0
@r2_bot_lo:
    lda kbd_tile_lo_row2.w,Y
    sta $00
    sta VMDATAL.w
    lda #$00
    sta VMDATAH.w
    lda $00
    clc
    adc #1
    sta VMDATAL.w
    lda #$00
    sta VMDATAH.w
    iny
    cpy #KBD_COLS
    bne @r2_bot_lo
    bra @row3

@r2_bot_hi:
    ldy #0
@r2_bot_hi_lp:
    lda kbd_tile_hi_row2.w,Y
    sta $00
    sta VMDATAL.w
    lda #$00
    sta VMDATAH.w
    lda $00
    clc
    adc #1
    sta VMDATAL.w
    lda #$00
    sta VMDATAH.w
    iny
    cpy #KBD_COLS
    bne @r2_bot_hi_lp

    ; ===================== Key Row 3: spacebar, tilemap rows 26-27 =====================
@row3:
    ; --- Spacebar top (row 26) ---
    ; Layout: blank(6), SPC_TL(1), SPC_TM(18), SPC_TR(1), blank(6) = 32 tiles
    rep #$20
    .ACCU 16
    lda #VRAM_BG3_MAP + (26 * 32)
    sta VMADDL.w
    sep #$20
    .ACCU 8

    ; 6 blank tiles (left margin: key cols 0-2 = tile cols 0-5)
    ldx #6
@spc_t_blank_l:
    stz VMDATAL.w
    lda #$00
    sta VMDATAH.w
    dex
    bne @spc_t_blank_l

    ; SPC_TL (1 tile, left cap)
    lda #KBD16_SPC_TL
    sta VMDATAL.w
    lda #$0C                     ; Priority=0, PPP=3 (spacebar palette)
    sta VMDATAH.w

    ; SPC_TM (18 tiles, middle)
    ldx #18
@spc_t_mid:
    lda #KBD16_SPC_TM
    sta VMDATAL.w
    lda #$0C
    sta VMDATAH.w
    dex
    bne @spc_t_mid

    ; SPC_TR (1 tile, right cap)
    lda #KBD16_SPC_TR
    sta VMDATAL.w
    lda #$0C
    sta VMDATAH.w

    ; 6 blank tiles (right margin: key cols 13-15 = tile cols 26-31)
    ldx #6
@spc_t_blank_r:
    stz VMDATAL.w
    lda #$00
    sta VMDATAH.w
    dex
    bne @spc_t_blank_r

    ; --- Spacebar bottom (row 27) ---
    ; Layout: blank(6), SPC_BL(1), SPC_BM(5), S,P,A,C,E(5), SPC_BM(7), SPC_BR(1), blank(6)
    rep #$20
    .ACCU 16
    lda #VRAM_BG3_MAP + (27 * 32)
    sta VMADDL.w
    sep #$20
    .ACCU 8

    ; 6 blank tiles
    ldx #6
@spc_b_blank_l:
    stz VMDATAL.w
    lda #$00
    sta VMDATAH.w
    dex
    bne @spc_b_blank_l

    ; SPC_BL (left cap)
    lda #KBD16_SPC_BL
    sta VMDATAL.w
    lda #$0C
    sta VMDATAH.w

    ; 5 blank middle tiles
    ldx #5
@spc_b_mid1:
    lda #KBD16_SPC_BM
    sta VMDATAL.w
    lda #$0C
    sta VMDATAH.w
    dex
    bne @spc_b_mid1

    ; "SPACE" letters (5 tiles)
    lda #KBD16_SPC_S
    sta VMDATAL.w
    lda #$0C
    sta VMDATAH.w
    lda #KBD16_SPC_P
    sta VMDATAL.w
    lda #$0C
    sta VMDATAH.w
    lda #KBD16_SPC_A
    sta VMDATAL.w
    lda #$0C
    sta VMDATAH.w
    lda #KBD16_SPC_C
    sta VMDATAL.w
    lda #$0C
    sta VMDATAH.w
    lda #KBD16_SPC_E
    sta VMDATAL.w
    lda #$0C
    sta VMDATAH.w

    ; 7 blank middle tiles
    ldx #7
@spc_b_mid2:
    lda #KBD16_SPC_BM
    sta VMDATAL.w
    lda #$0C
    sta VMDATAH.w
    dex
    bne @spc_b_mid2

    ; SPC_BR (right cap)
    lda #KBD16_SPC_BR
    sta VMDATAL.w
    lda #$0C
    sta VMDATAH.w

    ; 6 blank tiles
    ldx #6
@spc_b_blank_r:
    stz VMDATAL.w
    lda #$00
    sta VMDATAH.w
    dex
    bne @spc_b_blank_r

    rts


; ============================================================================
; _kbd_apply_shift_pal — Set SHIFT key tiles to palette 2 if shift active
; SHIFT key is at key row 2, col 0 → tilemap rows 24-25, cols 0-1.
; Must be called during force blank or VBlank (writes VRAM directly).
; Assumes: 8-bit A/X/Y, VMAIN=$80
; ============================================================================
_kbd_apply_shift_pal:
    .ACCU 8
    .INDEX 8

    lda kbd_shift.w
    beq @no_shift

    lda #$80
    sta VMAIN.w

    ; TL at row 24, col 0
    rep #$20
    .ACCU 16
    lda #VRAM_BG3_MAP + (24 * 32) + 0
    sta VMADDL.w
    sep #$20
    .ACCU 8
    lda #KBD16_TL
    sta VMDATAL.w
    lda #$08                     ; Priority=0, PPP=2 (shift palette)
    sta VMDATAH.w

    ; TR at row 24, col 1
    lda #KBD16_TR
    sta VMDATAL.w                ; VMAIN auto-incremented to col 1
    lda #$08
    sta VMDATAH.w

    ; BL at row 25, col 0
    rep #$20
    .ACCU 16
    lda #VRAM_BG3_MAP + (25 * 32) + 0
    sta VMADDL.w
    sep #$20
    .ACCU 8
    lda #204                     ; ↑ shift BL tile
    sta VMDATAL.w
    lda #$08
    sta VMDATAH.w

    ; BR at row 25, col 1
    lda #205                     ; ↑ shift BR tile
    sta VMDATAL.w
    lda #$08
    sta VMDATAH.w

@no_shift:
    rts


; ============================================================================
; _kbd_rebuild_keys — Rebuild key rows after SHIFT toggle
; Assumes: 8-bit A/X/Y
; ============================================================================
_kbd_rebuild_keys:
    .ACCU 8
    .INDEX 8

    wai                          ; Sync with VBlank first
    lda #$8F
    sta INIDISP.w

    lda #$80
    sta VMAIN.w

    jsr _kbd_write_key_rows

    ; Apply shift key palette (blue if active)
    jsr _kbd_apply_shift_pal

    ; Force highlight update next frame
    lda #$01
    sta kbd_dirty.w

    lda SHADOW_INIDISP.w
    sta INIDISP.w
    rts


; ============================================================================
; _kbd_update_highlight — Update tilemap palette for old and new cursor pos
; For rows 0-2: queue 4 VRAM writes per key (TL,TR,BL,BR) to change palette.
; For row 3 (spacebar): queue 2 CGRAM writes to change spacebar sub-palette 3.
; Assumes: 8-bit A/X/Y
; ============================================================================
_kbd_update_highlight:
    .ACCU 8
    .INDEX 8

    ; === If both old and new are spacebar (row 3), skip — already highlighted ===
    lda kbd_old_row.w
    cmp #$03
    bcc +
    lda kbd_cursor_row.w
    cmp #$03
    bcc +
    jmp @save_old                ; Both on spacebar, nothing to change
+

    ; === Unhighlight old position ===
    lda kbd_old_row.w
    cmp #$03
    bcc +
    jmp @unhighlight_spacebar
+

    ; --- Unhighlight regular key (rows 0-2): 4 VRAM writes ---
    ; Determine attribute for old position
    lda #$00                     ; Priority=0, PPP=0 (normal)
    ; Check if old position is SHIFT key (row 2, col 0) AND shift active
    ldx kbd_old_row.w
    cpx #$02
    bne @old_attr_ok
    ldx kbd_old_col.w
    bne @old_attr_ok
    ldx kbd_shift.w
    beq @old_attr_ok
    lda #$08                     ; Priority=0, PPP=2 (shift palette)
@old_attr_ok:
    sta $0A                      ; $0A = old attribute byte

    ; Get BL tile for old position
    lda kbd_old_row.w
    asl A
    asl A
    asl A
    asl A
    ora kbd_old_col.w
    tax
    lda kbd_shift.w
    bne @old_tile_hi
    lda kbd_tile_lo_row0.w,X
    bra @old_tile_got
@old_tile_hi:
    lda kbd_tile_hi_row0.w,X
@old_tile_got:
    sta $04                      ; $04 = old BL tile

    ; Compute base VRAM address for old key
    ; base = VRAM_BG3_MAP + (KBD_MAP_START_ROW + row*2) * 32 + col*2
    jsr _kbd_calc_key_vram_old
    ; $06-$07 = base VRAM address (TL position)

    ; Queue 4 writes: TL, TR, BL, BR
    lda vram_wq_count.w
    asl A
    asl A
    tax

    ; TL (base + 0)
    rep #$20
    .ACCU 16
    lda $06
    sta vram_wq_data.w,X
    sep #$20
    .ACCU 8
    lda #KBD16_TL
    sta vram_wq_data+2.w,X
    lda $0A                      ; old attr
    sta vram_wq_data+3.w,X
    inx
    inx
    inx
    inx

    ; TR (base + 1)
    rep #$20
    .ACCU 16
    lda $06
    clc
    adc #1
    sta vram_wq_data.w,X
    sep #$20
    .ACCU 8
    lda #KBD16_TR
    sta vram_wq_data+2.w,X
    lda $0A
    sta vram_wq_data+3.w,X
    inx
    inx
    inx
    inx

    ; BL (base + 32)
    rep #$20
    .ACCU 16
    lda $06
    clc
    adc #32
    sta vram_wq_data.w,X
    sep #$20
    .ACCU 8
    lda $04                      ; BL tile
    sta vram_wq_data+2.w,X
    lda $0A
    sta vram_wq_data+3.w,X
    inx
    inx
    inx
    inx

    ; BR (base + 33)
    rep #$20
    .ACCU 16
    lda $06
    clc
    adc #33
    sta vram_wq_data.w,X
    sep #$20
    .ACCU 8
    lda $04
    clc
    adc #1                       ; BR = BL + 1
    sta vram_wq_data+2.w,X
    lda $0A
    sta vram_wq_data+3.w,X

    lda vram_wq_count.w
    clc
    adc #4
    sta vram_wq_count.w
    bra @do_highlight

@unhighlight_spacebar:
    ; --- Unhighlight spacebar: write white to sub-palette 3 via CGRAM ---
    lda vram_wq_count.w
    asl A
    asl A
    tax

    ; Color 1 of sub-palette 3 = CGRAM word address 3*4+1 = 13 = $0D
    lda #$0D
    sta vram_wq_data.w,X
    lda #$FF                     ; CGRAM marker
    sta vram_wq_data+1.w,X
    lda #$FF                     ; White low byte ($7FFF & $FF)
    sta vram_wq_data+2.w,X
    lda #$7F                     ; White high byte ($7FFF >> 8)
    sta vram_wq_data+3.w,X
    inx
    inx
    inx
    inx

    ; Color 2 of sub-palette 3 = CGRAM word address 3*4+2 = 14 = $0E
    lda #$0E
    sta vram_wq_data.w,X
    lda #$FF
    sta vram_wq_data+1.w,X
    lda #$4A                     ; Gray low ($294A & $FF)
    sta vram_wq_data+2.w,X
    lda #$29                     ; Gray high ($294A >> 8)
    sta vram_wq_data+3.w,X

    lda vram_wq_count.w
    clc
    adc #2
    sta vram_wq_count.w

    ; === Highlight new position ===
@do_highlight:
    lda kbd_cursor_row.w
    cmp #$03
    bcc +
    jmp @highlight_spacebar
+

    ; --- Highlight regular key (rows 0-2): 4 VRAM writes with PPP=1 ---
    ; Get BL tile for new position
    lda kbd_cursor_row.w
    asl A
    asl A
    asl A
    asl A
    ora kbd_cursor_col.w
    tax
    lda kbd_shift.w
    bne @new_tile_hi
    lda kbd_tile_lo_row0.w,X
    bra @new_tile_got
@new_tile_hi:
    lda kbd_tile_hi_row0.w,X
@new_tile_got:
    sta $05                      ; $05 = new BL tile

    ; Compute base VRAM address for new key
    jsr _kbd_calc_key_vram_cur
    ; $08-$09 = base VRAM address

    lda vram_wq_count.w
    asl A
    asl A
    tax

    ; TL
    rep #$20
    .ACCU 16
    lda $08
    sta vram_wq_data.w,X
    sep #$20
    .ACCU 8
    lda #KBD16_TL
    sta vram_wq_data+2.w,X
    lda #$04                     ; Priority=0, PPP=1 (hover)
    sta vram_wq_data+3.w,X
    inx
    inx
    inx
    inx

    ; TR
    rep #$20
    .ACCU 16
    lda $08
    clc
    adc #1
    sta vram_wq_data.w,X
    sep #$20
    .ACCU 8
    lda #KBD16_TR
    sta vram_wq_data+2.w,X
    lda #$04
    sta vram_wq_data+3.w,X
    inx
    inx
    inx
    inx

    ; BL
    rep #$20
    .ACCU 16
    lda $08
    clc
    adc #32
    sta vram_wq_data.w,X
    sep #$20
    .ACCU 8
    lda $05                      ; new BL tile
    sta vram_wq_data+2.w,X
    lda #$04
    sta vram_wq_data+3.w,X
    inx
    inx
    inx
    inx

    ; BR
    rep #$20
    .ACCU 16
    lda $08
    clc
    adc #33
    sta vram_wq_data.w,X
    sep #$20
    .ACCU 8
    lda $05
    clc
    adc #1
    sta vram_wq_data+2.w,X
    lda #$04
    sta vram_wq_data+3.w,X

    lda vram_wq_count.w
    clc
    adc #4
    sta vram_wq_count.w
    bra @save_old

@highlight_spacebar:
    ; --- Highlight spacebar: write yellow to sub-palette 3 via CGRAM ---
    lda vram_wq_count.w
    asl A
    asl A
    tax

    ; Color 1 → yellow ($03FF)
    lda #$0D
    sta vram_wq_data.w,X
    lda #$FF
    sta vram_wq_data+1.w,X
    lda #$FF                     ; Yellow low ($03FF & $FF)
    sta vram_wq_data+2.w,X
    lda #$03                     ; Yellow high
    sta vram_wq_data+3.w,X
    inx
    inx
    inx
    inx

    ; Color 2 → dark yellow ($01AD)
    lda #$0E
    sta vram_wq_data.w,X
    lda #$FF
    sta vram_wq_data+1.w,X
    lda #$AD                     ; Dark yellow low
    sta vram_wq_data+2.w,X
    lda #$01                     ; Dark yellow high
    sta vram_wq_data+3.w,X

    lda vram_wq_count.w
    clc
    adc #2
    sta vram_wq_count.w

@save_old:
    ; Save current as old
    lda kbd_cursor_col.w
    sta kbd_old_col.w
    lda kbd_cursor_row.w
    sta kbd_old_row.w

    rts


; ============================================================================
; _kbd_calc_key_vram_old — Compute base VRAM address for key at old position
; base = VRAM_BG3_MAP + (KBD_MAP_START_ROW + old_row*2) * 32 + old_col*2
; Result in $06-$07
; Assumes: 8-bit A/X/Y
; ============================================================================
_kbd_calc_key_vram_old:
    .ACCU 8
    .INDEX 8

    lda kbd_old_row.w
    asl A                        ; row * 2
    clc
    adc #KBD_MAP_START_ROW       ; + 20
    sta $00
    stz $01

    lda kbd_old_col.w
    asl A                        ; col * 2
    sta $02
    stz $03

    rep #$20
    .ACCU 16
    lda $00
    and #$00FF
    asl A
    asl A
    asl A
    asl A
    asl A                        ; tilemap_row * 32
    clc
    adc $02
    clc
    adc #VRAM_BG3_MAP
    sta $06
    sep #$20
    .ACCU 8
    rts


; ============================================================================
; _kbd_calc_key_vram_cur — Compute base VRAM address for key at cursor position
; Result in $08-$09
; Assumes: 8-bit A/X/Y
; ============================================================================
_kbd_calc_key_vram_cur:
    .ACCU 8
    .INDEX 8

    lda kbd_cursor_row.w
    asl A
    clc
    adc #KBD_MAP_START_ROW
    sta $00
    stz $01

    lda kbd_cursor_col.w
    asl A
    sta $02
    stz $03

    rep #$20
    .ACCU 16
    lda $00
    and #$00FF
    asl A
    asl A
    asl A
    asl A
    asl A
    clc
    adc $02
    clc
    adc #VRAM_BG3_MAP
    sta $08
    sep #$20
    .ACCU 8
    rts
