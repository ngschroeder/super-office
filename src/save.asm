; ============================================================================
; save.asm — SRAM Save / Load System (Phase 6)
;
; SRAM Layout at $70:0000 - $70:7FFF (32 KB):
;   $0000-$000F  Header (16 bytes): magic "SOFA", version, file count
;   $0010-$008F  Directory (8 slots × 16 bytes)
;   $0100-$7FFF  Data area (8 slots × $0F60 bytes each)
;
; Directory entry format (16 bytes):
;   Byte 0:     Flags — bit 7: in-use, bit 0: type (0=text, 1=sheet)
;   Byte 1:     Data size high byte
;   Byte 2:     Data size low byte
;   Bytes 3-14: Filename (12 chars, null-padded)
;   Byte 15:    Reserved
; ============================================================================

; --- SRAM constants ---
.define SRAM_BASE       $0000    ; Bank $70 offset base
.define SRAM_MAGIC_OFS  $0000    ; "SOFA" signature
.define SRAM_VER_OFS    $0004    ; Format version
.define SRAM_COUNT_OFS  $0005    ; File count
.define SRAM_DIR_OFS    $0010    ; Directory start
.define SRAM_DIR_ENTRY  16       ; Bytes per directory entry
.define SRAM_DATA_OFS   $0100    ; Data area start
.define SRAM_SLOT_SIZE  $0F60    ; Bytes per data slot (3936)
.define SRAM_MAX_SLOTS  8        ; Maximum file slots
.define SRAM_NAME_LEN   12       ; Filename length
.define SRAM_FLAG_USED  $80      ; In-use flag
.define SRAM_FLAG_SHEET $01      ; Type flag: spreadsheet

; --- SRAM WRAM directory cache ---
.define SRAM_DIR_BUF    $0100    ; WRAM buffer for directory cache (128 bytes)
                                 ; Uses $0100-$017F (below OAM buf at $0200)

; --- File menu / save system variables (DP $9E-$AF) ---
; current_slot ($9E), save_name_len ($A6), save_name_buf ($A7) defined in constants.asm
.define file_type       $9F      ; Current file type (0=text, 1=sheet)
.define fmenu_visible   $A0      ; File menu overlay visible flag
.define fmenu_sel       $A1      ; File menu selection (0=save, 1=save as, 2=close)
.define fmenu_prev_sel  $A2      ; Previous file menu selection
.define dialog_visible  $A3      ; Save dialog visible flag
.define dialog_sel      $A4      ; Dialog selection (0=yes, 1=no, 2=cancel)
.define dialog_type     $A5      ; Dialog type (0=dirty prompt, 1=filename entry)
; $B3 = end of save_name_buf
.define fb_sel          $B3      ; File browser selection (0-7, $FF=none)
.define fb_prev_sel     $B4      ; Previous file browser selection
.define fb_action       $B5      ; File browser pending action
.define fb_initialized  $B6      ; File browser init flag
.define fb_confirm_del  $B7      ; Delete confirmation visible flag

; File browser actions
.define FB_ACT_NONE     0
.define FB_ACT_LOAD     1
.define FB_ACT_DELETE   2


; ============================================================================
; sram_init — Initialize SRAM on first boot (check magic signature)
; Call during boot, after WRAM clear but before title screen.
; Assumes: 8-bit A/X/Y
; ============================================================================
sram_init:
    .ACCU 8
    .INDEX 8

    ; Check magic bytes "SOFA" at $70:0000-0003
    lda $700000.l
    cmp #$53                     ; 'S'
    bne @sram_format
    lda $700001.l
    cmp #$4F                     ; 'O'
    bne @sram_format
    lda $700002.l
    cmp #$46                     ; 'F'
    bne @sram_format
    lda $700003.l
    cmp #$41                     ; 'A'
    bne @sram_format

    ; Magic is valid — SRAM already initialized
    rts

@sram_format:
    ; Fresh SRAM — write header
    lda #$53                     ; 'S'
    sta $700000.l
    lda #$4F                     ; 'O'
    sta $700001.l
    lda #$46                     ; 'F'
    sta $700002.l
    lda #$41                     ; 'A'
    sta $700003.l
    lda #$01                     ; Version 1
    sta $700004.l
    lda #$00                     ; File count = 0
    sta $700005.l

    ; Zero reserved header bytes ($06-$0F)
    rep #$10
    .INDEX 16
    lda #$00
    ldx #$0006
@zero_hdr:
    sta $700000.l,X
    inx
    cpx #$0010
    bne @zero_hdr

    ; Zero entire directory ($10-$8F = 128 bytes)
    ldx #SRAM_DIR_OFS
@zero_dir:
    sta $700000.l,X
    inx
    cpx #SRAM_DIR_OFS + (SRAM_MAX_SLOTS * SRAM_DIR_ENTRY)
    bne @zero_dir

    sep #$10
    .INDEX 8
    rts


; ============================================================================
; sram_get_directory — Copy 128-byte directory from SRAM to WRAM cache
; Output: directory cached at SRAM_DIR_BUF ($0100)
; Assumes: 8-bit A/X/Y
; ============================================================================
sram_get_directory:
    .ACCU 8
    .INDEX 8

    rep #$10
    .INDEX 16
    ldx #$0000
@copy_dir:
    lda $700010.l,X              ; SRAM $70:0010 + X
    sta SRAM_DIR_BUF.w,X
    inx
    cpx #SRAM_MAX_SLOTS * SRAM_DIR_ENTRY  ; 128 bytes
    bne @copy_dir

    sep #$10
    .INDEX 8
    rts


; ============================================================================
; sram_save_file — Save current document/spreadsheet to an SRAM slot
; Input: A = slot index (0-7)
;        file_type = file type (0=text, 1=spreadsheet)
;        save_name_buf = filename (12 bytes)
; Assumes: 8-bit A/X/Y
; ============================================================================
sram_save_file:
    .ACCU 8
    .INDEX 8

    sta $00                      ; $00 = slot index

    rep #$10
    .INDEX 16

    ; --- Check if slot was previously free (for file count update) ---
    jsr _sram_dir_addr           ; X = SRAM dir entry offset
    lda $700000.l,X              ; Read flags byte
    sta $01                      ; $01 = old flags

    ; --- Write directory entry ---
    ; Flags byte: bit 7 = in-use, bit 0 = type
    lda #SRAM_FLAG_USED
    ora file_type.w
    sta $700000.l,X              ; Byte 0: flags

    ; Data size
    lda file_type.w
    bne @save_sheet_size

    ; Text doc: size = doc_length (16-bit)
    lda doc_length+1.w           ; High byte
    sta $700001.l,X
    lda doc_length.w             ; Low byte
    sta $700002.l,X
    bra @save_write_name

@save_sheet_size:
    ; Spreadsheet: fixed size = 2304 bytes ($0900)
    lda #$09                     ; High byte of $0900
    sta $700001.l,X
    lda #$00
    sta $700002.l,X              ; Low byte = $00

