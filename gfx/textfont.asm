; ============================================================================
; gfx/textfont.asm — 4bpp Monospace Font for Text Editor (BG1)
;
; Converts the 2bpp keyboard font to 4bpp by appending 16 zero bytes
; (bitplanes 2-3) to each tile's 2bpp data (bitplanes 0-1).
;
; 4bpp tile format (32 bytes per 8x8 tile):
;   Bytes 0-15:  bitplane 0 and 1 data (same as 2bpp)
;   Bytes 16-31: bitplane 2 and 3 data (all zeros — uses colors 0-1 only)
;
; Characters use color 1 (bp0=1) on transparent background (color 0).
; Tile indices match the keyboard tile numbering (0-59), plus tile 60 = cursor.
; ============================================================================

; Macro: define a single 4bpp tile from 8 row patterns (bp0 bytes only)
.MACRO MAKE_4BPP_TILE ARGS r0, r1, r2, r3, r4, r5, r6, r7
    ; Bitplanes 0-1 (bp0 = pattern, bp1 = $00 for all rows)
    .db r0, $00, r1, $00, r2, $00, r3, $00
    .db r4, $00, r5, $00, r6, $00, r7, $00
    ; Bitplanes 2-3 (all zero — only use colors 0-1)
    .db $00,$00, $00,$00, $00,$00, $00,$00
    .db $00,$00, $00,$00, $00,$00, $00,$00
.ENDM

textfont_tiles:

; --- Tile 0: Blank (space) ---
MAKE_4BPP_TILE $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile 1: A ---
MAKE_4BPP_TILE $3C,$66,$66,$7E,$66,$66,$00,$00

; --- Tile 2: B ---
MAKE_4BPP_TILE $7C,$66,$7C,$66,$66,$7C,$00,$00

; --- Tile 3: C ---
MAKE_4BPP_TILE $3C,$66,$60,$60,$66,$3C,$00,$00

; --- Tile 4: D ---
MAKE_4BPP_TILE $78,$6C,$66,$66,$6C,$78,$00,$00

; --- Tile 5: E ---
MAKE_4BPP_TILE $7E,$60,$7C,$60,$60,$7E,$00,$00

; --- Tile 6: F ---
MAKE_4BPP_TILE $7E,$60,$7C,$60,$60,$60,$00,$00

; --- Tile 7: G ---
MAKE_4BPP_TILE $3C,$66,$60,$6E,$66,$3C,$00,$00

; --- Tile 8: H ---
MAKE_4BPP_TILE $66,$66,$7E,$66,$66,$66,$00,$00

; --- Tile 9: I ---
MAKE_4BPP_TILE $3C,$18,$18,$18,$18,$3C,$00,$00

; --- Tile 10: J ---
MAKE_4BPP_TILE $1E,$06,$06,$06,$66,$3C,$00,$00

; --- Tile 11: K ---
MAKE_4BPP_TILE $66,$6C,$78,$78,$6C,$66,$00,$00

; --- Tile 12: L ---
MAKE_4BPP_TILE $60,$60,$60,$60,$60,$7E,$00,$00

; --- Tile 13: M ---
MAKE_4BPP_TILE $66,$7E,$7E,$5A,$66,$66,$00,$00

; --- Tile 14: N ---
MAKE_4BPP_TILE $66,$76,$7E,$6E,$66,$66,$00,$00

; --- Tile 15: O ---
MAKE_4BPP_TILE $3C,$66,$66,$66,$66,$3C,$00,$00

; --- Tile 16: P ---
MAKE_4BPP_TILE $7C,$66,$66,$7C,$60,$60,$00,$00

; --- Tile 17: Q ---
MAKE_4BPP_TILE $3C,$66,$66,$66,$6E,$3C,$06,$00

; --- Tile 18: R ---
MAKE_4BPP_TILE $7C,$66,$66,$7C,$6C,$66,$00,$00

; --- Tile 19: S ---
MAKE_4BPP_TILE $3C,$66,$38,$06,$66,$3C,$00,$00

; --- Tile 20: T ---
MAKE_4BPP_TILE $7E,$18,$18,$18,$18,$18,$00,$00

; --- Tile 21: U ---
MAKE_4BPP_TILE $66,$66,$66,$66,$66,$3C,$00,$00

; --- Tile 22: V ---
MAKE_4BPP_TILE $66,$66,$66,$66,$3C,$18,$00,$00

