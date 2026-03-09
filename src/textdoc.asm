; ============================================================================
; textdoc.asm — Text Document Editor (Phase 4)
;
; STATE_TEXTDOC: Full text editor with on-screen keyboard input.
; Uses BG1 for document text (4bpp font), BG3 for keyboard overlay.
;
; Layout:
;   Row 0:     Status bar ("UNTITLED")
;   Rows 1-19: Document text (19 visible rows × 30 columns)
;   Rows 20+:  On-screen keyboard (managed by keyboard.asm)
;
; Document buffer at WRAM $0500, max 2048 bytes.
; Text stored as raw bytes, $0A = newline, $00 = end of document.
; ============================================================================


; ============================================================================
; textdoc_init — Set up the text editor PPU state and buffers
; Called on first frame of STATE_TEXTDOC.
; Assumes: 8-bit A/X/Y
; ============================================================================
textdoc_init:
    .ACCU 8
    .INDEX 8

    ; === Force blank ===
    lda #$8F
    sta INIDISP.w

    ; === Disable HDMA ===
    stz SHADOW_HDMAEN.w
    stz HDMAEN.w

    ; === Clear OAM ===
    jsr clear_oam

    ; === Disable color math ===
    stz SHADOW_CGWSEL.w
    stz CGWSEL.w
    stz SHADOW_CGADSUB.w
    stz CGADSUB.w

    ; === Set backdrop to dark blue ===
    stz CGADD.w
    lda #$00
    sta CGDATA.w
    lda #$28
    sta CGDATA.w

    ; === Upload 4bpp font tiles to BG1 chr (VRAM $0000) ===
    lda #$80
    sta VMAIN.w
    lda #$01                     ; DMA mode 1 (two regs: VMDATAL/H)
    sta DMAP0.w
    lda #$18
    sta BBAD0.w
    lda #:textfont_tiles
    sta A1B0.w

    rep #$20
    .ACCU 16
    lda #VRAM_BG1_CHR
    sta VMADDL.w
    lda #textfont_tiles
    sta A1T0L.w
    lda #textfont_tiles_end - textfont_tiles
    sta DAS0L.w
    sep #$20
    .ACCU 8
    lda #$01
    sta MDMAEN.w

    ; === Upload font palette to CGRAM 0-15 (BG1 sub-palette 0) ===
    stz CGADD.w
    lda #$00                     ; DMA mode 0 (single reg)
    sta DMAP0.w
    lda #$22                     ; CGDATA
    sta BBAD0.w
    lda #:textfont_palette
    sta A1B0.w
    rep #$20
    .ACCU 16
    lda #textfont_palette
    sta A1T0L.w
    lda #textfont_palette_end - textfont_palette
    sta DAS0L.w
    sep #$20
    .ACCU 8
    lda #$01
    sta MDMAEN.w

    ; === Upload box overlay palettes (for file menu/dialogs on BG1) ===
    ; Box normal palette → CGRAM 48-63 (sub-palette 3)
    lda #48
    sta CGADD.w
    lda #:box_palette
    sta A1B0.w
    rep #$20
    .ACCU 16
    lda #box_palette
    sta A1T0L.w
    lda #box_palette_end - box_palette
    sta DAS0L.w
    sep #$20
    .ACCU 8
    lda #$01
    sta MDMAEN.w

    ; Box highlight palette → CGRAM 64-79 (sub-palette 4)
    lda #64
    sta CGADD.w
    lda #:box_pal_highlight
    sta A1B0.w
    rep #$20
    .ACCU 16
    lda #box_pal_highlight
    sta A1T0L.w
    lda #box_pal_highlight_end - box_pal_highlight
    sta DAS0L.w
    sep #$20
    .ACCU 8
    lda #$01
    sta MDMAEN.w

    ; === Clear BG1 tilemap via fixed-source DMA ===
    lda #$80
    sta VMAIN.w
    rep #$20
    .ACCU 16
    lda #VRAM_BG1_MAP
    sta VMADDL.w
    sep #$20
    .ACCU 8
    stz $00                      ; source byte = $00
    lda #$09                     ; fixed source, mode 1
    sta DMAP0.w
    lda #$18
    sta BBAD0.w
    stz A1T0L.w
    stz A1T0H.w
    stz A1B0.w
    rep #$20
    .ACCU 16
    lda #2048                    ; 32×32 tilemap = 2048 bytes
    sta DAS0L.w
    sep #$20
    .ACCU 8
    lda #$01
    sta MDMAEN.w

    ; === Clear BG2 tilemap (remove title screen leftovers) ===
    lda #$80
    sta VMAIN.w
    rep #$20
    .ACCU 16
    lda #VRAM_BG2_MAP
    sta VMADDL.w
    sep #$20
    .ACCU 8
    stz $00
    lda #$09
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

    ; === Clear document buffer (skip if loaded from SRAM) ===
    rep #$20
    .ACCU 16
    lda doc_length.w
    sep #$20
    .ACCU 8
    bne @loaded_from_sram        ; Data loaded from SRAM, don't wipe it

    rep #$30
    .ACCU 16
    .INDEX 16
    lda #$0000
    ldx #DOC_MAX_SIZE - 2
