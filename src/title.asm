; ============================================================================
; title.asm — Title Screen State Logic
;
; title_init:  Loads all title graphics, sets up HDMA, starts fade in.
;              Called once from state_boot.
; state_title: Per-frame update — input, menu highlight, click detection.
; ============================================================================

; ============================================================================
; title_init — Set up the title screen
; Called during STATE_BOOT. Screen should be in force blank.
; Uploads tiles, tilemaps, palettes; configures HDMA; starts fade in.
; ============================================================================
title_init:
    .ACCU 8
    .INDEX 8

    ; === Force blank while we upload ===
    lda #$8F
    sta INIDISP.w
    sta SHADOW_INIDISP.w

    ; === Upload BG1 font tiles to VRAM ===
    lda #$80
    sta VMAIN.w
    lda #$01                     ; DMA mode 1: two registers (VMDATAL/H)
    sta DMAP0.w
    lda #$18
    sta BBAD0.w
    lda #:title_font_tiles
    sta A1B0.w

    rep #$20
    .ACCU 16
    lda #VRAM_BG1_CHR
    sta VMADDL.w
    lda #title_font_tiles
    sta A1T0L.w
    lda #title_font_tiles_end - title_font_tiles
    sta DAS0L.w
    sep #$20
    .ACCU 8
    lda #$01
    sta MDMAEN.w

    ; === Upload BG2 scene tiles to VRAM ===
    lda #:title_scene_tiles
    sta A1B0.w
    rep #$20
    .ACCU 16
    lda #VRAM_BG2_CHR
    sta VMADDL.w
    lda #title_scene_tiles
    sta A1T0L.w
    lda #title_scene_tiles_end - title_scene_tiles
    sta DAS0L.w
    sep #$20
    .ACCU 8
    lda #$01
    sta MDMAEN.w

    ; === Upload sprite icon tiles ===
    ; Top row: tiles 2-9 → VRAM $6020 (after cursor's tiles 0-1)
    lda #:title_icon_tiles_top
    sta A1B0.w
    rep #$20
    .ACCU 16
    lda #VRAM_OBJ_CHR + (2 * 16) ; Tile 2 = offset 32 words from base
    sta VMADDL.w
    lda #title_icon_tiles_top
    sta A1T0L.w
    lda #title_icon_tiles_top_end - title_icon_tiles_top
    sta DAS0L.w
    sep #$20
    .ACCU 8
    lda #$01
    sta MDMAEN.w

    ; Bottom row: tiles 18-25 → VRAM $6120
    lda #:title_icon_tiles_bot
    sta A1B0.w
    rep #$20
    .ACCU 16
    lda #VRAM_OBJ_CHR + (18 * 16) ; Tile 18
    sta VMADDL.w
    lda #title_icon_tiles_bot
    sta A1T0L.w
    lda #title_icon_tiles_bot_end - title_icon_tiles_bot
    sta DAS0L.w
    sep #$20
    .ACCU 8
    lda #$01
    sta MDMAEN.w

    ; === Upload BG palettes (all 256 bytes) ===
    stz CGADD.w                  ; Start at color 0
    lda #$00
    sta DMAP0.w                  ; Mode 0: single register
    lda #$22
    sta BBAD0.w                  ; CGDATA
    lda #:title_bg_palettes
    sta A1B0.w
    rep #$20
    .ACCU 16
    lda #title_bg_palettes
    sta A1T0L.w
    lda #title_bg_palettes_end - title_bg_palettes
    sta DAS0L.w
    sep #$20
    .ACCU 8
    lda #$01
    sta MDMAEN.w

    ; === Upload sprite icon palettes (palettes 1-4, starting at CGRAM 144) ===
    lda #144                     ; Sprite palette 1 start (128 + 16)
    sta CGADD.w
    lda #:title_sprite_palettes
    sta A1B0.w
    rep #$20
    .ACCU 16
    lda #title_sprite_palettes
    sta A1T0L.w
    lda #title_sprite_palettes_end - title_sprite_palettes
    sta DAS0L.w
    sep #$20
    .ACCU 8
    lda #$01
    sta MDMAEN.w

    ; === Build BG1 tilemap (title text + menu) ===
    jsr _title_build_bg1_map

    ; === Build BG2 tilemap (scene) ===
    jsr _title_build_bg2_map

    ; === Set up sprite icons in OAM shadow ===
    jsr _title_setup_icons

    ; === Configure color math for HDMA sky gradient ===
    ; Sub screen source = fixed color, color math always enabled
    lda #$02                     ; CGWSEL: sub = fixed color
    sta CGWSEL.w
    sta SHADOW_CGWSEL.w
    lda #$20                     ; CGADSUB: add to backdrop
    sta CGADSUB.w
    sta SHADOW_CGADSUB.w

    ; Initialize fixed color to black (HDMA will override per-scanline)
    lda #$E0                     ; All channels, intensity 0
    sta COLDATA.w

    ; === Set up HDMA channel 7 for sky gradient ===
    lda #$02                     ; Transfer mode 2: write same register twice
    sta DMAP7.w
    lda #$32                     ; B-bus: COLDATA ($2132)
    sta BBAD7.w
    rep #$20
    .ACCU 16
    lda #title_hdma_gradient
    sta A1T7L.w
    sep #$20
    .ACCU 8
    lda #:title_hdma_gradient
    sta A1B7.w                   ; Source bank (A1B7 = $4374)

    ; Enable HDMA channel 7
    lda #$80                     ; Bit 7 = channel 7
    sta SHADOW_HDMAEN.w

    ; === Enable BG1, BG2, and sprites on main screen ===
    lda #%00010011               ; OBJ + BG2 + BG1
    sta TM.w
    sta SHADOW_TM.w

    ; === Initialize fade: start from black, fade in ===
    lda #FADE_IN
    sta fade_dir.w
    stz fade_level.w

    ; Screen on at brightness 0 (will fade in)
    stz SHADOW_INIDISP.w

    ; === Initialize menu state — nothing selected ===
    lda #$FF
    sta title_menu_sel.w
    sta title_prev_sel.w

    ; Hide selection arrow (OAM entry 5, Y = $F0 = off-screen)
    lda #$F0
    sta OAM_BUF+21.w

    ; Un-force blank (brightness 0 — black but rendering active)
    stz INIDISP.w

    rts


; ============================================================================
; state_title — Per-frame title screen update
; Called from main loop. Reads input, handles fade, menu selection.
; Assumes: 8-bit A/X/Y
; ============================================================================
state_title:
    .ACCU 8
    .INDEX 8

    jsr read_input

    ; --- Handle fade ---
    lda fade_dir.w
    beq @no_fade

    cmp #FADE_IN
    bne @fade_out

    ; Fade in: increment brightness
    lda fade_level.w
    cmp #$0F
    bcs @fade_in_done
    inc A
    sta fade_level.w
    sta SHADOW_INIDISP.w
    rts                          ; Don't process input during fade

@fade_in_done:
    stz fade_dir.w               ; Fade complete
    bra @no_fade

@fade_out:
    ; Fade out: decrement brightness
    lda fade_level.w
    beq @fade_out_done
    dec A
    sta fade_level.w
    sta SHADOW_INIDISP.w
    rts                          ; Don't process input during fade

@fade_out_done:
    stz fade_dir.w
    ; Transition to next state based on menu selection
    lda title_menu_sel.w
    beq @goto_type_sel           ; 0 = CREATE NEW → type selection
    ; 1 = OPEN FILE → file browser
    jsr file_brw_init
    lda #STATE_FILE_BRW
    sta current_state.w
    rts

@goto_type_sel:
    stz menu_choice.w            ; Record that we came from "CREATE NEW"
    jsr type_sel_init
    lda #STATE_TYPE_SEL
    sta current_state.w
    rts

@no_fade:
    ; --- Check cursor position against menu items ---
    jsr _title_check_menu_hover

    ; --- Check for click ---
    lda click_new.w
    beq @no_click
    lda title_menu_sel.w
    cmp #$FF
    beq @no_click

    ; Menu item clicked! Start fade out.
    lda #FADE_OUT
    sta fade_dir.w
    rts

@no_click:
    ; --- Update menu highlight arrow ---
    lda title_menu_sel.w
    cmp title_prev_sel.w
    beq @no_menu_change
    jsr _title_update_menu_arrow
    lda title_menu_sel.w
    sta title_prev_sel.w
@no_menu_change:
    rts


; ============================================================================
; _title_check_menu_hover — Test cursor position against menu hit boxes
; Sets title_menu_sel to 0, 1, or $FF
; ============================================================================
_title_check_menu_hover:
    .ACCU 8
    .INDEX 8

    rep #$20
    .ACCU 16

    ; --- Check menu item 0: "CREATE NEW" ---
    lda cursor_x.w
    cmp #MENU0_X1
    bcc @check_menu1
    cmp #MENU0_X2+1
    bcs @check_menu1
    lda cursor_y.w
    cmp #MENU0_Y1
    bcc @check_menu1
    cmp #MENU0_Y2+1
    bcs @check_menu1
    ; Hit!
    sep #$20
    .ACCU 8
    stz title_menu_sel.w         ; 0 = CREATE NEW
    rts

@check_menu1:
    ; --- Check menu item 1: "OPEN FILE" ---
    lda cursor_x.w
    cmp #MENU1_X1
    bcc @no_hover
    cmp #MENU1_X2+1
    bcs @no_hover
    lda cursor_y.w
    cmp #MENU1_Y1
    bcc @no_hover
    cmp #MENU1_Y2+1
    bcs @no_hover
    ; Hit!
    sep #$20
    .ACCU 8
    lda #$01
    sta title_menu_sel.w         ; 1 = OPEN FILE
    rts

@no_hover:
    sep #$20
    .ACCU 8
    lda #$FF
    sta title_menu_sel.w         ; No selection
    rts


; ============================================================================
; _title_update_menu_arrow — Update selection arrow as OAM sprite entry 5
; Uses an 8x8 sprite (tile 0 top-left = small arrow shape) positioned
; next to the selected menu item text. No VRAM writes needed.
; ============================================================================
_title_update_menu_arrow:
    .ACCU 8
    .INDEX 8

    lda title_menu_sel.w
    cmp #$FF
    beq @hide_arrow

    ; Position arrow sprite next to selected menu item
    ; OAM entry 5 = bytes 20-23 in low table
    lda #(10 * 8)               ; X = col 10 * 8 = 80
    sta OAM_BUF+20.w

    lda title_menu_sel.w
    beq @arrow_row0
    lda #184                     ; Row 23 * 8 = 184
    bra @set_arrow_y
@arrow_row0:
    lda #168                     ; Row 21 * 8 = 168
@set_arrow_y:
    sta OAM_BUF+21.w

    stz OAM_BUF+22.w            ; Tile 0 (cursor top-left = arrow shape)
    lda #%00110000               ; Priority 3, palette 0 (white), no flip
    sta OAM_BUF+23.w

    ; High table: sprite 5 = byte 1, bits 3:2; keep small (8x8)
    lda OAM_BUF_HI+1.w
    and #%11110011               ; Clear sprite 5 bits (small, X<256)
    sta OAM_BUF_HI+1.w
    rts

@hide_arrow:
    lda #$F0                     ; Y=$F0 = off screen
    sta OAM_BUF+21.w
    rts


; ============================================================================
; _title_build_bg1_map — Write BG1 tilemap to VRAM
; Zeroes the entire map first, then writes text rows.
; Must be called during force blank.
; ============================================================================
_title_build_bg1_map:
    .ACCU 8
    .INDEX 8

    ; Set VRAM address to BG1 map base
    lda #$80
    sta VMAIN.w

    ; Zero the entire 32x32 tilemap (2048 bytes = 1024 words)
    rep #$20
    .ACCU 16
    lda #VRAM_BG1_MAP
    sta VMADDL.w
    sep #$20
    .ACCU 8

    ; Use DMA with fixed source of $0000 to fill
    stz $00                      ; Source byte = 0
    lda #$09                     ; Fixed source, mode 1 (two regs)
    sta DMAP0.w
    lda #$18
    sta BBAD0.w
    stz A1T0L.w
    stz A1T0H.w
    stz A1B0.w
    rep #$20
    .ACCU 16
    lda #2048                    ; 1024 words = 2048 bytes
    sta DAS0L.w
    sep #$20
    .ACCU 8
    lda #$01
    sta MDMAEN.w

    ; --- Write text rows (6 rows for large 16x16 title + menu) ---
    ; Set up DMA mode 1 and bank once
    lda #$01                     ; Mode 1 (increment, two regs)
    sta DMAP0.w
    lda #:title_text_row3
    sta A1B0.w

    ; Row 3: "SUPER" top halves
    rep #$20
    .ACCU 16
    lda #VRAM_BG1_MAP + (3 * 32) + TITLE_ROW3_COL
    sta VMADDL.w
    lda #title_text_row3
    sta A1T0L.w
    lda #title_text_row3_end - title_text_row3
    sta DAS0L.w
    sep #$20
    .ACCU 8
    lda #$01
    sta MDMAEN.w

    ; Row 4: "SUPER" bottom halves
    rep #$20
    .ACCU 16
    lda #VRAM_BG1_MAP + (4 * 32) + TITLE_ROW4_COL
    sta VMADDL.w
    lda #title_text_row4
    sta A1T0L.w
    lda #title_text_row4_end - title_text_row4
    sta DAS0L.w
    sep #$20
    .ACCU 8
    lda #$01
    sta MDMAEN.w

    ; Row 6: "OFFICE APP" top halves
    rep #$20
    .ACCU 16
    lda #VRAM_BG1_MAP + (6 * 32) + TITLE_ROW6_COL
    sta VMADDL.w
    lda #title_text_row6
    sta A1T0L.w
    lda #title_text_row6_end - title_text_row6
    sta DAS0L.w
    sep #$20
    .ACCU 8
    lda #$01
    sta MDMAEN.w

    ; Row 7: "OFFICE APP" bottom halves
    rep #$20
    .ACCU 16
    lda #VRAM_BG1_MAP + (7 * 32) + TITLE_ROW7_COL
    sta VMADDL.w
    lda #title_text_row7
    sta A1T0L.w
    lda #title_text_row7_end - title_text_row7
    sta DAS0L.w
    sep #$20
    .ACCU 8
    lda #$01
    sta MDMAEN.w

    ; Row 21: "CREATE NEW"
    rep #$20
    .ACCU 16
    lda #VRAM_BG1_MAP + (21 * 32) + TITLE_ROW21_COL
    sta VMADDL.w
    lda #title_text_row21
    sta A1T0L.w
    lda #title_text_row21_end - title_text_row21
    sta DAS0L.w
    sep #$20
    .ACCU 8
    lda #$01
    sta MDMAEN.w

    ; Row 23: "OPEN FILE"
    rep #$20
    .ACCU 16
    lda #VRAM_BG1_MAP + (23 * 32) + TITLE_ROW23_COL
    sta VMADDL.w
    lda #title_text_row23
    sta A1T0L.w
    lda #title_text_row23_end - title_text_row23
    sta DAS0L.w
    sep #$20
    .ACCU 8
    lda #$01
    sta MDMAEN.w

    rts


; ============================================================================
; _title_build_bg2_map — Write BG2 tilemap to VRAM
; Zeroes the map, then writes building and desk rows.
; Must be called during force blank.
; ============================================================================
_title_build_bg2_map:
    .ACCU 8
    .INDEX 8

    lda #$80
    sta VMAIN.w

    ; Zero BG2 tilemap
    rep #$20
    .ACCU 16
    lda #VRAM_BG2_MAP
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

    ; --- Write cloud tiles into sky rows (direct VRAM writes) ---
    ; Cloud cluster 1: row 2, cols 3-6
    rep #$20
    .ACCU 16
    lda #VRAM_BG2_MAP + (2 * 32) + 3
    sta VMADDL.w
    lda #(SCENE_CLOUD_L | (PAL2_HI << 8))
    sta VMDATAL.w
    lda #(SCENE_CLOUD_M | (PAL2_HI << 8))
    sta VMDATAL.w
    lda #(SCENE_CLOUD_M | (PAL2_HI << 8))
    sta VMDATAL.w
    lda #(SCENE_CLOUD_R | (PAL2_HI << 8))
    sta VMDATAL.w

    ; Cloud cluster 2: row 4, cols 22-25
    lda #VRAM_BG2_MAP + (4 * 32) + 22
    sta VMADDL.w
    lda #(SCENE_CLOUD_L | (PAL2_HI << 8))
    sta VMDATAL.w
    lda #(SCENE_CLOUD_M | (PAL2_HI << 8))
    sta VMDATAL.w
    lda #(SCENE_CLOUD_M | (PAL2_HI << 8))
    sta VMDATAL.w
    lda #(SCENE_CLOUD_R | (PAL2_HI << 8))
    sta VMDATAL.w
    sep #$20
    .ACCU 8

    ; --- Write building rows 8-14 ---
    lda #$01                     ; Mode 1
    sta DMAP0.w
    lda #:title_scene_row8
    sta A1B0.w

    ; Row 8
    rep #$20
    .ACCU 16
    lda #VRAM_BG2_MAP + (8 * 32)
    sta VMADDL.w
    lda #title_scene_row8
    sta A1T0L.w
    lda #64                      ; 32 entries x 2 bytes
    sta DAS0L.w
    sep #$20
    .ACCU 8
    lda #$01
    sta MDMAEN.w

    ; Row 9
    rep #$20
    .ACCU 16
    lda #VRAM_BG2_MAP + (9 * 32)
    sta VMADDL.w
    lda #title_scene_row9
    sta A1T0L.w
    lda #64
    sta DAS0L.w
    sep #$20
    .ACCU 8
    lda #$01
    sta MDMAEN.w

    ; Row 10
    rep #$20
    .ACCU 16
    lda #VRAM_BG2_MAP + (10 * 32)
    sta VMADDL.w
    lda #title_scene_row10
    sta A1T0L.w
    lda #64                      ; 32 entries x 2 bytes
    sta DAS0L.w
    sep #$20
    .ACCU 8
    lda #$01
    sta MDMAEN.w

    ; Row 11
    rep #$20
    .ACCU 16
    lda #VRAM_BG2_MAP + (11 * 32)
    sta VMADDL.w
    lda #title_scene_row11
    sta A1T0L.w
    lda #64
    sta DAS0L.w
    sep #$20
    .ACCU 8
    lda #$01
    sta MDMAEN.w

    ; Row 12
    rep #$20
    .ACCU 16
    lda #VRAM_BG2_MAP + (12 * 32)
    sta VMADDL.w
    lda #title_scene_row12
    sta A1T0L.w
    lda #64
    sta DAS0L.w
    sep #$20
    .ACCU 8
    lda #$01
    sta MDMAEN.w

    ; Row 13
    rep #$20
    .ACCU 16
    lda #VRAM_BG2_MAP + (13 * 32)
    sta VMADDL.w
    lda #title_scene_row13
    sta A1T0L.w
    lda #64
    sta DAS0L.w
    sep #$20
    .ACCU 8
    lda #$01
    sta MDMAEN.w

    ; Row 14
    rep #$20
    .ACCU 16
    lda #VRAM_BG2_MAP + (14 * 32)
    sta VMADDL.w
    lda #title_scene_row14
    sta A1T0L.w
    lda #64
    sta DAS0L.w
    sep #$20
    .ACCU 8
    lda #$01
    sta MDMAEN.w

    ; Row 15 (desk edge)
    rep #$20
    .ACCU 16
    lda #VRAM_BG2_MAP + (15 * 32)
    sta VMADDL.w
    lda #title_scene_row15
    sta A1T0L.w
    lda #64
    sta DAS0L.w
    sep #$20
    .ACCU 8
    lda #$01
    sta MDMAEN.w

    ; Rows 16-27 (desk surface — reuse same row data 12 times)
    rep #$30
    .ACCU 16
    .INDEX 16
    ldx #16                      ; Start at row 16
@desk_loop:
    txa
    asl A                        ; row * 2
    asl A                        ; row * 4
    asl A                        ; row * 8
    asl A                        ; row * 16
    asl A                        ; row * 32
    clc
    adc #VRAM_BG2_MAP
    sta VMADDL.w
    lda #title_desk_row
    sta A1T0L.w
    lda #64
    sta DAS0L.w
    sep #$20
    .ACCU 8
    lda #:title_desk_row
    sta A1B0.w
    lda #$01
    sta DMAP0.w
    lda #$18
    sta BBAD0.w
    lda #$01
    sta MDMAEN.w
    rep #$20
    .ACCU 16
    inx
    cpx #28                      ; Rows 16-27
    bcc @desk_loop

    sep #$30
    .ACCU 8
    .INDEX 8
    rts


; ============================================================================
; _title_setup_icons — Write sprite icon entries into OAM shadow buffer
; OAM entries 1-4 for the four desk icons.
; Entry 0 is the cursor (managed by cursor_update).
; ============================================================================
_title_setup_icons:
    .ACCU 8
    .INDEX 8

    ; --- Coffee mug: OAM entry 1, position (24, 130), tile 2, palette 4 ---
    ; Far-left on desk surface
    lda #24
    sta OAM_BUF+4.w             ; X low
    lda #130
    sta OAM_BUF+5.w             ; Y
    lda #$08                     ; Tile 8
    sta OAM_BUF+6.w
    lda #%00100100               ; Priority 2, palette 4
    sta OAM_BUF+7.w

    ; --- Doc icon: OAM entry 2, position (80, 108), tile 2, palette 1 ---
    ; Center-left, above desk
    lda #80
    sta OAM_BUF+8.w
    lda #108
    sta OAM_BUF+9.w
    lda #$02                     ; Tile 2
    sta OAM_BUF+10.w
    lda #%00100001               ; Priority 2, palette 1
    sta OAM_BUF+11.w

    ; --- Spreadsheet icon: OAM entry 3, position (152, 108), tile 4, palette 2 ---
    ; Center-right, above desk
    lda #152
    sta OAM_BUF+12.w
    lda #108
    sta OAM_BUF+13.w
    lda #$04                     ; Tile 4
    sta OAM_BUF+14.w
    lda #%00100010               ; Priority 2, palette 2
    sta OAM_BUF+15.w

    ; --- Floppy icon: OAM entry 4, position (224, 130), tile 6, palette 3 ---
    ; Far-right on desk surface
    lda #224
    sta OAM_BUF+16.w
    lda #130
    sta OAM_BUF+17.w
    lda #$06                     ; Tile 6
    sta OAM_BUF+18.w
    lda #%00100011               ; Priority 2, palette 3
    sta OAM_BUF+19.w

    ; --- OAM high table: set all 4 icons to large (16x16) ---
    ; High table byte 0: sprites 0-3 (2 bits each)
    ; Sprite 0 (cursor) = bits 1:0 → already set to large by cursor_update
    ; Sprite 1 (doc) = bits 3:2 → set bit 3 (large)
    ; Sprite 2 (sheet) = bits 5:4 → set bit 5 (large)
    ; Sprite 3 (floppy) = bits 7:6 → set bit 7 (large)
    ; Note: cursor_update writes OAM_BUF_HI byte 0 every frame, we need
    ; to OR our bits in. But cursor_update only touches bits 1:0.
    ; Actually cursor_update writes the full byte. Let's handle this
    ; by setting all bits here — cursor_update will override bits 1:0 each frame.
    lda #%10101010               ; All 4 sprites large (bits 1,3,5,7)
    sta OAM_BUF_HI.w

    ; High table byte 1: sprite 4 (coffee mug) = bits 1:0
    lda #%00000010               ; Sprite 4 large
    sta OAM_BUF_HI+1.w

    rts
