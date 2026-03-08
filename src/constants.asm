; ============================================================================
; constants.asm — App-Wide Constants and Equates
; ============================================================================

; --- Screen dimensions ---
.define SCREEN_WIDTH    256
.define SCREEN_HEIGHT   224

; --- Cursor bounds (clamped to visible area) ---
.define CURSOR_MIN_X    0
.define CURSOR_MAX_X    255      ; 256 - 1 (0-indexed)
.define CURSOR_MIN_Y    0
.define CURSOR_MAX_Y    223      ; 224 - 1

; --- Input device ID ---
.define INPUT_MOUSE     1

; --- Mouse signature nibble ---
.define MOUSE_SIGNATURE $01

; --- Application states ---
.define STATE_BOOT      0
.define STATE_TITLE     1
.define STATE_TYPE_SEL  2        ; "Text Doc" / "Spreadsheet" submenu
.define STATE_FILE_BRW  3        ; File browser (list saved files)
.define STATE_TEXTDOC   4        ; Text document editor (Phase 4)
.define STATE_SHEET     5        ; Spreadsheet editor (Phase 5)
.define STATE_FMENU     6        ; File menu overlay (Phase 6)

; --- Fade system ---
.define FADE_NONE       0
.define FADE_IN         1
.define FADE_OUT        $FF

; --- OAM shadow buffer location in WRAM ---
; 544 bytes: 512 (128 sprites x 4 bytes) + 32 (high table)
.define OAM_BUF         $0200    ; Low table: $0200-$03FF (512 bytes)
.define OAM_BUF_HI      $0400    ; High table: $0400-$041F (32 bytes)
.define OAM_BUF_SIZE    544      ; Total size for DMA

; --- PPU shadow register locations in WRAM ---
.define SHADOW_INIDISP  $50      ; -> $2100
.define SHADOW_OBJSEL   $51      ; -> $2101
.define SHADOW_BGMODE   $52      ; -> $2105
.define SHADOW_MOSAIC   $53      ; -> $2106
.define SHADOW_BG1SC    $54      ; -> $2107
.define SHADOW_BG2SC    $55      ; -> $2108
.define SHADOW_BG3SC    $56      ; -> $2109
.define SHADOW_BG4SC    $57      ; -> $210A
.define SHADOW_BG12NBA  $58      ; -> $210B
.define SHADOW_BG34NBA  $59      ; -> $210C
.define SHADOW_TM       $5A      ; -> $212C
.define SHADOW_TS       $5B      ; -> $212D
.define SHADOW_CGWSEL   $5C      ; -> $2130
.define SHADOW_CGADSUB  $5D      ; -> $2131
.define SHADOW_COLDATA  $5E      ; -> $2132
.define SHADOW_NMITIMEN $5F      ; -> $4200
.define SHADOW_HDMAEN   $60      ; -> $420C

; --- VRAM layout (word addresses) ---
; OBJSEL bbb field: base = bbb * $2000. Valid bases: $0000,$2000,$4000,$6000,...
; BG1 character data (font tiles, 4bpp)
.define VRAM_BG1_CHR    $0000
; BG2 character data (UI chrome, 4bpp)
.define VRAM_BG2_CHR    $2000
; BG3 character data (keyboard/overlay, 2bpp)
.define VRAM_BG3_CHR    $4000
; Sprite character data (cursor, icons) — must be at bbb*$2000
.define VRAM_OBJ_CHR    $6000
; BG1 tilemap
.define VRAM_BG1_MAP    $7000
; BG2 tilemap
.define VRAM_BG2_MAP    $7400
; BG3 tilemap
.define VRAM_BG3_MAP    $7800

; --- Game variables in WRAM (direct page / low RAM) ---
.define vblank_done     $61      ; Set by NMI, cleared by main loop
.define frame_count     $62      ; Frame counter (8-bit, wraps)
.define current_state   $63      ; Current application state
.define cursor_x        $65      ; Cursor X position (16-bit: $65-$66)
.define cursor_y        $67      ; Cursor Y position (16-bit: $67-$68)
.define joy_current_l   $69      ; Serial byte 2 (mouse: buttons+sig)
.define joy_current_h   $6A      ; Serial byte 1 (mouse: sensitivity)
.define click_new       $6F      ; Left-click newly pressed flag
.define click_held      $70      ; Left-click held flag
.define rclick_new      $6B      ; Right-click newly pressed flag
.define rclick_held     $6C      ; Right-click held flag
.define mouse_dx        $71      ; Mouse X delta (signed, 16-bit: $71-$72)
.define mouse_dy        $73      ; Mouse Y delta (signed, 16-bit: $73-$74)
.define mouse_buttons   $75      ; Mouse button state (bit 0 = left, bit 1 = right)
.define mouse_old_btns  $76      ; Previous mouse button state
.define oam_index       $79      ; Current index into OAM buffer

