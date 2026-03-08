; ============================================================================
; gfx/keyboard.asm — Graphical On-Screen Keyboard Tiles & Data
;
; 2bpp tiles with key-cap backgrounds:
;   bp0 = key background fill (color 1)
;   bp1 = character pixels (color 2 alone, color 3 on bg)
;
; Color mapping:
;   Color 0 (neither bp): transparent gap between keys
;   Color 1 (bp0 only):   key background (white/yellow/blue per palette)
;   Color 2 (bp1 only):   char outside bg (unused in practice)
;   Color 3 (both bps):   character on key background (dark text)
;
; Color 1 = white in sub-palette 0, preserving BG1 font compatibility.
; ============================================================================

; Macro: create a 2bpp key tile with background fill and transparent gaps
; bp0 = $7E background (bits 1-6 set, bits 0+7 clear = 1px gap left & right)
; bp1 = character pixel pattern (6 rows, mapped to tile rows 1-6)
; Rows 0 and 7 are fully transparent (1px gap top & bottom).
; Character centered in 6×6 visible key body.
.MACRO MAKE_KEY_TILE ARGS r0, r1, r2, r3, r4, r5
    .db $00, $00             ; Row 0: transparent (top gap)
    .db $7E, (r0 & $7E)     ; Row 1: key body + char
    .db $7E, (r1 & $7E)     ; Row 2: key body + char
    .db $7E, (r2 & $7E)     ; Row 3: key body + char
    .db $7E, (r3 & $7E)     ; Row 4: key body + char
    .db $7E, (r4 & $7E)     ; Row 5: key body + char
    .db $7E, (r5 & $7E)     ; Row 6: key body + char
    .db $00, $00             ; Row 7: transparent (bottom gap)
.ENDM


kbd_tiles:

; --- Tile 0: Blank (fully transparent — used for tilemap clear) ---
.db $00,$00, $00,$00, $00,$00, $00,$00
.db $00,$00, $00,$00, $00,$00, $00,$00

; ====================== Uppercase A-Z (tiles 1-26) ======================

; --- Tile 1: A ---
MAKE_KEY_TILE $3C,$66,$66,$7E,$66,$66
; --- Tile 2: B ---
MAKE_KEY_TILE $7C,$66,$7C,$66,$66,$7C
; --- Tile 3: C ---
MAKE_KEY_TILE $3C,$66,$60,$60,$66,$3C
; --- Tile 4: D ---
MAKE_KEY_TILE $78,$6C,$66,$66,$6C,$78
; --- Tile 5: E ---
MAKE_KEY_TILE $7E,$60,$7C,$60,$60,$7E
; --- Tile 6: F ---
MAKE_KEY_TILE $7E,$60,$7C,$60,$60,$60
; --- Tile 7: G ---
MAKE_KEY_TILE $3C,$66,$60,$6E,$66,$3C
; --- Tile 8: H ---
MAKE_KEY_TILE $66,$66,$7E,$66,$66,$66
; --- Tile 9: I ---
MAKE_KEY_TILE $3C,$18,$18,$18,$18,$3C
; --- Tile 10: J ---
MAKE_KEY_TILE $1E,$06,$06,$06,$66,$3C
; --- Tile 11: K ---
MAKE_KEY_TILE $66,$6C,$78,$78,$6C,$66
; --- Tile 12: L ---
MAKE_KEY_TILE $60,$60,$60,$60,$60,$7E
; --- Tile 13: M ---
MAKE_KEY_TILE $66,$7E,$7E,$5A,$66,$66
; --- Tile 14: N ---
MAKE_KEY_TILE $66,$76,$7E,$6E,$66,$66
; --- Tile 15: O ---
MAKE_KEY_TILE $3C,$66,$66,$66,$66,$3C
; --- Tile 16: P ---
MAKE_KEY_TILE $7C,$66,$66,$7C,$60,$60
; --- Tile 17: Q ---
MAKE_KEY_TILE $3C,$66,$66,$6E,$3C,$06
; --- Tile 18: R ---
MAKE_KEY_TILE $7C,$66,$66,$7C,$6C,$66
; --- Tile 19: S ---
MAKE_KEY_TILE $3C,$66,$38,$06,$66,$3C
; --- Tile 20: T ---
MAKE_KEY_TILE $7E,$18,$18,$18,$18,$18
; --- Tile 21: U ---
MAKE_KEY_TILE $66,$66,$66,$66,$66,$3C
; --- Tile 22: V ---
MAKE_KEY_TILE $66,$66,$66,$66,$3C,$18
; --- Tile 23: W ---
MAKE_KEY_TILE $66,$66,$66,$5A,$7E,$66
; --- Tile 24: X ---
MAKE_KEY_TILE $66,$3C,$18,$18,$3C,$66
; --- Tile 25: Y ---
MAKE_KEY_TILE $66,$66,$3C,$18,$18,$18
; --- Tile 26: Z ---
MAKE_KEY_TILE $7E,$06,$0C,$18,$30,$7E

