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

textfont_tiles_end:


; ============================================================================
; ASCII-to-Tile Lookup Table
; 96 entries for ASCII 32 ($20) through 127 ($7F).
; Maps each ASCII code to the corresponding keyboard font tile index.
; Characters without a tile glyph map to 0 (blank).
; Lowercase letters (97-122) map to same tiles as uppercase (1-26).
; ============================================================================

ascii_to_tile:
;       sp   !    "    #    $    %    &    '    (    )    *    +    ,    -    .    /
.db      0, 46,  55,  58,  59,   0,   0,  56,  53,  54,   0,  49,  42,  48,  43,  41
;        0    1    2    3    4    5    6    7    8    9    :    ;    <    =    >    ?
.db     27,  28,  29,  30,  31,  32,  33,  34,  35,  36,  52,  51,   0,  50,   0,  47
;        @    A    B    C    D    E    F    G    H    I    J    K    L    M    N    O
.db     57,   1,   2,   3,   4,   5,   6,   7,   8,   9,  10,  11,  12,  13,  14,  15
;        P    Q    R    S    T    U    V    W    X    Y    Z    [    \    ]    ^    _
.db     16,  17,  18,  19,  20,  21,  22,  23,  24,  25,  26,   0,   0,   0,   0,  44
;        `    a    b    c    d    e    f    g    h    i    j    k    l    m    n    o
.db      0,   1,   2,   3,   4,   5,   6,   7,   8,   9,  10,  11,  12,  13,  14,  15
;        p    q    r    s    t    u    v    w    x    y    z    {    |    }    ~   DEL
.db     16,  17,  18,  19,  20,  21,  22,  23,  24,  25,  26,   0,   0,   0,   0,   0


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