@clear_doc:
    sta DOC_BUF_ADDR.w,X
    dex
    dex
    bpl @clear_doc
    sep #$30
    .ACCU 8
    .INDEX 8

    ; === Initialize document variables ===
    rep #$20
    .ACCU 16
    stz doc_cursor_pos.w
    stz doc_length.w
    sep #$20
    .ACCU 8
    stz doc_scroll_y.w
    stz doc_cursor_col.w
    stz doc_cursor_row.w
    stz doc_num_lines.w
    bra @skip_clear_doc

@loaded_from_sram:
    ; Place cursor at end of document
    rep #$10
    .INDEX 16
    jsr _textdoc_calc_cursor
    jsr _textdoc_adjust_scroll
    sep #$10
    .INDEX 8

@skip_clear_doc:
    stz doc_blink_timer.w
    lda #$01
    sta doc_blink_on.w
    sta doc_dirty.w              ; Force initial render

    ; === PPU config: Mode 1, BG1 + sprites ===
    lda #$01
    sta SHADOW_BGMODE.w
    sta BGMODE.w

    lda #%00010001               ; OBJ + BG1
    sta SHADOW_TM.w
    sta TM.w

    ; === Show on-screen keyboard (adds BG3 to TM) ===
    jsr kbd_show

    ; === Mark initialized ===
    lda #$01
    sta doc_initialized.w

    ; === Start fade in ===
    lda #FADE_IN
    sta fade_dir.w
    stz fade_level.w
    stz SHADOW_INIDISP.w
    stz INIDISP.w

    ; === Start editor music ===
    lda #SONG_EDITOR
    jsr play_music

    rts


; ============================================================================
; state_textdoc — Per-frame handler for the text document editor
; Assumes: 8-bit A/X/Y
; ============================================================================
state_textdoc:
    .ACCU 8
    .INDEX 8

    ; --- Initialize on first frame ---
    lda doc_initialized.w
    bne @td_running
    jsr textdoc_init
    rts

@td_running:
    jsr read_input

    ; --- Handle fade ---
    lda fade_dir.w
    beq @td_no_fade

    cmp #FADE_IN
    bne @td_fade_out

    ; Fade in
    lda fade_level.w
    cmp #$0F
    bcs @td_fade_in_done
    inc A
    sta fade_level.w
    sta SHADOW_INIDISP.w
    jsr kbd_update               ; Keep keyboard highlight in sync during fade
    rts
@td_fade_in_done:
    stz fade_dir.w
    bra @td_no_fade

@td_fade_out:
    ; Fade out
    lda fade_level.w
    beq @td_fade_out_done
    dec A
    sta fade_level.w
    sta SHADOW_INIDISP.w
    rts
@td_fade_out_done:
    stz fade_dir.w
    jsr stop_music
    jsr kbd_hide
    stz doc_initialized.w
    lda #STATE_BOOT
    sta current_state.w
    rts

@td_no_fade:
    ; --- Update keyboard ---
    jsr kbd_update

    ; --- Process character from keyboard ---
    lda kbd_char_out.w
    beq @td_no_char
    jsr _textdoc_process_char

@td_no_char:
    ; --- Render if dirty ---
    lda doc_dirty.w
    beq @td_no_render
    jsr _textdoc_render

@td_no_render:
    ; --- Update cursor blink ---
    jsr _textdoc_blink_cursor

    ; --- Right-click = open file menu ---
    lda rclick_new.w
    beq @td_done
    stz file_type.w              ; 0 = text doc
    jsr fmenu_open
    lda #STATE_FMENU
    sta current_state.w
    rts