; ====================== Lowercase a-z (tiles 27-52) ======================

; --- Tile 27: a ---
MAKE_KEY_TILE $00,$3C,$06,$3E,$66,$3E
; --- Tile 28: b ---
MAKE_KEY_TILE $60,$60,$7C,$66,$66,$7C
; --- Tile 29: c ---
MAKE_KEY_TILE $00,$3C,$66,$60,$66,$3C
; --- Tile 30: d ---
MAKE_KEY_TILE $06,$06,$3E,$66,$66,$3E
; --- Tile 31: e ---
MAKE_KEY_TILE $00,$3C,$66,$7E,$60,$3C
; --- Tile 32: f ---
MAKE_KEY_TILE $1C,$30,$7C,$30,$30,$30
; --- Tile 33: g ---
MAKE_KEY_TILE $3E,$66,$66,$3E,$06,$3C
; --- Tile 34: h ---
MAKE_KEY_TILE $60,$60,$7C,$66,$66,$66
; --- Tile 35: i ---
MAKE_KEY_TILE $18,$00,$38,$18,$18,$3C
; --- Tile 36: j ---
MAKE_KEY_TILE $0C,$00,$0C,$0C,$6C,$38
; --- Tile 37: k ---
MAKE_KEY_TILE $60,$66,$6C,$78,$6C,$66
; --- Tile 38: l ---
MAKE_KEY_TILE $38,$18,$18,$18,$18,$3C
; --- Tile 39: m ---
MAKE_KEY_TILE $00,$76,$5A,$5A,$5A,$5A
; --- Tile 40: n ---
MAKE_KEY_TILE $00,$7C,$66,$66,$66,$66
; --- Tile 41: o ---
MAKE_KEY_TILE $00,$3C,$66,$66,$66,$3C
; --- Tile 42: p ---
MAKE_KEY_TILE $00,$7C,$66,$7C,$60,$60
; --- Tile 43: q ---
MAKE_KEY_TILE $00,$3E,$66,$3E,$06,$06
; --- Tile 44: r ---
MAKE_KEY_TILE $00,$7C,$66,$60,$60,$60
; --- Tile 45: s ---
MAKE_KEY_TILE $00,$3C,$60,$3C,$06,$3C
; --- Tile 46: t ---
MAKE_KEY_TILE $30,$30,$7C,$30,$30,$1C
; --- Tile 47: u ---
MAKE_KEY_TILE $00,$66,$66,$66,$66,$3E
; --- Tile 48: v ---
MAKE_KEY_TILE $00,$66,$66,$66,$3C,$18
; --- Tile 49: w ---
MAKE_KEY_TILE $00,$66,$66,$66,$5A,$3C
; --- Tile 50: x ---
MAKE_KEY_TILE $00,$66,$3C,$18,$3C,$66
; --- Tile 51: y ---
MAKE_KEY_TILE $00,$66,$66,$3E,$06,$3C
; --- Tile 52: z ---
MAKE_KEY_TILE $00,$7E,$0C,$18,$30,$7E

; ====================== Digits 0-9 (tiles 53-62) ======================

; --- Tile 53: 0 ---
MAKE_KEY_TILE $3C,$66,$6E,$76,$66,$3C
; --- Tile 54: 1 ---
MAKE_KEY_TILE $18,$38,$18,$18,$18,$7E
; --- Tile 55: 2 ---
MAKE_KEY_TILE $3C,$66,$06,$1C,$30,$7E
; --- Tile 56: 3 ---
MAKE_KEY_TILE $3C,$66,$0C,$06,$66,$3C
; --- Tile 57: 4 ---
MAKE_KEY_TILE $0C,$1C,$3C,$6C,$7E,$0C
; --- Tile 58: 5 ---
MAKE_KEY_TILE $7E,$60,$7C,$06,$66,$3C
; --- Tile 59: 6 ---
MAKE_KEY_TILE $3C,$60,$7C,$66,$66,$3C
; --- Tile 60: 7 ---
MAKE_KEY_TILE $7E,$06,$0C,$18,$18,$18
; --- Tile 61: 8 ---
MAKE_KEY_TILE $3C,$66,$3C,$66,$66,$3C
; --- Tile 62: 9 ---
MAKE_KEY_TILE $3C,$66,$3E,$06,$06,$3C

