; ============================================================================
; snes.asm — SNES Hardware Register Definitions
; Reference: Mario Paint snes.asm, fullsnes.txt
; ============================================================================

; --- PPU Registers ($2100-$213F) ---
.define INIDISP   $2100    ; Screen display: force blank + brightness
.define OBJSEL    $2101    ; Sprite size and character base address
.define OAMADDL   $2102    ; OAM address low
.define OAMADDH   $2103    ; OAM address high + priority rotation
.define OAMDATA   $2104    ; OAM data write
.define BGMODE    $2105    ; BG mode (0-7) and character size
.define MOSAIC    $2106    ; Mosaic effect size and enable
.define BG1SC     $2107    ; BG1 tilemap address and size
.define BG2SC     $2108    ; BG2 tilemap address and size
.define BG3SC     $2109    ; BG3 tilemap address and size
.define BG4SC     $210A    ; BG4 tilemap address and size
.define BG12NBA   $210B    ; BG1/BG2 character base address
.define BG34NBA   $210C    ; BG3/BG4 character base address
.define BG1HOFS   $210D    ; BG1 horizontal scroll (write twice)
.define BG1VOFS   $210E    ; BG1 vertical scroll (write twice)
.define BG2HOFS   $210F    ; BG2 horizontal scroll (write twice)
.define BG2VOFS   $2110    ; BG2 vertical scroll (write twice)
.define BG3HOFS   $2111    ; BG3 horizontal scroll (write twice)
.define BG3VOFS   $2112    ; BG3 vertical scroll (write twice)
.define BG4HOFS   $2113    ; BG4 horizontal scroll (write twice)
.define BG4VOFS   $2114    ; BG4 vertical scroll (write twice)
.define VMAIN     $2115    ; VRAM address increment mode
.define VMADDL    $2116    ; VRAM word address low
.define VMADDH    $2117    ; VRAM word address high
.define VMDATAL   $2118    ; VRAM data write low
.define VMDATAH   $2119    ; VRAM data write high
.define M7SEL     $211A    ; Mode 7 settings
.define M7A       $211B    ; Mode 7 matrix A (write twice)
.define M7B       $211C    ; Mode 7 matrix B (write twice)
.define M7C       $211D    ; Mode 7 matrix C (write twice)
.define M7D       $211E    ; Mode 7 matrix D (write twice)
.define M7X       $211F    ; Mode 7 center X (write twice)
.define M7Y       $2120    ; Mode 7 center Y (write twice)
.define CGADD     $2121    ; CGRAM palette address
.define CGDATA    $2122    ; CGRAM data write (write twice)
.define W12SEL    $2123    ; Window mask settings BG1/BG2
.define W34SEL    $2124    ; Window mask settings BG3/BG4
.define WOBJSEL   $2125    ; Window mask settings OBJ/color
.define WH0       $2126    ; Window 1 left position
.define WH1       $2127    ; Window 1 right position
.define WH2       $2128    ; Window 2 left position
.define WH3       $2129    ; Window 2 right position
.define WBGLOG    $212A    ; Window logic for BG layers
.define WOBJLOG   $212B    ; Window logic for OBJ/color
.define TM        $212C    ; Main screen layer enable
.define TS        $212D    ; Sub screen layer enable
.define TMW       $212E    ; Window mask for main screen
.define TSW       $212F    ; Window mask for sub screen
.define CGWSEL    $2130    ; Color math region settings
.define CGADSUB   $2131    ; Color math layer designation
.define COLDATA   $2132    ; Fixed color data
.define SETINI    $2133    ; Display mode (interlace, overscan)

; --- PPU Read Registers ---
.define MPYL      $2134    ; PPU multiply result low
.define MPYM      $2135    ; PPU multiply result mid
.define MPYH      $2136    ; PPU multiply result high
.define SLHV      $2137    ; Latch H/V counter
.define OAMDATAREAD $2138  ; OAM data read
.define VMDATALREAD $2139  ; VRAM data read low
.define VMDATAHREAD $213A  ; VRAM data read high
.define CGDATAREAD  $213B  ; CGRAM data read
.define OPHCT     $213C    ; H counter output
.define OPVCT     $213D    ; V counter output
.define STAT77    $213E    ; PPU1 status
.define STAT78    $213F    ; PPU2 status

; --- APU Communication ($2140-$2143) ---
.define APUIO0    $2140    ; APU I/O port 0
.define APUIO1    $2141    ; APU I/O port 1
.define APUIO2    $2142    ; APU I/O port 2
.define APUIO3    $2143    ; APU I/O port 3