@td_done:
    rts


; ============================================================================
; _textdoc_process_char — Handle a character from the on-screen keyboard
; Input: kbd_char_out contains the character
; Assumes: 8-bit A/X/Y
; ============================================================================
_textdoc_process_char:
    .ACCU 8
    .INDEX 8

    lda kbd_char_out.w

    ; Check special codes
    cmp #KEY_BKSP
    beq @proc_backspace
    cmp #KEY_DEL
    beq @proc_delete
    cmp #KEY_ENTER
    beq @proc_enter
    cmp #KEY_SHIFT
    beq @proc_ignore

    ; Printable character ($20-$7E)
    cmp #$20
    bcc @proc_ignore
    cmp #$7F
    bcs @proc_ignore
    jmp _textdoc_insert

@proc_backspace:
    jmp _textdoc_backspace

@proc_delete:
    jmp _textdoc_delete

@proc_enter:
    lda #$0A
    jmp _textdoc_insert

@proc_ignore:
    rts


; ============================================================================
; _textdoc_insert — Insert a character at the cursor position
; Input: A = character to insert
; Assumes: 8-bit A/X/Y
; ============================================================================
_textdoc_insert:
    .ACCU 8
    .INDEX 8

    sta $06                      ; Save character to insert

    ; Check if buffer is full
    rep #$20
    .ACCU 16
    lda doc_length.w
    cmp #DOC_MAX_SIZE - 1
    sep #$20
    .ACCU 8
    bcs @insert_full

    ; Switch to 16-bit index for buffer operations
    rep #$10
    .INDEX 16

    ; Shift bytes right: buffer[cursor_pos..length-1] → buffer[cursor_pos+1..length]
    ldx doc_length.w
@insert_shift:
    cpx doc_cursor_pos.w
    beq @insert_place
    dex
    lda DOC_BUF_ADDR.w,X        ; buffer[X]
    sta DOC_BUF_ADDR+1.w,X      ; buffer[X+1]
    bra @insert_shift

@insert_place:
    ; Store character at cursor position
    ldx doc_cursor_pos.w
    lda $06
    sta DOC_BUF_ADDR.w,X

    ; Increment cursor position and length
    rep #$20
    .ACCU 16
    inc doc_cursor_pos.w
    inc doc_length.w
    sep #$20
    .ACCU 8

    ; Null-terminate buffer
    ldx doc_length.w
    stz DOC_BUF_ADDR.w,X

    ; Recalculate cursor row/col and adjust scroll
    jsr _textdoc_calc_cursor

    ; Word wrap if cursor past right edge
    lda doc_cursor_col.w
    cmp #DOC_VISIBLE_COLS
    bcc @no_wrap
    jsr _textdoc_word_wrap
@no_wrap:

    jsr _textdoc_adjust_scroll

    ; Mark dirty
    lda #$01
    sta doc_dirty.w

    sep #$10
    .INDEX 8

@insert_full:
    rts


; ============================================================================
; _textdoc_backspace — Delete character before cursor
; Assumes: 8-bit A/X/Y
; ============================================================================
_textdoc_backspace:
    .ACCU 8
    .INDEX 8

    ; Check if at beginning
    rep #$20
    .ACCU 16
    lda doc_cursor_pos.w
    beq @bksp_nothing
    sep #$20
    .ACCU 8

    rep #$10
    .INDEX 16

    ; Decrement cursor position
    rep #$20
    .ACCU 16
    dec doc_cursor_pos.w
    sep #$20
    .ACCU 8

    ; Shift bytes left: buffer[cursor_pos+1..length-1] → buffer[cursor_pos..length-2]
    ldx doc_cursor_pos.w
@bksp_shift:
    cpx doc_length.w
    bcs @bksp_shift_done
    lda DOC_BUF_ADDR+1.w,X      ; buffer[X+1]
    sta DOC_BUF_ADDR.w,X        ; buffer[X]
    inx
    bra @bksp_shift
@bksp_shift_done:

    ; Decrement length
    rep #$20
    .ACCU 16
    dec doc_length.w
    sep #$20
    .ACCU 8

    ; Null-terminate
    ldx doc_length.w
    stz DOC_BUF_ADDR.w,X

    ; Recalculate
    jsr _textdoc_calc_cursor
    jsr _textdoc_adjust_scroll

    lda #$01
    sta doc_dirty.w

    sep #$10
    .INDEX 8
    rts

