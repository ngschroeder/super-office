; ============================================================================
; menu.asm — Type Selection Submenu & File Browser
;
; STATE_TYPE_SEL: "TEXT DOCUMENT" / "SPREADSHEET" choice after "CREATE NEW"
; STATE_FILE_BRW: File browser listing saved files from SRAM (stub for now)
;
; Both screens reuse BG1 for text (same font tiles uploaded by title_init)
; and clear BG2/sprites. BG3 is off (keyboard not active on these screens).
; ============================================================================

; ============================================================================
; Menu font tile additions — we need additional letters not in the title font
; B=2, D=4, G=7, H=8, K=11, M=13, X=24, Y=25 (using keyboard tile indices)
; But the title BG1 font only has 15 tiles (A,C,E,F,I,L,N,O,P,R,S,T,U,W).
;
; Solution: upload the full keyboard 2bpp font to BG1 as 4bpp during menu
; states, since we need all 26 letters. The 2bpp tile data can be converted
; on the fly, or we create a separate 4bpp font for menus.
;
; Simpler solution: reuse the keyboard 2bpp tiles on BG3 for menu text too.
; Just enable BG3 and write the text there. BG1/BG2 can be blank.
; ============================================================================


; ============================================================================
; type_sel_init — Set up the type selection screen
; Called from state dispatch when entering STATE_TYPE_SEL.
; Assumes: 8-bit A/X/Y
; ============================================================================
type_sel_init:
    .ACCU 8
    .INDEX 8

    ; === Force blank ===
    lda #$8F
    sta INIDISP.w

    ; === Disable HDMA (no sky gradient on this screen) ===
    stz SHADOW_HDMAEN.w
    stz HDMAEN.w

    ; === Clear OAM (hide title icons, keep cursor) ===
    jsr clear_oam

    ; === Upload keyboard 2bpp tiles to BG3 chr for menu text ===
    lda #$80
    sta VMAIN.w
    lda #$01
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

    ; === Upload keyboard palette to CGRAM 0-7 ===
    stz CGADD.w
    lda #$00
    sta DMAP0.w
    lda #$22
    sta BBAD0.w
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

    ; === Set backdrop color to dark blue ===
    stz CGADD.w
    lda #$00
    sta CGDATA.w
    lda #$28
    sta CGDATA.w

    ; === Build BG3 tilemap for type selection menu ===
    jsr _type_sel_build_map

    ; === PPU config: BG3 only + sprites ===
    lda #%00010100               ; OBJ + BG3
    sta SHADOW_TM.w
    sta TM.w

    ; Mode 1 with BG3 priority
    lda #$09
    sta SHADOW_BGMODE.w
    sta BGMODE.w

    ; Disable color math
    stz SHADOW_CGWSEL.w
    stz CGWSEL.w
    stz SHADOW_CGADSUB.w
    stz CGADSUB.w

    ; === Initialize selection ===
    stz menu_sel.w               ; 0 = Text Document
    lda #$FF
    sta menu_prev_sel2.w

    ; === Start fade in ===
    lda #FADE_IN
    sta fade_dir.w
    stz fade_level.w
    stz SHADOW_INIDISP.w
    stz INIDISP.w

    rts


; ============================================================================
; state_type_sel — Per-frame update for type selection screen
; Assumes: 8-bit A/X/Y
; ============================================================================
state_type_sel:
    .ACCU 8
    .INDEX 8

    jsr read_input

    ; Handle fade
    lda fade_dir.w
    beq @no_fade

    cmp #FADE_IN
    bne @fade_out_ts

    lda fade_level.w
    cmp #$0F
    bcs @fade_in_done_ts
    inc A
    sta fade_level.w
    sta SHADOW_INIDISP.w
    rts

@fade_in_done_ts:
    stz fade_dir.w
    bra @no_fade

@fade_out_ts:
    lda fade_level.w
    beq @fade_out_done_ts
    dec A
    sta fade_level.w
    sta SHADOW_INIDISP.w
    rts

@fade_out_done_ts:
    stz fade_dir.w
    ; Check if going back to title
    lda menu_sel.w
    cmp #$FE
    bne @not_back_ts
    ; Return to title via boot
    lda #STATE_BOOT
    sta current_state.w
    rts
