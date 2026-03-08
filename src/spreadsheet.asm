; ============================================================================
; spreadsheet.asm — Spreadsheet Editor (Phase 5)
;
; STATE_SHEET: Grid-based cell editor with on-screen keyboard input.
; Uses BG1 for cell grid (4bpp font), BG3 for keyboard overlay.
;
; Layout:
;   Row 0:     Status bar ("SHEET")
;   Row 1:     Column headers (A-H)
;   Rows 2-19: Data rows (18 visible rows × 8 columns × 3 chars)
;   Rows 20+:  On-screen keyboard (managed by keyboard.asm)
;
; Cell buffer at WRAM $0500, 2048 bytes total.
; Each cell: 8 bytes, null-terminated ASCII content.
; Cell address = $0500 + row * 64 + col * 8
; ============================================================================


; ============================================================================
; spreadsheet_init — Set up the spreadsheet PPU state and buffers
; Called on first frame of STATE_SHEET.
; Assumes: 8-bit A/X/Y
; ============================================================================
spreadsheet_init:
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

    ; === Upload font palette to CGRAM 0-15 (sub-palette 0: white text) ===
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

    ; === Upload highlight palette to CGRAM 16-31 (sub-palette 1: yellow) ===
    lda #16
    sta CGADD.w
    lda #$00                     ; DMA mode 0
    sta DMAP0.w
    lda #$22
    sta BBAD0.w
    lda #:sheet_pal_highlight
    sta A1B0.w
    rep #$20
    .ACCU 16
    lda #sheet_pal_highlight
    sta A1T0L.w
    lda #sheet_pal_highlight_end - sheet_pal_highlight
    sta DAS0L.w
    sep #$20
    .ACCU 8
    lda #$01
    sta MDMAEN.w

    ; === Upload header palette to CGRAM 32-47 (sub-palette 2: gray) ===
    lda #32
    sta CGADD.w
    lda #$00                     ; DMA mode 0
    sta DMAP0.w
    lda #$22
    sta BBAD0.w
    lda #:sheet_pal_headers
    sta A1B0.w
    rep #$20
    .ACCU 16
    lda #sheet_pal_headers
    sta A1T0L.w
    lda #sheet_pal_headers_end - sheet_pal_headers
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

    ; === Clear BG2 tilemap ===
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

    ; === Clear cell buffer (skip if loaded from SRAM) ===
    lda current_slot.w
    cmp #$FF
    bne @skip_clear_buf          ; Data loaded from SRAM, don't wipe it

    rep #$30
    .ACCU 16
    .INDEX 16
    lda #$0000
    ldx #DOC_MAX_SIZE - 2        ; Reuse DOC_MAX_SIZE (2048) for buffer size
@clear_buf:
    sta SHEET_BUF_ADDR.w,X
    dex
    dex
    bpl @clear_buf
    sep #$30
    .ACCU 8
    .INDEX 8

    ; === Initialize spreadsheet variables ===
    stz sheet_cursor_col.w
    stz sheet_cursor_row.w
    stz sheet_scroll_y.w
    stz sheet_edit_len.w

@skip_clear_buf:
    stz sheet_blink_timer.w
    lda #$01
    sta sheet_blink_on.w
    sta sheet_dirty.w            ; Force initial render

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
    sta sheet_initialized.w

    ; === Start fade in ===
    lda #FADE_IN
    sta fade_dir.w
    stz fade_level.w
    stz SHADOW_INIDISP.w
    stz INIDISP.w

    rts


; ============================================================================
; state_sheet — Per-frame handler for the spreadsheet editor
; Assumes: 8-bit A/X/Y
; ============================================================================
state_sheet:
    .ACCU 8
    .INDEX 8

    ; --- Initialize on first frame ---
    lda sheet_initialized.w
    bne @ss_running
    jsr spreadsheet_init
    rts

@ss_running:
    jsr read_input

    ; --- Handle fade ---
    lda fade_dir.w
    beq @ss_no_fade

    cmp #FADE_IN
    bne @ss_fade_out

    ; Fade in
    lda fade_level.w
    cmp #$0F
    bcs @ss_fade_in_done
    inc A
    sta fade_level.w
    sta SHADOW_INIDISP.w
    jsr kbd_update               ; Keep keyboard highlight in sync during fade
    rts