@bksp_nothing:
    sep #$20
    .ACCU 8
    rts


; ============================================================================
; _textdoc_delete — Delete character at cursor (forward delete)
; Assumes: 8-bit A/X/Y
; ============================================================================
_textdoc_delete:
    .ACCU 8
    .INDEX 8

    ; Check if at end
    rep #$20
    .ACCU 16
    lda doc_cursor_pos.w
    cmp doc_length.w
    bcs @del_nothing
    sep #$20
    .ACCU 8

    rep #$10
    .INDEX 16

    ; Shift bytes left starting from cursor_pos
    ldx doc_cursor_pos.w
@del_shift:
    cpx doc_length.w
    bcs @del_shift_done
    lda DOC_BUF_ADDR+1.w,X      ; buffer[X+1]
    sta DOC_BUF_ADDR.w,X        ; buffer[X]
    inx
    bra @del_shift
@del_shift_done:

    ; Decrement length
    rep #$20
    .ACCU 16
    dec doc_length.w
    sep #$20
    .ACCU 8

    ; Null-terminate
    ldx doc_length.w
    stz DOC_BUF_ADDR.w,X

    lda #$01
    sta doc_dirty.w

    sep #$10
    .INDEX 8
    rts

@del_nothing:
    sep #$20
    .ACCU 8
    rts


; ============================================================================
; _textdoc_calc_cursor — Compute cursor row/col from buffer position
; Scans buffer from start to doc_cursor_pos, counting newlines.
; Output: doc_cursor_row, doc_cursor_col
; Assumes: 8-bit A, 16-bit X/Y
; ============================================================================
_textdoc_calc_cursor:
    .ACCU 8
    .INDEX 16

    stz doc_cursor_row.w
    stz doc_cursor_col.w

    ldx #$0000
@calc_scan:
    cpx doc_cursor_pos.w
    bcs @calc_done
    lda DOC_BUF_ADDR.w,X
    cmp #$0A
    bne @calc_not_nl
    inc doc_cursor_row.w
    stz doc_cursor_col.w
    inx
    bra @calc_scan
@calc_not_nl:
    inc doc_cursor_col.w
    inx
    bra @calc_scan
@calc_done:
    rts


; ============================================================================
; _textdoc_adjust_scroll — Ensure cursor is within visible area
; Adjusts doc_scroll_y so cursor row is on screen.
; Assumes: 8-bit A, 16-bit X/Y
; ============================================================================
_textdoc_adjust_scroll:
    .ACCU 8
    .INDEX 16

    ; If cursor_row < scroll_y → scroll up
    lda doc_cursor_row.w
    cmp doc_scroll_y.w
    bcs @adj_check_below
    sta doc_scroll_y.w
    lda #$01
    sta doc_dirty.w
    rts

@adj_check_below:
    ; If cursor_row >= scroll_y + DOC_VISIBLE_ROWS → scroll down
    lda doc_cursor_row.w
    sec
    sbc doc_scroll_y.w           ; A = screen row (cursor_row - scroll_y)
    cmp #DOC_VISIBLE_ROWS
    bcc @adj_ok                  ; Within visible area

    ; Scroll down: scroll_y = cursor_row - DOC_VISIBLE_ROWS + 1
    lda doc_cursor_row.w
    sec
    sbc #DOC_VISIBLE_ROWS - 1
    sta doc_scroll_y.w
    lda #$01
    sta doc_dirty.w

@adj_ok:
    rts


; ============================================================================
; _textdoc_word_wrap — Insert a newline to wrap the current line at col 30
;
; When cursor col >= DOC_VISIBLE_COLS after an insert, this routine:
;   1. Finds the start of the current line in the buffer
;   2. Scans forward to find the last space or post-hyphen break point
;      within the first 30 columns
;   3. If a break point is found: replaces space with $0A (or inserts $0A
;      after hyphen), adjusting buffer and cursor accordingly
;   4. If no break point: inserts $0A at the column boundary (hard break)
;
; Assumes: 8-bit A, 16-bit X/Y (called from _textdoc_insert context)
; ============================================================================
_textdoc_word_wrap:
    .ACCU 8
    .INDEX 16

    ; --- Find the start of the current line ---
    ; Scan backwards from cursor_pos to find preceding newline (or buffer start)
    ldx doc_cursor_pos.w
    bne +                        ; Safety: can't wrap at pos 0
    jmp @wrap_no_room