; --- Tile 23: W ---
MAKE_4BPP_TILE $66,$66,$66,$5A,$7E,$66,$00,$00

; --- Tile 24: X ---
MAKE_4BPP_TILE $66,$3C,$18,$18,$3C,$66,$00,$00

; --- Tile 25: Y ---
MAKE_4BPP_TILE $66,$66,$3C,$18,$18,$18,$00,$00

; --- Tile 26: Z ---
MAKE_4BPP_TILE $7E,$06,$0C,$18,$30,$7E,$00,$00

; --- Tile 27: 0 ---
MAKE_4BPP_TILE $3C,$66,$6E,$76,$66,$3C,$00,$00

; --- Tile 28: 1 ---
MAKE_4BPP_TILE $18,$38,$18,$18,$18,$7E,$00,$00

; --- Tile 29: 2 ---
MAKE_4BPP_TILE $3C,$66,$06,$1C,$30,$7E,$00,$00

; --- Tile 30: 3 ---
MAKE_4BPP_TILE $3C,$66,$0C,$06,$66,$3C,$00,$00

; --- Tile 31: 4 ---
MAKE_4BPP_TILE $0C,$1C,$3C,$6C,$7E,$0C,$00,$00

; --- Tile 32: 5 ---
MAKE_4BPP_TILE $7E,$60,$7C,$06,$66,$3C,$00,$00

; --- Tile 33: 6 ---
MAKE_4BPP_TILE $3C,$60,$7C,$66,$66,$3C,$00,$00

; --- Tile 34: 7 ---
MAKE_4BPP_TILE $7E,$06,$0C,$18,$18,$18,$00,$00

; --- Tile 35: 8 ---
MAKE_4BPP_TILE $3C,$66,$3C,$66,$66,$3C,$00,$00

; --- Tile 36: 9 ---
MAKE_4BPP_TILE $3C,$66,$3E,$06,$06,$3C,$00,$00

; --- Tile 37: ← (backspace arrow) ---
MAKE_4BPP_TILE $00,$10,$30,$7E,$30,$10,$00,$00

; --- Tile 38: ↵ (enter arrow) ---
MAKE_4BPP_TILE $00,$04,$04,$24,$3C,$20,$00,$00

; --- Tile 39: ^ (caret) ---
MAKE_4BPP_TILE $18,$3C,$66,$00,$7E,$00,$00,$00

; --- Tile 40: X mark (delete) ---
MAKE_4BPP_TILE $00,$66,$3C,$18,$3C,$66,$00,$00

; --- Tile 41: / ---
MAKE_4BPP_TILE $00,$06,$0C,$18,$30,$60,$00,$00

; --- Tile 42: , ---
MAKE_4BPP_TILE $00,$00,$00,$00,$18,$18,$30,$00

; --- Tile 43: . ---
MAKE_4BPP_TILE $00,$00,$00,$00,$00,$18,$18,$00

; --- Tile 44: _ (underscore) ---
MAKE_4BPP_TILE $00,$00,$00,$00,$00,$00,$7E,$00

; --- Tile 45: ─ (horizontal line) ---
MAKE_4BPP_TILE $00,$00,$00,$FF,$00,$00,$00,$00

; --- Tile 46: ! ---
MAKE_4BPP_TILE $18,$18,$18,$18,$00,$18,$00,$00

; --- Tile 47: ? ---
MAKE_4BPP_TILE $3C,$66,$06,$1C,$00,$18,$00,$00

; --- Tile 48: - (minus/hyphen) ---
MAKE_4BPP_TILE $00,$00,$00,$7E,$00,$00,$00,$00

; --- Tile 49: + ---
MAKE_4BPP_TILE $00,$18,$18,$7E,$18,$18,$00,$00

; --- Tile 50: = ---
MAKE_4BPP_TILE $00,$00,$7E,$00,$7E,$00,$00,$00

; --- Tile 51: ; ---
MAKE_4BPP_TILE $00,$18,$18,$00,$18,$18,$30,$00

; --- Tile 52: : ---
MAKE_4BPP_TILE $00,$18,$18,$00,$18,$18,$00,$00

; --- Tile 53: ( ---
MAKE_4BPP_TILE $0C,$18,$30,$30,$18,$0C,$00,$00

; --- Tile 54: ) ---
MAKE_4BPP_TILE $30,$18,$0C,$0C,$18,$30,$00,$00

