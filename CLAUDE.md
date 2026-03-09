# Super Office App

SNES productivity ROM: a text editor and spreadsheet with mouse-only input (no joypad). Think Mario Paint meets Notepad. Built entirely in 65816 assembly for WLA-DX.

## Build

```
make          # produces super-office-app.smc
make clean    # removes .o and .smc
```

Toolchain: `wla-65816` (assembler) + `wlalink` (linker). Source entry point is `src/main.s` which `.INCLUDE`s everything in dependency order.

## ROM Configuration

- **Layout:** LoROM, SlowROM, 1 MB (32 banks x 32 KB), 32 KB battery-backed SRAM
- **Entry:** `init_reset` (emulation vector in `hdr.asm`) → native 65816 mode → `main_loop`
- **Stack:** $1FFF, Direct Page at $0000

## Source File Map

| File | Purpose |
|---|---|
| `src/main.s` | Master include, memory map, bank directives |
| `src/hdr.asm` | ROM header, native/emulation interrupt vectors |
| `src/snes.asm` | All hardware register defines ($2100-$421F) |
| `src/constants.asm` | VRAM layout, shadow addresses, game variables (DP $61-$B7) |
| `src/utils.asm` | clear_wram, clear_vram, clear_cgram, clear_oam, wait_vblank |
| `src/init.asm` | Boot sequence, PPU config, DMA graphics upload, SRAM/audio init |
| `src/nmi.asm` | VBlank handler: OAM DMA, VRAM/CGRAM write queue, shadow flush |
| `src/input.asm` | Mouse serial bit-bang (manual latch+clock, no auto-joypad) |
| `src/cursor.asm` | OAM entry 0 management for mouse cursor sprite |
| `src/states.asm` | Main loop + state dispatch jump table (8 states) |
| `src/title.asm` | Title screen init, menu logic, HDMA sky gradient, fade |
| `src/keyboard.asm` | On-screen keyboard: BG3 overlay, 16x16 keys, hover, SHIFT, char output |
| `src/menu.asm` | Type selection submenu + SRAM-backed file browser |
| `src/textdoc.asm` | Text editor: buffer ops, insert/backspace/delete, scroll, cursor blink |
| `src/spreadsheet.asm` | Spreadsheet editor: cell grid, edit, navigation, cursor blink |
| `src/save.asm` | SRAM save/load, file menu overlay, dirty-check dialogs |
| `src/audio.asm` | 65816 audio API: IPL upload, play_music, stop_music, play_sfx, set_volume |
| `src/dma.asm` | Deferred DMA queue (stub) |
| `gfx/cursor.asm` | 16x16 arrow cursor sprite tiles (4bpp) + palette |
| `gfx/title.asm` | Title screen font, scene tiles, icon sprites, palettes, HDMA table, tilemaps |
| `gfx/keyboard.asm` | 2bpp keyboard font (A-Z, 0-9, symbols), palette, key layout/char map tables |
| `gfx/textfont.asm` | 4bpp monospace font (MAKE_4BPP_TILE macro), ASCII-to-tile table, palettes |
| `gfx/asciitable.asm` | ASCII-to-tile lookup table (must stay in bank 0) |
| `spc/driver.asm` | SPC700 audio driver (hand-assembled .db binary, ~1.3 KB) |
| `spc/samples.asm` | BRR sample directory + 6 waveforms (~200 bytes) |
| `spc/sfx.asm` | 5 SFX definitions (chirp, click, chime, buzz, thud) |
| `spc/songs.asm` | 2 songs: "Office Hours" (title) + "Desk Work" (editors) |
| `tools/img2snes.py` | PNG to SNES 4bpp tile/palette/tilemap converter |
| `tools/quantize_snes.py` | Image quantization for SNES palette constraints |

## Architecture

### State Machine

The main loop in `states.asm` runs: `wait_vblank` → state handler (via jump table) → `cursor_update` → loop.

```
STATE_BOOT (0)     → Initialize everything, jump to title
STATE_TITLE (1)    → Title screen with menu: "CREATE NEW" / "OPEN FILE"
STATE_TYPE_SEL (2) → Submenu: "TEXT DOCUMENT" / "SPREADSHEET"
STATE_FILE_BRW (3) → File browser listing SRAM slots
STATE_TEXTDOC (4)  → Text document editor
STATE_SHEET (5)    → Spreadsheet editor
STATE_FMENU (6)    → File menu overlay (runs on top of active editor)
STATE_OPTIONS (7)  → Options/settings screen
```

State transitions always use fade in/out (`fade_dir`/`fade_level` → INIDISP brightness 0-15).

### PPU & Shadow Registers

