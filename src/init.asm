; ============================================================================
; init.asm — Full SNES Boot / Initialization Sequence
; Reference: programming-patterns.md §1, Mario Paint bank0.asm
; ============================================================================

; ============================================================================
; init_reset — RESET vector entry point
; CPU starts in 6502 emulation mode. We switch to native 65816 mode,
; initialize all hardware, upload graphics, and enter the main loop.
; ============================================================================
init_reset:
    sei                          ; Disable interrupts
    clc
    xce                          ; Switch to 65816 native mode

    ; --- Set register widths ---
    rep #$30                     ; 16-bit A/X/Y (M=0, X=0)
    .ACCU 16
    .INDEX 16
    cld                          ; Clear decimal flag
    ldx #$1FFF
    txs                          ; Stack at top of 8 KB WRAM mirror
    lda #$0000
    tcd                          ; Direct page = $0000

    ; --- 8-bit mode for hardware register setup ---
    sep #$30                     ; 8-bit A/X/Y (M=1, X=1)
    .ACCU 8
    .INDEX 8

    ; --- Force blank: screen off, prevent garbage display ---
    lda #$8F
    sta INIDISP.w                ; Force blank ON, brightness = max (masked)

    ; --- Disable all interrupts and DMA ---
    stz NMITIMEN.w               ; Disable NMI, IRQ, auto-joypad
    stz HDMAEN.w                 ; Disable all HDMA channels
    stz MDMAEN.w                 ; Disable all DMA channels

    ; --- Clear PPU registers to known state ---
    stz OBJSEL.w                 ; Sprites: 8x8/16x16, char base $0000
    stz OAMADDL.w
    stz OAMADDH.w
    stz BGMODE.w                 ; Mode 0
    stz MOSAIC.w
    stz BG1SC.w
    stz BG2SC.w
    stz BG3SC.w
    stz BG4SC.w
    stz BG12NBA.w
    stz BG34NBA.w

    ; Zero all scroll registers (write twice each)
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
    stz BG4HOFS.w
    stz BG4HOFS.w
    stz BG4VOFS.w
    stz BG4VOFS.w

    ; VRAM increment: +1 word after writing high byte
    lda #$80
    sta VMAIN.w
    stz VMADDL.w
    stz VMADDH.w

    ; Mode 7 defaults
    stz M7SEL.w

    ; Window and color math defaults (all disabled)
    stz W12SEL.w
    stz W34SEL.w
    stz WOBJSEL.w
    stz WH0.w
    stz WH1.w
    stz WH2.w
    stz WH3.w
    stz WBGLOG.w
    stz WOBJLOG.w
    stz TM.w
    stz TS.w
    stz TMW.w
    stz TSW.w
    stz CGWSEL.w
    stz CGADSUB.w
    stz COLDATA.w
    stz SETINI.w

    ; --- Clear WRAM (inline — cannot JSR because the loop would zero the stack) ---
    rep #$30                     ; 16-bit A/X/Y
    .ACCU 16
    .INDEX 16
    lda #$0000
    ldx #$04FE                   ; Zero $0000-$04FF (DP vars + OAM buffer area)
@clear_wram:                     ; (skip $0500+ to preserve stack at $1FFF)
    sta $00.w,X
    dex
    dex
    bpl @clear_wram
    sep #$30                     ; 8-bit A/X/Y
    .ACCU 8
    .INDEX 8

    ; --- Clear VRAM, OAM, CGRAM ---
    jsr clear_vram               ; Zero all 64 KB VRAM
    jsr clear_cgram              ; Zero all 512 bytes CGRAM
    jsr clear_oam                ; Set all OAM sprites off-screen

    ; === Configure PPU for our app ===

    ; --- Mode 1: 3 BG layers ---
    lda #$01                     ; Mode 1, 8x8 tiles for all BGs
    sta BGMODE.w
    sta SHADOW_BGMODE.w

    ; --- OBJSEL: 8x8 and 16x16 sprites, char base at VRAM $6000 ---
    ; OBJSEL format: sssNNbbb
    ;   sss = size (000 = 8x8/16x16)
    ;   NN  = name select (gap between char tables)
    ;   bbb = character base address / $2000
    ;   $6000 / $2000 = 3, so bbb = 011 -> lower 3 bits = $03
    lda #$03                     ; 8x8/16x16, base at VRAM word $6000 (bbb=3)
    sta OBJSEL.w
    sta SHADOW_OBJSEL.w

    ; --- BG tilemap addresses ---
    ; BGnSC format: aaaaaass (aaaaaa = base>>10, ss = size)
    ; BG1SC: VRAM word $7000, $7000>>10 = $1C, $1C<<2 = $70
    lda #$70                     ; Tilemap at $7000, 32x32
    sta BG1SC.w
    sta SHADOW_BG1SC.w
    ; BG2SC: VRAM word $7400, $7400>>10 = $1D, $1D<<2 = $74
    lda #$74
    sta BG2SC.w
    sta SHADOW_BG2SC.w
    ; BG3SC: VRAM word $7800, $7800>>10 = $1E, $1E<<2 = $78
    lda #$78
    sta BG3SC.w
    sta SHADOW_BG3SC.w

    ; --- BG character base addresses ---
    ; BG12NBA: BG1 base = $0000>>12 = 0, BG2 base = $2000>>12 = 2
    ;   Format: BBBB bbbb (B=BG2, b=BG1)
    lda #$20                     ; BG1 at $0000, BG2 at $2000
    sta BG12NBA.w
    sta SHADOW_BG12NBA.w
    ; BG34NBA: BG3 base = $4000>>12 = 4, BG4 unused
    lda #$04                     ; BG3 at $4000
    sta BG34NBA.w
    sta SHADOW_BG34NBA.w

    ; --- Enable sprites + BG1 on main screen ---
    ; TM: bit 4 = OBJ, bit 0 = BG1
    lda #%00010001               ; OBJ + BG1
    sta TM.w
    sta SHADOW_TM.w

    ; --- Initialize DMA queue ---
    jsr dma_queue_init

    ; === Upload cursor sprite graphics to VRAM via DMA ===
    ; 16x16 sprite uses tiles 0, 1, 16, 17 in the VRAM tile grid.
    ; Upload top 2 tiles to VRAM $6000, bottom 2 to VRAM $6100.

    ; --- Common DMA channel 0 setup ---
    lda #$80
    sta VMAIN.w                  ; Increment after high byte write
    lda #$01                     ; DMA mode 1: A->B, two registers ($2118/$2119)
    sta DMAP0.w
    lda #$18                     ; B-bus: VMDATAL
    sta BBAD0.w
    lda #:cursor_tiles           ; Source bank
    sta A1B0.w

    ; --- Transfer 1: Top row tiles (0,1) -> VRAM $6000 ---
    rep #$20                     ; 16-bit A
    .ACCU 16
    lda #VRAM_OBJ_CHR
    sta VMADDL.w                 ; VRAM destination: $6000
    lda #cursor_tiles
    sta A1T0L.w
    lda #64                      ; 2 tiles x 32 bytes
    sta DAS0L.w
    sep #$20                     ; 8-bit A
    .ACCU 8
    lda #$01
    sta MDMAEN.w                 ; Trigger DMA channel 0

    ; --- Transfer 2: Bottom row tiles (16,17) -> VRAM $6100 ---
    rep #$20                     ; 16-bit A
    .ACCU 16
    lda #VRAM_OBJ_CHR + $0100   ; Tile 16 = base + 16*16 words
    sta VMADDL.w
    lda #cursor_tiles + 64       ; Source: skip first 2 tiles (64 bytes)
    sta A1T0L.w
    lda #64                      ; 2 tiles x 32 bytes
    sta DAS0L.w
    sep #$20                     ; 8-bit A
    .ACCU 8
    lda #$01
    sta MDMAEN.w                 ; Trigger DMA channel 0

    ; === Upload cursor palette to CGRAM ===
    ; Sprite palettes start at CGRAM word 128 (byte offset $100)
    ; Palette 0 for sprites = colors 128-143
    lda #$80                     ; CGADD = 128 (first sprite palette)
    sta CGADD.w

    lda #$00                     ; DMA mode 0: A->B, single register
    sta DMAP0.w
    lda #$22                     ; B-bus: CGDATA
    sta BBAD0.w
    rep #$20                     ; 16-bit A
    .ACCU 16
    lda #cursor_palette
    sta A1T0L.w
    sep #$20                     ; 8-bit A
    .ACCU 8
    lda #:cursor_palette
    sta A1B0.w
    rep #$20                     ; 16-bit A
    .ACCU 16
    lda #cursor_palette_end - cursor_palette  ; 32 bytes (16 colors x 2)
    sta DAS0L.w
    sep #$20                     ; 8-bit A
    .ACCU 8
    lda #$01
    sta MDMAEN.w

    ; === Upload a background color to CGRAM color 0 ===
    ; Dark blue: $2800 in BGR555 (R=0, G=0, B=10)
    stz CGADD.w                  ; Color 0 (backdrop)
    lda #$00                     ; Low byte of $2800
    sta CGDATA.w
    lda #$28                     ; High byte of $2800
    sta CGDATA.w

    ; === Initialize SRAM (check/format on first boot) ===
    jsr sram_init

    ; === Initialize audio engine (upload SPC700 driver + data) ===
    jsr audio_init

    ; === Initialize save system variables ===
    lda #$FF
    sta current_slot.w           ; No file loaded yet
    stz file_type.w
    stz fmenu_visible.w
    stz dialog_visible.w
    stz fb_initialized.w

    ; === Set initial cursor position (center of screen) ===
    rep #$20                     ; 16-bit A
    .ACCU 16
    lda #128
    sta cursor_x.w
    lda #112
    sta cursor_y.w
    sep #$20                     ; 8-bit A
    .ACCU 8

    ; === Initialize BG1 vertical scroll (default: -1 for PPU quirk) ===
    lda #$FE
    sta bg1_scroll_y.w

    ; === Initialize state machine ===
    lda #STATE_BOOT
    sta current_state.w

    ; === Initialize input ---
    stz click_new.w
    stz click_held.w
    stz rclick_new.w
    stz rclick_held.w
    stz mouse_buttons.w
    stz mouse_old_btns.w

    ; === Initialize shadow registers ===
    lda #$0F                     ; Full brightness, force blank OFF
    sta SHADOW_INIDISP.w

    lda #$80                     ; Enable NMI, auto-joypad OFF (manual reads)
    sta SHADOW_NMITIMEN.w

    ; === Enable NMI, unfade display ===
    lda #$80
    sta NMITIMEN.w               ; Enable NMI, auto-joypad OFF
    lda #$0F                     ; Full brightness, no force blank
    sta INIDISP.w

    ; === Fall through to main loop ===
    ; (interrupts are implicitly enabled once NMI is on;
    ;  CLI not needed since NMI is non-maskable)
    jmp main_loop
