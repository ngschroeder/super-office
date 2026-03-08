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

; --- Cursor movement ---
.define CURSOR_SPEED_SLOW   2    ; Pixels per frame (d-pad, initial)
.define CURSOR_SPEED_FAST   4    ; Pixels per frame (d-pad, after hold)
.define CURSOR_ACCEL_DELAY  16   ; Frames held before acceleration

; --- Input device IDs ---
.define INPUT_JOYPAD    0
.define INPUT_MOUSE     1

; --- Mouse signature nibble ---
.define MOUSE_SIGNATURE $01

; --- Application states ---
.define STATE_BOOT      0

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
.define input_device    $64      ; 0 = joypad, 1 = mouse
.define cursor_x        $65      ; Cursor X position (16-bit: $65-$66)
.define cursor_y        $67      ; Cursor Y position (16-bit: $67-$68)
.define joy_current_l   $69      ; Current joypad low byte
.define joy_current_h   $6A      ; Current joypad high byte
.define joy_previous_l  $6B      ; Previous frame joypad low byte
.define joy_previous_h  $6C      ; Previous frame joypad high byte
.define joy_new_l       $6D      ; Newly pressed low byte
.define joy_new_h       $6E      ; Newly pressed high byte
.define click_new       $6F      ; Left-click newly pressed flag
.define click_held      $70      ; Left-click held flag
.define mouse_dx        $71      ; Mouse X delta (signed, 16-bit: $71-$72)
.define mouse_dy        $73      ; Mouse Y delta (signed, 16-bit: $73-$74)
.define mouse_buttons   $75      ; Mouse button state (bit 0 = left, bit 1 = right)
.define mouse_old_btns  $76      ; Previous mouse button state
.define dpad_hold_count $77      ; Frames d-pad has been held
.define mouse_sensitivity $78    ; Current mouse sensitivity (0-2)
.define oam_index       $79      ; Current index into OAM buffer