@ss_fade_in_done:
    stz fade_dir.w
    bra @ss_no_fade

@ss_fade_out:
    ; Fade out
    lda fade_level.w
    beq @ss_fade_out_done
    dec A
    sta fade_level.w
    sta SHADOW_INIDISP.w
    rts
@ss_fade_out_done:
    stz fade_dir.w
    jsr kbd_hide
    stz sheet_initialized.w
    lda #STATE_BOOT
    sta current_state.w
    rts

@ss_no_fade:
    ; --- Update keyboard ---
    jsr kbd_update

    ; --- Process character from keyboard ---
    lda kbd_char_out.w
    beq @ss_no_char
    jsr _sheet_process_char

@ss_no_char:
    ; --- Handle mouse click on grid ---
    lda click_new.w
    beq @ss_no_click
    jsr _sheet_check_click

@ss_no_click:
    ; --- Render if dirty ---
    lda sheet_dirty.w
    beq @ss_no_render
    jsr _sheet_render

@ss_no_render:
    ; --- Update cursor blink ---
    jsr _sheet_blink_cursor

    ; --- Right-click = open file menu ---
    lda rclick_new.w
    beq @ss_done
    lda #$01
    sta file_type.w              ; 1 = spreadsheet
    jsr fmenu_open
    lda #STATE_FMENU
    sta current_state.w
    rts

@ss_done:
    rts


; ============================================================================
; _sheet_process_char — Handle a character from the on-screen keyboard
; Input: kbd_char_out contains the character
; Assumes: 8-bit A/X/Y
; ============================================================================
_sheet_process_char:
    .ACCU 8
    .INDEX 8

    lda kbd_char_out.w

    ; Check special codes
    cmp #KEY_BKSP
    beq @sp_backspace
    cmp #KEY_DEL
    beq @sp_delete
    cmp #KEY_ENTER
    beq @sp_enter
    cmp #KEY_SHIFT
    beq @sp_ignore_near

    ; Printable character ($20-$7E)
    cmp #$20
    bcc @sp_ignore_near
    cmp #$7F
    bcs @sp_ignore_near

    ; --- Append char to active cell ---
    sta $06                      ; Save character

    lda sheet_edit_len.w
    cmp #SHEET_CELL_SIZE
    bcc @sp_not_full
@sp_ignore_near:
    jmp @sp_ignore               ; Trampoline for far branch
@sp_not_full:

    rep #$10
    .INDEX 16
    jsr _sheet_get_cell_addr     ; X = cell address

    ; Offset to end of current content
    lda sheet_edit_len.w
    sta $08
    stz $09
    rep #$20
    .ACCU 16
    txa
    clc
    adc $08
    tax
    sep #$20
    .ACCU 8

    ; Store character and null-terminate
    lda $06
    sta $0000.w,X
    stz $0001.w,X               ; Null terminate

    inc sheet_edit_len.w

    lda #$01
    sta sheet_dirty.w

    sep #$10
    .INDEX 8
    rts

@sp_backspace:
    lda sheet_edit_len.w
    beq @sp_ignore               ; Nothing to delete

    rep #$10
    .INDEX 16
    jsr _sheet_get_cell_addr     ; X = cell address

    ; Null out the last character
    lda sheet_edit_len.w
    dec A
    sta sheet_edit_len.w
    sta $08
    stz $09
    rep #$20
    .ACCU 16
    txa
    clc
    adc $08
    tax
    sep #$20
    .ACCU 8
    stz $0000.w,X               ; Null out char

    lda #$01
    sta sheet_dirty.w

    sep #$10
    .INDEX 8
    rts

@sp_delete:
    ; Clear entire cell
    rep #$10
    .INDEX 16
    jsr _sheet_get_cell_addr     ; X = cell address

    stz $0000.w,X               ; Null first byte
    stz sheet_edit_len.w

    lda #$01
    sta sheet_dirty.w

    sep #$10
    .INDEX 8
    rts

@sp_enter:
    ; Move cursor down one row
    lda sheet_cursor_row.w
    cmp #SHEET_ROWS - 1
    bcs @sp_enter_done           ; Already at last row

    inc sheet_cursor_row.w
    jsr _sheet_adjust_scroll
    jsr _sheet_calc_edit_len

    lda #$01
    sta sheet_dirty.w