; ============= Shifted digit symbols !@#$%^&*() (tiles 63-72) =============

; --- Tile 63: ! ---
MAKE_KEY_TILE $18,$18,$18,$18,$00,$18
; --- Tile 64: @ ---
MAKE_KEY_TILE $3C,$66,$6E,$6E,$60,$3C
; --- Tile 65: # ---
MAKE_KEY_TILE $24,$7E,$24,$7E,$24,$00
; --- Tile 66: $ ---
MAKE_KEY_TILE $18,$3E,$60,$3C,$06,$7C
; --- Tile 67: % ---
MAKE_KEY_TILE $66,$0C,$18,$18,$30,$66
; --- Tile 68: ^ ---
MAKE_KEY_TILE $18,$3C,$66,$00,$00,$00
; --- Tile 69: & ---
MAKE_KEY_TILE $38,$6C,$38,$6E,$66,$3C
; --- Tile 70: * ---
MAKE_KEY_TILE $00,$24,$18,$7E,$18,$24
; --- Tile 71: ( ---
MAKE_KEY_TILE $0C,$18,$30,$30,$18,$0C
; --- Tile 72: ) ---
MAKE_KEY_TILE $30,$18,$0C,$0C,$18,$30

; ====================== Special keys (tiles 73-76) ======================

; --- Tile 73: ← (backspace arrow) ---
MAKE_KEY_TILE $00,$10,$30,$7E,$30,$10
; --- Tile 74: ↵ (enter arrow) ---
MAKE_KEY_TILE $00,$04,$04,$24,$3C,$20
; --- Tile 75: ↑ (shift arrow) ---
MAKE_KEY_TILE $18,$3C,$7E,$18,$18,$18
; --- Tile 76: X (delete mark) ---
MAKE_KEY_TILE $00,$66,$3C,$18,$3C,$66

; ====================== Punctuation (tiles 77-82) ======================

; --- Tile 77: / ---
MAKE_KEY_TILE $06,$0C,$18,$30,$60,$00
; --- Tile 78: , ---
MAKE_KEY_TILE $00,$00,$00,$18,$18,$30
; --- Tile 79: . ---
MAKE_KEY_TILE $00,$00,$00,$00,$18,$18
; --- Tile 80: < ---
MAKE_KEY_TILE $0C,$18,$30,$60,$30,$18
; --- Tile 81: > ---
MAKE_KEY_TILE $30,$18,$0C,$06,$0C,$18
; --- Tile 82: ? ---
MAKE_KEY_TILE $3C,$66,$06,$1C,$00,$18

; ============= Extra punctuation for UI text (tiles 83-84) =============

; --- Tile 83: - (minus/hyphen) ---
MAKE_KEY_TILE $00,$00,$00,$7E,$00,$00
; --- Tile 84: _ (underscore) ---
MAKE_KEY_TILE $00,$00,$00,$00,$00,$7E

; ====================== Separator line (tile 85) ======================

; Horizontal separator — uses bp0 only (color 1 = white line)
; Not a key tile — no background fill, just a line at row 3
.db $00,$00, $00,$00, $00,$00, $FF,$00
.db $00,$00, $00,$00, $00,$00, $00,$00

; --- Tile 86: + (plus) ---
MAKE_KEY_TILE $00,$18,$18,$7E,$18,$18

; ====================== Spacebar tiles (87-94) ======================
; Spacebar uses continuous background (no inter-key gaps) with
; transparent top/bottom rows. Three edge types + letter overlays.

; --- Tile 87: Spacebar left cap ---
; bp0: $7F = 01111111 (left px transparent, rest filled)
.db $00,$00, $7F,$00, $7F,$00, $7F,$00
.db $7F,$00, $7F,$00, $7F,$00, $00,$00

; --- Tile 88: Spacebar middle (blank) ---
; bp0: $FF = all filled (connects to adjacent spacebar tiles)
.db $00,$00, $FF,$00, $FF,$00, $FF,$00
.db $FF,$00, $FF,$00, $FF,$00, $00,$00

; --- Tile 89: Spacebar right cap ---
; bp0: $FE = 11111110 (right px transparent, rest filled)
.db $00,$00, $FE,$00, $FE,$00, $FE,$00
.db $FE,$00, $FE,$00, $FE,$00, $00,$00