+   dex                          ; Back up past the char we just inserted
@wrap_find_line_start:
    cpx #$0000
    beq @wrap_got_line_start
    dex
    lda DOC_BUF_ADDR.w,X
    cmp #$0A
    bne @wrap_find_line_start
    inx                          ; Point past the newline
@wrap_got_line_start:
    stx $08                      ; $08-$09 = line start offset

    ; --- Scan forward up to 30 cols to find last break point ---
    ; A break point is: a space (replace with newline) or
    ; the position after a hyphen (insert newline after it)
    ldy #$0000                   ; Y = column counter
    stz $0B                      ; $0B = best break type (0=none, 1=space, 2=after-hyphen)
    ; $0C-$0D = best break buffer offset (16-bit)

@wrap_scan:
    cpy #DOC_VISIBLE_COLS
    bcs @wrap_scan_done
    cpx doc_length.w
    bcs @wrap_scan_done
    lda DOC_BUF_ADDR.w,X
    cmp #$0A
    beq @wrap_scan_done          ; Hit a newline — shouldn't happen but bail

    cmp #$20                     ; Space?
    beq @wrap_found_space
    cmp #$2D                     ; Hyphen?
    beq @wrap_found_hyphen
    bra @wrap_scan_next

@wrap_found_space:
    lda #$01                     ; Type = space (replace with newline)
    sta $0B
    stx $0C                      ; Save offset of space
    bra @wrap_scan_next

@wrap_found_hyphen:
    lda #$02                     ; Type = after-hyphen (insert newline after)
    sta $0B
    inx                          ; Point to position after hyphen
    stx $0C                      ; Save offset after hyphen
    dex                          ; Restore X for scan loop
    bra @wrap_scan_next

@wrap_scan_next:
    inx
    iny
    bra @wrap_scan

@wrap_scan_done:
    ; --- Decide wrap action ---
    lda $0B
    beq @wrap_hard_break         ; No break point found — hard break at col 30

    cmp #$01
    beq @wrap_replace_space

    ; --- Type 2: Insert newline after hyphen ---
    ; Insert $0A at $0C (after the hyphen)
    ldx $0C                      ; Buffer offset for new newline
    jmp @wrap_insert_nl

@wrap_replace_space:
    ; --- Type 1: Replace space with newline ---
    ldx $0C
    lda #$0A
    sta DOC_BUF_ADDR.w,X        ; Replace space with newline

    ; Cursor position doesn't change (it's after the wrapped word)
    ; Recalculate cursor row/col
    jsr _textdoc_calc_cursor
    rts

@wrap_hard_break:
    ; Insert $0A at line_start + 30
    rep #$20
    .ACCU 16
    lda $08                      ; line start
    clc
    adc #DOC_VISIBLE_COLS
    tax
    sep #$20
    .ACCU 8
    ; Fall through to insert newline

@wrap_insert_nl:
    ; --- Insert $0A at buffer position X ---
    ; Check buffer capacity
    rep #$20
    .ACCU 16
    lda doc_length.w
    cmp #DOC_MAX_SIZE - 1
    sep #$20
    .ACCU 8
    bcs @wrap_no_room

    ; Save insert position
    stx $0E                      ; $0E-$0F = newline insert offset

    ; Shift bytes right from insert point
    ldx doc_length.w
@wrap_shift:
    cpx $0E
    beq @wrap_place_nl
    dex
    lda DOC_BUF_ADDR.w,X
    sta DOC_BUF_ADDR+1.w,X
    bra @wrap_shift

@wrap_place_nl:
    ldx $0E
    lda #$0A
    sta DOC_BUF_ADDR.w,X

    ; Increment length and cursor position (newline inserted before cursor)
    rep #$20
    .ACCU 16
    inc doc_length.w

    ; If newline was inserted at or before cursor, bump cursor forward
    lda $0E
    cmp doc_cursor_pos.w
    bcs @wrap_nl_after_cursor
    inc doc_cursor_pos.w
@wrap_nl_after_cursor:
    sep #$20
    .ACCU 8

    ; Null-terminate
    ldx doc_length.w
    stz DOC_BUF_ADDR.w,X

    ; Recalculate cursor
    jsr _textdoc_calc_cursor