@sp_enter_done:
    rts

@sp_ignore:
    rts


; ============================================================================
; _sheet_get_cell_addr — Compute WRAM address of active cell
; Output: X = cell WRAM address (16-bit)
; Uses sheet_cursor_row and sheet_cursor_col
; Assumes: 8-bit A, 16-bit X/Y
; ============================================================================
_sheet_get_cell_addr:
    .ACCU 8
    .INDEX 16

    ; X = SHEET_BUF_ADDR + sheet_cursor_row * 64 + sheet_cursor_col * 8
    lda sheet_cursor_row.w
    sta $08
    stz $09                      ; $08-$09 = row (16-bit)

    rep #$20
    .ACCU 16
    lda $08
    ; Multiply by 64: shift left 6 times
    asl A
    asl A
    asl A
    asl A
    asl A
    asl A
    sta $08                      ; $08-$09 = row * 64
    sep #$20
    .ACCU 8

    ; col * 8
    lda sheet_cursor_col.w
    sta $0A
    stz $0B                      ; $0A-$0B = col (16-bit)
    rep #$20
    .ACCU 16
    lda $0A
    asl A
    asl A
    asl A                        ; × 8
    clc
    adc $08                      ; + row * 64
    clc
    adc #SHEET_BUF_ADDR          ; + base address
    tax
    sep #$20
    .ACCU 8

    rts


; ============================================================================
; _sheet_calc_edit_len — Scan active cell to find content length
; Stores result in sheet_edit_len
; Assumes: 8-bit A/X/Y (switches to 16-bit index internally)
; ============================================================================
_sheet_calc_edit_len:
    .ACCU 8
    .INDEX 8

    rep #$10
    .INDEX 16
    jsr _sheet_get_cell_addr     ; X = cell address

    ldy #$0000
@cel_scan:
    cpy #SHEET_CELL_SIZE
    bcs @cel_done
    lda $0000.w,X
    beq @cel_done
    inx
    iny
    bra @cel_scan
@cel_done:
    sep #$10
    .INDEX 8
    tya
    sta sheet_edit_len.w
    rts


; ============================================================================
; _sheet_render — Full render of spreadsheet to BG1 tilemap (force blank)
; Assumes: 8-bit A/X/Y
; ============================================================================
_sheet_render:
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

    ; === Render status bar ===
    jsr _sheet_render_status

    ; === Render column headers ===
    jsr _sheet_render_headers

    ; === Render data rows ===
    jsr _sheet_render_rows

    ; === Render cursor in active cell ===
    jsr _sheet_render_cursor

    ; === Restore display ===
    lda SHADOW_INIDISP.w
    sta INIDISP.w

    stz sheet_dirty.w

    sep #$10
    .INDEX 8
    rts


; ============================================================================
; _sheet_render_status — Write filename or "SHEET" centered on row 0 (gray palette)
; Must be called during force blank.
; Assumes: 8-bit A, 16-bit X/Y, VMAIN=$80
; ============================================================================
_sheet_render_status:
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
    lda #$28                     ; Priority=1, PPP=2 (gray)
    sta VMDATAH.w
    dey
    bne @clear_status

    ; Check if file has been saved (current_slot != $FF)
    lda current_slot.w
    cmp #$FF
    beq @show_sheet

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
    ; Convert ASCII to tile index: subtract $20, look up in table
    sec
    sbc #$20
    phy
    sta $0E
    stz $0F
    ldx $0E
    lda ascii_to_tile.w,X
    ply
    sta VMDATAL.w
    lda #$28                     ; Priority=1, PPP=2 (gray)
    sta VMDATAH.w
    iny
    bra @status_name_loop
@status_name_done:
    rts

@show_sheet:
    ; Write "SHEET" at col 13 (centered)
    ; S=19, H=8, E=5, E=5, T=20
    rep #$20
    .ACCU 16
    lda #VRAM_BG1_MAP + 13
    sta VMADDL.w
    sep #$20
    .ACCU 8

    lda #19                      ; S
    sta VMDATAL.w
    lda #$28
    sta VMDATAH.w

    lda #8                       ; H
    sta VMDATAL.w
    lda #$28
    sta VMDATAH.w

    lda #5                       ; E
    sta VMDATAL.w
    lda #$28
    sta VMDATAH.w

    lda #5                       ; E
    sta VMDATAL.w
    lda #$28
    sta VMDATAH.w

    lda #20                      ; T
    sta VMDATAL.w
    lda #$28
    sta VMDATAH.w

    rts