; --- Tile 90: Spacebar "S" ---
.db $00,$00, $FF,$3C, $FF,$66, $FF,$38
.db $FF,$06, $FF,$66, $FF,$3C, $00,$00

; --- Tile 91: Spacebar "P" ---
.db $00,$00, $FF,$7C, $FF,$66, $FF,$66
.db $FF,$7C, $FF,$60, $FF,$60, $00,$00

; --- Tile 92: Spacebar "A" ---
.db $00,$00, $FF,$3C, $FF,$66, $FF,$66
.db $FF,$7E, $FF,$66, $FF,$66, $00,$00

; --- Tile 93: Spacebar "C" ---
.db $00,$00, $FF,$3C, $FF,$66, $FF,$60
.db $FF,$60, $FF,$66, $FF,$3C, $00,$00

; --- Tile 94: Spacebar "E" ---
.db $00,$00, $FF,$7E, $FF,$60, $FF,$7C
.db $FF,$60, $FF,$60, $FF,$7E, $00,$00

kbd_tiles_8x8_end:    ; End of legacy 8x8 tiles (tiles 0-94) — referenced by save.asm and menu.asm


; ============================================================================
; 16x16 Key Tile Macros
;
; Each 16x16 key = 4 tiles: TL (95), TR (96) shared frame + BL/BR unique pair.
; BL/BR contain a 2x horizontally expanded version of the 6px character.
;
; Colors:
;   Color 0 (00): transparent (gaps between keys)
;   Color 1 (01, bp0 only): key face (white/yellow/blue)
;   Color 2 (10, bp1 only): shadow strip (gray)
;   Color 3 (11, both): character text (black)
; ============================================================================

; Macro: create bottom-left tile of a 16x16 key (2x horizontal char expansion)
; Takes 6 character row bytes (same as original MAKE_KEY_TILE args)
; Expands original bits 6,5,4 — each pixel doubled into 2 pixels
.MACRO MAKE_KEY_BL ARGS r0, r1, r2, r3, r4, r5
    .db $7F, (((r0 & $40) >> 6) * $30) | (((r0 & $20) >> 5) * $0C) | (((r0 & $10) >> 4) * $03)
    .db $7F, (((r1 & $40) >> 6) * $30) | (((r1 & $20) >> 5) * $0C) | (((r1 & $10) >> 4) * $03)
    .db $7F, (((r2 & $40) >> 6) * $30) | (((r2 & $20) >> 5) * $0C) | (((r2 & $10) >> 4) * $03)
    .db $7F, (((r3 & $40) >> 6) * $30) | (((r3 & $20) >> 5) * $0C) | (((r3 & $10) >> 4) * $03)
    .db $7F, (((r4 & $40) >> 6) * $30) | (((r4 & $20) >> 5) * $0C) | (((r4 & $10) >> 4) * $03)
    .db $7F, (((r5 & $40) >> 6) * $30) | (((r5 & $20) >> 5) * $0C) | (((r5 & $10) >> 4) * $03)
    .db $00, $7F
    .db $00, $00
.ENDM

; Macro: create bottom-right tile of a 16x16 key (2x horizontal char expansion)
; Expands original bits 3,2,1 — each pixel doubled into 2 pixels
.MACRO MAKE_KEY_BR ARGS r0, r1, r2, r3, r4, r5
    .db $FE, (((r0 & $08) >> 3) * $C0) | (((r0 & $04) >> 2) * $30) | (((r0 & $02) >> 1) * $0C)
    .db $FE, (((r1 & $08) >> 3) * $C0) | (((r1 & $04) >> 2) * $30) | (((r1 & $02) >> 1) * $0C)
    .db $FE, (((r2 & $08) >> 3) * $C0) | (((r2 & $04) >> 2) * $30) | (((r2 & $02) >> 1) * $0C)
    .db $FE, (((r3 & $08) >> 3) * $C0) | (((r3 & $04) >> 2) * $30) | (((r3 & $02) >> 1) * $0C)
    .db $FE, (((r4 & $08) >> 3) * $C0) | (((r4 & $04) >> 2) * $30) | (((r4 & $02) >> 1) * $0C)
    .db $FE, (((r5 & $08) >> 3) * $C0) | (((r5 & $04) >> 2) * $30) | (((r5 & $02) >> 1) * $0C)
    .db $00, $FE
    .db $00, $00
.ENDM