; --- Tile 55: " ---
MAKE_4BPP_TILE $66,$66,$44,$00,$00,$00,$00,$00

; --- Tile 56: ' ---
MAKE_4BPP_TILE $18,$18,$08,$00,$00,$00,$00,$00

; --- Tile 57: @ ---
MAKE_4BPP_TILE $3C,$66,$6E,$6E,$60,$3C,$00,$00

; --- Tile 58: # ---
MAKE_4BPP_TILE $24,$7E,$24,$7E,$24,$00,$00,$00

; --- Tile 59: $ ---
MAKE_4BPP_TILE $18,$3E,$60,$3C,$06,$7C,$18,$00

; --- Tile 60: Text cursor (solid underscore) ---
MAKE_4BPP_TILE $00,$00,$00,$00,$00,$00,$FF,$00

; ============================================================================
; Box Frame Tiles — 4bpp opaque tiles for file menu/dialog overlays on BG1
; Background pixels = color 1 (solid fill), text/border = color 3.
; No transparent pixels, so underlying layers don't bleed through.
; ============================================================================

; Macro: 4bpp tile with solid background (color 1) and pattern in color 3
.MACRO MAKE_4BPP_BOX_TILE ARGS r0, r1, r2, r3, r4, r5, r6, r7
    .db $FF, r0, $FF, r1, $FF, r2, $FF, r3
    .db $FF, r4, $FF, r5, $FF, r6, $FF, r7
    .db $00,$00, $00,$00, $00,$00, $00,$00
    .db $00,$00, $00,$00, $00,$00, $00,$00
.ENDM

; --- Tile 61: Box fill (solid color 1) ---
MAKE_4BPP_BOX_TILE $00,$00,$00,$00,$00,$00,$00,$00

; --- Tile 62: Box corner TL (2px top + 2px left border in color 3) ---
MAKE_4BPP_BOX_TILE $FF,$FF,$C0,$C0,$C0,$C0,$C0,$C0

; --- Tile 63: Box horizontal edge (2px top border) ---
MAKE_4BPP_BOX_TILE $FF,$FF,$00,$00,$00,$00,$00,$00

; --- Tile 64: Box vertical edge (2px left border) ---
MAKE_4BPP_BOX_TILE $C0,$C0,$C0,$C0,$C0,$C0,$C0,$C0

; ============================================================================
; Opaque Font Tiles (tiles 65-125) — same glyphs as tiles 0-60 but with
; solid background. Index = original tile + BOX_TEXT_BASE (65).
; ============================================================================

