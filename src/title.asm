; ============================================================================
; title.asm — Title Screen State Logic
;
; title_init:  Loads all title graphics, starts fade in.
;              Called once from state_boot.
; state_title: Per-frame update — input, menu highlight, click detection.
;
; BG2 displays the full pre-converted title scene (sky, buildings, desk,
; title text, icons).  BG1 overlays menu text ("CREATE NEW" / "OPEN FILE").
; No HDMA or color math — sky gradient is baked into the BG2 tiles.
; ============================================================================

; ============================================================================
; title_init — Set up the title screen
; Called during STATE_BOOT. Screen should be in force blank.
; Uploads tiles, tilemaps, palettes; starts fade in.
; ============================================================================
title_init:
    .ACCU 8
    .INDEX 8

    ; === Force blank while we upload ===
    lda #$8F
    sta INIDISP.w
    sta SHADOW_INIDISP.w

    ; === Disable HDMA (not used for converted title) ===
    stz SHADOW_HDMAEN.w
    stz HDMAEN.w

    ; === Disable color math ===
    stz CGWSEL.w
    stz SHADOW_CGWSEL.w
    stz CGADSUB.w
    stz SHADOW_CGADSUB.w

    ; === Set up DMA channel 0 for all uploads ===
    lda #$80
    sta VMAIN.w
    lda #$01                     ; DMA mode 1: two registers (VMDATAL/H)
    sta DMAP0.w
    lda #$18
    sta BBAD0.w

    ; === Upload BG1 font tiles to VRAM $0000 ===
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

    ; === Upload BG2 converted image tiles to VRAM $2000 ===
    lda #:title_img_tiles
    sta A1B0.w
    rep #$20
    .ACCU 16
    lda #VRAM_BG2_CHR
    sta VMADDL.w
    lda #title_img_tiles
    sta A1T0L.w
    lda #title_img_tiles_end - title_img_tiles
    sta DAS0L.w
    sep #$20
    .ACCU 8
    lda #$01
    sta MDMAEN.w

    ; === Upload BG2 converted tilemap to VRAM $7400 ===
    lda #:title_img_map
    sta A1B0.w
    rep #$20
    .ACCU 16
    lda #VRAM_BG2_MAP
    sta VMADDL.w
    lda #title_img_map
    sta A1T0L.w
    lda #title_img_map_end - title_img_map
    sta DAS0L.w
    sep #$20
    .ACCU 8
    lda #$01
    sta MDMAEN.w

    ; === Upload palettes 0-6 (converted image) to CGRAM ===
    stz CGADD.w                  ; Start at color 0
    lda #$00
    sta DMAP0.w                  ; Mode 0: single register
    lda #$22
    sta BBAD0.w                  ; CGDATA
    lda #:title_img_palette
    sta A1B0.w
    rep #$20
    .ACCU 16
    lda #title_img_palette
    sta A1T0L.w
    lda #title_img_palette_end - title_img_palette
    sta DAS0L.w
    sep #$20
    .ACCU 8
    lda #$01
    sta MDMAEN.w

    ; === Upload palette 7 (menu text: white) to CGRAM ===
    lda #(7 * 16)               ; Palette 7 starts at CGRAM index 112
    sta CGADD.w
    lda #:title_menu_palette
    sta A1B0.w
    rep #$20
    .ACCU 16
    lda #title_menu_palette
    sta A1T0L.w
    lda #title_menu_palette_end - title_menu_palette
    sta DAS0L.w
    sep #$20
    .ACCU 8
    lda #$01
    sta MDMAEN.w

    ; === Build BG1 tilemap (menu text only) ===
    jsr _title_build_bg1_map

    ; === Enable BG1, BG2, and sprites on main screen ===
    ; BG2 = converted scene image, BG1 = menu text overlay, OBJ = cursor + arrow
    lda #%00010011               ; OBJ + BG2 + BG1
    sta TM.w
    sta SHADOW_TM.w

    ; === Set BG1 scroll to shift menu text up 12 pixels ===
    lda #(12 - 1)               ; 12px offset, -1 for PPU scroll quirk
    sta bg1_scroll_y.w

    ; === Initialize fade: start from black, fade in ===
    lda #FADE_IN
    sta fade_dir.w
    stz fade_level.w

    ; Screen on at brightness 0 (will fade in)
    stz SHADOW_INIDISP.w

    ; === Initialize menu state — nothing selected ===
    ; Set sel=$FF (none), prev=$00 (force arrow update on first active frame)
    lda #$FF
    sta title_menu_sel.w
    stz title_prev_sel.w

    ; === Start title music ===
    lda #SONG_TITLE
    jsr play_music

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
    ; Restore default BG1 scroll before leaving title
    lda #$FE
    sta bg1_scroll_y.w
    ; Transition to next state based on menu selection
    lda title_menu_sel.w
    beq @goto_type_sel           ; 0 = CREATE NEW → type selection
    cmp #$02
    beq @goto_options            ; 2 = OPTIONS → options screen
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

@goto_options:
    jsr options_init
    lda #STATE_OPTIONS
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

    ; Menu item clicked! Play SFX and start fade out.
    lda #SFX_MENU_SEL
    jsr play_sfx
    ; Don't stop music for OPTIONS — it stays playing
    lda title_menu_sel.w
    cmp #$02
    beq @skip_stop_music
    jsr stop_music