; Convenience: generate BL+BR pair (2 consecutive tiles per character)
.MACRO MAKE_KEY_16 ARGS r0, r1, r2, r3, r4, r5
    MAKE_KEY_BL r0, r1, r2, r3, r4, r5
    MAKE_KEY_BR r0, r1, r2, r3, r4, r5
.ENDM

; Spacebar letter tile: full-width face (no left/right gap) + character + shadow
.MACRO MAKE_SPC_LETTER ARGS r0, r1, r2, r3, r4, r5
    .db $FF, r0
    .db $FF, r1
    .db $FF, r2
    .db $FF, r3
    .db $FF, r4
    .db $FF, r5
    .db $00, $FF
    .db $00, $00
.ENDM


; ============================================================================
; 16x16 Key Tile Data — tiles 95 onward
; ============================================================================

kbd_tiles_16:

; ====================== Shared Frame Tiles (95-96) ======================

; --- Tile 95: TL (top-left frame) ---
; 1px transparent top + left gaps, rest is face
.db $00,$00  ; Row 0: transparent (top gap)
.db $7F,$00  ; Row 1: face ($7F = bit 7 clear for left gap)
.db $7F,$00  ; Row 2: face
.db $7F,$00  ; Row 3: face
.db $7F,$00  ; Row 4: face
.db $7F,$00  ; Row 5: face
.db $7F,$00  ; Row 6: face
.db $7F,$00  ; Row 7: face

; --- Tile 96: TR (top-right frame) ---
; 1px transparent top + right gaps, rest is face
.db $00,$00  ; Row 0: transparent (top gap)
.db $FE,$00  ; Row 1: face ($FE = bit 0 clear for right gap)
.db $FE,$00  ; Row 2: face
.db $FE,$00  ; Row 3: face
.db $FE,$00  ; Row 4: face
.db $FE,$00  ; Row 5: face
.db $FE,$00  ; Row 6: face
.db $FE,$00  ; Row 7: face

; ====================== Spacebar Tiles (97-107) ======================

; --- Tile 97: SPC_TL — spacebar top-left cap ---
.db $00,$00, $7F,$00, $7F,$00, $7F,$00, $7F,$00, $7F,$00, $7F,$00, $7F,$00

; --- Tile 98: SPC_TM — spacebar top middle ---
.db $00,$00, $FF,$00, $FF,$00, $FF,$00, $FF,$00, $FF,$00, $FF,$00, $FF,$00

; --- Tile 99: SPC_TR — spacebar top-right cap ---
.db $00,$00, $FE,$00, $FE,$00, $FE,$00, $FE,$00, $FE,$00, $FE,$00, $FE,$00

; --- Tile 100: SPC_BL — spacebar bottom-left cap ---
.db $7F,$00, $7F,$00, $7F,$00, $7F,$00, $7F,$00, $7F,$00, $00,$7F, $00,$00

; --- Tile 101: SPC_BM — spacebar bottom middle blank ---
.db $FF,$00, $FF,$00, $FF,$00, $FF,$00, $FF,$00, $FF,$00, $00,$FF, $00,$00

; --- Tile 102: SPC_BR — spacebar bottom-right cap ---
.db $FE,$00, $FE,$00, $FE,$00, $FE,$00, $FE,$00, $FE,$00, $00,$FE, $00,$00

; --- Tile 103: SPC_S — spacebar "S" letter ---
MAKE_SPC_LETTER $3C,$66,$38,$06,$66,$3C

; --- Tile 104: SPC_P — spacebar "P" letter ---
MAKE_SPC_LETTER $7C,$66,$66,$7C,$60,$60

; --- Tile 105: SPC_A — spacebar "A" letter ---
MAKE_SPC_LETTER $3C,$66,$66,$7E,$66,$66

; --- Tile 106: SPC_C — spacebar "C" letter ---
MAKE_SPC_LETTER $3C,$66,$60,$60,$66,$3C

; --- Tile 107: SPC_E — spacebar "E" letter ---
MAKE_SPC_LETTER $7E,$60,$7C,$60,$60,$7E

; ====================== Uppercase A-Z BL/BR Pairs (tiles 108-159) ======================