; --- Tile 65: Blank (solid fill) ---
MAKE_4BPP_BOX_TILE $00,$00,$00,$00,$00,$00,$00,$00
; --- Tile 66: A ---
MAKE_4BPP_BOX_TILE $3C,$66,$66,$7E,$66,$66,$00,$00
; --- Tile 67: B ---
MAKE_4BPP_BOX_TILE $7C,$66,$7C,$66,$66,$7C,$00,$00
; --- Tile 68: C ---
MAKE_4BPP_BOX_TILE $3C,$66,$60,$60,$66,$3C,$00,$00
; --- Tile 69: D ---
MAKE_4BPP_BOX_TILE $78,$6C,$66,$66,$6C,$78,$00,$00
; --- Tile 70: E ---
MAKE_4BPP_BOX_TILE $7E,$60,$7C,$60,$60,$7E,$00,$00
; --- Tile 71: F ---
MAKE_4BPP_BOX_TILE $7E,$60,$7C,$60,$60,$60,$00,$00
; --- Tile 72: G ---
MAKE_4BPP_BOX_TILE $3C,$66,$60,$6E,$66,$3C,$00,$00
; --- Tile 73: H ---
MAKE_4BPP_BOX_TILE $66,$66,$7E,$66,$66,$66,$00,$00
; --- Tile 74: I ---
MAKE_4BPP_BOX_TILE $3C,$18,$18,$18,$18,$3C,$00,$00
; --- Tile 75: J ---
MAKE_4BPP_BOX_TILE $1E,$06,$06,$06,$66,$3C,$00,$00
; --- Tile 76: K ---
MAKE_4BPP_BOX_TILE $66,$6C,$78,$78,$6C,$66,$00,$00
; --- Tile 77: L ---
MAKE_4BPP_BOX_TILE $60,$60,$60,$60,$60,$7E,$00,$00
; --- Tile 78: M ---
MAKE_4BPP_BOX_TILE $66,$7E,$7E,$5A,$66,$66,$00,$00
; --- Tile 79: N ---
MAKE_4BPP_BOX_TILE $66,$76,$7E,$6E,$66,$66,$00,$00
; --- Tile 80: O ---
MAKE_4BPP_BOX_TILE $3C,$66,$66,$66,$66,$3C,$00,$00
; --- Tile 81: P ---
MAKE_4BPP_BOX_TILE $7C,$66,$66,$7C,$60,$60,$00,$00
; --- Tile 82: Q ---
MAKE_4BPP_BOX_TILE $3C,$66,$66,$66,$6E,$3C,$06,$00
; --- Tile 83: R ---
MAKE_4BPP_BOX_TILE $7C,$66,$66,$7C,$6C,$66,$00,$00
; --- Tile 84: S ---
MAKE_4BPP_BOX_TILE $3C,$66,$38,$06,$66,$3C,$00,$00
; --- Tile 85: T ---
MAKE_4BPP_BOX_TILE $7E,$18,$18,$18,$18,$18,$00,$00
; --- Tile 86: U ---
MAKE_4BPP_BOX_TILE $66,$66,$66,$66,$66,$3C,$00,$00
; --- Tile 87: V ---
MAKE_4BPP_BOX_TILE $66,$66,$66,$66,$3C,$18,$00,$00
; --- Tile 88: W ---
MAKE_4BPP_BOX_TILE $66,$66,$66,$5A,$7E,$66,$00,$00
; --- Tile 89: X ---
MAKE_4BPP_BOX_TILE $66,$3C,$18,$18,$3C,$66,$00,$00
; --- Tile 90: Y ---
MAKE_4BPP_BOX_TILE $66,$66,$3C,$18,$18,$18,$00,$00
; --- Tile 91: Z ---
MAKE_4BPP_BOX_TILE $7E,$06,$0C,$18,$30,$7E,$00,$00
; --- Tile 92: 0 ---
MAKE_4BPP_BOX_TILE $3C,$66,$6E,$76,$66,$3C,$00,$00
; --- Tile 93: 1 ---
MAKE_4BPP_BOX_TILE $18,$38,$18,$18,$18,$7E,$00,$00
; --- Tile 94: 2 ---
MAKE_4BPP_BOX_TILE $3C,$66,$06,$1C,$30,$7E,$00,$00
; --- Tile 95: 3 ---
MAKE_4BPP_BOX_TILE $3C,$66,$0C,$06,$66,$3C,$00,$00
; --- Tile 96: 4 ---
MAKE_4BPP_BOX_TILE $0C,$1C,$3C,$6C,$7E,$0C,$00,$00
; --- Tile 97: 5 ---
MAKE_4BPP_BOX_TILE $7E,$60,$7C,$06,$66,$3C,$00,$00
; --- Tile 98: 6 ---
MAKE_4BPP_BOX_TILE $3C,$60,$7C,$66,$66,$3C,$00,$00
; --- Tile 99: 7 ---
MAKE_4BPP_BOX_TILE $7E,$06,$0C,$18,$18,$18,$00,$00
; --- Tile 100: 8 ---
MAKE_4BPP_BOX_TILE $3C,$66,$3C,$66,$66,$3C,$00,$00
; --- Tile 101: 9 ---
MAKE_4BPP_BOX_TILE $3C,$66,$3E,$06,$06,$3C,$00,$00
; --- Tile 102: ← (backspace) ---
MAKE_4BPP_BOX_TILE $00,$10,$30,$7E,$30,$10,$00,$00
; --- Tile 103: ↵ (enter) ---
MAKE_4BPP_BOX_TILE $00,$04,$04,$24,$3C,$20,$00,$00
; --- Tile 104: ^ (caret) ---
MAKE_4BPP_BOX_TILE $18,$3C,$66,$00,$7E,$00,$00,$00
; --- Tile 105: X mark (delete) ---
MAKE_4BPP_BOX_TILE $00,$66,$3C,$18,$3C,$66,$00,$00
; --- Tile 106: / ---
MAKE_4BPP_BOX_TILE $00,$06,$0C,$18,$30,$60,$00,$00
; --- Tile 107: , (comma) ---
MAKE_4BPP_BOX_TILE $00,$00,$00,$00,$18,$18,$30,$00
; --- Tile 108: . (period) ---
MAKE_4BPP_BOX_TILE $00,$00,$00,$00,$00,$18,$18,$00
; --- Tile 109: _ (underscore) ---
MAKE_4BPP_BOX_TILE $00,$00,$00,$00,$00,$00,$7E,$00
; --- Tile 110: ─ (horizontal line) ---
MAKE_4BPP_BOX_TILE $00,$00,$00,$FF,$00,$00,$00,$00
; --- Tile 111: ! ---
MAKE_4BPP_BOX_TILE $18,$18,$18,$18,$00,$18,$00,$00
; --- Tile 112: ? ---
MAKE_4BPP_BOX_TILE $3C,$66,$06,$1C,$00,$18,$00,$00
; --- Tile 113: - (minus) ---
MAKE_4BPP_BOX_TILE $00,$00,$00,$7E,$00,$00,$00,$00
; --- Tile 114: + ---
MAKE_4BPP_BOX_TILE $00,$18,$18,$7E,$18,$18,$00,$00
; --- Tile 115: = ---
MAKE_4BPP_BOX_TILE $00,$00,$7E,$00,$7E,$00,$00,$00
; --- Tile 116: ; ---
MAKE_4BPP_BOX_TILE $00,$18,$18,$00,$18,$18,$30,$00
; --- Tile 117: : ---
MAKE_4BPP_BOX_TILE $00,$18,$18,$00,$18,$18,$00,$00
; --- Tile 118: ( ---
MAKE_4BPP_BOX_TILE $0C,$18,$30,$30,$18,$0C,$00,$00
; --- Tile 119: ) ---
MAKE_4BPP_BOX_TILE $30,$18,$0C,$0C,$18,$30,$00,$00
; --- Tile 120: " ---
MAKE_4BPP_BOX_TILE $66,$66,$44,$00,$00,$00,$00,$00
; --- Tile 121: ' ---
MAKE_4BPP_BOX_TILE $18,$18,$08,$00,$00,$00,$00,$00
; --- Tile 122: @ ---
MAKE_4BPP_BOX_TILE $3C,$66,$6E,$6E,$60,$3C,$00,$00
; --- Tile 123: # ---
MAKE_4BPP_BOX_TILE $24,$7E,$24,$7E,$24,$00,$00,$00
; --- Tile 124: $ ---
MAKE_4BPP_BOX_TILE $18,$3E,$60,$3C,$06,$7C,$18,$00
; --- Tile 125: Text cursor (opaque solid underscore) ---
MAKE_4BPP_BOX_TILE $00,$00,$00,$00,$00,$00,$FF,$00