; ============================================================================
; _sheet_render_headers — Write column headers A-H on row 1 (gray palette)
; Must be called during force blank.
; Assumes: 8-bit A, 16-bit X/Y, VMAIN=$80
; ============================================================================
_sheet_render_headers:
    .ACCU 8
    .INDEX 16

    ; Clear row 1
    rep #$20
    .ACCU 16
    lda #VRAM_BG1_MAP + 32       ; Row 1 = base + 32 words
    sta VMADDL.w
    sep #$20
    .ACCU 8
    ldy #32
@clear_hdr:
    stz VMDATAL.w
    lda #$28                     ; Gray palette
    sta VMDATAH.w
    dey
    bne @clear_hdr

    ; Write column letter at: SHEET_DATA_COL + col * SHEET_COL_WIDTH + 1
    ; Col 0 (A): tile col 3 + 0*3 + 1 = 4
    ; Col 1 (B): tile col 3 + 1*3 + 1 = 7
    ; Col 2 (C): tile col 3 + 2*3 + 1 = 10
    ; etc.
    stz $02                      ; $02 = column counter (0-7)

@hdr_col:
    lda $02
    cmp #SHEET_COLS
    bcs @hdr_done

    ; Compute tilemap position: row 1 offset + tile col
    ; tile col = SHEET_DATA_COL + col * SHEET_COL_WIDTH + 1
    lda $02
    ; Multiply by 3 (col * SHEET_COL_WIDTH)
    sta $04
    asl A
    clc
    adc $04                      ; A = col * 3
    clc
    adc #SHEET_DATA_COL + 1      ; + data start + 1 (center in 3-wide cell)
    sta $04
    stz $05                      ; $04-$05 = tile column (16-bit)

    rep #$20
    .ACCU 16
    lda #VRAM_BG1_MAP + 32       ; Row 1 base
    clc
    adc $04
    sta VMADDL.w
    sep #$20
    .ACCU 8

    ; Write letter tile: A=1, B=2, ..., H=8
    lda $02
    inc A                        ; col 0→1 (A), col 1→2 (B), ...
    sta VMDATAL.w
    lda #$28                     ; Gray palette
    sta VMDATAH.w

    inc $02
    bra @hdr_col

@hdr_done:
    rts


; ============================================================================
; _sheet_render_rows — Render visible data rows (tilemap rows 2-19)
; Must be called during force blank.
; Assumes: 8-bit A, 16-bit X/Y, VMAIN=$80
; ============================================================================
_sheet_render_rows:
    .ACCU 8
    .INDEX 16

    stz $02                      ; $02 = screen row counter (0-17)

@row_loop:
    lda $02
    cmp #SHEET_VISIBLE_ROWS
    bcc @row_continue
    jmp @rows_done
@row_continue:

    ; Compute data row = sheet_scroll_y + screen_row
    lda sheet_scroll_y.w
    clc
    adc $02
    sta $03                      ; $03 = data row

    ; Compute VRAM address = VRAM_BG1_MAP + (screen_row + SHEET_DATA_START) * 32
    lda $02
    clc
    adc #SHEET_DATA_START
    sta $06
    stz $07
    rep #$20
    .ACCU 16
    lda $06
    asl A
    asl A
    asl A
    asl A
    asl A                        ; × 32
    clc
    adc #VRAM_BG1_MAP
    sta VMADDL.w
    sep #$20
    .ACCU 8

    ; Check if data_row >= SHEET_ROWS → render blank row
    lda $03
    cmp #SHEET_ROWS
    bcc @row_valid
    jmp @row_blank

@row_valid:
    ; --- Write row number (1-based, right-aligned in 2 cols) ---
    lda $03
    inc A                        ; 1-based row number
    sta $04                      ; $04 = row number (1-32)

    ; Compute tens digit via subtraction
    ldx #$0000                   ; X = tens count
    lda $04