@wrap_no_room:
    rts


; ============================================================================
; _textdoc_find_scroll_offset — Find buffer offset for doc_scroll_y
; Skips doc_scroll_y newlines from the start of the buffer.
; Output: X = buffer offset for first visible line
; Assumes: 8-bit A, 16-bit X/Y
; ============================================================================
_textdoc_find_scroll_offset:
    .ACCU 8
    .INDEX 16

    ldx #$0000
    lda doc_scroll_y.w
    beq @scroll_found
    sta $00                      ; $00 = lines to skip

@scroll_skip:
    cpx doc_length.w
    bcs @scroll_found            ; Past end of document
    lda DOC_BUF_ADDR.w,X
    inx
    cmp #$0A
    bne @scroll_skip
    dec $00
    bne @scroll_skip

@scroll_found:
    rts


; ============================================================================
; _textdoc_render — Render visible document text to BG1 tilemap
; Uses force blank to safely write VRAM.
; Assumes: 8-bit A/X/Y
; ============================================================================
_textdoc_render:
    .ACCU 8
    .INDEX 8

    ; === Sync with VBlank, then force blank ===
    wai                          ; Wait for NMI — ensures we start from VBlank
    lda #$8F
    sta INIDISP.w
    lda #$80
    sta VMAIN.w

    ; Switch to 16-bit index
    rep #$10
    .INDEX 16

    ; === Render status bar on row 0 ===
    jsr _textdoc_render_status

    ; === Find buffer offset for first visible line ===
    jsr _textdoc_find_scroll_offset
    ; X = buffer offset

    ; === Render text rows ===
    stz $02                      ; $02 = screen row counter (0 to 18)

@render_row:
    lda $02
    cmp #DOC_VISIBLE_ROWS
    bcs @render_done

    ; Calculate VRAM address for this row
    ; VRAM addr = VRAM_BG1_MAP + (row + DOC_TEXT_START_ROW) * 32 + DOC_TEXT_START_COL
    phx                          ; Save buffer offset
    lda $02
    clc
    adc #DOC_TEXT_START_ROW
    sta $06
    stz $07                      ; $06-$07 = tilemap row (16-bit)

    rep #$20
    .ACCU 16
    lda $06
    asl A
    asl A
    asl A
    asl A
    asl A                        ; × 32
    clc
    adc #VRAM_BG1_MAP + DOC_TEXT_START_COL
    sta VMADDL.w
    sep #$20
    .ACCU 8
    plx                          ; Restore buffer offset

    ; Render characters for this row
    stz $04                      ; $04 = column counter (0 to 29)

@render_char:
    lda $04
    cmp #DOC_VISIBLE_COLS
    bcs @render_truncate         ; Line too long, truncate
    cpx doc_length.w
    bcs @render_pad              ; Past end of document
    lda DOC_BUF_ADDR.w,X
    cmp #$0A
    beq @render_newline          ; End of line

    ; Convert ASCII to tile index
    jsr _char_to_tile
    sta VMDATAL.w
    lda #$20                     ; Priority=1, palette=0
    sta VMDATAH.w
    inx
    inc $04
    bra @render_char

@render_newline:
    inx                          ; Skip the newline byte
    bra @render_pad

@render_truncate:
    ; Skip remaining characters until newline or end of document
@skip_rest:
    cpx doc_length.w
    bcs @render_next_row
    lda DOC_BUF_ADDR.w,X
    inx
    cmp #$0A
    bne @skip_rest
    bra @render_next_row         ; Found newline, move on

@render_pad:
    ; Fill remaining columns with blank tiles
    lda $04
    cmp #DOC_VISIBLE_COLS
    bcs @render_next_row
    stz VMDATAL.w                ; Blank tile
    lda #$20                     ; Priority=1, palette=0
    sta VMDATAH.w
    inc $04
    bra @render_pad

@render_next_row:
    inc $02
    bra @render_row

@render_done:
    ; === Render text cursor ===
    jsr _textdoc_render_cursor

    ; === Restore display ===
    lda SHADOW_INIDISP.w
    sta INIDISP.w

    stz doc_dirty.w

    sep #$10
    .INDEX 8
    rts