@save_write_name:
    ; Write filename (12 bytes from save_name_buf)
    ; X = dir entry offset; name starts at offset + 3
    rep #$20
    .ACCU 16
    txa
    clc
    adc #3                       ; X now points to name field start
    tax
    sep #$20
    .ACCU 8

    ldy #$0000
@save_name_loop:
    cpy #SRAM_NAME_LEN
    bcs @save_name_done
    lda save_name_buf.w,Y
    sta $700000.l,X
    inx
    iny
    bra @save_name_loop
@save_name_done:

    ; Reserved byte (byte 15) = $00
    ; (Already zero from init, no need to write)

    ; --- Update file count if slot was previously free ---
    lda $01                      ; Old flags
    and #SRAM_FLAG_USED
    bne @save_count_ok           ; Was already in-use, no count change
    lda $700005.l                ; File count
    inc A
    sta $700005.l
@save_count_ok:

    ; --- Copy data to SRAM slot ---
    lda $00                      ; Slot index
    jsr _sram_data_addr          ; X = SRAM data area offset

    lda file_type.w
    bne @save_sheet_data

    ; --- Text doc: copy doc_length bytes from DOC_BUF_ADDR ---
    ldy #$0000
@save_doc_loop:
    rep #$20
    .ACCU 16
    tya
    cmp doc_length.w
    sep #$20
    .ACCU 8
    bcs @save_doc_done
    lda DOC_BUF_ADDR.w,Y
    sta $700000.l,X
    inx
    iny
    bra @save_doc_loop
@save_doc_done:
    ; Write null terminator
    lda #$00
    sta $700000.l,X

    ; Clear dirty flag
    stz doc_dirty.w
    bra @save_slot_update

@save_sheet_data:
    ; --- Spreadsheet: copy 2048 bytes from SHEET_BUF_ADDR ---
    ; (Buffer is 2048 bytes = 8 cols × 32 rows × 8 bytes)
    ldy #$0000
@save_sheet_loop:
    cpy #DOC_MAX_SIZE            ; 2048 bytes
    bcs @save_sheet_done
    lda SHEET_BUF_ADDR.w,Y
    sta $700000.l,X
    inx
    iny
    bra @save_sheet_loop
@save_sheet_done:
    ; Clear dirty flag
    stz sheet_dirty.w

@save_slot_update:
    ; Update current_slot
    lda $00
    sta current_slot.w

    sep #$10
    .INDEX 8
    rts


; ============================================================================
; sram_load_file — Load a file from SRAM into the working buffer
; Input: A = slot index (0-7)
; Output: Sets current_state to appropriate editor, sets current_slot
; Assumes: 8-bit A/X/Y
; ============================================================================
sram_load_file:
    .ACCU 8
    .INDEX 8

    sta $00                      ; $00 = slot index

    rep #$10
    .INDEX 16

    ; --- Read directory entry ---
    jsr _sram_dir_addr           ; X = dir entry offset
    lda $700000.l,X              ; Flags
    sta $01                      ; $01 = flags
    and #SRAM_FLAG_USED
    bne @load_ok                 ; Slot has data
    jmp @load_fail               ; Slot is empty
@load_ok:

    ; Get data size
    lda $700001.l,X              ; Size high
    sta $03
    lda $700002.l,X              ; Size low
    sta $02                      ; $02-$03 = data size (16-bit)

    ; Get file type
    lda $01
    and #SRAM_FLAG_SHEET
    sta file_type.w

    ; --- Get data pointer ---
    lda $00
    jsr _sram_data_addr          ; X = SRAM data offset

    lda file_type.w
    bne @load_sheet

    ; --- Load text doc ---
    ; Clear buffer first
    phy
    ldy #DOC_MAX_SIZE - 2
    rep #$20
    .ACCU 16
    lda #$0000
@load_clr_doc:
    sta DOC_BUF_ADDR.w,Y
    dey
    dey
    bpl @load_clr_doc
    sep #$20
    .ACCU 8
    ply

    ; Copy data
    ldy #$0000
@load_doc_loop:
    rep #$20
    .ACCU 16
    tya
    cmp $02                      ; Compare with data size
    sep #$20
    .ACCU 8
    bcs @load_doc_done
    lda $700000.l,X
    sta DOC_BUF_ADDR.w,Y
    inx
    iny
    bra @load_doc_loop
@load_doc_done:
    ; Set doc_length
    rep #$20
    .ACCU 16
    lda $02                      ; data size
    sta doc_length.w
    stz doc_cursor_pos.w
    sep #$20
    .ACCU 8

    stz doc_scroll_y.w
    stz doc_cursor_col.w
    stz doc_cursor_row.w
    stz doc_dirty.w
    stz doc_initialized.w        ; Force re-init on state entry

    ; Copy filename to save_name_buf
    lda $00
    jsr _sram_copy_name

    ; Set state
    lda $00
    sta current_slot.w
    lda #STATE_TEXTDOC
    sta current_state.w
    bra @load_done

@load_sheet:
    ; --- Load spreadsheet ---
    ; Clear buffer first
    phy
    ldy #DOC_MAX_SIZE - 2
    rep #$20
    .ACCU 16
    lda #$0000
@load_clr_sheet:
    sta SHEET_BUF_ADDR.w,Y
    dey
    dey
    bpl @load_clr_sheet
    sep #$20
    .ACCU 8
    ply

    ; Copy data (2048 bytes)
    ldy #$0000
@load_sheet_loop:
    cpy #DOC_MAX_SIZE
    bcs @load_sheet_done
    lda $700000.l,X
    sta SHEET_BUF_ADDR.w,Y
    inx
    iny
    bra @load_sheet_loop
@load_sheet_done:
    stz sheet_cursor_col.w
    stz sheet_cursor_row.w
    stz sheet_scroll_y.w
    stz sheet_edit_len.w
    stz sheet_dirty.w
    stz sheet_initialized.w      ; Force re-init on state entry

    ; Copy filename to save_name_buf
    lda $00
    jsr _sram_copy_name

    ; Set state
    lda $00
    sta current_slot.w
    lda #STATE_SHEET
    sta current_state.w

@load_done:
    sep #$10
    .INDEX 8
    rts

@load_fail:
    sep #$10
    .INDEX 8
    rts