@not_back_ts:
    ; Set up as new unsaved file
    lda #$FF
    sta current_slot.w

    ; Transition to editor state based on menu_sel
    lda menu_sel.w
    beq @to_textdoc
    ; Spreadsheet
    lda #$01
    sta file_type.w
    lda #STATE_SHEET
    sta current_state.w
    rts
@to_textdoc:
    stz file_type.w              ; 0 = text doc
    lda #STATE_TEXTDOC
    sta current_state.w
    rts

@no_fade:
    ; --- Check cursor against menu items ---
    jsr _type_sel_check_hover

    ; --- Check for click ---
    lda click_new.w
    beq @no_click_ts
    lda menu_sel.w
    cmp #$FF
    beq @no_click_ts
    ; Play menu select SFX and start fade out
    lda #SFX_MENU_SEL
    jsr play_sfx
    lda #FADE_OUT
    sta fade_dir.w
    rts

@no_click_ts:
    ; --- Right-click = go back to title ---
    lda rclick_new.w
    beq @no_back

    ; Fade out, then return to boot (re-init title)
    lda #SFX_MENU_SEL
    jsr play_sfx
    lda #FADE_OUT
    sta fade_dir.w
    lda #$FE                     ; Special: go back to title
    sta menu_sel.w
    rts

@no_back:
    ; --- Update highlight if selection changed ---
    lda menu_sel.w
    cmp menu_prev_sel2.w
    beq @no_change_ts
    jsr _type_sel_update_arrow
    lda menu_sel.w
    sta menu_prev_sel2.w
@no_change_ts:
    rts


; ============================================================================
; _type_sel_build_map — Build BG3 tilemap for type selection screen
; Shows "SELECT TYPE" header and two menu items.
; Must be called during force blank.
; Assumes: 8-bit A/X/Y
; ============================================================================
_type_sel_build_map:
    .ACCU 8
    .INDEX 8

    lda #$80
    sta VMAIN.w

    ; Zero entire BG3 tilemap
    rep #$20
    .ACCU 16
    lda #VRAM_BG3_MAP
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

    ; --- Write "SELECT TYPE" at row 8, col 10 (11 chars) ---
    ; S E L E C T   T Y P E
    ; Tile indices: 19,5,12,5,3,20,0,20,25,16,5
    rep #$20
    .ACCU 16
    lda #VRAM_BG3_MAP + (8 * 32) + 10
    sta VMADDL.w
    sep #$20
    .ACCU 8

    ; Write each tile manually (no DMA — just 11 tiles)
    lda #19                      ; S
    sta VMDATAL.w
    lda #$30                     ; Priority=1, PPP=4 (text label)
    sta VMDATAH.w
    lda #5                       ; E
    sta VMDATAL.w
    lda #$30
    sta VMDATAH.w
    lda #12                      ; L
    sta VMDATAL.w
    lda #$30
    sta VMDATAH.w
    lda #5                       ; E
    sta VMDATAL.w
    lda #$30
    sta VMDATAH.w
    lda #3                       ; C
    sta VMDATAL.w
    lda #$30
    sta VMDATAH.w
    lda #20                      ; T
    sta VMDATAL.w
    lda #$30
    sta VMDATAH.w
    stz VMDATAL.w                ; space
    lda #$30
    sta VMDATAH.w
    lda #20                      ; T
    sta VMDATAL.w
    lda #$30
    sta VMDATAH.w
    lda #25                      ; Y
    sta VMDATAL.w
    lda #$30
    sta VMDATAH.w
    lda #16                      ; P
    sta VMDATAL.w
    lda #$30
    sta VMDATAH.w
    lda #5                       ; E
    sta VMDATAL.w
    lda #$30
    sta VMDATAH.w

    ; --- Write "TEXT DOCUMENT" at row 13, col 10 ---
    ; T E X T   D O C U M E N T (13 chars)
    rep #$20
    .ACCU 16
    lda #VRAM_BG3_MAP + (13 * 32) + 10
    sta VMADDL.w
    sep #$20
    .ACCU 8

    .MACRO _write_tile ARGS _tile
        lda #_tile
        sta VMDATAL.w
        lda #$30                     ; PPP=4 (white text on transparent) + priority
        sta VMDATAH.w
    .ENDM

    .MACRO _write_tile_bg1 ARGS _tile
        lda #_tile
        sta VMDATAL.w
        lda #$20                     ; PPP=0 (BG1 4bpp font palette) + priority
        sta VMDATAH.w
    .ENDM

    _write_tile 20               ; T
    _write_tile 5                ; E
    _write_tile 24               ; X
    _write_tile 20               ; T
    _write_tile 0                ; (space)
    _write_tile 4                ; D
    _write_tile 15               ; O
    _write_tile 3                ; C
    _write_tile 21               ; U
    _write_tile 13               ; M
    _write_tile 5                ; E
    _write_tile 14               ; N
    _write_tile 20               ; T

    ; --- Write "SPREADSHEET" at row 15, col 10 ---
    ; S P R E A D S H E E T (11 chars)
    rep #$20
    .ACCU 16
    lda #VRAM_BG3_MAP + (15 * 32) + 10
    sta VMADDL.w
    sep #$20
    .ACCU 8

    _write_tile 19               ; S
    _write_tile 16               ; P
    _write_tile 18               ; R
    _write_tile 5                ; E
    _write_tile 1                ; A
    _write_tile 4                ; D
    _write_tile 19               ; S
    _write_tile 8                ; H
    _write_tile 5                ; E
    _write_tile 5                ; E
    _write_tile 20               ; T

    rts


