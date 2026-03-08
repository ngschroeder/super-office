; ============================================================================
; hdr.asm — ROM Header, Interrupt Vectors
; LoROM, SlowROM, 8 Mbit (1 MB), 256 Kbit SRAM
; ============================================================================

.SNESHEADER
  NAME "SUPER OFFICE APP     "  ; 21 bytes, space-padded
  SLOWROM
  LOROM
  CARTRIDGETYPE $02              ; ROM + Save RAM (battery-backed)
  ROMSIZE $0A                    ; 8 Mbit (1 MB)
  SRAMSIZE $05                   ; 256 Kbit (32 KB)
  COUNTRY $01                    ; North America (NTSC)
  LICENSEECODE $00
  VERSION $00
.ENDSNES

; --- Native mode vectors (65816) ---
.SNESNATIVEVECTOR
  COP EmptyHandler
  BRK EmptyHandler
  ABORT EmptyHandler
  NMI nmi_handler
  IRQ EmptyHandler
  UNUSED $0000
.ENDNATIVEVECTOR

; --- Emulation mode vectors (6502 compat) ---
.SNESEMUVECTOR
  COP EmptyHandler
  ABORT EmptyHandler
  NMI EmptyHandler
  RESET init_reset
  IRQBRK EmptyHandler
  UNUSED $0000
.ENDEMUVECTOR