; ============================================================================
; _textdoc_render_status — Write filename or "UNTITLED" on row 0 of BG1 tilemap
; Must be called during force blank.
; Assumes: 8-bit A, 16-bit X/Y, VMAIN=$80
; ============================================================================
_textdoc_render_status:
    .ACCU 8
    .INDEX 16

    ; Clear row 0 first
    rep #$20
    .ACCU 16
    lda #VRAM_BG1_MAP
    sta VMADDL.w
    sep #$20
    .ACCU 8
    ldy #32
@clear_status:
    stz VMDATAL.w
    lda #$20
    sta VMDATAH.w
    dey
    bne @clear_status

    ; Check if file has been saved (current_slot != $FF)
    lda current_slot.w
    cmp #$FF
    beq @show_untitled

    ; --- Show filename from save_name_buf ---
    ; Center: col = (32 - save_name_len) / 2
    lda #32
    sec
    sbc save_name_len.w
    lsr A
    ; Set VRAM address = VRAM_BG1_MAP + col
    sta $0E
    stz $0F
    rep #$20
    .ACCU 16
    lda $0E
    clc
    adc #VRAM_BG1_MAP
    sta VMADDL.w
    sep #$20
    .ACCU 8

    ; Write each char from save_name_buf via ascii_to_tile
    ; X/Y are 16-bit; use Y as loop counter, compare via 8-bit A
    ldy #$0000
@status_name_loop:
    tya
    cmp save_name_len.w          ; 8-bit compare: counter vs length
    bcs @status_name_done
    lda save_name_buf.w,Y
    beq @status_name_blank       ; Null byte → blank tile
    cmp #$20
    bcc @status_name_blank       ; Control char → blank tile
    ; Convert ASCII to tile index: subtract $20, look up in table
    sec
    sbc #$20
    phy
    sta $0E
    stz $0F
    ldx $0E
    lda ascii_to_tile.w,X
    ply
    bra @status_name_write
@status_name_blank:
    lda #$00                     ; Tile 0 = blank
@status_name_write:
    sta VMDATAL.w
    lda #$20                     ; Priority=1, PPP=0 (white)
    sta VMDATAH.w
    iny
    bra @status_name_loop
@status_name_done:
    rts

@show_untitled:
    ; Write "UNTITLED" centered at row 0, col 12
    rep #$20
    .ACCU 16
    lda #VRAM_BG1_MAP + 12
    sta VMADDL.w
    sep #$20
    .ACCU 8

    _write_tile_bg1 21            ; U
    _write_tile_bg1 14            ; N
    _write_tile_bg1 20            ; T
    _write_tile_bg1  9            ; I
    _write_tile_bg1 20            ; T
    _write_tile_bg1 12            ; L
    _write_tile_bg1  5            ; E
    _write_tile_bg1  4            ; D

    rts


; ============================================================================
; _textdoc_render_cursor — Draw cursor tile at cursor position on BG1
; Only draws if cursor is within visible area.
; Must be called during force blank.
; Assumes: 8-bit A, 16-bit X/Y, VMAIN=$80
; ============================================================================
_textdoc_render_cursor:
    .ACCU 8
    .INDEX 16

    ; Compute screen row = cursor_row - scroll_y
    lda doc_cursor_row.w
    sec
    sbc doc_scroll_y.w
    bcc @cursor_off              ; Above visible area
    cmp #DOC_VISIBLE_ROWS
    bcs @cursor_off              ; Below visible area

    ; Check if cursor column is within visible area
    lda doc_cursor_col.w
    cmp #DOC_VISIBLE_COLS
    bcs @cursor_off              ; Past right edge

    ; A = cursor column, compute tilemap position
    ; tilemap col = doc_cursor_col + DOC_TEXT_START_COL
    clc
    adc #DOC_TEXT_START_COL
    sta $08
    stz $09                      ; $08-$09 = tilemap col

    ; tilemap row = (cursor_row - scroll_y) + DOC_TEXT_START_ROW
    lda doc_cursor_row.w
    sec
    sbc doc_scroll_y.w
    clc
    adc #DOC_TEXT_START_ROW
    sta $06
    stz $07                      ; $06-$07 = tilemap row

    ; VRAM address = VRAM_BG1_MAP + row*32 + col
    rep #$20
    .ACCU 16
    lda $06
    asl A
    asl A
    asl A
    asl A
    asl A                        ; × 32
    clc
    adc $08
    clc
    adc #VRAM_BG1_MAP
    sta VMADDL.w
    sep #$20
    .ACCU 8

    ; Check blink state
    lda doc_blink_on.w
    beq @cursor_off              ; Cursor hidden this frame

    lda #DOC_CURSOR_TILE
    sta VMDATAL.w
    lda #$20                     ; Priority=1, palette=0
    sta VMDATAH.w

