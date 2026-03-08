; ============================================================================
; nmi.asm — NMI (VBlank) Handler
; Reference: programming-patterns.md §3, Mario Paint bank0.asm L0000D4
;
; Ordering: OAM DMA first (most time-critical), then shadow reg flush,
; then deferred DMA queue, then set vblank_done flag.
; ============================================================================

; ============================================================================
; nmi_handler — Called by hardware at start of VBlank
; ============================================================================
nmi_handler:
    rep #$30                     ; 16-bit A/X/Y for register pushes
    .ACCU 16
    .INDEX 16
    pha
    phx
    phy
    phd
    phb

    ; Set direct page to $0000, data bank to $00
    pea $0000
    pld                          ; DP = $0000
    lda #$0000
    sep #$20                     ; 8-bit A (M=1)
    .ACCU 8
    pha
    plb                          ; DB = $00

    ; --- Acknowledge NMI (read $4210 clears the NMI flag) ---
    lda RDNMI.w

    ; ===================================================================
    ; 1. OAM DMA — Upload 544-byte shadow buffer to OAM
    ;    Most time-critical: do this first
    ; ===================================================================
    stz OAMADDL.w                ; OAM address = 0
    stz OAMADDH.w

    lda #$00                     ; DMA mode 0: A->B, increment, single register
    sta DMAP0.w
    lda #$04                     ; B-bus: OAMDATA ($2104)
    sta BBAD0.w

    rep #$20                     ; 16-bit A
    .ACCU 16
    lda #OAM_BUF
    sta A1T0L.w                  ; Source: OAM shadow buffer
    sep #$20                     ; 8-bit A
    .ACCU 8
    stz A1B0.w                   ; Source bank: $00

    rep #$20                     ; 16-bit A
    .ACCU 16
    lda #OAM_BUF_SIZE            ; 544 bytes
    sta DAS0L.w
    sep #$20                     ; 8-bit A
    .ACCU 8

    lda #$01                     ; Trigger DMA channel 0
    sta MDMAEN.w

    ; ===================================================================
    ; 2. Process VRAM/CGRAM write queue (cursor blink, kbd highlight)
    ;    Up to 10 entries, each = addr (2) + data (2)
    ;    If addr_hi=$FF: CGRAM write (addr_lo=CGRAM addr, data=color)
    ;    Else: VRAM write (addr=VRAM addr, data=tile+attr)
    ; ===================================================================
    .INDEX 16                       ; X/Y are 16-bit from entry rep #$30
    lda vram_wq_count.w
    beq @no_vram_wq

    lda #$80
    sta VMAIN.w                  ; VRAM increment after high byte write
    ldx #$0000
@vram_wq_loop:
    lda vram_wq_data+1.w,X      ; addr_hi
    cmp #$FF
    beq @cgram_write

    ; --- VRAM write ---
    rep #$20
    .ACCU 16
    lda vram_wq_data.w,X        ; VRAM address (16-bit)
    sta VMADDL.w
    sep #$20
    .ACCU 8
    lda vram_wq_data+2.w,X      ; Tile index
    sta VMDATAL.w
    lda vram_wq_data+3.w,X      ; Attribute byte
    sta VMDATAH.w
    bra @wq_next

@cgram_write:
    ; --- CGRAM write (addr_hi=$FF marker) ---
    lda vram_wq_data.w,X        ; CGRAM byte address
    sta CGADD.w
    lda vram_wq_data+2.w,X      ; Color low byte
    sta CGDATA.w
    lda vram_wq_data+3.w,X      ; Color high byte
    sta CGDATA.w

@wq_next:
    inx
    inx
    inx
    inx
    dec vram_wq_count.w
    bne @vram_wq_loop
    stz vram_wq_count.w          ; Ensure count is exactly 0
@no_vram_wq:

    ; ===================================================================
    ; 2b. Flush deferred DMA queue (no-op in Phase 1)
    ; ===================================================================
    jsr dma_queue_flush

    ; ===================================================================
    ; 3. Flush shadow PPU registers to hardware
    ; ===================================================================
    lda SHADOW_INIDISP.w
    sta INIDISP.w

    lda SHADOW_OBJSEL.w
    sta OBJSEL.w

    lda SHADOW_BGMODE.w
    sta BGMODE.w

    lda SHADOW_BG1SC.w
    sta BG1SC.w
    lda SHADOW_BG2SC.w
    sta BG2SC.w
    lda SHADOW_BG3SC.w
    sta BG3SC.w

    lda SHADOW_BG12NBA.w
    sta BG12NBA.w
    lda SHADOW_BG34NBA.w
    sta BG34NBA.w

    lda SHADOW_TM.w
    sta TM.w

    lda SHADOW_CGWSEL.w
    sta CGWSEL.w
    lda SHADOW_CGADSUB.w
    sta CGADSUB.w

    ; --- Flush HDMA enable ---
    lda SHADOW_HDMAEN.w
    sta HDMAEN.w

    ; ===================================================================
    ; 4. Update scroll registers (all zero for Phase 1)
    ;    These are write-twice registers: low byte then high byte
    ; ===================================================================
    stz BG1HOFS.w
    stz BG1HOFS.w
    stz BG1VOFS.w
    stz BG1VOFS.w
    stz BG2HOFS.w
    stz BG2HOFS.w
    stz BG2VOFS.w
    stz BG2VOFS.w
    stz BG3HOFS.w
    stz BG3HOFS.w
    stz BG3VOFS.w
    stz BG3VOFS.w

    ; ===================================================================
    ; 5. Set vblank_done flag for main loop synchronization
    ; ===================================================================
    lda #$01
    sta vblank_done.w

    ; --- Increment frame counter ---
    inc frame_count.w

    ; --- Restore registers and return ---
    rep #$30                     ; 16-bit for pulls
    .ACCU 16
    .INDEX 16
    plb
    pld
    ply
    plx
    pla
    rti