textfont_tiles_end:


; ============================================================================
; Text Font Palette — 4bpp BG1 sub-palette 0
; Uploaded to CGRAM colors 0-15 when entering text editor.
; Only colors 0-1 are used by the font tiles.
; ============================================================================

textfont_palette:
.dw $0000    ; 0: transparent (backdrop shows through)
.dw $7FFF    ; 1: white (character color)
.dw $294A    ; 2: dark gray (status bar / UI)
.dw $0000    ; 3: unused
; Colors 4-15 mirror BG3 keyboard sub-palettes 1-3 so that re-uploading
; this palette after kbd_show doesn't clobber keyboard hover/shift/spacebar.
.dw $0000    ; 4: transparent  (BG3 sub-pal 1: hover)
.dw $03FF    ; 5: yellow       (hover key face)
.dw $01AD    ; 6: dark yellow  (hover shadow)
.dw $0000    ; 7: black        (hover text)
.dw $0000    ; 8: transparent  (BG3 sub-pal 2: shift-active)
.dw $7A90    ; 9: light blue   (shift key face)
.dw $3548    ; 10: darker blue (shift shadow)
.dw $0000    ; 11: black       (shift text)
.dw $0000    ; 12: transparent (BG3 sub-pal 3: spacebar)
.dw $7FFF    ; 13: white       (spacebar face)
.dw $294A    ; 14: gray        (spacebar shadow)
.dw $0000    ; 15: black       (spacebar text)
textfont_palette_end:

; ============================================================================
; Spreadsheet Editor Palettes — Additional BG1 sub-palettes for grid display
; Sub-palette 1 (CGRAM 16-31): Active/highlighted cell
; Sub-palette 2 (CGRAM 32-47): Headers and row numbers
; ============================================================================