; --- Fade variables ---
.define fade_dir        $7A      ; 0=none, 1=fade in, $FF=fade out
.define fade_level      $7B      ; Current brightness 0-15

; --- Title screen variables ---
.define title_menu_sel  $7C      ; 0=create new, 1=open file, $FF=none
.define title_prev_sel  $7D      ; Previous selection (for redraw)

; --- Menu / submenu variables ---
.define menu_choice     $7E      ; Title selection carried forward (0=create, 1=open)
.define menu_sel        $7F      ; Current submenu selection (0=text, 1=sheet, $FF=none)
.define menu_prev_sel2  $80      ; Previous submenu selection (for redraw)

; --- Keyboard variables (on-screen keyboard overlay) ---
.define kbd_visible     $81      ; 0=hidden, 1=shown
.define kbd_cursor_col  $82      ; 0-15 column in key grid
.define kbd_cursor_row  $83      ; 0-2 row in key grid
.define kbd_shift       $84      ; 0=lowercase, 1=uppercase (display + output)
                                 ; $85 unused (was kbd_sym)
.define kbd_char_out    $86      ; Character output (0=none, read and clear)
.define kbd_dirty       $87      ; Bit flags: b0=need highlight update
.define kbd_old_col     $88      ; Previous cursor col (for unhighlight)
.define kbd_old_row     $89      ; Previous cursor row (for unhighlight)

; --- Title screen menu hit boxes (pixel coords) ---
; "CREATE NEW" at tile row 21, cols 11-20
.define MENU0_X1        88
.define MENU0_X2        167
.define MENU0_Y1        160
.define MENU0_Y2        175
; "OPEN FILE" at tile row 23, cols 11-19
.define MENU1_X1        88
.define MENU1_X2        167
.define MENU1_Y1        176
.define MENU1_Y2        191

; --- Large title font tile indices (16x16, 4 tiles each: TL,TR,BL,BR) ---
.define BIG_S           1        ; tiles 1-4
.define BIG_U           5        ; tiles 5-8
.define BIG_P           9        ; tiles 9-12
.define BIG_E           13       ; tiles 13-16
.define BIG_R           17       ; tiles 17-20
.define BIG_O           21       ; tiles 21-24
.define BIG_F           25       ; tiles 25-28
.define BIG_I           29       ; tiles 29-32
.define BIG_C           33       ; tiles 33-36
.define BIG_A           37       ; tiles 37-40

; --- Small menu font tile indices (8x8, in BG1 chr tiles 41-55) ---
.define TILE_BLANK      0
.define TILE_A          41
.define TILE_C          42
.define TILE_E          43
.define TILE_F          44
.define TILE_I          45
.define TILE_L          46
.define TILE_N          47
.define TILE_O          48
.define TILE_P          49
.define TILE_R          50
.define TILE_S          51
.define TILE_T          52
.define TILE_U          53
.define TILE_W          54
.define TILE_ARROW      55

; --- BG2 scene tile indices ---
.define SCENE_EMPTY     0
.define SCENE_BLDG      1        ; Solid building fill
.define SCENE_BWIN      2        ; Building with window
.define SCENE_BTOP      3        ; Building top edge
.define SCENE_DESK      4        ; Desk surface
.define SCENE_DEDGE     5        ; Desk front edge
.define SCENE_CLOUD_L   6        ; Cloud left
.define SCENE_CLOUD_M   7        ; Cloud middle
.define SCENE_CLOUD_R   8        ; Cloud right

; --- Keyboard layout constants ---
.define KBD_ROWS        4        ; 4 key rows (3 letter rows + spacebar)
.define KBD_COLS        16       ; 16 keys per row
.define KBD_MAP_START_ROW 20     ; BG3 tilemap row for first key row
.define KBD_MAP_COL     0        ; Starting tilemap column (full width)
.define KBD_PIXEL_X     0        ; Left edge of keyboard in pixels (full width)
.define KBD_PIXEL_Y     160      ; Top of first key row in pixels (row 20 * 8)
.define KBD_KEY_W       16       ; Pixels per key width (16x16 keys)
.define KBD_KEY_H       16       ; Pixels per key height
.define KBD_AREA_TOP    160      ; Pixel Y where keyboard starts (row 20)
.define KBD_SPC_COL_START 3      ; Spacebar starts at key column 3
.define KBD_SPC_COL_END   13     ; Spacebar ends before key column 13 (exclusive)
.define KBD_SPC_TILE_START 6     ; Spacebar tilemap start column (SPC_COL_START*2)
.define KBD_SPC_TILE_END  26     ; Spacebar tilemap end column (SPC_COL_END*2)