; ============================================================================
; _type_sel_check_hover — Check cursor against type selection hit boxes
; Row 13 = "TEXT DOCUMENT" (pixel Y 104-111), row 15 = "SPREADSHEET" (Y 120-127)
; Col range 10-22 (pixel X 80-183)
; ============================================================================
_type_sel_check_hover:
    .ACCU 8
    .INDEX 8

    rep #$20
    .ACCU 16

    ; Check X bounds
    lda cursor_x.w
    cmp #80
    bcc @no_sel
    cmp #184
    bcs @no_sel

    ; Check "TEXT DOCUMENT" row (Y 104-111)
    lda cursor_y.w
    cmp #104
    bcc @no_sel
    cmp #112
    bcc @sel0

    ; Check "SPREADSHEET" row (Y 120-127)
    cmp #120
    bcc @no_sel
    cmp #128
    bcc @sel1

@no_sel:
    sep #$20
    .ACCU 8
    lda #$FF
    sta menu_sel.w
    rts

@sel0:
    sep #$20
    .ACCU 8
    stz menu_sel.w               ; 0 = text doc
    rts

@sel1:
    sep #$20
    .ACCU 8
    lda #$01
    sta menu_sel.w               ; 1 = spreadsheet
    rts


; ============================================================================
; _type_sel_update_arrow — Show selection arrow next to chosen item
; Reuses OAM entry 5 (8x8 arrow sprite, same as title screen)
; Assumes: 8-bit A/X/Y
; ============================================================================
_type_sel_update_arrow:
    .ACCU 8
    .INDEX 8

    lda menu_sel.w
    cmp #$FF
    beq @hide_sel_arrow

    ; X = col 9 * 8 = 72
    lda #72
    sta OAM_BUF+20.w

    ; Y based on selection
    lda menu_sel.w
    beq @sel_arrow_0
    lda #120                     ; Row 15 * 8 = 120
    bra @set_sel_y
@sel_arrow_0:
    lda #104                     ; Row 13 * 8 = 104
@set_sel_y:
    sta OAM_BUF+21.w

    ; Use cursor tile 0 (arrow shape), priority 3, palette 0
    stz OAM_BUF+22.w
    lda #%00110000
    sta OAM_BUF+23.w

    ; High table: sprite 5 = byte 1, bits 3:2 — small (8x8)
    lda OAM_BUF_HI+1.w
    and #%11110011
    sta OAM_BUF_HI+1.w
    rts

@hide_sel_arrow:
    lda #$F0
    sta OAM_BUF+21.w
    rts