; --- WRAM Port ($2180-$2183) ---
.define WMDATA    $2180    ; WRAM data read/write
.define WMADDL    $2181    ; WRAM address low
.define WMADDM    $2182    ; WRAM address mid
.define WMADDH    $2183    ; WRAM address high (bit 0 only)

; --- Joypad Serial Ports ---
.define JOYSER0   $4016    ; Joypad port 1 (write: latch; read: serial data)
.define JOYSER1   $4017    ; Joypad port 2 (read: serial data)

; --- CPU Registers ($4200-$421F) ---
.define NMITIMEN  $4200    ; NMI/IRQ enable, auto-joypad enable
.define WRIO      $4201    ; Programmable I/O port (output)
.define WRMPYA    $4202    ; Multiply factor A
.define WRMPYB    $4203    ; Multiply factor B (starts multiply)
.define WRDIVL    $4204    ; Dividend low
.define WRDIVH    $4205    ; Dividend high
.define WRDIVB    $4206    ; Divisor (starts division)
.define HTIMEL    $4207    ; H-counter target low
.define HTIMEH    $4208    ; H-counter target high
.define VTIMEL    $4209    ; V-counter target low
.define VTIMEH    $420A    ; V-counter target high
.define MDMAEN    $420B    ; General DMA channel enable
.define HDMAEN    $420C    ; HDMA channel enable
.define MEMSEL    $420D    ; FastROM enable

; --- CPU Read Registers ---
.define RDNMI     $4210    ; NMI flag (bit 7) + CPU version
.define TIMEUP    $4211    ; IRQ flag (bit 7)
.define HVBJOY    $4212    ; V-blank, H-blank, auto-joypad flags
.define RDIO      $4213    ; Programmable I/O readback

.define RDDIVL    $4214    ; Division quotient low
.define RDDIVH    $4215    ; Division quotient high
.define RDMPYL    $4216    ; Multiply product low / division remainder
.define RDMPYH    $4217    ; Multiply product high

; --- Auto-Joypad Read Results ---
.define JOY1L     $4218    ; Joypad 1 low byte (AXlr 0000)
.define JOY1H     $4219    ; Joypad 1 high byte (BYsS UDLR)
.define JOY2L     $421A    ; Joypad 2 low byte
.define JOY2H     $421B    ; Joypad 2 high byte
.define JOY3L     $421C    ; Joypad 3 low byte
.define JOY3H     $421D    ; Joypad 3 high byte
.define JOY4L     $421E    ; Joypad 4 low byte
.define JOY4H     $421F    ; Joypad 4 high byte

; --- DMA Channel 0 Registers ---
.define DMAP0     $4300    ; DMA control (direction, mode, increment)
.define BBAD0     $4301    ; Bus B address ($21xx target)
.define A1T0L     $4302    ; Source address low
.define A1T0H     $4303    ; Source address high
.define A1B0      $4304    ; Source bank
.define DAS0L     $4305    ; Byte count low (0 = 65536)
.define DAS0H     $4306    ; Byte count high

; --- DMA Channel 1 Registers ---
.define DMAP1     $4310
.define BBAD1     $4311
.define A1T1L     $4312
.define A1T1H     $4313
.define A1B1      $4314
.define DAS1L     $4315
.define DAS1H     $4316

; --- DMA Channel 2 Registers ---
.define DMAP2     $4320
.define BBAD2     $4321
.define A1T2L     $4322
.define A1T2H     $4323
.define A1B2      $4324
.define DAS2L     $4325
.define DAS2H     $4326

; --- DMA Channel 7 Registers (for HDMA later) ---
.define DMAP7     $4370
.define BBAD7     $4371
.define A1T7L     $4372
.define A1T7H     $4373
.define A1B7      $4374
.define DAS7L     $4375
.define DAS7H     $4376

; --- Joypad Button Masks (as read from JOY1H/JOY1L) ---
; JOY1H: BYsS UDLR
.define JOY_B       $80
.define JOY_Y       $40
.define JOY_SELECT  $20
.define JOY_START   $10
.define JOY_UP      $08
.define JOY_DOWN    $04
.define JOY_LEFT    $02
.define JOY_RIGHT   $01

; JOY1L: AXlr 0000
.define JOY_A       $80
.define JOY_X       $40
.define JOY_L       $20
.define JOY_R       $10