; --- Legacy 8x8 keyboard tile indices (used by save.asm, menu.asm for text) ---
.define KBD_TILE_BLANK  0
; Tiles 1-26 = Uppercase A-Z (8x8 with key background)
; Tiles 27-52 = Lowercase a-z (8x8)
; Tiles 53-62 = Digits 0-9 (8x8)
; Tiles 63-72 = Shifted digits !@#$%^&*() (8x8)
.define KBD_TILE_BKSP   73       ; ← backspace arrow (8x8)
.define KBD_TILE_ENTER  74       ; ↵ enter symbol (8x8)
.define KBD_TILE_SHIFT  75       ; ↑ shift arrow (8x8)
.define KBD_TILE_DEL    76       ; X delete marker (8x8)
.define KBD_TILE_SLASH  77       ; / (8x8)
.define KBD_TILE_COMMA  78       ; , (8x8)
.define KBD_TILE_PERIOD 79       ; . (8x8)
.define KBD_TILE_LTHAN  80       ; < (8x8)
.define KBD_TILE_GTHAN  81       ; > (8x8)
.define KBD_TILE_QUEST  82       ; ? (8x8)
.define KBD_TILE_MINUS  83       ; - (8x8, used by menu/save UI)
.define KBD_TILE_USCORE 84       ; _ (8x8, used by save cursor)
.define KBD_TILE_HLINE  85       ; ─ horizontal separator (8x8)
.define KBD_TILE_PLUS   86       ; + (8x8)
; Tiles 87-94 = Old spacebar tiles (8x8, legacy)

; --- New 16x16 key tile indices (BG3 chr, tiles 95+) ---
.define KBD16_TL         95      ; Shared top-left frame tile
.define KBD16_TR         96      ; Shared top-right frame tile
.define KBD16_SPC_TL     97      ; Spacebar top left cap
.define KBD16_SPC_TM     98      ; Spacebar top middle
.define KBD16_SPC_TR     99      ; Spacebar top right cap
.define KBD16_SPC_BL    100      ; Spacebar bottom left cap
.define KBD16_SPC_BM    101      ; Spacebar bottom middle blank
.define KBD16_SPC_BR    102      ; Spacebar bottom right cap
.define KBD16_SPC_S     103      ; Spacebar "S"
.define KBD16_SPC_P     104      ; Spacebar "P"
.define KBD16_SPC_A     105      ; Spacebar "A"
.define KBD16_SPC_C     106      ; Spacebar "C"
.define KBD16_SPC_E     107      ; Spacebar "E"
; Character BL/BR pairs start at tile 108 (BR = BL + 1)
; A=108, B=110, ... Z=158, 0=160, ... 9=178
; !=180, @=182, ... )=198, ←=200, ↵=202, ↑=204, X=206
; /=208, ,=210, .=212, <=214, >=216, ?=218, -=220, _=222, +=224
.define KBD16_TILE_COUNT 226     ; Total tiles (old + new)

; --- Keyboard BG3 palette indices (2bpp: PPP field in tilemap) ---
; 2bpp sub-palette 0 (CGRAM 0-3): normal key (white bg, dark text)
; 2bpp sub-palette 1 (CGRAM 4-7): hover key (yellow bg, dark text)
; 2bpp sub-palette 2 (CGRAM 8-11): shift-active key (blue bg, dark text)
.define KBD_PAL_NORMAL  $00      ; PPP=0 shifted for tilemap high byte
.define KBD_PAL_HILITE  $04      ; PPP=1 shifted for tilemap high byte
.define KBD_PAL_SHIFT   $08      ; PPP=2 shifted for tilemap high byte

; --- Keyboard special character codes (in key map tables) ---
.define KEY_NONE        0        ; No action
.define KEY_BKSP        $08      ; Backspace
.define KEY_ENTER       $0A      ; Newline / Enter
.define KEY_SHIFT       $01      ; Toggle SHIFT (case + symbols)
.define KEY_DEL         $7F      ; Delete forward
.define KEY_SPACE       $20      ; Space

; --- Text document editor constants ---
.define DOC_BUF_ADDR     $0500   ; Document buffer start in WRAM
.define DOC_MAX_SIZE     2048    ; Max document size in bytes
.define DOC_VISIBLE_ROWS 19     ; Visible text rows (rows 1-19 on tilemap)
.define DOC_VISIBLE_COLS 30     ; Visible text columns (cols 1-30 on tilemap)
.define DOC_TEXT_START_ROW 1     ; First tilemap row for text content
.define DOC_TEXT_START_COL 1     ; First tilemap column for text content
.define DOC_CURSOR_TILE  60     ; Tile index for text cursor (underscore)