@tens_loop:
    cmp #10
    bcc @tens_done
    sec
    sbc #10
    inx
    bra @tens_loop
@tens_done:
    sta $05                      ; $05 = ones digit (0-9)
    stx $06                      ; $06 = tens digit (0-3)

    ; Write tens digit (or space if zero)
    lda $06
    beq @tens_space
    clc
    adc #27                      ; Digit tiles: 0→27, 1→28, ..., 9→36
    sta VMDATAL.w
    lda #$28                     ; Gray palette
    sta VMDATAH.w
    bra @ones_digit
@tens_space:
    stz VMDATAL.w                ; Blank tile
    lda #$28
    sta VMDATAH.w

@ones_digit:
    ; Write ones digit
    lda $05
    clc
    adc #27                      ; Digit tile
    sta VMDATAL.w
    lda #$28
    sta VMDATAH.w

    ; --- Write separator at col 2 ---
    lda #52                      ; Colon tile (:)
    sta VMDATAL.w
    lda #$28                     ; Gray palette
    sta VMDATAH.w

    ; --- Write cell data for columns 0-7 ---
    stz $0C                      ; $0C = column counter (0-7)

@col_loop:
    lda $0C
    cmp #SHEET_COLS
    bcs @row_next

    ; Compute cell address = SHEET_BUF_ADDR + data_row * 64 + col * 8
    lda $03                      ; data row
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
    asl A                        ; × 64
    sta $06                      ; $06-$07 = row * 64
    sep #$20
    .ACCU 8

    lda $0C                      ; col
    sta $08
    stz $09
    rep #$20
    .ACCU 16
    lda $08
    asl A
    asl A
    asl A                        ; × 8
    clc
    adc $06                      ; + row * 64
    clc
    adc #SHEET_BUF_ADDR
    tax                          ; X = cell buffer address
    sep #$20
    .ACCU 8

    ; Determine palette: $24 for active cell, $20 for normal
    lda $03                      ; data_row
    cmp sheet_cursor_row.w
    bne @col_normal
    lda $0C
    cmp sheet_cursor_col.w
    bne @col_normal
    lda #$24                     ; Highlight palette (PPP=1)
    bra @col_pal_set
@col_normal:
    lda #$20                     ; Normal palette (PPP=0)
@col_pal_set:
    sta $0D                      ; $0D = palette high byte

    ; Write up to 3 chars from cell content
    ldy #$0000                   ; Y = char counter within cell

@cell_char:
    cpy #SHEET_DISP_CHARS
    bcs @col_next
    lda $0000.w,X
    beq @cell_pad                ; Null = end of content
    jsr _char_to_tile
    sta VMDATAL.w
    lda $0D
    sta VMDATAH.w
    inx
    iny
    bra @cell_char

@cell_pad:
    ; Pad remaining display chars with blanks
    cpy #SHEET_DISP_CHARS
    bcs @col_next
    stz VMDATAL.w
    lda $0D
    sta VMDATAH.w
    iny
    bra @cell_pad

@col_next:
    inc $0C
    bra @col_loop

@row_next:
    ; Fill remaining tile cols (27-31) with blanks
    ; 8 cols × 3 tiles = 24 data tiles + 3 prefix = 27 tiles used, 5 remain
    ldy #5
@row_pad:
    stz VMDATAL.w
    lda #$20
    sta VMDATAH.w
    dey
    bne @row_pad

    inc $02
    jmp @row_loop

@row_blank:
    ; Blank entire row (32 tiles)
    ldy #32
@blank_tile:
    stz VMDATAL.w
    lda #$20
    sta VMDATAH.w
    dey
    bne @blank_tile

    inc $02
    jmp @row_loop

@rows_done:
    rts