@cursor_off:
    rts


; ============================================================================
; _textdoc_blink_cursor — Toggle cursor visibility every 30 frames
; Writes cursor tile on/off via brief force blank (2 VRAM words).
; Assumes: 8-bit A/X/Y
; ============================================================================
_textdoc_blink_cursor:
    .ACCU 8
    .INDEX 8

    inc doc_blink_timer.w
    lda doc_blink_timer.w
    cmp #30                      ; Toggle every 30 frames (~0.5 sec)
    bcc @blink_no_toggle
    ; Reset timer and toggle
    stz doc_blink_timer.w
    lda doc_blink_on.w
    eor #$01
    sta doc_blink_on.w
    jmp _textdoc_blink_write     ; Write the updated cursor state
@blink_no_toggle:
    rts

; --- Separated to avoid branch distance issues ---
_textdoc_blink_write:
    .ACCU 8
    .INDEX 8

    rep #$10
    .INDEX 16

    ; Compute screen row — bail out if off screen
    lda doc_cursor_row.w
    sec
    sbc doc_scroll_y.w
    bcs +
    jmp @bw_done                 ; Off screen (above)
+   cmp #DOC_VISIBLE_ROWS
    bcc +
    jmp @bw_done                 ; Off screen (below)
+
    lda doc_cursor_col.w
    cmp #DOC_VISIBLE_COLS
    bcc +
    jmp @bw_done                 ; Past right edge
+

    ; Calculate VRAM address
    lda doc_cursor_col.w
    clc
    adc #DOC_TEXT_START_COL
    sta $08
    stz $09

    lda doc_cursor_row.w
    sec
    sbc doc_scroll_y.w
    clc
    adc #DOC_TEXT_START_ROW
    sta $06
    stz $07

    rep #$20
    .ACCU 16
    lda $06
    asl A
    asl A
    asl A
    asl A
    asl A
    clc
    adc $08
    clc
    adc #VRAM_BG1_MAP
    sta $0A                      ; Save VRAM address

    sep #$20
    .ACCU 8

    ; Determine tile + attr to write
    lda doc_blink_on.w
    beq @bw_show_char

    ; Show cursor tile
    lda #DOC_CURSOR_TILE
    sta $0C                      ; tile
    bra @bw_queue

@bw_show_char:
    ; Show the actual character at cursor position (or blank if at end)
    ldx doc_cursor_pos.w
    cpx doc_length.w
    bcs @bw_blank
    lda DOC_BUF_ADDR.w,X
    cmp #$0A
    beq @bw_blank
    jsr _char_to_tile
    sta $0C                      ; tile
    bra @bw_queue

@bw_blank:
    stz $0C                      ; tile = 0 (blank)

@bw_queue:
    ; Queue the VRAM write for NMI handler (no force blank needed)
    lda vram_wq_count.w
    asl A
    asl A                        ; ×4 = byte offset
    tax
    rep #$20
    .ACCU 16
    lda $0A                      ; VRAM address
    sta vram_wq_data.w,X
    sep #$20
    .ACCU 8
    lda $0C                      ; tile
    sta vram_wq_data+2.w,X
    lda #$20                     ; attr (palette 2 = white text)
    sta vram_wq_data+3.w,X
    inc vram_wq_count.w

@bw_done:
    sep #$10
    .INDEX 8
    rts


; ============================================================================
; _char_to_tile — Convert ASCII character to tile index
; Input:  A = ASCII character (8-bit)
; Output: A = tile index (8-bit)
; Assumes: 8-bit A, 16-bit X/Y
; ============================================================================
_char_to_tile:
    .ACCU 8
    .INDEX 16

    sec
    sbc #$20                     ; ASCII 32 = table index 0
    bcc @blank_ct                ; Below space
    cmp #96                      ; Table has 96 entries
    bcs @blank_ct                ; Above 127

    ; Zero-extend to 16-bit index
    sta $0E
    stz $0F
    phx
    ldx $0E
    lda ascii_to_tile.w,X
    plx
    rts

@blank_ct:
    lda #$00
    rts