@skip_stop_music:
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
    .ACCU 16
    lda cursor_x.w
    cmp #MENU1_X1
    bcc @check_menu2
    cmp #MENU1_X2+1
    bcs @check_menu2
    lda cursor_y.w
    cmp #MENU1_Y1
    bcc @check_menu2
    cmp #MENU1_Y2+1
    bcs @check_menu2
    ; Hit!
    sep #$20
    .ACCU 8
    lda #$01
    sta title_menu_sel.w         ; 1 = OPEN FILE
    rts

@check_menu2:
    ; --- Check menu item 2: "OPTIONS" ---
    .ACCU 16
    lda cursor_x.w
    cmp #MENU2_X1
    bcc @no_hover
    cmp #MENU2_X2+1
    bcs @no_hover
    lda cursor_y.w
    cmp #MENU2_Y1
    bcc @no_hover
    cmp #MENU2_Y2+1
    bcs @no_hover
    ; Hit!
    sep #$20
    .ACCU 8
    lda #$02
    sta title_menu_sel.w         ; 2 = OPTIONS
    rts

@no_hover:
    sep #$20
    .ACCU 8
    lda #$FF
    sta title_menu_sel.w         ; No selection
    rts


; ============================================================================
; _title_update_menu_arrow — Update selection indicator via BG1 tilemap
; Queues VRAM writes to show/hide TILE_ARROW at the arrow placeholder
; position (col 10) on the selected menu row. Uses the NMI write queue.
; ============================================================================
_title_update_menu_arrow:
    .ACCU 8
    .INDEX 8

    ; --- Clear old arrow (write TILE_BLANK at previous position) ---
    lda title_prev_sel.w
    cmp #$FF
    beq @no_old_arrow

    ; Get queue offset: count * 4
    pha                          ; Save prev_sel
    lda vram_wq_count.w
    asl A
    asl A
    tax
    pla                          ; Restore prev_sel

    cmp #$01
    beq @old_row26
    cmp #$02
    beq @old_row28
    ; Old was row 24 (CREATE NEW)
    rep #$20
    .ACCU 16
    lda #VRAM_BG1_MAP + (24 * 32) + 10
    bra @write_old
@old_row26:
    rep #$20
    .ACCU 16
    lda #VRAM_BG1_MAP + (26 * 32) + 10
    bra @write_old
@old_row28:
    rep #$20
    .ACCU 16
    lda #VRAM_BG1_MAP + (28 * 32) + 10
@write_old:
    sta vram_wq_data.w,X
    sep #$20
    .ACCU 8
    lda #TILE_BLANK
    sta vram_wq_data+2.w,X
    lda #PAL7_HI
    sta vram_wq_data+3.w,X
    inc vram_wq_count.w

@no_old_arrow:
    ; --- Show new arrow (write TILE_ARROW at new position) ---
    lda title_menu_sel.w
    cmp #$FF
    beq @done

    ; Get queue offset: count * 4
    pha                          ; Save menu_sel
    lda vram_wq_count.w
    asl A
    asl A
    tax
    pla                          ; Restore menu_sel

    cmp #$01
    beq @new_row26
    cmp #$02
    beq @new_row28
    ; New is row 24 (CREATE NEW)
    rep #$20
    .ACCU 16
    lda #VRAM_BG1_MAP + (24 * 32) + 10
    bra @write_new
@new_row26:
    rep #$20
    .ACCU 16
    lda #VRAM_BG1_MAP + (26 * 32) + 10
    bra @write_new
@new_row28:
    rep #$20
    .ACCU 16
    lda #VRAM_BG1_MAP + (28 * 32) + 10
@write_new:
    sta vram_wq_data.w,X
    sep #$20
    .ACCU 8
    lda #TILE_ARROW
    sta vram_wq_data+2.w,X
    lda #PAL7_HI
    sta vram_wq_data+3.w,X
    inc vram_wq_count.w

@done:
    rts


; ============================================================================
; _title_build_bg1_map — Write BG1 tilemap to VRAM
; Zeroes the entire map first, then writes menu text rows only.
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

    ; --- Write menu text rows ---
    ; Set up DMA mode 1 and bank once
    lda #$01                     ; Mode 1 (increment, two regs)
    sta DMAP0.w
    lda #:title_text_row24
    sta A1B0.w

    ; Row 24: "CREATE NEW"
    rep #$20
    .ACCU 16
    lda #VRAM_BG1_MAP + (24 * 32) + TITLE_ROW24_COL
    sta VMADDL.w
    lda #title_text_row24
    sta A1T0L.w
    lda #title_text_row24_end - title_text_row24
    sta DAS0L.w
    sep #$20
    .ACCU 8
    lda #$01
    sta MDMAEN.w

    ; Row 26: "OPEN FILE"
    rep #$20
    .ACCU 16
    lda #VRAM_BG1_MAP + (26 * 32) + TITLE_ROW26_COL
    sta VMADDL.w
    lda #title_text_row26
    sta A1T0L.w
    lda #title_text_row26_end - title_text_row26
    sta DAS0L.w
    sep #$20
    .ACCU 8
    lda #$01
    sta MDMAEN.w

    ; Row 28: "OPTIONS"
    rep #$20
    .ACCU 16
    lda #VRAM_BG1_MAP + (28 * 32) + TITLE_ROW28_COL
    sta VMADDL.w
    lda #title_text_row28
    sta A1T0L.w
    lda #title_text_row28_end - title_text_row28
    sta DAS0L.w
    sep #$20
    .ACCU 8
    lda #$01
    sta MDMAEN.w

    rts