; ============================================================================
; _sheet_render_cursor — Write underscore cursor at active cell position
; Must be called during force blank.
; Assumes: 8-bit A, 16-bit X/Y, VMAIN=$80
; ============================================================================
_sheet_render_cursor:
    .ACCU 8
    .INDEX 16

    ; Compute screen row = cursor_row - scroll_y
    lda sheet_cursor_row.w
    sec
    sbc sheet_scroll_y.w
    bcc @rc_off                  ; Above visible area
    cmp #SHEET_VISIBLE_ROWS
    bcs @rc_off                  ; Below visible area

    ; Compute tilemap row = screen_row + SHEET_DATA_START
    clc
    adc #SHEET_DATA_START
    sta $06
    stz $07

    ; Compute tilemap col = SHEET_DATA_COL + cursor_col * SHEET_COL_WIDTH + edit_len
    ; But clamp edit_len to SHEET_DISP_CHARS-1
    lda sheet_edit_len.w
    cmp #SHEET_DISP_CHARS
    bcc @rc_len_ok
    lda #SHEET_DISP_CHARS - 1    ; Clamp to last display position
@rc_len_ok:
    sta $08                      ; $08 = cursor offset within cell

    lda sheet_cursor_col.w
    sta $04
    asl A
    clc
    adc $04                      ; A = cursor_col * 3
    clc
    adc #SHEET_DATA_COL
    clc
    adc $08                      ; + edit_len offset
    sta $08
    stz $09

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

    ; Only show cursor tile if blink is on
    lda sheet_blink_on.w
    beq @rc_off

    lda #SHEET_CURSOR_TILE
    sta VMDATAL.w
    lda #$24                     ; Highlight palette
    sta VMDATAH.w

@rc_off:
    rts


; ============================================================================
; _sheet_check_click — Convert mouse click position to grid cell selection
; Assumes: 8-bit A/X/Y
; ============================================================================
_sheet_check_click:
    .ACCU 8
    .INDEX 8

    ; Check Y bounds: pixel Y must be in data area
    ; Top = SHEET_DATA_START * 8 = 16, Bottom = (SHEET_DATA_START + SHEET_VISIBLE_ROWS) * 8 = 160
    rep #$20
    .ACCU 16
    lda cursor_y.w
    cmp #SHEET_DATA_START * 8
    sep #$20
    .ACCU 8
    bcc @click_miss              ; Above data area

    rep #$20
    .ACCU 16
    lda cursor_y.w
    cmp #(SHEET_DATA_START + SHEET_VISIBLE_ROWS) * 8
    sep #$20
    .ACCU 8
    bcs @click_miss              ; Below data area

    ; Check X bounds: pixel X must be in data columns
    ; Left = SHEET_DATA_COL * 8 = 24, Right = (SHEET_DATA_COL + SHEET_COLS * SHEET_COL_WIDTH) * 8 = 216
    rep #$20
    .ACCU 16
    lda cursor_x.w
    cmp #SHEET_DATA_COL * 8
    sep #$20
    .ACCU 8
    bcc @click_miss

    rep #$20
    .ACCU 16
    lda cursor_x.w
    cmp #(SHEET_DATA_COL + SHEET_COLS * SHEET_COL_WIDTH) * 8
    sep #$20
    .ACCU 8
    bcs @click_miss

    ; Compute screen row = (cursor_y - 16) / 8
    rep #$20
    .ACCU 16
    lda cursor_y.w
    sec
    sbc #SHEET_DATA_START * 8    ; - 16
    sep #$20
    .ACCU 8
    ; A = low byte (0-143), divide by 8
    lsr A
    lsr A
    lsr A                        ; screen_row
    ; data_row = screen_row + sheet_scroll_y
    clc
    adc sheet_scroll_y.w
    cmp #SHEET_ROWS
    bcs @click_miss
    sta sheet_cursor_row.w

    ; Compute column = (cursor_x - 24) / 8 / 3
    rep #$20
    .ACCU 16
    lda cursor_x.w
    sec
    sbc #SHEET_DATA_COL * 8      ; - 24
    sep #$20
    .ACCU 8
    ; A = low byte, divide by 8
    lsr A
    lsr A
    lsr A                        ; tile_col (0-23)
    ; Divide tile_col by 3 to get column
    ; Use subtraction loop
    ldx #$00
@div3:
    cmp #3
    bcc @div3_done
    sec
    sbc #3
    inx
    bra @div3
@div3_done:
    cpx #SHEET_COLS
    bcs @click_miss              ; Column out of range
    stx sheet_cursor_col.w

    ; Recalculate edit length for new cell
    jsr _sheet_calc_edit_len

    lda #$01
    sta sheet_dirty.w

@click_miss:
    rts