; ============================================================================
; file_brw_init — Set up the file browser screen with real SRAM data
; Assumes: 8-bit A/X/Y
; ============================================================================
file_brw_init:
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

    ; === Upload keyboard 2bpp tiles to BG3 chr ===
    lda #$80
    sta VMAIN.w
    lda #$01
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

    ; === Upload keyboard palette (includes highlight sub-palette) ===
    stz CGADD.w
    lda #$00
    sta DMAP0.w
    lda #$22
    sta BBAD0.w
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

    ; === Backdrop color ===
    stz CGADD.w
    lda #$00
    sta CGDATA.w
    lda #$28
    sta CGDATA.w

    ; === Zero BG3 tilemap ===
    rep #$20
    .ACCU 16
    lda #VRAM_BG3_MAP
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

    ; === Refresh directory from SRAM ===
    jsr sram_get_directory

    ; === Initialize browser state ===
    lda #$FF
    sta fb_sel.w
    sta fb_prev_sel.w
    stz fb_confirm_del.w
    lda #$01
    sta fb_initialized.w

    ; === Build tilemap: header + file list ===
    jsr _fb_render

    ; === PPU: BG3 + OBJ ===
    lda #%00010100
    sta SHADOW_TM.w
    sta TM.w

    lda #$09
    sta SHADOW_BGMODE.w
    sta BGMODE.w

    stz SHADOW_CGWSEL.w
    stz CGWSEL.w
    stz SHADOW_CGADSUB.w
    stz CGADSUB.w

    ; === Fade in ===
    lda #FADE_IN
    sta fade_dir.w
    stz fade_level.w
    stz SHADOW_INIDISP.w
    stz INIDISP.w

    rts


; ============================================================================
; _fb_render — Render file browser tilemap on BG3
; Shows "OPEN FILE" header and 8 file slots.
; Must be called during force blank.
; Assumes: 8-bit A/X/Y
; ============================================================================
_fb_render:
    .ACCU 8
    .INDEX 8

    lda #$80
    sta VMAIN.w

    ; --- Header: "OPEN FILE" at row 2, col 11 ---
    rep #$20
    .ACCU 16
    lda #VRAM_BG3_MAP + (2 * 32) + 11
    sta VMADDL.w
    sep #$20
    .ACCU 8

    _write_tile 15               ; O
    _write_tile 16               ; P
    _write_tile 5                ; E
    _write_tile 14               ; N
    _write_tile 0                ; space
    _write_tile 6                ; F
    _write_tile 9                ; I
    _write_tile 12               ; L
    _write_tile 5                ; E

    ; --- Render 8 file slots (rows 5-12, one per row) ---
    ldx #0                       ; X = slot index (8-bit)
@fb_slot:
    cpx #SRAM_MAX_SLOTS
    bcc @fb_slot_continue
    jmp @fb_footer
@fb_slot_continue:

    ; Compute VRAM address for row (5 + X), col 4
    phx
    txa
    clc
    adc #5                       ; Row = 5 + slot
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
    adc #VRAM_BG3_MAP + 4
    sta VMADDL.w
    sep #$20
    .ACCU 8
    plx

    ; Determine row palette: highlight if X == fb_sel
    ; $0E = palette byte for this row
    txa
    cmp fb_sel.w
    bne @fb_pal_normal
    lda #$34                     ; Highlight (PPP=5, yellow text)
    bra @fb_pal_set
@fb_pal_normal:
    lda #$30                     ; Normal (PPP=4, white text)
@fb_pal_set:
    sta $0E                      ; $0E = palette high byte for this row

    ; Read directory entry flags from WRAM cache
    ; Entry offset = slot * 16
    phx
    txa
    asl A
    asl A
    asl A
    asl A                        ; × 16
    tay                          ; Y = dir entry offset in cache

    lda SRAM_DIR_BUF.w,Y        ; Flags byte
    and #SRAM_FLAG_USED
    bne @fb_occupied_slot
    jmp @fb_empty_slot
