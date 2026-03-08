; ============================================================================
; cursor.asm — Cursor Sprite OAM Management
;
; Writes cursor_x / cursor_y into OAM entry 0 in the shadow buffer.
; The cursor is a 16x16 sprite using tile 0 from the sprite character area.
;
; Reference: graphics-ppu.md §7, programming-patterns.md §5
; ============================================================================

; ============================================================================
; cursor_update — Write cursor position into OAM shadow buffer
; Called from the main loop each frame.
; Assumes: 8-bit A/X/Y (sep #$30)
;
; OAM low table entry format (4 bytes per sprite):
;   Byte 0: X position (low 8 bits)
;   Byte 1: Y position
;   Byte 2: Tile number (character name)
;   Byte 3: Attributes (vhoopppc — flip, priority, palette, name MSB)
;
; OAM high table (2 bits per sprite):
;   Bit 0: X position bit 8 (MSB)
;   Bit 1: Size flag (0=small/8x8, 1=large/16x16)
; ============================================================================
cursor_update:
    ; --- Write OAM entry 0 (low table at OAM_BUF + 0) ---
    lda cursor_x.w              ; X position low byte
    sta OAM_BUF.w                ; Byte 0: X low

    lda cursor_y.w              ; Y position (only low byte needed for 0-223)
    sta OAM_BUF+1.w              ; Byte 1: Y

    stz OAM_BUF+2.w              ; Byte 2: tile number = 0

    ; Byte 3: attributes
    ;   v=0 (no vflip), h=0 (no hflip)
    ;   oo=11 (priority 3 = in front of everything)
    ;   ppp=000 (palette 0 of sprite palettes)
    ;   c=0 (name table 0)
    lda #%00110000               ; Priority 3, palette 0, no flip
    sta OAM_BUF+3.w

    ; --- Write OAM high table entry for sprite 0 ---
    ; High table byte 0 covers sprites 0-3 (2 bits each)
    ; Sprite 0 uses bits 1:0 of byte 0
    ;   Bit 0 = X bit 8 (MSB of X position)
    ;   Bit 1 = Size (1 = large = 16x16)

    ; Check if X >= 256 (bit 8 of cursor_x)
    lda cursor_x+1.w            ; High byte of 16-bit cursor_x
    and #$01                     ; Bit 0 = X position bit 8
    ora #%00000010               ; Bit 1 = 1 (large size = 16x16)
    ; Preserve bits 2-7 (sprites 1-3 large flags set by title icons)
    sta $00                      ; temp: cursor bits
    lda OAM_BUF_HI.w
    and #%11111100               ; Clear sprite 0 bits
    ora $00                      ; Merge cursor bits
    sta OAM_BUF_HI.w            ; High table byte 0

    rts