; ============================================================================
; sram_delete_file — Delete a file from an SRAM slot
; Input: A = slot index (0-7)
; Assumes: 8-bit A/X/Y
; ============================================================================
sram_delete_file:
    .ACCU 8
    .INDEX 8

    sta $00                      ; $00 = slot index

    rep #$10
    .INDEX 16

    jsr _sram_dir_addr           ; X = dir entry offset

    ; Check if slot is in-use
    lda $700000.l,X
    and #SRAM_FLAG_USED
    beq @del_done                ; Already empty

    ; Clear flags (marks slot as free)
    lda #$00
    sta $700000.l,X

    ; (No need to zero filename — flags=0 marks slot as free)

    ; Decrement file count
    lda $700005.l
    beq @del_done                ; Already 0 (shouldn't happen)
    dec A
    sta $700005.l

@del_done:
    sep #$10
    .INDEX 8
    rts


; ============================================================================
; sram_find_free_slot — Find the first free slot in the directory
; Output: A = slot index (0-7), or $FF if all full
; Assumes: 8-bit A/X/Y
; ============================================================================
sram_find_free_slot:
    .ACCU 8
    .INDEX 8

    rep #$10
    .INDEX 16

    ldx #SRAM_DIR_OFS
    ldy #$0000                   ; Y = slot counter
@find_loop:
    cpy #SRAM_MAX_SLOTS
    bcs @find_full
    lda $700000.l,X              ; Flags byte
    and #SRAM_FLAG_USED
    beq @find_found

    ; Next entry: X += 16
    rep #$20
    .ACCU 16
    txa
    clc
    adc #SRAM_DIR_ENTRY
    tax
    sep #$20
    .ACCU 8
    iny
    bra @find_loop

@find_found:
    sep #$10
    .INDEX 8
    tya                          ; A = slot index
    rts

@find_full:
    sep #$10
    .INDEX 8
    lda #$FF
    rts


; ============================================================================
; _sram_dir_addr — Compute SRAM directory entry offset
; Input: $00 = slot index
; Output: X = absolute offset within bank $70 (16-bit)
; Assumes: 8-bit A, 16-bit X/Y
; ============================================================================
_sram_dir_addr:
    .ACCU 8
    .INDEX 16

    ; X = SRAM_DIR_OFS + slot * 16
    lda $00
    sta $04
    stz $05
    rep #$20
    .ACCU 16
    lda $04
    asl A
    asl A
    asl A
    asl A                        ; × 16
    clc
    adc #SRAM_DIR_OFS
    tax
    sep #$20
    .ACCU 8
    rts


; ============================================================================
; _sram_data_addr — Compute SRAM data area offset for a slot
; Input: A = slot index
; Output: X = absolute offset within bank $70 (16-bit)
; Assumes: 8-bit A, 16-bit X/Y
; ============================================================================
_sram_data_addr:
    .ACCU 8
    .INDEX 16

    ; X = SRAM_DATA_OFS + slot * SRAM_SLOT_SIZE ($0F60)
    sta $04
    stz $05
    rep #$20
    .ACCU 16
    lda $04
    ; Multiply by $0F60: use shifts and adds
    ; $0F60 = $1000 - $A0 = 4096 - 160
    ; Or simply: A * $0F60
    ; Easier: multiply by table lookup for small values 0-7
    asl A                        ; × 2 (index into word table)
    tax
    lda _sram_slot_offsets.w,X
    tax
    sep #$20
    .ACCU 8
    rts

_sram_slot_offsets:
    .dw SRAM_DATA_OFS + (0 * SRAM_SLOT_SIZE)   ; $0100
    .dw SRAM_DATA_OFS + (1 * SRAM_SLOT_SIZE)   ; $1060
    .dw SRAM_DATA_OFS + (2 * SRAM_SLOT_SIZE)   ; $1FC0
    .dw SRAM_DATA_OFS + (3 * SRAM_SLOT_SIZE)   ; $2F20
    .dw SRAM_DATA_OFS + (4 * SRAM_SLOT_SIZE)   ; $3E80
    .dw SRAM_DATA_OFS + (5 * SRAM_SLOT_SIZE)   ; $4DE0
    .dw SRAM_DATA_OFS + (6 * SRAM_SLOT_SIZE)   ; $5D40
    .dw SRAM_DATA_OFS + (7 * SRAM_SLOT_SIZE)   ; $6CA0


; ============================================================================
; _sram_copy_name — Copy filename from SRAM directory to save_name_buf
; Input: A = slot index (in $00)
; Assumes: 8-bit A, 16-bit X/Y
; ============================================================================
_sram_copy_name:
    .ACCU 8
    .INDEX 16

    sta $00
    jsr _sram_dir_addr           ; X = dir entry offset

    ; Copy 12 bytes from dir entry offset+3 to save_name_buf
    ldy #$0000
    stz save_name_len.w
@copy_name:
    cpy #SRAM_NAME_LEN
    bcs @copy_name_done
    ; Compute source = X + 3 + Y
    phx
    rep #$20
    .ACCU 16
    txa
    clc
    adc #3
    sta $04
    tya
    clc
    adc $04
    tax
    sep #$20
    .ACCU 8
    lda $700000.l,X
    plx                          ; Restore dir entry X
    sta save_name_buf.w,Y
    beq @copy_name_done          ; Null = end of name
    inc save_name_len.w
    iny
    bra @copy_name
@copy_name_done:
    ; Pad rest with zeros
@pad_name:
    cpy #SRAM_NAME_LEN
    bcs @pad_done
    lda #$00
    sta save_name_buf.w,Y
    iny
    bra @pad_name
@pad_done:
    rts


; ============================================================================
; sram_get_slot_name — Get pointer to filename in WRAM directory cache
; Input: A = slot index
; Output: X = WRAM address of 12-byte filename
; Assumes: 8-bit A/X/Y
; ============================================================================
sram_get_slot_name:
    .ACCU 8
    .INDEX 8

    ; X = SRAM_DIR_BUF + slot * 16 + 3
    rep #$10
    .INDEX 16
    sta $00
    stz $01
    rep #$20
    .ACCU 16
    lda $00
    asl A
    asl A
    asl A
    asl A                        ; × 16
    clc
    adc #SRAM_DIR_BUF + 3        ; + base + name offset
    tax
    sep #$30
    .ACCU 8
    .INDEX 8
    rts


; ============================================================================
; File Menu Overlay — Start button opens save/close menu in editors
; ============================================================================

; ============================================================================
; fmenu_open — Show the file menu overlay on BG3
; Must be called during force blank (or will enter force blank itself).
; Assumes: 8-bit A/X/Y
; ============================================================================
fmenu_open:
    .ACCU 8
    .INDEX 8

    lda #$01
    sta fmenu_visible.w
    stz fmenu_sel.w              ; Default to "SAVE"
    lda #$FF
    sta fmenu_prev_sel.w

    ; Draw menu box on BG3 tilemap (rows 8-14, cols 10-21)
    ; Force blank for VRAM writes
    lda #$8F
    sta INIDISP.w
    lda #$80
    sta VMAIN.w

    rep #$10
    .INDEX 16

    ; --- Draw top border (row 8) ---
    rep #$20
    .ACCU 16
    lda #VRAM_BG3_MAP + (8 * 32) + 10
    sta VMADDL.w
    sep #$20
    .ACCU 8
    lda #KBD_TILE_HLINE          ; ─
    ldy #12                      ; 12 tiles wide
@fm_top:
    sta VMDATAL.w
    pha
    lda #$20                     ; Priority=1
    sta VMDATAH.w
    pla
    dey
    bne @fm_top

    ; --- Row 9: blank (spacer) ---
    rep #$20
    .ACCU 16
    lda #VRAM_BG3_MAP + (9 * 32) + 10
    sta VMADDL.w
    sep #$20
    .ACCU 8
    ldy #12
@fm_r9:
    stz VMDATAL.w
    lda #$20
    sta VMDATAH.w
    dey
    bne @fm_r9

    ; --- Row 10: "  SAVE      " ---
    rep #$20
    .ACCU 16
    lda #VRAM_BG3_MAP + (10 * 32) + 10
    sta VMADDL.w
    sep #$20
    .ACCU 8
    _write_tile 0                ; space
    _write_tile 0                ; space
    _write_tile 19               ; S
    _write_tile 1                ; A
    _write_tile 22               ; V
    _write_tile 5                ; E
    _write_tile 0                ; space
    _write_tile 0                ; space
    _write_tile 0                ; space
    _write_tile 0                ; space
    _write_tile 0                ; space
    _write_tile 0                ; space

    ; --- Row 11: "  SAVE AS   " ---
    rep #$20
    .ACCU 16
    lda #VRAM_BG3_MAP + (11 * 32) + 10
    sta VMADDL.w
    sep #$20
    .ACCU 8
    _write_tile 0                ; space
    _write_tile 0                ; space
    _write_tile 19               ; S
    _write_tile 1                ; A
    _write_tile 22               ; V
    _write_tile 5                ; E
    _write_tile 0                ; space
    _write_tile 1                ; A
    _write_tile 19               ; S
    _write_tile 0                ; space
    _write_tile 0                ; space
    _write_tile 0                ; space

    ; --- Row 12: "  CLOSE     " ---
    rep #$20
    .ACCU 16
    lda #VRAM_BG3_MAP + (12 * 32) + 10
    sta VMADDL.w
    sep #$20
    .ACCU 8
    _write_tile 0                ; space
    _write_tile 0                ; space
    _write_tile 3                ; C
    _write_tile 12               ; L
    _write_tile 15               ; O
    _write_tile 19               ; S
    _write_tile 5                ; E
    _write_tile 0                ; space
    _write_tile 0                ; space
    _write_tile 0                ; space
    _write_tile 0                ; space
    _write_tile 0                ; space

    ; --- Row 13: blank (spacer) ---
    rep #$20
    .ACCU 16
    lda #VRAM_BG3_MAP + (13 * 32) + 10
    sta VMADDL.w
    sep #$20
    .ACCU 8
    ldy #12
@fm_r13:
    stz VMDATAL.w
    lda #$20
    sta VMDATAH.w
    dey
    bne @fm_r13

    ; --- Bottom border (row 14) ---
    rep #$20
    .ACCU 16
    lda #VRAM_BG3_MAP + (14 * 32) + 10
    sta VMADDL.w
    sep #$20
    .ACCU 8
    lda #KBD_TILE_HLINE
    ldy #12
@fm_bot:
    sta VMDATAL.w
    pha
    lda #$20
    sta VMDATAH.w
    pla
    dey
    bne @fm_bot

    ; Restore display
    lda SHADOW_INIDISP.w
    sta INIDISP.w

    sep #$10
    .INDEX 8
    rts


; ============================================================================
; fmenu_close — Hide the file menu overlay, restore BG3 keyboard area
; Assumes: 8-bit A/X/Y
; ============================================================================
fmenu_close:
    .ACCU 8
    .INDEX 8

    stz fmenu_visible.w

    ; Clear the menu area on BG3 (rows 8-14, cols 10-21)
    lda #$8F
    sta INIDISP.w
    lda #$80
    sta VMAIN.w

    rep #$10
    .INDEX 16

    ldy #8                       ; Start row
@fc_row:
    cpy #15
    bcs @fc_done

    ; Compute VRAM address for row Y, col 10
    phy
    sty $04
    stz $05
    rep #$20
    .ACCU 16
    lda $04
    asl A
    asl A
    asl A
    asl A
    asl A                        ; × 32
    clc
    adc #VRAM_BG3_MAP + 10
    sta VMADDL.w
    sep #$20
    .ACCU 8
    ply

    ; Clear 12 tiles
    ldx #12
@fc_tile:
    stz VMDATAL.w
    lda #$00
    sta VMDATAH.w
    dex
    bne @fc_tile

    iny
    bra @fc_row

@fc_done:
    ; Restore display
    lda SHADOW_INIDISP.w
    sta INIDISP.w

    sep #$10
    .INDEX 8
    rts


; ============================================================================
; fmenu_update — Per-frame update for the file menu overlay
; Handles cursor hover, click, and d-pad navigation.
; Assumes: 8-bit A/X/Y
; ============================================================================
fmenu_update:
    .ACCU 8
    .INDEX 8

    ; --- Right-click to dismiss ---
    lda rclick_new.w
    beq @fm_no_dismiss
    jmp @fm_dismiss
@fm_no_dismiss:

    ; --- Mouse hover detection ---
    rep #$20
    .ACCU 16
    ; Check X bounds: cols 10-21 = pixels 80-175
    lda cursor_x.w
    cmp #80
    bcc @fm_no_hover
    cmp #176
    bcs @fm_no_hover

    ; Check row 10 = SAVE (Y 80-87)
    lda cursor_y.w
    cmp #80
    bcc @fm_no_hover
    cmp #88
    bcc @fm_hover_0
    ; Check row 11 = SAVE AS (Y 88-95)
    cmp #96
    bcc @fm_hover_1
    ; Check row 12 = CLOSE (Y 96-103)
    cmp #104
    bcc @fm_hover_2
    bra @fm_no_hover

@fm_hover_0:
    sep #$20
    .ACCU 8
    stz fmenu_sel.w
    bra @fm_check_click
@fm_hover_1:
    sep #$20
    .ACCU 8
    lda #1
    sta fmenu_sel.w
    bra @fm_check_click
@fm_hover_2:
    sep #$20
    .ACCU 8
    lda #2
    sta fmenu_sel.w
    bra @fm_check_click

@fm_no_hover:
    sep #$20
    .ACCU 8

@fm_check_click:
    ; --- Update highlight if selection changed ---
    lda fmenu_sel.w
    cmp fmenu_prev_sel.w
    beq @fm_no_hl_change
    jsr _fmenu_update_highlight
    lda fmenu_sel.w
    sta fmenu_prev_sel.w
@fm_no_hl_change:

    ; --- Check for left-click ---
    lda click_new.w
    beq @fm_done
    ; Execute menu action
    lda fmenu_sel.w
    beq @fm_do_save
    cmp #1
    beq @fm_do_save_as
    ; Close
    jmp @fm_do_close

@fm_do_save:
    jsr fmenu_close
    ; If unsaved (current_slot == $FF), do save-as instead
    lda current_slot.w
    cmp #$FF
    beq @fm_do_save_as_direct
    ; Save to current slot
    lda current_slot.w
    jsr sram_save_file
    ; Brief feedback: update status bar text to show "SAVED"
    jsr _fmenu_show_saved
    rts

@fm_do_save_as_direct:
    ; Fall through to save-as without closing menu (already closed above)
    jmp _fmenu_start_save_as

@fm_do_save_as:
    jsr fmenu_close
    jmp _fmenu_start_save_as

@fm_do_close:
    jsr fmenu_close
    ; Check dirty flag
    lda file_type.w
    bne @fm_check_sheet_dirty
    lda doc_dirty.w
    bra @fm_check_dirty_val
@fm_check_sheet_dirty:
    lda sheet_dirty.w
@fm_check_dirty_val:
    beq @fm_close_now
    ; Show dirty confirmation dialog
    jsr _dialog_show_dirty
    rts

@fm_close_now:
    ; Fade out and return to title
    lda #FADE_OUT
    sta fade_dir.w
    rts

@fm_dismiss:
    jsr fmenu_close
@fm_done:
    rts


; ============================================================================
; _fmenu_update_highlight — Update menu item highlight on BG3
; Highlights current selection with yellow palette, others white.
; Assumes: 8-bit A/X/Y
; ============================================================================
_fmenu_update_highlight:
    .ACCU 8
    .INDEX 8

    lda #$8F
    sta INIDISP.w
    lda #$80
    sta VMAIN.w

    rep #$10
    .INDEX 16

    ; Update all 3 menu rows (10, 11, 12)
    ldy #$0000                   ; Y = menu item index
@hl_loop:
    cpy #3
    bcs @hl_done

    ; Compute VRAM address for row (10 + Y), col 10
    phy
    sty $04
    stz $05
    rep #$20
    .ACCU 16
    lda $04
    clc
    adc #10                      ; Row 10 + Y
    asl A
    asl A
    asl A
    asl A
    asl A                        ; × 32
    clc
    adc #VRAM_BG3_MAP + 10
    sta VMADDL.w
    sep #$20
    .ACCU 8
    ply

    ; Determine palette: highlight if Y == fmenu_sel
    tya
    cmp fmenu_sel.w
    bne @hl_normal
    lda #$24                     ; PPP=1 (yellow/highlight) + priority
    bra @hl_write
@hl_normal:
    lda #$20                     ; PPP=0 (white/normal) + priority

@hl_write:
    sta $06                      ; $06 = palette byte

    ; Re-read and rewrite the 12 tile entries with new palette
    ; Since VMAIN=$80, just read current low bytes and rewrite
    ; Actually, we need to rewrite the tile data. Let's just rewrite
    ; the menu text with the appropriate palette.
    ; This requires knowing the tile content. Since we already know it,
    ; just rewrite the row.
    phx
    phy

    ; Determine which row text to write based on Y
    tya
    beq @hl_save_row
    cmp #1
    beq @hl_saveas_row
    ; Close row
    ldx #_fm_close_tiles.w
    bra @hl_write_row
@hl_save_row:
    ldx #_fm_save_tiles.w
    bra @hl_write_row
@hl_saveas_row:
    ldx #_fm_saveas_tiles.w

@hl_write_row:
    ldy #12
@hl_tile:
    lda $0000.w,X
    sta VMDATAL.w
    lda $06
    sta VMDATAH.w
    inx
    dey
    bne @hl_tile

    ply
    plx

    iny
    bra @hl_loop

@hl_done:
    lda SHADOW_INIDISP.w
    sta INIDISP.w

    sep #$10
    .INDEX 8
    rts

; Menu row tile data (12 bytes each)
_fm_save_tiles:
    .db 0, 0, 19, 1, 22, 5, 0, 0, 0, 0, 0, 0       ; "  SAVE      "
_fm_saveas_tiles:
    .db 0, 0, 19, 1, 22, 5, 0, 1, 19, 0, 0, 0       ; "  SAVE AS   "
_fm_close_tiles:
    .db 0, 0, 3, 12, 15, 19, 5, 0, 0, 0, 0, 0       ; "  CLOSE     "


; ============================================================================
; _fmenu_show_saved — Show "SAVED" briefly on status bar
; Assumes: 8-bit A/X/Y
; ============================================================================
_fmenu_show_saved:
    .ACCU 8
    .INDEX 8

    ; Force blank, write "SAVED" on row 0
    lda #$8F
    sta INIDISP.w
    lda #$80
    sta VMAIN.w

    rep #$20
    .ACCU 16
    lda #VRAM_BG1_MAP + 12       ; Row 0, col 12
    sta VMADDL.w
    sep #$20
    .ACCU 8

    ; "SAVED" in 4bpp font tile indices
    ; S=19, A=1, V=22, E=5, D=4 (using ascii_to_tile mapping)
    ; Actually these are keyboard tile indices used by _write_tile
    ; For BG1 we need 4bpp font tile indices from ascii_to_tile table
    ; Let's use the _char_to_tile approach: 'S'=$53, 'A'=$41, etc.
    ; But _char_to_tile needs 16-bit index mode. Just hardcode tile indices.
    ; From textfont: Space=0, !=1, "=2... A=33, B=34... S=51, etc.
    ; ascii_to_tile: ASCII - $20 → table lookup
    ; 'S' = $53 - $20 = $33 = 51 → tile 19 (from keyboard) but we're on BG1 with 4bpp
    ; Let's look at what textdoc uses: tile indices via ascii_to_tile table
    ; S=83-32=51, A=65-32=33, V=86-32=54, E=69-32=37, D=68-32=36
    ; But the actual tile number depends on the ascii_to_tile table values
    ; The textdoc renderer calls _char_to_tile which indexes into ascii_to_tile
    ; We need to use the same table. Let's just write with the keyboard tile
    ; system since BG3 is available and visible.

    ; Actually, we're on BG1 which has 4bpp textfont tiles.
    ; The status bar uses _write_tile macro which writes keyboard-indexed tiles.
    ; But _write_tile on BG1 uses the same tile indices? No, _write_tile
    ; was defined in menu.asm and writes tile index + palette $20 to VRAM.
    ; For BG1 with textfont, the tile indices are different.
    ;
    ; Looking at _textdoc_render_status: it uses _write_tile with keyboard
    ; tile indices (21=U, 14=N, 20=T, 9=I, 20=T, 12=L, 5=E, 4=D).
    ; These match keyboard tile indices (A=1, B=2, ..., Z=26).
    ; But BG1 uses textfont 4bpp tiles which have DIFFERENT indices!
    ; The textfont tiles are arranged differently from keyboard tiles.
    ;
    ; Wait - looking more carefully at the textfont, the tile indices in
    ; textdoc_render_status use single-digit values that look like keyboard
    ; indices. The textfont_tiles use the MAKE_4BPP_TILE macro and create
    ; tiles in the same order as keyboard tiles. So tile 1=A, 2=B, etc.
    ; Yes — the textfont reuses keyboard tile ordering.

    ; So: S=19, A=1, V=22, E=5, D=4
    _write_tile 19               ; S
    _write_tile 1                ; A
    _write_tile 22               ; V
    _write_tile 5                ; E
    _write_tile 4                ; D
    _write_tile 0                ; space
    _write_tile 0                ; space
    _write_tile 0                ; space

    lda SHADOW_INIDISP.w
    sta INIDISP.w

    ; Set dirty flag to re-render on next frame (restores status bar text)
    lda file_type.w
    bne @ss_dirty
    lda #$01
    sta doc_dirty.w
    rts
@ss_dirty:
    lda #$01
    sta sheet_dirty.w
    rts


; ============================================================================
; _fmenu_start_save_as — Begin "Save As" flow: prompt for filename
; Sets up dialog for filename entry using on-screen keyboard.
; Assumes: 8-bit A/X/Y
; ============================================================================
_fmenu_start_save_as:
    .ACCU 8
    .INDEX 8

    lda #$01
    sta dialog_visible.w
    lda #$01                     ; Dialog type: filename entry
    sta dialog_type.w
    stz save_name_len.w

    ; Clear save_name_buf
    ldx #0
@clr_name:
    stz save_name_buf.w,X
    inx
    cpx #SRAM_NAME_LEN
    bne @clr_name

    ; Draw filename entry dialog on BG3 (rows 4-7)
    lda #$8F
    sta INIDISP.w
    lda #$80
    sta VMAIN.w

    rep #$10
    .INDEX 16

    ; Top border (row 4)
    rep #$20
    .ACCU 16
    lda #VRAM_BG3_MAP + (4 * 32) + 8
    sta VMADDL.w
    sep #$20
    .ACCU 8
    lda #KBD_TILE_HLINE
    ldy #16
@sas_top:
    sta VMDATAL.w
    pha
    lda #$20
    sta VMDATAH.w
    pla
    dey
    bne @sas_top

    ; Row 5: "  ENTER NAME  " (16 chars)
    rep #$20
    .ACCU 16
    lda #VRAM_BG3_MAP + (5 * 32) + 8
    sta VMADDL.w
    sep #$20
    .ACCU 8
    _write_tile 0                ; space
    _write_tile 0                ; space
    _write_tile 5                ; E
    _write_tile 14               ; N
    _write_tile 20               ; T
    _write_tile 5                ; E
    _write_tile 18               ; R
    _write_tile 0                ; space
    _write_tile 14               ; N
    _write_tile 1                ; A
    _write_tile 13               ; M
    _write_tile 5                ; E
    _write_tile 0                ; space
    _write_tile 0                ; space
    _write_tile 0                ; space
    _write_tile 0                ; space

    ; Row 6: filename display area (blank initially)
    rep #$20
    .ACCU 16
    lda #VRAM_BG3_MAP + (6 * 32) + 8
    sta VMADDL.w
    sep #$20
    .ACCU 8
    _write_tile 0                ; space
    _write_tile 0                ; space
    ; 12 blank tiles for name
    ldy #12
@sas_blank:
    stz VMDATAL.w
    lda #$24                     ; Highlight palette
    sta VMDATAH.w
    dey
    bne @sas_blank
    _write_tile 0                ; space
    _write_tile 0                ; space

    ; Bottom border (row 7)
    rep #$20
    .ACCU 16
    lda #VRAM_BG3_MAP + (7 * 32) + 8
    sta VMADDL.w
    sep #$20
    .ACCU 8
    lda #KBD_TILE_HLINE
    ldy #16
@sas_bot:
    sta VMDATAL.w
    pha
    lda #$20
    sta VMDATAH.w
    pla
    dey
    bne @sas_bot

    lda SHADOW_INIDISP.w
    sta INIDISP.w

    sep #$10
    .INDEX 8
    rts


; ============================================================================
; _dialog_update_name — Per-frame update for filename entry dialog
; Processes keyboard chars into save_name_buf.
; Assumes: 8-bit A/X/Y
; ============================================================================
_dialog_update_name:
    .ACCU 8
    .INDEX 8

    ; Process keyboard character
    lda kbd_char_out.w
    beq @dn_no_char

    ; ENTER = confirm filename
    cmp #KEY_ENTER
    beq @dn_confirm

    ; BKSP = delete last char
    cmp #KEY_BKSP
    beq @dn_bksp

    ; SHIFT toggle = ignore
    cmp #KEY_SHIFT
    beq @dn_no_char

    ; DEL = ignore
    cmp #KEY_DEL
    beq @dn_no_char

    ; Printable char — append if room
    cmp #$20
    bcc @dn_no_char
    cmp #$7F
    bcs @dn_no_char

    ldx save_name_len.w
    cpx #SRAM_NAME_LEN
    bcs @dn_no_char              ; Name full

    sta save_name_buf.w,X
    inc save_name_len.w
    jsr _dialog_redraw_name
    rts

@dn_bksp:
    lda save_name_len.w
    beq @dn_no_char
    dec save_name_len.w
    ldx save_name_len.w
    stz save_name_buf.w,X
    jsr _dialog_redraw_name
    rts

@dn_confirm:
    ; If name is empty, don't save
    lda save_name_len.w
    beq @dn_no_char

    ; Find a free slot
    jsr sram_find_free_slot
    cmp #$FF
    beq @dn_full                 ; No free slots

    ; Save to the found slot
    jsr sram_save_file

    ; Show "SAVED" feedback and trigger status bar re-render
    jsr _fmenu_show_saved

    ; Close file menu and dialog
    stz fmenu_visible.w
    stz dialog_visible.w
    jsr _dialog_clear_area
    rts

@dn_full:
    ; TODO: show "NO FREE SLOTS" message
    ; For now, just dismiss
    stz dialog_visible.w
    jsr _dialog_clear_area

@dn_no_char:
    rts


; ============================================================================
; _dialog_redraw_name — Redraw filename on BG3 row 6
; Assumes: 8-bit A/X/Y
; ============================================================================
_dialog_redraw_name:
    .ACCU 8
    .INDEX 8

    lda #$8F
    sta INIDISP.w
    lda #$80
    sta VMAIN.w

    rep #$20
    .ACCU 16
    lda #VRAM_BG3_MAP + (6 * 32) + 10   ; Row 6, col 10 (after 2 spaces)
    sta VMADDL.w
    sep #$20
    .ACCU 8

    ; Write name chars (up to 12)
    ldx #0
@rn_loop:
    cpx #SRAM_NAME_LEN
    bcs @rn_done
    cpx save_name_len.w
    bcs @rn_pad
    lda save_name_buf.w,X
    ; Convert to keyboard tile index
    jsr _ascii_to_kbd_tile
    sta VMDATAL.w
    lda #$24                     ; Highlight palette
    sta VMDATAH.w
    inx
    bra @rn_loop
@rn_pad:
    ; Show cursor at current position, blank after
    cpx save_name_len.w
    bne @rn_blank
    ; Cursor position — show underscore
    lda #KBD_TILE_USCORE
    sta VMDATAL.w
    lda #$24
    sta VMDATAH.w
    inx
    bra @rn_loop
@rn_blank:
    stz VMDATAL.w
    lda #$24
    sta VMDATAH.w
    inx
    bra @rn_loop
@rn_done:

    lda SHADOW_INIDISP.w
    sta INIDISP.w
    rts


; ============================================================================
; _ascii_to_kbd_tile — Convert ASCII char to keyboard 2bpp tile index
; Input: A = ASCII character
; Output: A = keyboard tile index
; Assumes: 8-bit A
; ============================================================================
_ascii_to_kbd_tile:
    ; Uppercase letters A-Z: tiles 1-26
    cmp #$41                     ; 'A'
    bcc @not_upper
    cmp #$5B                     ; 'Z' + 1
    bcs @not_upper
    sec
    sbc #$40                     ; 'A' - 1 → tile 1
    rts
@not_upper:
    ; Lowercase a-z: map to uppercase tiles 1-26
    cmp #$61                     ; 'a'
    bcc @not_lower
    cmp #$7B                     ; 'z' + 1
    bcs @not_lower
    sec
    sbc #$60                     ; 'a' - 1 → tile 1
    rts
@not_lower:
    ; Digits 0-9: tiles 53-62
    cmp #$30                     ; '0'
    bcc @not_digit
    cmp #$3A                     ; '9' + 1
    bcs @not_digit
    sec
    sbc #$30
    clc
    adc #53                      ; '0' → tile 53
    rts
@not_digit:
    ; Space
    cmp #$20
    bne @not_space
    lda #KBD_TILE_BLANK
    rts
@not_space:
    ; Other punctuation — map common ones
    cmp #$2D                     ; '-'
    bne +
    lda #KBD_TILE_MINUS
    rts
+   cmp #$2E                     ; '.'
    bne +
    lda #KBD_TILE_PERIOD
    rts
+   cmp #$5F                     ; '_'
    bne +
    lda #KBD_TILE_USCORE
    rts
+
    ; Default: blank
    lda #KBD_TILE_BLANK
    rts


; ============================================================================
; _dialog_clear_area — Clear dialog area on BG3 (rows 4-7)
; Assumes: 8-bit A/X/Y
; ============================================================================
_dialog_clear_area:
    .ACCU 8
    .INDEX 8

    lda #$8F
    sta INIDISP.w
    lda #$80
    sta VMAIN.w

    rep #$10
    .INDEX 16

    ldy #4
@dc_row:
    cpy #8
    bcs @dc_done

    phy
    sty $04
    stz $05
    rep #$20
    .ACCU 16
    lda $04
    asl A
    asl A
    asl A
    asl A
    asl A                        ; × 32
    clc
    adc #VRAM_BG3_MAP + 8
    sta VMADDL.w
    sep #$20
    .ACCU 8
    ply

    ldx #16
@dc_tile:
    stz VMDATAL.w
    stz VMDATAH.w
    dex
    bne @dc_tile

    iny
    bra @dc_row

@dc_done:
    lda SHADOW_INIDISP.w
    sta INIDISP.w

    sep #$10
    .INDEX 8
    rts


; ============================================================================
; _dialog_show_dirty — Show "SAVE CHANGES?" dialog on BG3
; Options: YES / NO / CANCEL
; Assumes: 8-bit A/X/Y
; ============================================================================
_dialog_show_dirty:
    .ACCU 8
    .INDEX 8

    lda #$01
    sta dialog_visible.w
    stz dialog_type.w            ; Type 0 = dirty prompt
    stz dialog_sel.w             ; Default to YES

    lda #$8F
    sta INIDISP.w
    lda #$80
    sta VMAIN.w

    rep #$10
    .INDEX 16

    ; Top border (row 5)
    rep #$20
    .ACCU 16
    lda #VRAM_BG3_MAP + (5 * 32) + 6
    sta VMADDL.w
    sep #$20
    .ACCU 8
    lda #KBD_TILE_HLINE
    ldy #20
@dd_top:
    sta VMDATAL.w
    pha
    lda #$20
    sta VMDATAH.w
    pla
    dey
    bne @dd_top

    ; Row 6: "  SAVE CHANGES?   "
    rep #$20
    .ACCU 16
    lda #VRAM_BG3_MAP + (6 * 32) + 6
    sta VMADDL.w
    sep #$20
    .ACCU 8
    _write_tile 0                ; space
    _write_tile 0                ; space
    _write_tile 19               ; S
    _write_tile 1                ; A
    _write_tile 22               ; V
    _write_tile 5                ; E
    _write_tile 0                ; space
    _write_tile 3                ; C
    _write_tile 8                ; H
    _write_tile 1                ; A
    _write_tile 14               ; N
    _write_tile 7                ; G
    _write_tile 5                ; E
    _write_tile 19               ; S
    _write_tile 47               ; ? (KBD_TILE_QUEST)
    _write_tile 0                ; space
    _write_tile 0                ; space
    _write_tile 0                ; space
    _write_tile 0                ; space
    _write_tile 0                ; space

    ; Row 7: blank
    rep #$20
    .ACCU 16
    lda #VRAM_BG3_MAP + (7 * 32) + 6
    sta VMADDL.w
    sep #$20
    .ACCU 8
    ldy #20
@dd_r7:
    stz VMDATAL.w
    lda #$20
    sta VMDATAH.w
    dey
    bne @dd_r7

    ; Row 8: " YES   NO  CANCEL "
    rep #$20
    .ACCU 16
    lda #VRAM_BG3_MAP + (8 * 32) + 6
    sta VMADDL.w
    sep #$20
    .ACCU 8
    _write_tile 0                ; space
    _write_tile 25               ; Y
    _write_tile 5                ; E
    _write_tile 19               ; S
    _write_tile 0                ; space
    _write_tile 0                ; space
    _write_tile 0                ; space
    _write_tile 14               ; N
    _write_tile 15               ; O
    _write_tile 0                ; space
    _write_tile 0                ; space
    _write_tile 0                ; space
    _write_tile 3                ; C
    _write_tile 1                ; A
    _write_tile 14               ; N
    _write_tile 3                ; C
    _write_tile 5                ; E
    _write_tile 12               ; L
    _write_tile 0                ; space
    _write_tile 0                ; space

    ; Bottom border (row 9)
    rep #$20
    .ACCU 16
    lda #VRAM_BG3_MAP + (9 * 32) + 6
    sta VMADDL.w
    sep #$20
    .ACCU 8
    lda #KBD_TILE_HLINE
    ldy #20
@dd_bot:
    sta VMDATAL.w
    pha
    lda #$20
    sta VMDATAH.w
    pla
    dey
    bne @dd_bot

    lda SHADOW_INIDISP.w
    sta INIDISP.w

    ; Highlight default selection
    jsr _dialog_update_dirty_hl

    sep #$10
    .INDEX 8
    rts


; ============================================================================
; _dialog_update_dirty — Per-frame update for "Save changes?" dialog
; Assumes: 8-bit A/X/Y
; ============================================================================
_dialog_update_dirty:
    .ACCU 8
    .INDEX 8

    ; Mouse hover on row 8 (Y 64-71)
    rep #$20
    .ACCU 16
    lda cursor_y.w
    cmp #64
    bcc @dd_no_hover
    cmp #72
    bcs @dd_no_hover

    ; YES = cols 7-9 (X 56-79), NO = cols 13-14 (X 104-119), CANCEL = cols 18-23 (X 144-191)
    lda cursor_x.w
    cmp #56
    bcc @dd_no_hover
    cmp #80
    bcc @dd_h_yes
    cmp #104
    bcc @dd_no_hover
    cmp #120
    bcc @dd_h_no
    cmp #144
    bcc @dd_no_hover
    cmp #192
    bcc @dd_h_cancel

@dd_no_hover:
    sep #$20
    .ACCU 8
    bra @dd_check_click

@dd_h_yes:
    sep #$20
    .ACCU 8
    stz dialog_sel.w
    jsr _dialog_update_dirty_hl
    bra @dd_check_click
@dd_h_no:
    sep #$20
    .ACCU 8
    lda #1
    sta dialog_sel.w
    jsr _dialog_update_dirty_hl
    bra @dd_check_click
@dd_h_cancel:
    sep #$20
    .ACCU 8
    lda #2
    sta dialog_sel.w
    jsr _dialog_update_dirty_hl

@dd_check_click:
    ; Right-click = cancel
    lda rclick_new.w
    beq @dd_no_rclick
    lda #2
    sta dialog_sel.w
    bra @dd_click
@dd_no_rclick:
    ; Left-click = confirm hovered option
    lda click_new.w
    beq @dd_done
@dd_click:
    lda dialog_sel.w
    beq @dd_yes
    cmp #1
    beq @dd_no
    ; Cancel — dismiss dialog
    stz dialog_visible.w
    jsr _dialog_clear_dirty
    rts

@dd_yes:
    ; Save, then close
    stz dialog_visible.w
    jsr _dialog_clear_dirty
    lda current_slot.w
    cmp #$FF
    beq @dd_yes_save_as
    ; Save to existing slot
    jsr sram_save_file
    lda #FADE_OUT
    sta fade_dir.w
    rts
@dd_yes_save_as:
    ; Need save-as flow
    jsr _fmenu_start_save_as
    rts

@dd_no:
    ; Discard and close
    stz dialog_visible.w
    jsr _dialog_clear_dirty
    lda #FADE_OUT
    sta fade_dir.w
    rts

@dd_done:
    rts


; ============================================================================
; _dialog_update_dirty_hl — Highlight current selection in dirty dialog
; Assumes: 8-bit A/X/Y
; ============================================================================
_dialog_update_dirty_hl:
    .ACCU 8
    .INDEX 8

    lda #$8F
    sta INIDISP.w
    lda #$80
    sta VMAIN.w

    rep #$10
    .INDEX 16

    ; Rewrite row 8 with highlights
    rep #$20
    .ACCU 16
    lda #VRAM_BG3_MAP + (8 * 32) + 6
    sta VMADDL.w
    sep #$20
    .ACCU 8

    ; YES (3 chars at offset 1-3)
    lda dialog_sel.w
    beq @dhl_yes_hl
    lda #$20                     ; Normal
    bra @dhl_yes_pal
@dhl_yes_hl:
    lda #$24                     ; Highlight
@dhl_yes_pal:
    sta $06

    ; Write " YES   "
    stz VMDATAL.w                ; space
    lda #$20
    sta VMDATAH.w
    lda #25                      ; Y
    sta VMDATAL.w
    lda $06
    sta VMDATAH.w
    lda #5                       ; E
    sta VMDATAL.w
    lda $06
    sta VMDATAH.w
    lda #19                      ; S
    sta VMDATAL.w
    lda $06
    sta VMDATAH.w
    stz VMDATAL.w                ; space
    lda #$20
    sta VMDATAH.w
    stz VMDATAL.w                ; space
    lda #$20
    sta VMDATAH.w

    ; NO (2 chars at offset 7-8)
    lda dialog_sel.w
    cmp #1
    beq @dhl_no_hl
    lda #$20
    bra @dhl_no_pal
@dhl_no_hl:
    lda #$24
@dhl_no_pal:
    sta $06

    stz VMDATAL.w                ; space
    lda #$20
    sta VMDATAH.w
    lda #14                      ; N
    sta VMDATAL.w
    lda $06
    sta VMDATAH.w
    lda #15                      ; O
    sta VMDATAL.w
    lda $06
    sta VMDATAH.w
    stz VMDATAL.w                ; space
    lda #$20
    sta VMDATAH.w
    stz VMDATAL.w                ; space
    lda #$20
    sta VMDATAH.w

    ; CANCEL (6 chars at offset 12-17)
    lda dialog_sel.w
    cmp #2
    beq @dhl_can_hl
    lda #$20
    bra @dhl_can_pal
@dhl_can_hl:
    lda #$24
@dhl_can_pal:
    sta $06

    stz VMDATAL.w                ; space
    lda #$20
    sta VMDATAH.w
    lda #3                       ; C
    sta VMDATAL.w
    lda $06
    sta VMDATAH.w
    lda #1                       ; A
    sta VMDATAL.w
    lda $06
    sta VMDATAH.w
    lda #14                      ; N
    sta VMDATAL.w
    lda $06
    sta VMDATAH.w
    lda #3                       ; C
    sta VMDATAL.w
    lda $06
    sta VMDATAH.w
    lda #5                       ; E
    sta VMDATAL.w
    lda $06
    sta VMDATAH.w
    lda #12                      ; L
    sta VMDATAL.w
    lda $06
    sta VMDATAH.w
    stz VMDATAL.w                ; space
    lda #$20
    sta VMDATAH.w

    lda SHADOW_INIDISP.w
    sta INIDISP.w

    sep #$10
    .INDEX 8
    rts


; ============================================================================
; _dialog_clear_dirty — Clear dirty dialog area on BG3 (rows 5-9)
; Assumes: 8-bit A/X/Y
; ============================================================================
_dialog_clear_dirty:
    .ACCU 8
    .INDEX 8

    lda #$8F
    sta INIDISP.w
    lda #$80
    sta VMAIN.w

    rep #$10
    .INDEX 16

    ldy #5
@cdd_row:
    cpy #10
    bcs @cdd_done

    phy
    sty $04
    stz $05
    rep #$20
    .ACCU 16
    lda $04
    asl A
    asl A
    asl A
    asl A
    asl A                        ; × 32
    clc
    adc #VRAM_BG3_MAP + 6
    sta VMADDL.w
    sep #$20
    .ACCU 8
    ply

    ldx #20
@cdd_tile:
    stz VMDATAL.w
    stz VMDATAH.w
    dex
    bne @cdd_tile

    iny
    bra @cdd_row

@cdd_done:
    lda SHADOW_INIDISP.w
    sta INIDISP.w

    sep #$10
    .INDEX 8
    rts
