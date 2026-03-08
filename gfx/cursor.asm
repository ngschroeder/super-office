; ============================================================================
; gfx/cursor.asm — Cursor Sprite Tile Data and Palette
;
; 16x16 arrow cursor in 4bpp SNES format.
; A 16x16 sprite uses 4 tiles in 8x8 format (top-left, top-right,
; bottom-left, bottom-right), each 32 bytes in 4bpp = 128 bytes total.
;
; 4bpp tile format (per 8x8 tile, 32 bytes):
;   Rows 0-7: [bp0] [bp1] [bp2] [bp3] — 4 bytes per row
;   But SNES 4bpp interleaves: first 16 bytes = bitplanes 0+1 (like 2bpp),
;   next 16 bytes = bitplanes 2+3.
;
; Palette indices used:
;   0 = transparent
;   1 = black ($0000) — outline
;   2 = white ($7FFF) — fill
;
; Arrow design (16x16, using palette indices):
;   Row 0:  1 0 0 0 0 0 0 0  0 0 0 0 0 0 0 0
;   Row 1:  1 1 0 0 0 0 0 0  0 0 0 0 0 0 0 0
;   Row 2:  1 2 1 0 0 0 0 0  0 0 0 0 0 0 0 0
;   Row 3:  1 2 2 1 0 0 0 0  0 0 0 0 0 0 0 0
;   Row 4:  1 2 2 2 1 0 0 0  0 0 0 0 0 0 0 0
;   Row 5:  1 2 2 2 2 1 0 0  0 0 0 0 0 0 0 0
;   Row 6:  1 2 2 2 2 2 1 0  0 0 0 0 0 0 0 0
;   Row 7:  1 2 2 2 2 2 2 1  0 0 0 0 0 0 0 0
;   Row 8:  1 2 2 2 2 2 2 2  1 0 0 0 0 0 0 0
;   Row 9:  1 2 2 2 2 2 1 1  0 0 0 0 0 0 0 0
;   Row 10: 1 2 2 1 2 2 1 0  0 0 0 0 0 0 0 0
;   Row 11: 1 2 1 0 1 2 2 1  0 0 0 0 0 0 0 0
;   Row 12: 1 1 0 0 1 2 2 1  0 0 0 0 0 0 0 0
;   Row 13: 1 0 0 0 0 1 2 1  0 0 0 0 0 0 0 0
;   Row 14: 0 0 0 0 0 1 2 1  0 0 0 0 0 0 0 0
;   Row 15: 0 0 0 0 0 0 1 1  0 0 0 0 0 0 0 0
;
; For palette index encoding in 4bpp:
;   Index 0 = 0000 (transparent)
;   Index 1 = 0001 (black)
;   Index 2 = 0010 (white)
;
; Bitplane encoding per pixel:
;   Index 0: bp0=0 bp1=0 bp2=0 bp3=0
;   Index 1: bp0=1 bp1=0 bp2=0 bp3=0
;   Index 2: bp0=0 bp1=1 bp2=0 bp3=0
; ============================================================================

; The cursor tiles are laid out in VRAM as:
;   Tile 0 = top-left 8x8     (rows 0-7, columns 0-7)
;   Tile 1 = top-right 8x8    (rows 0-7, columns 8-15) — all transparent
;   Tile 2 = bottom-left 8x8  (rows 8-15, columns 0-7)
;   Tile 3 = bottom-right 8x8 (rows 8-15, columns 8-15) — all transparent

cursor_tiles:

; === Tile 0: Top-left 8x8 (rows 0-7) ===
; Bitplanes 0+1 (interleaved: bp0 row, bp1 row, bp0 row, bp1 row...)
; Row 0: 1 0 0 0 0 0 0 0  -> bp0: 10000000=$80  bp1: 00000000=$00
; Row 1: 1 1 0 0 0 0 0 0  -> bp0: 11000000=$C0  bp1: 00000000=$00
; Row 2: 1 2 1 0 0 0 0 0  -> bp0: 10100000=$A0  bp1: 01000000=$40
; Row 3: 1 2 2 1 0 0 0 0  -> bp0: 10010000=$90  bp1: 01100000=$60
; Row 4: 1 2 2 2 1 0 0 0  -> bp0: 10001000=$88  bp1: 01110000=$70
; Row 5: 1 2 2 2 2 1 0 0  -> bp0: 10000100=$84  bp1: 01111000=$78
; Row 6: 1 2 2 2 2 2 1 0  -> bp0: 10000010=$82  bp1: 01111100=$7C
; Row 7: 1 2 2 2 2 2 2 1  -> bp0: 10000001=$81  bp1: 01111110=$7E
.db $80, $00    ; Row 0: bp0, bp1
.db $C0, $00    ; Row 1
.db $A0, $40    ; Row 2
.db $90, $60    ; Row 3
.db $88, $70    ; Row 4
.db $84, $78    ; Row 5
.db $82, $7C    ; Row 6
.db $81, $7E    ; Row 7
; Bitplanes 2+3 (all zero — our indices only use bp0 and bp1)
.db $00, $00    ; Row 0: bp2, bp3
.db $00, $00    ; Row 1
.db $00, $00    ; Row 2
.db $00, $00    ; Row 3
.db $00, $00    ; Row 4
.db $00, $00    ; Row 5
.db $00, $00    ; Row 6
.db $00, $00    ; Row 7