All PPU register writes go to WRAM shadow copies at DP $50-$60, then flush to hardware during NMI VBlank. This prevents mid-frame glitches. See `nmi.asm` lines 122-153 for the flush sequence.

### NMI Handler Execution Order

1. OAM DMA (544-byte shadow buffer → OAM, most time-critical)
2. VRAM/CGRAM write queue (up to 10 entries for cursor blink, hover highlight)
3. Shadow PPU register flush (INIDISP, BGMODE, TM, scroll, etc.)
4. Set `vblank_done` flag + increment `frame_count`

The write queue uses a special marker: `addr_hi=$FF` signals a CGRAM write instead of VRAM.

### VRAM Layout (Word Addresses)

```
$0000-$1FFF  BG1 chr (4bpp font for editors)
$2000-$3FFF  BG2 chr (title screen scene/buildings)
$4000-$5FFF  BG3 chr (2bpp keyboard tiles)
$6000-$7FFF  OBJ chr (sprites: cursor, icons)
$7000        BG1 tilemap (32x32)
$7400        BG2 tilemap
$7800        BG3 tilemap
```

OBJSEL base is $6000 (bbb field = 3). Valid OBJSEL bases are multiples of $2000 only.

### WRAM Layout

```
$0000-$004F  Direct page scratch / temporaries
$0050-$0060  PPU shadow registers
$0061-$00B7  Game variables (allocated per-phase, tightly packed)
$00B8-$00E6  VRAM write queue + misc variables
$0100-$017F  SRAM directory cache (128 bytes)
$0200-$041F  OAM shadow buffer (544 bytes)
$0500-$0CFF  Document/cell buffer (2048 bytes, shared between editors)
$1FFF        Stack top
```

Document and spreadsheet share the same buffer at $0500 — they are mutually exclusive.

### Input System

Mouse-only, no joypad. Auto-joypad is disabled; input uses manual serial latch+clock via JOYSER0 ($4016). Sensitivity locked to "slow" via extra latch strobes.

Key variables:
- `click_new` / `click_held` — left button edge/held detection
- `rclick_new` / `rclick_held` — right button edge/held detection
- `cursor_x` / `cursor_y` — position (clamped 0-255, 0-223)

Left-click = select/confirm everywhere. Right-click = back/menu/cancel.

### On-Screen Keyboard

Rendered on BG3 with priority mode (BGMODE=$09 = Mode 1 + BG3 priority bit). 4 rows x 16 keys, each 16x16 pixels (2x2 tile grid). Hover highlight via palette swap. SHIFT key toggles case/symbols. Output goes to `kbd_char_out` variable, consumed by active editor each frame.

### SRAM Layout ($70:0000-$70:7FFF)

```
$0000-$000F  Header (magic "SOFA", version, file count)
$0010-$008F  Directory (8 slots x 16 bytes: flags, size, filename)
$0100-$7FFF  Data area (8 slots x $0F60 bytes each)
```

### Audio

Custom SPC700 driver uploaded via IPL protocol (3 blocks: driver→$0200, songs→$1000, samples→$2000). Fire-and-forget command protocol: port0=counter (must increment each command), port1=cmd, port2=param. 5 music voices + 1 dedicated SFX voice.

## Critical WLA-DX Rules

These will silently produce wrong code and cause runtime crashes if violated:

1. **Register width directives are mandatory.** Every `rep #$20`/`rep #$30` must be followed by `.ACCU 16` (and `.INDEX 16` if applicable). Every `sep #$20`/`sep #$30` must be followed by `.ACCU 8` (and `.INDEX 8`). Width tracking propagates through `.INCLUDE` files — the assembler inherits the last-set width, so every function entry point needs explicit directives.

2. **`stz` does not support long addressing.** You cannot write `stz $700000.l`. Always use `lda #$00` / `sta $700000.l,X` for SRAM zeroing.

3. **Branch distance limit.** Conditional branches (bne, beq, bcc, etc.) max out at 127 bytes forward / 128 bytes back. In large routines, use `jmp` trampolines.

4. **16x16 sprite tile layout.** A 16x16 sprite uses tiles N, N+1, N+16, N+17 (arranged in VRAM tile grid), NOT N, N+1, N+2, N+3.

5. **WRAM-to-WMDATA DMA does not work.** Both sides are the same physical RAM. Use a manual byte-copy loop instead.

## Coding Conventions

- **Variable access:** Always use `.w` addressing suffix for WRAM/DP variables (e.g., `lda current_state.w`) to avoid zero-page wrapping issues
- **Naming:** `snake_case` for variables and routines, `UPPER_CASE` for constants/defines
- **Comments:** Section headers use `; ====` separators
- **Module pattern:** Each module has an init routine (called on state entry, sets up PPU/VRAM) and an update routine (called each frame, handles input + rendering)
- **DMA uploads:** Set VMAIN once, then DMAP/BBAD/A1B, then per-transfer: VMADDL, A1T0L, DAS0L, trigger MDMAEN
- **Tilemap entries:** 16-bit little-endian: `VHOPPPcccccccccc` (V=vflip, H=hflip, O=priority, PPP=palette 0-7, c=tile index)
- **OAM high table updates:** Use mask+OR pattern to preserve other sprites' size/position bits when updating one sprite

## Image Conversion Tools

Two Python scripts in `tools/` handle the PNG-to-SNES pipeline. Both require Pillow (`PIL`).

### Workflow

For complex images (like the title screen), run quantization first, then conversion:

```bash
# Step 1: Pre-quantize to fit SNES palette constraints
python3 tools/quantize_snes.py input.png quantized.png [num_palettes]

# Step 2: Convert to SNES binary formats
python3 tools/img2snes.py quantized.png out.pal out.tiles out.map [num_palettes]
```

For simpler images that already have few colors, `img2snes.py` alone may suffice (it does its own per-tile quantization internally).

### quantize_snes.py

Pre-quantization step that ensures an image will fit SNES constraints before tile conversion. Two-pass approach:
1. **Global pass:** Median-cut quantize to `num_palettes * 15 + 1` total colors (reserving color 0 per sub-palette for transparency)
2. **Per-tile pass:** Any 8x8 tile still exceeding 16 colors gets individually re-quantized
3. All colors snapped to SNES 5-bit RGB space (3-bit truncation per channel)

Outputs a clean PNG ready for `img2snes.py`.

### img2snes.py

Full conversion pipeline from PNG to three binary files consumed by the assembler:

1. **Snap** all pixels to BGR555 color space
2. **Per-tile quantization** — reduce each 8x8 tile to max 16 colors (median cut, no dither)
3. **Palette assignment** — greedy bin-packing into 8 sub-palettes of 16 colors. Tries 23 orderings (most-constrained-first, spatial, least-constrained, + 20 random) and picks the one with fewest color remaps
4. **4bpp planar encoding** — bitplanes 0+1 interleaved (16 bytes), then 2+3 (16 bytes) = 32 bytes per tile
5. **Tile deduplication** — detects horizontal, vertical, and HV flip matches to reduce tile count
6. **Tilemap encoding** — 16-bit LE entries: `VHOPPPcccccccccc` with flip flags and palette index

**Output files:**

| Extension | Format | Size |
|---|---|---|
| `.pal` | 8 sub-palettes x 16 colors x 2 bytes BGR555 | 256 bytes |
| `.tiles` | N x 32 bytes (4bpp 8x8 tiles) | variable |
| `.map` | (W/8) x (H/8) x 2 bytes (tilemap entries) | variable |

### How Converted Assets Are Used

The converted binary files live in `gfx/converted/` and are included in the ROM via `.INCBIN` directives in `gfx/title.asm`:

```
.INCBIN "gfx/converted/title.pal"    → uploaded to CGRAM via DMA
.INCBIN "gfx/converted/title.tiles"  → uploaded to BG2 chr VRAM ($2000)
.INCBIN "gfx/converted/title.map"    → uploaded to BG2 tilemap VRAM ($7400)
```

Currently only the title screen background uses this pipeline. Other graphics (cursor, keyboard, text font) are hand-encoded as `.db` blocks directly in their `gfx/*.asm` files.

### Constraints to Keep in Mind

- Input images must be multiples of 8x8 pixels
- Max 8 sub-palettes, 16 colors each (SNES Mode 1 BG limit)
- Max 512 unique tiles per BG character region (the tool warns if exceeded)
- Color 0 in each sub-palette is typically transparency — the tool doesn't enforce this, so transparent areas in the source image should use a consistent color that lands in index 0
- The tool does NOT handle 2bpp conversion (keyboard tiles are hand-encoded)

## Common Pitfalls

- Forgetting `.ACCU`/`.INDEX` after width changes (the #1 source of crashes)
- VRAM writes outside VBlank without force blank (INIDISP bit 7) cause corruption
- Sprite palettes start at CGRAM index 128 (after 8 BG sub-palettes of 16 colors)
- The `gfx/asciitable.asm` file must stay in bank 0 (accessed with absolute addressing)
- The text font lives in bank 2 (`gfx/textfont.asm`) and is accessed only via DMA
- Document buffer at $0500 is shared between text editor and spreadsheet — never both active
- SPC700 command counter (`audio_cmd_ctr` at DP $E2) must be incremented for each command; the driver detects changes in counter value, not command byte alone