@fb_occupied_slot:

    ; --- Occupied slot ---
    ; Write slot number (1-based digit)
    plx
    phx
    txa
    inc A
    clc
    adc #53                      ; Digit tile (1→54, 2→55, ...)
    sta VMDATAL.w
    lda $0E
    sta VMDATAH.w

    ; Separator: period
    lda #KBD_TILE_PERIOD
    sta VMDATAL.w
    lda $0E
    sta VMDATAH.w

    ; Space
    stz VMDATAL.w
    lda $0E
    sta VMDATAH.w

    ; Write filename (12 chars from dir cache offset + 3)
    phy
    ; Name starts at Y + 3
    tya
    clc
    adc #3
    tay                          ; Y = name start offset
    ldx #0                       ; X = char counter
@fb_name_char:
    cpx #SRAM_NAME_LEN
    bcs @fb_name_done
    lda SRAM_DIR_BUF.w,Y
    beq @fb_name_pad
    jsr _ascii_to_kbd_tile
    sta VMDATAL.w
    lda $0E
    sta VMDATAH.w
    iny
    inx
    bra @fb_name_char
@fb_name_pad:
    cpx #SRAM_NAME_LEN
    bcs @fb_name_done
    stz VMDATAL.w
    lda $0E
    sta VMDATAH.w
    inx
    bra @fb_name_pad
@fb_name_done:
    ply                          ; Restore dir entry Y

    ; Space
    stz VMDATAL.w
    lda $0E
    sta VMDATAH.w

    ; Type label: "TXT" or "SHT"
    lda SRAM_DIR_BUF.w,Y        ; Re-read flags
    and #SRAM_FLAG_SHEET
    bne @fb_type_sheet

    ; Text: write TXT with row palette
    lda #20                      ; T
    sta VMDATAL.w
    lda $0E
    sta VMDATAH.w
    lda #24                      ; X
    sta VMDATAL.w
    lda $0E
    sta VMDATAH.w
    lda #20                      ; T
    sta VMDATAL.w
    lda $0E
    sta VMDATAH.w
    bra @fb_slot_end

@fb_type_sheet:
    lda #19                      ; S
    sta VMDATAL.w
    lda $0E
    sta VMDATAH.w
    lda #8                       ; H
    sta VMDATAL.w
    lda $0E
    sta VMDATAH.w
    lda #20                      ; T
    sta VMDATAL.w
    lda $0E
    sta VMDATAH.w

@fb_slot_end:
    ; Pad remaining cols with blanks
    ldy #4
@fb_pad:
    stz VMDATAL.w
    lda $0E
    sta VMDATAH.w
    dey
    bne @fb_pad

    plx
    inx
    jmp @fb_slot

@fb_empty_slot:
    ; Write slot number
    plx
    phx
    txa
    inc A
    clc
    adc #53
    sta VMDATAL.w
    lda $0E
    sta VMDATAH.w

    ; Period
    lda #KBD_TILE_PERIOD
    sta VMDATAL.w
    lda $0E
    sta VMDATAH.w

    ; Space
    stz VMDATAL.w
    lda $0E
    sta VMDATAH.w

    ; "- EMPTY -" (9 chars)
    lda #KBD_TILE_MINUS
    sta VMDATAL.w
    lda $0E
    sta VMDATAH.w
    stz VMDATAL.w                ; space
    lda $0E
    sta VMDATAH.w
    lda #5                       ; E
    sta VMDATAL.w
    lda $0E
    sta VMDATAH.w
    lda #13                      ; M
    sta VMDATAL.w
    lda $0E
    sta VMDATAH.w
    lda #16                      ; P
    sta VMDATAL.w
    lda $0E
    sta VMDATAH.w
    lda #20                      ; T
    sta VMDATAL.w
    lda $0E
    sta VMDATAH.w
    lda #25                      ; Y
    sta VMDATAL.w
    lda $0E
    sta VMDATAH.w
    stz VMDATAL.w                ; space
    lda $0E
    sta VMDATAH.w
    lda #KBD_TILE_MINUS
    sta VMDATAL.w
    lda $0E
    sta VMDATAH.w

    ; Pad remaining (24 - 3 - 9 = 12 tiles)
    ldy #12
@fb_epad:
    stz VMDATAL.w
    lda $0E
    sta VMDATAH.w
    dey
    bne @fb_epad

    plx
    inx
    jmp @fb_slot