; --- A (BL=108, BR=109) ---
MAKE_KEY_16 $3C,$66,$66,$7E,$66,$66
; --- B (BL=110, BR=111) ---
MAKE_KEY_16 $7C,$66,$7C,$66,$66,$7C
; --- C (BL=112, BR=113) ---
MAKE_KEY_16 $3C,$66,$60,$60,$66,$3C
; --- D (BL=114, BR=115) ---
MAKE_KEY_16 $78,$6C,$66,$66,$6C,$78
; --- E (BL=116, BR=117) ---
MAKE_KEY_16 $7E,$60,$7C,$60,$60,$7E
; --- F (BL=118, BR=119) ---
MAKE_KEY_16 $7E,$60,$7C,$60,$60,$60
; --- G (BL=120, BR=121) ---
MAKE_KEY_16 $3C,$66,$60,$6E,$66,$3C
; --- H (BL=122, BR=123) ---
MAKE_KEY_16 $66,$66,$7E,$66,$66,$66
; --- I (BL=124, BR=125) ---
MAKE_KEY_16 $3C,$18,$18,$18,$18,$3C
; --- J (BL=126, BR=127) ---
MAKE_KEY_16 $1E,$06,$06,$06,$66,$3C
; --- K (BL=128, BR=129) ---
MAKE_KEY_16 $66,$6C,$78,$78,$6C,$66
; --- L (BL=130, BR=131) ---
MAKE_KEY_16 $60,$60,$60,$60,$60,$7E
; --- M (BL=132, BR=133) ---
MAKE_KEY_16 $66,$7E,$7E,$5A,$66,$66
; --- N (BL=134, BR=135) ---
MAKE_KEY_16 $66,$76,$7E,$6E,$66,$66
; --- O (BL=136, BR=137) ---
MAKE_KEY_16 $3C,$66,$66,$66,$66,$3C
; --- P (BL=138, BR=139) ---
MAKE_KEY_16 $7C,$66,$66,$7C,$60,$60
; --- Q (BL=140, BR=141) ---
MAKE_KEY_16 $3C,$66,$66,$6E,$3C,$06
; --- R (BL=142, BR=143) ---
MAKE_KEY_16 $7C,$66,$66,$7C,$6C,$66
; --- S (BL=144, BR=145) ---
MAKE_KEY_16 $3C,$66,$38,$06,$66,$3C
; --- T (BL=146, BR=147) ---
MAKE_KEY_16 $7E,$18,$18,$18,$18,$18
; --- U (BL=148, BR=149) ---
MAKE_KEY_16 $66,$66,$66,$66,$66,$3C
; --- V (BL=150, BR=151) ---
MAKE_KEY_16 $66,$66,$66,$66,$3C,$18
; --- W (BL=152, BR=153) ---
MAKE_KEY_16 $66,$66,$66,$5A,$7E,$66
; --- X (BL=154, BR=155) ---
MAKE_KEY_16 $66,$3C,$18,$18,$3C,$66
; --- Y (BL=156, BR=157) ---
MAKE_KEY_16 $66,$66,$3C,$18,$18,$18
; --- Z (BL=158, BR=159) ---
MAKE_KEY_16 $7E,$06,$0C,$18,$30,$7E

; ====================== Digits 0-9 BL/BR Pairs (tiles 160-179) ======================

; --- 0 (BL=160, BR=161) ---
MAKE_KEY_16 $3C,$66,$6E,$76,$66,$3C
; --- 1 (BL=162, BR=163) ---
MAKE_KEY_16 $18,$38,$18,$18,$18,$7E
; --- 2 (BL=164, BR=165) ---
MAKE_KEY_16 $3C,$66,$06,$1C,$30,$7E
; --- 3 (BL=166, BR=167) ---
MAKE_KEY_16 $3C,$66,$0C,$06,$66,$3C
; --- 4 (BL=168, BR=169) ---
MAKE_KEY_16 $0C,$1C,$3C,$6C,$7E,$0C
; --- 5 (BL=170, BR=171) ---
MAKE_KEY_16 $7E,$60,$7C,$06,$66,$3C
; --- 6 (BL=172, BR=173) ---
MAKE_KEY_16 $3C,$60,$7C,$66,$66,$3C
; --- 7 (BL=174, BR=175) ---
MAKE_KEY_16 $7E,$06,$0C,$18,$18,$18
; --- 8 (BL=176, BR=177) ---
MAKE_KEY_16 $3C,$66,$3C,$66,$66,$3C
; --- 9 (BL=178, BR=179) ---
MAKE_KEY_16 $3C,$66,$3E,$06,$06,$3C

; =========== Shifted Digit Symbols !@#$%^&*() BL/BR Pairs (tiles 180-199) ===========