; --- Spreadsheet editor constants ---
.define SHEET_BUF_ADDR    $0500   ; Cell buffer start (shares doc buffer space)
.define SHEET_COLS        8       ; Columns A-H
.define SHEET_ROWS        32      ; Total data rows
.define SHEET_CELL_SIZE   8       ; Bytes per cell (null-padded content)
.define SHEET_ROW_BYTES   64      ; SHEET_COLS * SHEET_CELL_SIZE
.define SHEET_VISIBLE_ROWS 18     ; Visible data rows (tilemap rows 2-19)
.define SHEET_DISP_CHARS  3       ; Display chars per cell on screen
.define SHEET_HDR_ROW     1       ; Tilemap row for column headers
.define SHEET_DATA_START  2       ; First tilemap row for cell data
.define SHEET_NUM_COLS    2       ; Tile columns for row numbers (cols 0-1)
.define SHEET_SEP_COL     2       ; Tile column for separator
.define SHEET_DATA_COL    3       ; First tile column for cell data
.define SHEET_COL_WIDTH   3       ; Tiles per data column
.define SHEET_CURSOR_TILE 60      ; Underscore tile for cell edit cursor

; --- Text document editor variables (DP $8A-$95) ---
.define doc_cursor_pos  $8A     ; 16-bit: offset into doc_buffer ($8A-$8B)
.define doc_length      $8C     ; 16-bit: total byte count ($8C-$8D)
.define doc_scroll_y    $8E     ; 8-bit: first visible line number
.define doc_dirty       $8F     ; 8-bit: needs re-render flag
.define doc_cursor_col  $90     ; 8-bit: cursor column in current line
.define doc_cursor_row  $91     ; 8-bit: cursor row (absolute line number)
.define doc_initialized $92     ; 8-bit: editor init flag
.define doc_blink_timer $93     ; 8-bit: cursor blink frame counter
.define doc_blink_on    $94     ; 8-bit: cursor visible toggle
.define doc_num_lines   $95     ; 8-bit: total line count in document

; --- Spreadsheet editor variables (DP $96-$9D) ---
.define sheet_cursor_col  $96     ; 8-bit: active column (0-7)
.define sheet_cursor_row  $97     ; 8-bit: active row (0-31)
.define sheet_scroll_y    $98     ; 8-bit: first visible row
.define sheet_dirty       $99     ; 8-bit: needs re-render flag
.define sheet_initialized $9A     ; 8-bit: editor init flag
.define sheet_edit_len    $9B     ; 8-bit: chars in active cell (0-8)
.define sheet_blink_timer $9C     ; 8-bit: cursor blink frame counter
.define sheet_blink_on    $9D     ; 8-bit: cursor visible toggle

; --- Save system variables needed by editors (DP $9E-$B2) ---
; (Remaining save system variables defined in save.asm)
.define current_slot    $9E      ; Current save slot ($FF = unsaved)
.define save_name_len   $A6      ; Filename entry length
.define save_name_buf   $A7      ; Filename buffer start ($A7-$B2, 12 bytes)

; --- VRAM write queue (NMI-deferred writes, DP $B8-$DA) ---
; Small VRAM writes (cursor blink, kbd highlight) are queued here
; and processed by the NMI handler during VBlank — no mid-frame force blank.
; Entries with addr_hi=$FF are CGRAM writes: addr_lo=CGRAM addr, tile=color_lo, attr=color_hi
.define vram_wq_count   $B8      ; Number of pending writes (0-10)
.define vram_wq_data    $B9      ; Write queue: 10 entries × 4 bytes ($B9-$E0)
                                 ; Each entry: addr_lo, addr_hi, tile, attr

; --- Tilemap palette bits (shifted for tilemap entry high byte) ---
; Tilemap entry: VHOPPPcc cccccccc  (PPP = palette 0-7)
.define PAL0_HI         $00      ; Palette 0 (buildings)
.define PAL1_HI         $04      ; Palette 1 (desk)
.define PAL2_HI         $08      ; Palette 2 (white text)
.define PAL3_HI         $0C      ; Palette 3 (red - S,R)
.define PAL4_HI         $10      ; Palette 4 (orange - U)
.define PAL5_HI         $14      ; Palette 5 (green - P)
.define PAL6_HI         $18      ; Palette 6 (blue - E)
.define PAL7_HI         $1C      ; Palette 7 (highlight)