; === Tile 1: Top-right 8x8 (rows 0-7, columns 8-15) — all transparent ===
; Bitplanes 0+1
.db $00, $00    ; Row 0
.db $00, $00    ; Row 1
.db $00, $00    ; Row 2
.db $00, $00    ; Row 3
.db $00, $00    ; Row 4
.db $00, $00    ; Row 5
.db $00, $00    ; Row 6
.db $00, $00    ; Row 7
; Bitplanes 2+3
.db $00, $00
.db $00, $00
.db $00, $00
.db $00, $00
.db $00, $00
.db $00, $00
.db $00, $00
.db $00, $00

; === Tile 2: Bottom-left 8x8 (rows 8-15) ===
; Row 8:  1 2 2 2 2 2 2 2  -> bp0: 10000000=$80  bp1: 01111111=$7F
; Row 9:  1 2 2 2 2 2 1 1  -> bp0: 10000011=$83  bp1: 01111100=$7C
; Row 10: 1 2 2 1 2 2 1 0  -> bp0: 10010010=$92  bp1: 01100100=$64
; Row 11: 1 2 1 0 1 2 2 1  -> bp0: 10100001=$A1  bp1: 01000110=$46
; Row 12: 1 1 0 0 1 2 2 1  -> bp0: 11001001=$C9  bp1: 00000110=$06
; Row 13: 1 0 0 0 0 1 2 1  -> bp0: 10000101=$85  bp1: 00000010=$02
; Row 14: 0 0 0 0 0 1 2 1  -> bp0: 00000101=$05  bp1: 00000010=$02
; Row 15: 0 0 0 0 0 0 1 1  -> bp0: 00000011=$03  bp1: 00000000=$00
; Bitplanes 0+1
.db $80, $7F    ; Row 8
.db $83, $7C    ; Row 9
.db $92, $64    ; Row 10
.db $A1, $46    ; Row 11
.db $C9, $06    ; Row 12
.db $85, $02    ; Row 13
.db $05, $02    ; Row 14
.db $03, $00    ; Row 15
; Bitplanes 2+3
.db $00, $00
.db $00, $00
.db $00, $00
.db $00, $00
.db $00, $00
.db $00, $00
.db $00, $00
.db $00, $00

; === Tile 3: Bottom-right 8x8 (rows 8-15, columns 8-15) ===
; Row 8:  1 0 0 0 0 0 0 0  -> bp0: 10000000=$80  bp1: 00000000=$00
; Rows 9-15: all transparent
; Bitplanes 0+1
.db $80, $00    ; Row 8 (the "1" at column 8)
.db $00, $00    ; Row 9
.db $00, $00    ; Row 10
.db $00, $00    ; Row 11
.db $00, $00    ; Row 12
.db $00, $00    ; Row 13
.db $00, $00    ; Row 14
.db $00, $00    ; Row 15
; Bitplanes 2+3
.db $00, $00
.db $00, $00
.db $00, $00
.db $00, $00
.db $00, $00
.db $00, $00
.db $00, $00
.db $00, $00

cursor_tiles_end:

; ============================================================================
; Cursor Palette — 16 colors for sprite palette 0
; Loaded to CGRAM starting at color 128 (first sprite palette)
; Format: little-endian BGR555 (bbbbbggg ggrrrrrr)
; ============================================================================
cursor_palette:
.dw $0000    ; Color 0: transparent (not actually displayed)
.dw $0000    ; Color 1: black (R=0, G=0, B=0)
.dw $7FFF    ; Color 2: white (R=31, G=31, B=31)
.dw $0000    ; Color 3: unused
.dw $0000    ; Color 4: unused
.dw $0000    ; Color 5: unused
.dw $0000    ; Color 6: unused
.dw $0000    ; Color 7: unused
.dw $0000    ; Color 8: unused
.dw $0000    ; Color 9: unused
.dw $0000    ; Color 10: unused
.dw $0000    ; Color 11: unused
.dw $0000    ; Color 12: unused
.dw $0000    ; Color 13: unused
.dw $0000    ; Color 14: unused
.dw $0000    ; Color 15: unused
cursor_palette_end:
