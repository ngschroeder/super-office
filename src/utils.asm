; ============================================================================
; utils.asm — Shared Utility Routines
; ============================================================================

.BANK 0
.ORG $0000

; --- Empty interrupt handler (RTI stub for unused vectors) ---
EmptyHandler:
    rti

; ============================================================================
; wait_vblank — Spin until the NMI handler sets vblank_done, then clear it
; Assumes: 8-bit A
; ============================================================================
wait_vblank:
-   lda vblank_done.w
    beq -                        ; Spin until NMI sets this to non-zero
    stz vblank_done.w            ; Clear flag for next frame
    rts

; ============================================================================
; clear_wram_page — Zero-fill WRAM from $0000 to $1FFF (first 8 KB mirror)
; Uses a manual STZ loop (DMA from WRAM to WMDATA doesn't work on SNES
; because both endpoints are the same physical RAM).
; Must be called during init. Assumes: 8-bit A (sep #$20)
; ============================================================================
clear_wram_page:
    rep #$30                     ; 16-bit A and X/Y
    .ACCU 16
    .INDEX 16
    lda #$0000
    ldx #$1FFE
-   sta $00.w,X                  ; Zero two bytes at a time
    dex
    dex
    bpl -
    sep #$30                     ; 8-bit A and X/Y
    .ACCU 8
    .INDEX 8
    rts

; ============================================================================
; clear_vram — Zero all 64 KB of VRAM via DMA
; Must be called during forced blank
; ============================================================================
clear_vram:
    ; Set VRAM address to $0000, increment after high byte write
    lda #$80
    sta VMAIN.w
    stz VMADDL.w
    stz VMADDH.w

    ; DMA channel 1: fixed source (zero byte) -> VMDATAL/H
    stz $00                      ; Source byte = $00
    lda #$09                     ; A->B, fixed source, mode 1 (two regs)
    sta DMAP1.w
    lda #$18                     ; B-bus: VMDATAL ($2118, mode 1 also writes $2119)
    sta BBAD1.w
    stz A1T1L.w                  ; Source: $00:0000
    stz A1T1H.w
    stz A1B1.w
    stz DAS1L.w                  ; $0000 = 65536 bytes (fills all VRAM)
    stz DAS1H.w
    lda #$02                     ; Enable DMA channel 1
    sta MDMAEN.w
    rts

; ============================================================================
; clear_cgram — Zero all 512 bytes of CGRAM (256 colors = black)
; Must be called during forced blank
; ============================================================================
clear_cgram:
    stz CGADD.w                  ; Start at color 0
    stz $00                      ; Source byte = $00

    lda #$08                     ; A->B, fixed source, mode 0
    sta DMAP1.w
    lda #$22                     ; B-bus: CGDATA ($2122)
    sta BBAD1.w
    stz A1T1L.w
    stz A1T1H.w
    stz A1B1.w
    rep #$20                     ; 16-bit A
    .ACCU 16
    lda #$0200                   ; 512 bytes
    sta DAS1L.w
    sep #$20                     ; 8-bit A
    .ACCU 8
    lda #$02
    sta MDMAEN.w
    rts

; ============================================================================
; clear_oam — Set all 128 sprites off-screen (Y = $F0) in OAM shadow buffer
; Also clears the high table
; ============================================================================
clear_oam:
    rep #$30                     ; 16-bit A and X/Y
    .ACCU 16
    .INDEX 16
    ; Fill low table: set Y coord to $F0 (off-screen), X=0, tile=0, attr=0
    ; Each entry: [X lo] [Y] [tile] [attr] — 4 bytes per sprite
    ldx #$01FE
    lda #$F000                   ; Y=$F0, X=$00 for the word at sprite+0
-   sta OAM_BUF.w,X
    dex
    dex
    bpl -

    ; Zero the high table (size=small, X bit 8 = 0)
    ldx #$001E
    lda #$0000
-   sta OAM_BUF_HI.w,X
    dex
    dex
    bpl -

    sep #$30                     ; 8-bit A and X/Y
    .ACCU 8
    .INDEX 8
    rts