; --- ! (BL=180, BR=181) ---
MAKE_KEY_16 $18,$18,$18,$18,$00,$18
; --- @ (BL=182, BR=183) ---
MAKE_KEY_16 $3C,$66,$6E,$6E,$60,$3C
; --- # (BL=184, BR=185) ---
MAKE_KEY_16 $24,$7E,$24,$7E,$24,$00
; --- $ (BL=186, BR=187) ---
MAKE_KEY_16 $18,$3E,$60,$3C,$06,$7C
; --- % (BL=188, BR=189) ---
MAKE_KEY_16 $66,$0C,$18,$18,$30,$66
; --- ^ (BL=190, BR=191) ---
MAKE_KEY_16 $18,$3C,$66,$00,$00,$00
; --- & (BL=192, BR=193) ---
MAKE_KEY_16 $38,$6C,$38,$6E,$66,$3C
; --- * (BL=194, BR=195) ---
MAKE_KEY_16 $00,$24,$18,$7E,$18,$24
; --- ( (BL=196, BR=197) ---
MAKE_KEY_16 $0C,$18,$30,$30,$18,$0C
; --- ) (BL=198, BR=199) ---
MAKE_KEY_16 $30,$18,$0C,$0C,$18,$30

; ====================== Special Keys BL/BR Pairs (tiles 200-207) ======================

; --- ← backspace (BL=200, BR=201) ---
MAKE_KEY_16 $00,$10,$30,$7E,$30,$10
; --- ↵ enter (BL=202, BR=203) ---
MAKE_KEY_16 $00,$04,$04,$24,$3C,$20
; --- ↑ shift (BL=204, BR=205) ---
MAKE_KEY_16 $18,$3C,$7E,$18,$18,$18
; --- X delete (BL=206, BR=207) ---
MAKE_KEY_16 $00,$66,$3C,$18,$3C,$66

; ====================== Punctuation BL/BR Pairs (tiles 208-225) ======================

; --- / (BL=208, BR=209) ---
MAKE_KEY_16 $06,$0C,$18,$30,$60,$00
; --- , (BL=210, BR=211) ---
MAKE_KEY_16 $00,$00,$00,$18,$18,$30
; --- . (BL=212, BR=213) ---
MAKE_KEY_16 $00,$00,$00,$00,$18,$18
; --- < (BL=214, BR=215) ---
MAKE_KEY_16 $0C,$18,$30,$60,$30,$18
; --- > (BL=216, BR=217) ---
MAKE_KEY_16 $30,$18,$0C,$06,$0C,$18
; --- ? (BL=218, BR=219) ---
MAKE_KEY_16 $3C,$66,$06,$1C,$00,$18
; --- - (BL=220, BR=221) ---
MAKE_KEY_16 $00,$00,$00,$7E,$00,$00
; --- _ (BL=222, BR=223) ---
MAKE_KEY_16 $00,$00,$00,$00,$00,$7E
; --- + (BL=224, BR=225) ---
MAKE_KEY_16 $00,$18,$18,$7E,$18,$18

kbd_tiles_end:


; ============================================================================
; Keyboard Palette Data — 4 sub-palettes for BG3 (32 bytes to CGRAM 0-15)
;
; Color 0 = transparent (gaps between keys)
; Color 1 = key face (varies per palette state)
; Color 2 = shadow strip (gray, varies per palette)
; Color 3 = character text (black, constant across all palettes)
;
; CRITICAL: Sub-palette 0, color 1 MUST be white ($7FFF) to preserve
; BG1 4bpp font compatibility (font tiles use bp0 = color 1 for text).
; ============================================================================

kbd_palette:
; Sub-palette 0: normal key (CGRAM 0-3)
.dw $0000    ; 0: transparent
.dw $7FFF    ; 1: white (key face) — matches BG1 font color!
.dw $294A    ; 2: gray (shadow strip)
.dw $0000    ; 3: black (character text)

; Sub-palette 1: hover/highlighted key (CGRAM 4-7)
.dw $0000    ; 4: transparent
.dw $03FF    ; 5: yellow (hover face)
.dw $01AD    ; 6: dark yellow (hover shadow)
.dw $0000    ; 7: black (text)

; Sub-palette 2: shift-active key (CGRAM 8-11)
.dw $0000    ; 8: transparent
.dw $7A90    ; 9: light blue (shift face)
.dw $3548    ; 10: darker blue (shift shadow)
.dw $0000    ; 11: black (text)

; Sub-palette 3: spacebar (CGRAM 12-15) — same as normal, changed by hover
.dw $0000    ; 12: transparent
.dw $7FFF    ; 13: white (spacebar face)
.dw $294A    ; 14: gray (spacebar shadow)
.dw $0000    ; 15: black (text)