@fb_footer:
    ; --- Footer: "RIGHT-CLICK TO DELETE" at row 16 ---
    rep #$20
    .ACCU 16
    lda #VRAM_BG3_MAP + (16 * 32) + 6
    sta VMADDL.w
    sep #$20
    .ACCU 8

    _write_tile 18               ; R
    _write_tile 9                ; I
    _write_tile 7                ; G
    _write_tile 8                ; H
    _write_tile 20               ; T
    _write_tile 83               ; -
    _write_tile 3                ; C
    _write_tile 12               ; L
    _write_tile 9                ; I
    _write_tile 3                ; C
    _write_tile 11               ; K
    _write_tile 0                ; space
    _write_tile 20               ; T
    _write_tile 15               ; O
    _write_tile 0                ; space
    _write_tile 4                ; D
    _write_tile 5                ; E
    _write_tile 12               ; L
    _write_tile 5                ; E
    _write_tile 20               ; T
    _write_tile 5                ; E

    rts


; ============================================================================
; state_file_brw — Per-frame update for file browser
; Handles fade, cursor hover, slot selection, delete.
; Assumes: 8-bit A/X/Y
; ============================================================================
state_file_brw:
    .ACCU 8
    .INDEX 8

    ; Init on first frame
    lda fb_initialized.w
    bne @fb_running
    jsr file_brw_init
    rts

@fb_running:
    jsr read_input

    ; Handle fade
    lda fade_dir.w
    beq @no_fade_fb

    cmp #FADE_IN
    bne @fade_out_fb

    lda fade_level.w
    cmp #$0F
    bcs @fade_in_done_fb
    inc A
    sta fade_level.w
    sta SHADOW_INIDISP.w
    rts

@fade_in_done_fb:
    stz fade_dir.w
    bra @no_fade_fb

@fade_out_fb:
    lda fade_level.w
    beq @fade_out_done_fb
    dec A
    sta fade_level.w
    sta SHADOW_INIDISP.w
    rts

@fade_out_done_fb:
    stz fade_dir.w
    stz fb_initialized.w
    ; Check if loading a file
    lda fb_action.w
    cmp #FB_ACT_LOAD
    bne @fb_go_back
    ; Load the selected file
    lda fb_sel.w
    jsr sram_load_file
    ; current_state already set by sram_load_file
    rts
@fb_go_back:
    lda #STATE_BOOT
    sta current_state.w
    rts

@no_fade_fb:
    ; --- Delete confirmation dialog ---
    lda fb_confirm_del.w
    beq @fb_no_del_dialog
    jsr _fb_update_delete_confirm
    rts

@fb_no_del_dialog:
    ; --- Mouse hover on file slots ---
    rep #$20
    .ACCU 16
    ; Check Y: rows 5-12 = pixel Y 40-103
    lda cursor_y.w
    cmp #40
    bcc @fb_no_mouse_sel
    cmp #104
    bcs @fb_no_mouse_sel
    ; Check X: cols 4-27 = pixel X 32-223
    lda cursor_x.w
    cmp #32
    bcc @fb_no_mouse_sel
    cmp #224
    bcs @fb_no_mouse_sel

    ; Compute slot = (cursor_y - 40) / 8
    lda cursor_y.w
    sec
    sbc #40
    sep #$20
    .ACCU 8
    lsr A
    lsr A
    lsr A                        ; / 8
    cmp #SRAM_MAX_SLOTS
    bcs @fb_no_mouse_sel_8
    cmp fb_sel.w
    beq @fb_check_click
    sta fb_sel.w
    jsr _fb_update_highlight
    bra @fb_check_click

@fb_no_mouse_sel:
    sep #$20
    .ACCU 8
@fb_no_mouse_sel_8:

@fb_check_click:
    ; --- Left-click = load file ---
    lda click_new.w
    beq @fb_check_rclick
    lda fb_sel.w
    cmp #$FF
    beq @fb_check_rclick

    ; Check if slot is occupied (from WRAM cache)
    lda fb_sel.w
    asl A
    asl A
    asl A
    asl A                        ; × 16
    tax
    lda SRAM_DIR_BUF.w,X
    and #SRAM_FLAG_USED
    beq @fb_check_rclick         ; Empty slot, no action

    ; Start load: fade out, then load on completion
    lda #FB_ACT_LOAD
    sta fb_action.w
    lda #FADE_OUT
    sta fade_dir.w
    rts