; ============================================================================
; _sheet_adjust_scroll — Ensure active row is visible
; Adjusts sheet_scroll_y so cursor row is on screen.
; Assumes: 8-bit A/X/Y
; ============================================================================
_sheet_adjust_scroll:
    .ACCU 8
    .INDEX 8

    ; If cursor_row < scroll_y → scroll up
    lda sheet_cursor_row.w
    cmp sheet_scroll_y.w
    bcs @sadj_check_below
    sta sheet_scroll_y.w
    lda #$01
    sta sheet_dirty.w
    rts

@sadj_check_below:
    ; If cursor_row >= scroll_y + SHEET_VISIBLE_ROWS → scroll down
    lda sheet_cursor_row.w
    sec
    sbc sheet_scroll_y.w
    cmp #SHEET_VISIBLE_ROWS
    bcc @sadj_ok

    ; scroll_y = cursor_row - SHEET_VISIBLE_ROWS + 1
    lda sheet_cursor_row.w
    sec
    sbc #SHEET_VISIBLE_ROWS - 1
    sta sheet_scroll_y.w
    lda #$01
    sta sheet_dirty.w

@sadj_ok:
    rts


; ============================================================================
; _sheet_blink_cursor — Toggle cursor visibility every 30 frames
; Assumes: 8-bit A/X/Y
; ============================================================================
_sheet_blink_cursor:
    .ACCU 8
    .INDEX 8

    inc sheet_blink_timer.w
    lda sheet_blink_timer.w
    cmp #30                      ; Toggle every 30 frames (~0.5 sec)
    bcc @sblink_no_toggle
    ; Reset timer and toggle
    stz sheet_blink_timer.w
    lda sheet_blink_on.w
    eor #$01
    sta sheet_blink_on.w
    jmp _sheet_blink_write
@sblink_no_toggle:
    rts


; --- Separated to avoid branch distance issues ---
_sheet_blink_write:
    .ACCU 8
    .INDEX 8

    rep #$10
    .INDEX 16

    ; Compute screen row — bail out if off screen
    lda sheet_cursor_row.w
    sec
    sbc sheet_scroll_y.w
    bcs +
    jmp @sbw_done                ; Off screen (above)
+   cmp #SHEET_VISIBLE_ROWS
    bcc +
    jmp @sbw_done                ; Off screen (below)
+

    ; Compute tilemap row = screen_row + SHEET_DATA_START
    clc
    adc #SHEET_DATA_START
    sta $06
    stz $07

    ; Compute tilemap col = SHEET_DATA_COL + cursor_col * SHEET_COL_WIDTH + edit_len
    lda sheet_edit_len.w
    cmp #SHEET_DISP_CHARS
    bcc +
    lda #SHEET_DISP_CHARS - 1
+   sta $08

    lda sheet_cursor_col.w
    sta $04
    asl A
    clc
    adc $04                      ; A = col * 3
    clc
    adc #SHEET_DATA_COL
    clc
    adc $08
    sta $08
    stz $09

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
    sta $0A                      ; Save VRAM address
    sep #$20
    .ACCU 8

    ; Determine tile + attr to write
    lda sheet_blink_on.w
    beq @sbw_show_char

    ; Show cursor tile
    lda #SHEET_CURSOR_TILE
    sta $0C                      ; tile
    bra @sbw_queue

@sbw_show_char:
    ; Show the actual character at cursor position (or blank)
    jsr _sheet_get_cell_addr     ; X = cell address

    ; Offset to edit_len position
    lda sheet_edit_len.w
    cmp #SHEET_DISP_CHARS
    bcc +
    lda #SHEET_DISP_CHARS - 1
+   sta $04
    stz $05
    rep #$20
    .ACCU 16
    txa
    clc
    adc $04
    tax
    sep #$20
    .ACCU 8

    lda $0000.w,X
    beq @sbw_blank
    jsr _char_to_tile
    sta $0C                      ; tile
    bra @sbw_queue

@sbw_blank:
    stz $0C                      ; tile = 0 (blank)

@sbw_queue:
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
    lda #$24                     ; attr (highlight palette)
    sta vram_wq_data+3.w,X
    inc vram_wq_count.w

@sbw_done:
    sep #$10
    .INDEX 8
    rts