; Sub-palette 4: text label — white on transparent (CGRAM 16-19)
.dw $0000    ; 16: transparent
.dw $0000    ; 17: transparent (hides key background)
.dw $0000    ; 18: transparent (hides shadow)
.dw $7FFF    ; 19: white (text color)

; Sub-palette 5: text label highlighted — yellow on transparent (CGRAM 20-23)
.dw $0000    ; 20: transparent
.dw $0000    ; 21: transparent (hides key background)
.dw $0000    ; 22: transparent (hides shadow)
.dw $03FF    ; 23: yellow (highlighted text)
kbd_palette_end:


; ============================================================================
; Keyboard Tile Layout Tables — display tiles per key position
; 4 rows × 16 columns = 64 entries per layer
; Rows 0-2: letter/symbol keys. Row 3: spacebar (same for both layers).
; Two layers: lowercase (shift off) and uppercase (shift on)
; ============================================================================

; Unshifted layer — BL tile indices (16x16 keys always show uppercase letters)
; SHIFT only changes digit/symbol keys
kbd_tile_lo_row0:
;     Q    W    E    R    T    Y    U    I    O    P    ←    1    2    3    4    5
.db 140, 152, 116, 142, 146, 156, 148, 124, 136, 138, 200, 162, 164, 166, 168, 170

kbd_tile_lo_row1:
;     A    S    D    F    G    H    J    K    L    /    ↵    6    7    8    9    0
.db 108, 144, 114, 118, 120, 122, 126, 128, 130, 208, 202, 172, 174, 176, 178, 160

kbd_tile_lo_row2:
;     ↑    Z    X    C    V    B    N    M    ,    .    ←    /    -    _    ↵    X
.db 204, 158, 154, 112, 150, 110, 134, 132, 210, 212, 200, 208, 220, 222, 202, 206

; Row 3: spacebar (not used for tilemap building, kept for table alignment)
kbd_tile_lo_row3:
.db   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0

; Shifted layer — BL tile indices (uppercase letters same, digits→symbols change)
kbd_tile_hi_row0:
;     Q    W    E    R    T    Y    U    I    O    P    ←    !    @    #    $    %
.db 140, 152, 116, 142, 146, 156, 148, 124, 136, 138, 200, 180, 182, 184, 186, 188

kbd_tile_hi_row1:
;     A    S    D    F    G    H    J    K    L    ?    ↵    ^    &    *    (    )
.db 108, 144, 114, 118, 120, 122, 126, 128, 130, 218, 202, 190, 192, 194, 196, 198

kbd_tile_hi_row2:
;     ↑    Z    X    C    V    B    N    M    <    >    ←    ?    +    _    ↵    X
.db 204, 158, 154, 112, 150, 110, 134, 132, 214, 216, 200, 218, 224, 222, 202, 206

; Row 3: spacebar (same as unshifted)
kbd_tile_hi_row3:
.db   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,   0


; ============================================================================
; Keyboard Character Map — ASCII codes output when a key is pressed
; 4 rows × 16 columns = 64 entries per layer
; Special codes: $01=SHIFT toggle, $08=backspace, $0A=enter, $7F=delete
; Row 3 = spacebar ($20=space, $00=no action on blank positions)
; ============================================================================

; Lowercase / unshifted character output
kbd_char_lo_row0:
.db 'q','w','e','r','t','y','u','i','o','p', $08, '1','2','3','4','5'

kbd_char_lo_row1:
.db 'a','s','d','f','g','h','j','k','l','/', $0A, '6','7','8','9','0'

kbd_char_lo_row2:
.db $01, 'z','x','c','v','b','n','m',',','.', $08, '/','_','-', $0A, $7F

kbd_char_lo_row3:
.db $00, $00, $00, ' ',' ',' ',' ',' ',' ',' ',' ',' ',' ', $00, $00, $00

; Uppercase / shifted character output
kbd_char_hi_row0:
.db 'Q','W','E','R','T','Y','U','I','O','P', $08, '!','@','#','$','%'

kbd_char_hi_row1:
.db 'A','S','D','F','G','H','J','K','L','?', $0A, '^','&','*','(',')'

kbd_char_hi_row2:
.db $01, 'Z','X','C','V','B','N','M','<','>', $08, '?','+','_', $0A, $7F

kbd_char_hi_row3:
.db $00, $00, $00, ' ',' ',' ',' ',' ',' ',' ',' ',' ',' ', $00, $00, $00