@fb_check_rclick:
    ; --- Right-click on occupied slot = delete ---
    lda rclick_new.w
    beq @done_fb

    ; If cursor is on a slot, offer delete; otherwise go back
    lda fb_sel.w
    cmp #$FF
    beq @fb_rclick_back

    ; Check if slot is occupied
    lda fb_sel.w
    asl A
    asl A
    asl A
    asl A
    tax
    lda SRAM_DIR_BUF.w,X
    and #SRAM_FLAG_USED
    beq @fb_rclick_back           ; Empty slot — treat as go back

    ; Show delete confirmation
    jsr _fb_show_delete_confirm
    rts

@fb_rclick_back:
    ; Right-click on empty space = go back to title
    lda #FB_ACT_NONE
    sta fb_action.w
    lda #FADE_OUT
    sta fade_dir.w

@done_fb:
    rts


; ============================================================================
; _fb_update_highlight — Update selection highlight by re-rendering all slots
; Uses force blank to rewrite the full file list with correct palettes.
; Assumes: 8-bit A/X/Y
; ============================================================================
_fb_update_highlight:
    .ACCU 8
    .INDEX 8

    lda #$8F
    sta INIDISP.w

    ; Re-render the full file list (it handles highlight via fb_sel)
    jsr _fb_render

    lda fb_sel.w
    sta fb_prev_sel.w

    lda SHADOW_INIDISP.w
    sta INIDISP.w
    rts


; ============================================================================
; _fb_show_delete_confirm — Show "DELETE? Y/N" dialog on BG3
; Assumes: 8-bit A/X/Y
; ============================================================================
_fb_show_delete_confirm:
    .ACCU 8
    .INDEX 8

    lda #$01
    sta fb_confirm_del.w
    stz dialog_sel.w             ; Default to NO (0=no, 1=yes)

    lda #$8F
    sta INIDISP.w
    lda #$80
    sta VMAIN.w

    rep #$10
    .INDEX 16

    ; Draw on row 14: "DELETE? YES  NO"
    rep #$20
    .ACCU 16
    lda #VRAM_BG3_MAP + (14 * 32) + 7
    sta VMADDL.w
    sep #$20
    .ACCU 8

    _write_tile 4                ; D
    _write_tile 5                ; E
    _write_tile 12               ; L
    _write_tile 5                ; E
    _write_tile 20               ; T
    _write_tile 5                ; E
    _write_tile 82               ; ? (KBD_TILE_QUEST)
    _write_tile 0                ; space
    _write_tile 25               ; Y
    _write_tile 5                ; E
    _write_tile 19               ; S
    _write_tile 0                ; space
    _write_tile 0                ; space
    _write_tile 14               ; N
    _write_tile 15               ; O
    _write_tile 0                ; space
    _write_tile 0                ; space

    lda SHADOW_INIDISP.w
    sta INIDISP.w

    ; Highlight default (NO)
    jsr _fb_update_del_hl

    sep #$10
    .INDEX 8
    rts


; ============================================================================
; _fb_update_delete_confirm — Per-frame update for delete confirmation
; Assumes: 8-bit A/X/Y
; ============================================================================
_fb_update_delete_confirm:
    .ACCU 8
    .INDEX 8

    ; --- Mouse hover on YES/NO options (row 14) ---
    ; YES at cols 15-17 (pixel X 120-143), NO at cols 20-21 (pixel X 160-175)
    rep #$20
    .ACCU 16
    lda cursor_y.w
    cmp #112
    bcc @fdc_no_hover
    cmp #120
    bcs @fdc_no_hover
    lda cursor_x.w
    cmp #120
    bcc @fdc_no_hover
    cmp #144
    bcc @fdc_hover_yes
    cmp #160
    bcc @fdc_no_hover
    cmp #176
    bcc @fdc_hover_no