sheet_pal_highlight:
.dw $3000    ; 0: dark blue background (highlight fill)
.dw $03FF    ; 1: bright yellow (highlighted character)
.dw $0000    ; 2: unused
.dw $0000    ; 3: unused
.dw $0000    ; 4: unused
.dw $0000    ; 5: unused
.dw $0000    ; 6: unused
.dw $0000    ; 7: unused
.dw $0000    ; 8: unused
.dw $0000    ; 9: unused
.dw $0000    ; 10: unused
.dw $0000    ; 11: unused
.dw $0000    ; 12: unused
.dw $0000    ; 13: unused
.dw $0000    ; 14: unused
.dw $0000    ; 15: unused
sheet_pal_highlight_end:

sheet_pal_headers:
.dw $0000    ; 0: transparent
.dw $294A    ; 1: gray (header/grid text)
.dw $0000    ; 2: unused
.dw $0000    ; 3: unused
.dw $0000    ; 4: unused
.dw $0000    ; 5: unused
.dw $0000    ; 6: unused
.dw $0000    ; 7: unused
.dw $0000    ; 8: unused
.dw $0000    ; 9: unused
.dw $0000    ; 10: unused
.dw $0000    ; 11: unused
.dw $0000    ; 12: unused
.dw $0000    ; 13: unused
.dw $0000    ; 14: unused
.dw $0000    ; 15: unused
sheet_pal_headers_end:

; ============================================================================
; Box Overlay Palettes — BG1 sub-palettes 3 and 4 for file menu/dialog
; Sub-palette 3 (CGRAM 48-63): Normal box — white text on dark gray fill
; Sub-palette 4 (CGRAM 64-79): Highlight box — yellow text on dark gray fill
; ============================================================================

box_palette:
.dw $0000    ; 0: transparent
.dw $1084    ; 1: dark gray (box fill background)
.dw $1084    ; 2: dark gray (same as fill)
.dw $7FFF    ; 3: white (text / border color)
.dw $0000, $0000, $0000, $0000   ; 4-7: unused
.dw $0000, $0000, $0000, $0000   ; 8-11: unused
.dw $0000, $0000, $0000, $0000   ; 12-15: unused
box_palette_end:

box_pal_highlight:
.dw $0000    ; 0: transparent
.dw $1084    ; 1: dark gray (box fill background)
.dw $1084    ; 2: dark gray (same as fill)
.dw $03FF    ; 3: yellow (highlighted text / border)
.dw $0000, $0000, $0000, $0000   ; 4-7: unused
.dw $0000, $0000, $0000, $0000   ; 8-11: unused
.dw $0000, $0000, $0000, $0000   ; 12-15: unused
box_pal_highlight_end:

; ============================================================================
; Grid Border Tiles — 4bpp tiles for BG2 cell grid overlay
; 4 tiles × 32 bytes = 128 bytes. Color 1 (white) used for border pixels.
; ============================================================================

sheet_grid_tiles:

; --- Tile 0: Blank (transparent) ---
.db $00,$00, $00,$00, $00,$00, $00,$00
.db $00,$00, $00,$00, $00,$00, $00,$00
.db $00,$00, $00,$00, $00,$00, $00,$00
.db $00,$00, $00,$00, $00,$00, $00,$00

; --- Tile 1: Corner (top row + left column border) ---
.db $FF,$00, $80,$00, $80,$00, $80,$00
.db $80,$00, $80,$00, $80,$00, $80,$00
.db $00,$00, $00,$00, $00,$00, $00,$00
.db $00,$00, $00,$00, $00,$00, $00,$00

; --- Tile 2: Top border only (horizontal line at row 0) ---
.db $FF,$00, $00,$00, $00,$00, $00,$00
.db $00,$00, $00,$00, $00,$00, $00,$00
.db $00,$00, $00,$00, $00,$00, $00,$00
.db $00,$00, $00,$00, $00,$00, $00,$00

; --- Tile 3: Left border only (vertical line at col 0) ---
.db $80,$00, $80,$00, $80,$00, $80,$00
.db $80,$00, $80,$00, $80,$00, $80,$00
.db $00,$00, $00,$00, $00,$00, $00,$00
.db $00,$00, $00,$00, $00,$00, $00,$00

sheet_grid_tiles_end:
