; ============================================================================
; Super Office App — Master Include File
; Assembler: WLA-DX (wla-65816)
; ROM layout: LoROM, SlowROM, 1 MB (32 banks x 32 KB)
; ============================================================================

.MEMORYMAP
  SLOTSIZE $8000
  DEFAULTSLOT 0
  SLOT 0 $8000              ; LoROM: code/data mapped at $8000-$FFFF
.ENDME

.ROMBANKSIZE $8000           ; 32 KB per bank
.ROMBANKS 32                 ; 32 banks = 1 MB

.EMPTYFILL $FF               ; Fill unused ROM space with $FF

; --- Include order matters: definitions first, then code, then data ---

.INCLUDE "hdr.asm"           ; ROM header, memory map, interrupt vectors
.INCLUDE "snes.asm"          ; Hardware register definitions
.INCLUDE "constants.asm"     ; App-wide constants and equates
.INCLUDE "utils.asm"         ; Shared utility routines
.INCLUDE "dma.asm"           ; Deferred DMA queue (stub for Phase 1)
.INCLUDE "init.asm"          ; Boot / initialization sequence
.INCLUDE "nmi.asm"           ; NMI (VBlank) handler
.INCLUDE "input.asm"         ; Mouse protocol + joypad fallback
.INCLUDE "cursor.asm"        ; Cursor sprite OAM management
.INCLUDE "title.asm"         ; Title screen logic
.INCLUDE "keyboard.asm"      ; On-screen keyboard overlay (BG3)
.INCLUDE "menu.asm"          ; Type selection + file browser
.INCLUDE "textdoc.asm"       ; Text document editor (Phase 4)
.INCLUDE "spreadsheet.asm"   ; Spreadsheet editor (Phase 5)
.INCLUDE "save.asm"          ; SRAM save/load system (Phase 6)
.INCLUDE "audio.asm"         ; Audio engine API (Phase 7)
.INCLUDE "states.asm"        ; Top-level state machine dispatch

; --- Graphics data ---
.INCLUDE "gfx/cursor.asm"   ; Cursor sprite tiles and palette
.INCLUDE "gfx/title.asm"    ; Title screen tiles, tilemaps, palettes
.INCLUDE "gfx/keyboard.asm" ; Keyboard font tiles and palette
.INCLUDE "gfx/asciitable.asm" ; ASCII-to-tile lookup (must stay in bank 0)

; --- Audio data ---
.INCLUDE "spc/driver.asm"   ; SPC700 driver binary blob
.INCLUDE "spc/samples.asm"  ; BRR waveform data + sample directory
.INCLUDE "spc/sfx.asm"      ; Sound effect definitions
.INCLUDE "spc/songs.asm"    ; Music sequence data

; --- Bank 2: Large tile data (accessed only via DMA) ---
; Bank 1 is already used by gfx/title.asm (title_img_tiles + title_img_map)
.BANK 2 SLOT 0
.ORG $0000
.INCLUDE "gfx/textfont.asm" ; Text editor 4bpp font tiles + palettes