@fdc_no_hover:
    sep #$20
    .ACCU 8
    bra @fdc_check_click

@fdc_hover_yes:
    sep #$20
    .ACCU 8
    lda dialog_sel.w
    cmp #1
    beq @fdc_check_click
    lda #1
    sta dialog_sel.w
    jsr _fb_update_del_hl
    bra @fdc_check_click

@fdc_hover_no:
    sep #$20
    .ACCU 8
    lda dialog_sel.w
    beq @fdc_check_click
    stz dialog_sel.w
    jsr _fb_update_del_hl

@fdc_check_click:
    ; Left-click = confirm
    lda click_new.w
    beq @fdc_check_rclick
@fdc_confirm:
    lda dialog_sel.w
    cmp #1
    bne @fdc_cancel              ; 0 = NO

    ; YES = delete
    lda fb_sel.w
    jsr sram_delete_file
    ; Play delete SFX
    lda #SFX_DELETE
    jsr play_sfx
    ; Refresh directory and re-render
    jsr sram_get_directory
    stz fb_confirm_del.w

    lda #$8F
    sta INIDISP.w

    ; Clear the confirmation row
    lda #$80
    sta VMAIN.w
    rep #$20
    .ACCU 16
    lda #VRAM_BG3_MAP + (14 * 32) + 7
    sta VMADDL.w
    sep #$20
    .ACCU 8
    ldx #17
@fdc_clr:
    stz VMDATAL.w
    stz VMDATAH.w
    dex
    bne @fdc_clr

    ; Re-render file list
    jsr _fb_render

    lda SHADOW_INIDISP.w
    sta INIDISP.w
    rts

@fdc_cancel:
    stz fb_confirm_del.w
    ; Clear the confirmation row
    lda #$8F
    sta INIDISP.w
    lda #$80
    sta VMAIN.w
    rep #$20
    .ACCU 16
    lda #VRAM_BG3_MAP + (14 * 32) + 7
    sta VMADDL.w
    sep #$20
    .ACCU 8
    ldx #17
@fdc_clr2:
    stz VMDATAL.w
    stz VMDATAH.w
    dex
    bne @fdc_clr2
    lda SHADOW_INIDISP.w
    sta INIDISP.w
    rts

@fdc_check_rclick:
    ; Right-click = cancel
    lda rclick_new.w
    beq @fdc_done
    bra @fdc_cancel
@fdc_done:
    rts


; ============================================================================
; _fb_update_del_hl — Update YES/NO highlight in delete confirmation
; dialog_sel: 0=NO (default), 1=YES
; Assumes: 8-bit A/X/Y
; ============================================================================
_fb_update_del_hl:
    .ACCU 8
    .INDEX 8

    lda #$8F
    sta INIDISP.w
    lda #$80
    sta VMAIN.w

    rep #$10
    .INDEX 16

    ; Rewrite "YES  NO" portion at row 14, col 15
    rep #$20
    .ACCU 16
    lda #VRAM_BG3_MAP + (14 * 32) + 15
    sta VMADDL.w
    sep #$20
    .ACCU 8

    ; YES palette
    lda dialog_sel.w
    cmp #1
    bne @del_yes_normal
    lda #$34                     ; Highlight (PPP=5)
    bra @del_yes_set
@del_yes_normal:
    lda #$30                     ; Normal (PPP=4)
@del_yes_set:
    sta $06

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

    ; Spaces
    stz VMDATAL.w
    lda #$30
    sta VMDATAH.w
    stz VMDATAL.w
    lda #$30
    sta VMDATAH.w

    ; NO palette
    lda dialog_sel.w
    beq @del_no_hl
    lda #$30                     ; Normal (YES is selected)
    bra @del_no_set
@del_no_hl:
    lda #$34                     ; Highlight (NO is selected = default)
@del_no_set:
    sta $06

    lda #14                      ; N
    sta VMDATAL.w
    lda $06
    sta VMDATAH.w
    lda #15                      ; O
    sta VMDATAL.w
    lda $06
    sta VMDATAH.w

    lda SHADOW_INIDISP.w
    sta INIDISP.w

    sep #$10
    .INDEX 8
    rts
