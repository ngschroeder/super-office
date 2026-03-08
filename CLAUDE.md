# Super Office App — Developer Guide

## Project Overview

SNES productivity ROM (text editor + spreadsheet) with mouse/joypad input.
Phases 1 (skeleton & input), 2 (title screen), 3 (menu system & on-screen keyboard), 4 (text document editor), 5 (spreadsheet editor), and 6 (save/load system) are complete.

## Build System

- **Assembler:** WLA-DX (`wla-65816` + `wlalink`) — NOT ca65 or asar
- **Build:** `make` produces `super-office-app.smc`
- **ROM:** LoROM, SlowROM, 1 MB (32 banks x 32 KB), 32 KB SRAM
- **Linker config:** `linkfile` (single object file)
- **Include order matters:** `src/main.s` is the master include file; definitions first, then code, then graphics data

## WLA-DX Critical Rules

These cause silent bugs if violated:

1. **`.ACCU 8/16` and `.INDEX 8/16` MUST follow every `rep`/`sep` instruction.** WLA-DX tracks register widths for immediate operand encoding. Missing directives cause wrong-size immediates (2 bytes encoded as 1 or vice versa), corrupting all subsequent code.

2. **Width tracking propagates across `.INCLUDE` boundaries.** If file A ends in 16-bit mode and file B is included next, file B inherits 16-bit mode. Every function entry point needs explicit `.ACCU`/`.INDEX` directives documenting the expected width.

3. **Use `.w` addressing for all WRAM variables and hardware registers** accessed with absolute addressing (e.g., `lda cursor_x.w`, `sta INIDISP.w`). Without `.w`, WLA-DX may emit direct-page addressing, which is correct for DP-range addresses but the explicit `.w` ensures 16-bit absolute addressing for clarity and safety.

4. **Anonymous labels use `+` / `-`** (not `@` which is local labels). Both are scoped differently — `@labels` are local to the enclosing named label, anonymous labels reference the nearest `+`/`-` in the given direction.

## Memory Map

### CPU Address Space
- **Stack:** `$1FFF` (top of 8 KB WRAM mirror)
- **Direct Page:** `$0000`
- **Data Bank:** `$00` (set in NMI handler and init)
- **SRAM:** `$70:0000-$70:7FFF` (32 KB, battery-backed)

### WRAM Layout
| Range | Purpose |
|-------|---------|
| `$0000-$004F` | Reserved / scratch |
| `$0050-$0060` | PPU shadow registers |
| `$0061-$00B7` | Game variables (direct page) |
| `$0100-$017F` | SRAM directory cache (128 bytes) |
| `$0200-$03FF` | OAM shadow buffer (low table, 512 bytes) |
| `$0400-$041F` | OAM shadow buffer (high table, 32 bytes) |
| `$0500-$0CFF` | Document text buffer (2048 bytes, Phase 4) |
| `$1FFF` | Stack top |

### VRAM Layout (word addresses)
| Address | Content |
|---------|---------|
| `$0000` | BG1 character data (font/text tiles, 4bpp) |
| `$2000` | BG2 character data (scene/UI tiles, 4bpp) |
| `$4000` | BG3 character data (keyboard/overlay, 2bpp) |
| `$6000` | Sprite character data (cursor, icons) |
| `$7000` | BG1 tilemap (32x32) |
| `$7400` | BG2 tilemap (32x32) |
| `$7800` | BG3 tilemap (32x32) |

**OBJSEL note:** Sprite char base must be a multiple of `$2000` (bbb field). Current base is `$6000` (bbb=3, OBJSEL=`$03`).

### PPU Shadow Registers (DP `$50-$60`)
Modified during gameplay, flushed to hardware by the NMI handler every VBlank. Defined in `constants.asm`. Key shadows:
- `SHADOW_INIDISP` (`$50`) — brightness/force blank
- `SHADOW_TM` (`$5A`) — main screen layer enable
- `SHADOW_HDMAEN` (`$60`) — HDMA channel enable

### Game Variables (DP `$61-$95`)
All defined in `constants.asm`. Key variables:
- `cursor_x/y` — 16-bit cursor position
- `current_state` — state machine index
- `mouse_dx/dy/buttons` — mouse displacement and buttons
- `click_new/click_held` — left mouse button (edge-detected / held)
- `rclick_new/rclick_held` — right mouse button (edge-detected / held)
- `fade_dir/fade_level` — screen fade state machine
- `title_menu_sel/title_prev_sel` — title screen menu hover state
- `kbd_visible/cursor_col/row/shift/sym/char_out/dirty` — keyboard state
- `doc_cursor_pos` (16-bit) — offset into document buffer
- `doc_length` (16-bit) — document byte count
- `doc_scroll_y` — first visible line number
- `doc_cursor_col/row` — cursor position in document grid
- `doc_dirty` — re-render flag
- `doc_blink_timer/on` — cursor blink state
- `sheet_cursor_col/row` — spreadsheet active cell position
- `sheet_scroll_y` — first visible spreadsheet row
- `sheet_dirty` — spreadsheet re-render flag
- `sheet_initialized` — spreadsheet init flag
- `sheet_edit_len` — chars in active cell (0-8)
- `sheet_blink_timer/on` — spreadsheet cursor blink state
- `current_slot` — SRAM save slot index ($FF = unsaved)
- `file_type` — current file type (0=text, 1=spreadsheet)
- `fmenu_visible/sel` — file menu overlay state
- `dialog_visible/sel/type` — save dialog state (0=dirty prompt, 1=filename entry)
- `save_name_buf` (12 bytes) — filename entry buffer
- `fb_sel/initialized/confirm_del` — file browser state

## Architecture & Patterns

### State Machine
States are dispatched via a jump table in `states.asm`. The main loop calls `wait_vblank`, dispatches the current state handler, then calls `cursor_update`. To add a new state:
1. Add a `.define STATE_NAME <index>` in `constants.asm`
2. Add a `.dw state_handler` entry to `_state_table` in `states.asm`
3. Create the state handler (returns via `rts`)

Current states: `STATE_BOOT` (0) → `STATE_TITLE` (1) → `STATE_TYPE_SEL` (2) or `STATE_FILE_BRW` (3) → `STATE_TEXTDOC` (4) or `STATE_SHEET` (5). `STATE_FMENU` (6) is the file menu overlay triggered by right-click in editors.

### NMI Handler (`nmi.asm`)
Execution order during VBlank:
1. OAM DMA (shadow buffer → OAM, most time-critical)
2. Deferred DMA queue flush (stub, future use)
3. Shadow PPU register flush to hardware
4. Scroll register writes (write-twice registers)
5. Set `vblank_done` flag + increment `frame_count`

The handler saves/restores all registers, sets DP=`$0000` and DB=`$00`.

### Input System (`input.asm`)
- **Mouse-only input.** No joypad fallback. SNES Mouse required.
- **Auto-joypad is DISABLED.** All reads use manual latch+serial bit-bang via `JOYSER0` (`$4016`).
- Latch strobe captures controller state, then 16 serial reads get bytes 1-2 (buttons/signature).
- 16 additional serial reads get bytes 3-4 (Y/X displacement, signed-magnitude → two's complement conversion).
- Mouse sensitivity locked to "slow" via extra latch strobes after reading.
- **Left button:** `click_new` (edge-detected), `click_held` — selects, confirms, clicks UI elements.
- **Right button:** `rclick_new` (edge-detected), `rclick_held` — goes back, opens file menu, cancels dialogs.
- Cursor position: `cursor_x`, `cursor_y` (16-bit, clamped to screen bounds).

### OAM Management
- 544-byte shadow buffer at WRAM `$0200-$041F`, DMA'd to OAM every VBlank.
- Entry 0: cursor sprite (16x16, managed by `cursor_update` every frame).
- Entries 1-4: title screen desk icons (16x16, set up by `_title_setup_icons`).
- Entry 5: menu selection arrow (8x8, managed by `_title_update_menu_arrow`).
- `cursor_update` preserves high table bits for entries 1-3 using mask+OR on `OAM_BUF_HI`.

### On-Screen Keyboard (`src/keyboard.asm`, `gfx/keyboard.asm`)

The on-screen keyboard is a 4-row overlay rendered on BG3 (2bpp) using 16×16 graphical keys. It is used by the text document editor, spreadsheet editor, and the save-system filename entry dialog. The public API is `kbd_show`, `kbd_hide`, and `kbd_update` (called per-frame). Editors read `kbd_char_out` each frame to get typed characters.

#### Visual Layout

The keyboard occupies the bottom portion of the screen (pixel Y 160-223), using the full 256px width. Each key is 16×16 pixels (2×2 tiles), giving 16 key positions per row.

```
Tilemap    Pixel Y   Content
rows 20-21 160-175   q w e r t y u i o p ← 1 2 3 4 5       ← row 0
rows 22-23 176-191   a s d f g h j k l / ↵ 6 7 8 9 0       ← row 1
rows 24-25 192-207   ↑ z x c v b n m , . ← / - _ ↵ X       ← row 2
rows 26-27 208-223      [     S P A C E     ]                ← row 3 (spacebar)
```

Each 16×16 key occupies 2 tilemap columns and 2 tilemap rows. Row 0 starts at tilemap row 20 (pixel Y 160). All rows are packed consecutively with no gaps. Coordinate mapping: `row = (cursor_y - 160) / 16`, `col = cursor_x / 16`.

#### Tile Design (2bpp, 16×16 keys)

Each 16×16 key is composed of 4 tiles in a 2×2 grid:

```
TL (shared) | TR (shared)     ← top half: key frame only
BL (unique) | BR (unique)     ← bottom half: frame + 2× scaled character
```

- **TL (tile 95):** Shared top-left frame. bp0=`$7F` (left edge transparent), rows 0-1 transparent (top gap), rows 6-7 = gray shadow (color 2).
- **TR (tile 96):** Shared top-right frame. bp0=`$FE` (right edge transparent), same top/bottom structure.
- **BL/BR (unique per character):** Bottom half with 2× horizontally scaled character pixels. The original 6px character glyph is expanded to 12px across both tiles using bit manipulation macros.

**2× horizontal scaling:** Each row of the original 8×8 character tile has 6 visible bits (bits 6-1). The `MAKE_KEY_BL` macro expands bits 6,5,4 into doubled pairs in the BL tile. The `MAKE_KEY_BR` macro expands bits 3,2,1 into the BR tile. Result: each original pixel becomes 2px wide, filling the 12px key interior.

**Color mapping (2bpp):**
- Color 0 = transparent (gaps between keys)
- Color 1 = key face background (white/yellow/blue per sub-palette)
- Color 2 = shadow strip (gray, bottom 2 rows of TL/TR for 3D raised look)
- Color 3 = character text (black)

#### Spacebar Tiles (97-107)

The spacebar spans columns 1-14 (26 tilemap cells wide) using dedicated tiles:

| Tile | Purpose |
|------|---------|
| 97 (SPC_TL) | Top-left cap (`$7F` face) |
| 98 (SPC_TM) | Top middle (full `$FF` face) |
| 99 (SPC_TR) | Top-right cap (`$FE` face) |
| 100 (SPC_BL) | Bottom-left cap |
| 101 (SPC_BM) | Bottom middle blank |
| 102 (SPC_BR) | Bottom-right cap |
| 103-107 | Bottom middle with S, P, A, C, E letters |

All spacebar tiles use sub-palette 3 (PPP=3) exclusively. This enables hover highlighting via CGRAM color swap instead of rewriting 40+ tilemap entries.

#### Tile Inventory

| Range | Content |
|-------|---------|
| 0-94 | Legacy 8×8 tiles (preserved for save.asm/menu.asm text rendering) |
| 95 | TL — shared top-left frame tile |
| 96 | TR — shared top-right frame tile |
| 97-102 | Spacebar frame tiles (TL, TM, TR, BL, BM, BR) |
| 103-107 | Spacebar letter tiles (S, P, A, C, E) |
| 108-225 | BL/BR character pairs (A-Z, 0-9, symbols, special keys, punctuation) |

Total: 226 tiles. Uppercase display only (no separate lowercase BL/BR tiles needed).

#### Palettes (4 sub-palettes, CGRAM 0-15)

| Sub-palette | PPP | Color 0 | Color 1 (face) | Color 2 (shadow) | Color 3 (text) | Use |
|-------------|-----|---------|-----------------|-------------------|-----------------|-----|
| 0 | 0 | Transparent | White (`$7FFF`) | Gray (`$294A`) | Black (`$0000`) | Normal key |
| 1 | 1 | Transparent | Yellow (`$03FF`) | Gray (`$294A`) | Black (`$0000`) | Hover/highlighted key |
| 2 | 2 | Transparent | Light blue (`$7A90`) | Gray (`$294A`) | Black (`$0000`) | Active SHIFT key |
| 3 | 3 | Transparent | White (`$7FFF`) | Gray (`$294A`) | Black (`$0000`) | Spacebar (CGRAM-swappable) |

Color 1 in sub-palette 0 **must** be white (`$7FFF`) because BG1's 4bpp text font also uses bp0 color 1 for its text color. Changing it would break the editor font.

#### Key Layout Tables

Two parallel sets of tables in `gfx/keyboard.asm` define what each key position displays and outputs:

- **Tile tables** (`kbd_tile_lo_row0-3`, `kbd_tile_hi_row0-3`): BL tile index per position (BR = BL+1), one set for unshifted and one for shifted. Row 3 (spacebar) is identical in both.
- **Character tables** (`kbd_char_lo_row0-3`, `kbd_char_hi_row0-3`): ASCII byte output per position. Special codes: `$01`=SHIFT toggle, `$08`=backspace, `$0A`=enter, `$7F`=delete, `$00`=no action (blank spacebar positions).

The tables are laid out as 4 rows × 16 columns = 64 bytes each. Lookup offset = `row * 16 + col`.

#### Input Handling (`kbd_update`)

Called every frame when the keyboard is visible. Execution flow:

1. Clear `kbd_char_out` to `$00`.
2. If left-click detected (`click_new`), call `_kbd_check_click`:
   - Map `cursor_y` to key row: `(cursor_y - 160) / 16`, must be 0-3.
   - Map `cursor_x` to key column: `cursor_x / 16`, must be 0-15.
   - Call `_kbd_press_key` to look up the character table and set `kbd_char_out`.
3. Otherwise, call `_kbd_mouse_to_grid` to update hover position from mouse coordinates (same row/column mapping).
4. If `kbd_dirty` is set, call `_kbd_update_highlight` to swap tilemap palette entries via the VRAM write queue.

#### Highlight System

When the mouse hovers over a key, highlight updates use the NMI write queue (`vram_wq_data`, up to 10 entries × 4 bytes each). Each entry is: VRAM address (2 bytes), tile index (1 byte), attribute byte (1 byte). A special marker (`addr_hi=$FF`) indicates CGRAM writes instead.

**Rows 0-2 (regular keys):** 4 VRAM writes per key (TL, TR, BL, BR tilemap entries) to swap PPP bits. Unhighlight old key (4 writes) + highlight new key (4 writes) = 8 entries max. The previous key is restored to sub-palette 0 (or sub-palette 2 if it's the SHIFT key and shift is active).

**Row 3 (spacebar):** Instead of rewriting 40+ tilemap entries, uses 2 CGRAM writes to swap color 1 and color 2 of sub-palette 3. On hover: color 1 → yellow (`$03FF`), color 2 → gray (`$294A`). On unhover: color 1 → white (`$7FFF`), color 2 → gray (`$294A`). This changes all spacebar tiles simultaneously with just 2 queue entries.

#### SHIFT Toggle

Pressing the SHIFT key (row 2, col 0) toggles `kbd_shift` between 0 and 1. This triggers `_kbd_rebuild_keys`, which:

1. Waits for VBlank (`wai`), enters force blank.
2. Rewrites all 4 key rows from the shifted/unshifted tile tables (BL/BR tiles change, TL/TR stay the same).
3. Applies sub-palette 2 (blue) to all 4 tiles of the SHIFT key if shift is active.
4. Sets `kbd_dirty` to force a highlight refresh.
5. Restores display brightness.

#### Show/Hide

- `kbd_show`: Enters force blank, DMA-uploads all tiles (8×8 legacy + 16×16 keys) to VRAM `$4000`, builds full BG3 tilemap (2×2 tile grid per key), uploads 4 sub-palettes (32 bytes) to CGRAM, enables BG3 on main screen (`SHADOW_TM |= $04`), sets BGMODE to `$09` (Mode 1 + BG3 priority).
- `kbd_hide`: Disables BG3 (`SHADOW_TM &= ~$04`), restores BGMODE to `$01` (standard Mode 1).

### Menu System (Phase 3)
- Type selection (`STATE_TYPE_SEL`): "TEXT DOCUMENT" / "SPREADSHEET" on BG3
- File browser (`STATE_FILE_BRW`): stub showing "NO SAVED FILES" (SRAM browsing is Phase 6)
- Both screens use keyboard 2bpp font tiles uploaded to BG3 chr area
- B button returns to title screen via fade-out → `STATE_BOOT`

### 16x16 Sprite Tile Layout
16x16 sprites use a 2x2 grid in VRAM with a stride of 16 tiles per row:
```
Tile N   | Tile N+1
Tile N+16| Tile N+17
```
Top row uploaded to base address, bottom row to base + `$0100` words.

### DMA Patterns
- **VRAM uploads:** DMA mode 1 (two registers: `VMDATAL`/`VMDATAH`), `VMAIN=$80` (increment after high byte).
- **CGRAM uploads:** DMA mode 0 (single register: `CGDATA`).
- **OAM uploads:** DMA mode 0 (single register: `OAMDATA`).
- **VRAM fill (zero):** DMA mode 1 with fixed source (`DMAP=$09`), size 0 = 65536 bytes.
- **Tilemap fill (zero):** Same fixed-source technique, 2048 bytes for 32x32 map.
- **WRAM clear:** Manual loop (WRAM-to-WMDATA DMA doesn't work — same physical RAM).

### Screen Fade
- `fade_dir`: `FADE_IN` (1) = incrementing brightness, `FADE_OUT` ($FF) = decrementing, `FADE_NONE` (0) = idle.
- `fade_level`: written directly to `SHADOW_INIDISP` (brightness 0-15).
- During fade, input is not processed (state handler returns early).

### Text Document Editor (Phase 4)
- **Font:** 4bpp monospace (61 tiles) on BG1, converted from 2bpp keyboard tiles with `MAKE_4BPP_TILE` macro (appends 16 zero bytes for bitplanes 2-3). ASCII-to-tile lookup table (96 entries).
- **Buffer:** 2048 bytes at WRAM `$0500`. Text stored as raw bytes, `$0A` = newline, `$00` = end. Max document size = 2047 chars.
- **Layout:** Row 0 = "UNTITLED" status bar, rows 1-19 = document text (30 cols × 19 rows), rows 20+ = keyboard (BG3).
- **Operations:** Insert shifts buffer right from cursor to end. Backspace/delete shift left. All use 16-bit index mode (`sep #$20, rep #$10`) for buffer addressing.
- **Rendering:** Full BG1 tilemap re-render during force blank when `doc_dirty` flag set. Scans buffer from `doc_scroll_y` offset, maps each char through `ascii_to_tile`, writes directly to VRAM. Truncates lines exceeding 30 columns.
- **Scrolling:** `doc_scroll_y` tracks first visible line. Auto-adjusts when cursor exits visible area (`_textdoc_adjust_scroll`).
- **Cursor:** Blinking underscore tile (tile 60) toggled every 30 frames via brief force blank VRAM write. Cursor row/col computed by scanning buffer from start (`_textdoc_calc_cursor`).
- **Init:** `doc_initialized` flag checked each frame; first frame calls `textdoc_init` which uploads font, clears tilemaps, shows keyboard, starts fade.
- **Lowercase:** Keyboard outputs uppercase/lowercase; display shows uppercase only (same tiles for both).

### Spreadsheet Editor (Phase 5)
- **Font:** Reuses 4bpp monospace font from Phase 4 (BG1), plus two additional sub-palettes: highlight (PPP=1, yellow on dark blue) and headers (PPP=2, gray).
- **Buffer:** 2048 bytes at WRAM `$0500` (shares space with doc buffer). 8 cols × 32 rows × 8 bytes per cell, null-terminated.
- **Cell address:** `SHEET_BUF_ADDR + row * 64 + col * 8`
- **Layout:** Row 0 = "SHEET" status bar (gray), Row 1 = column headers A-H (gray), Rows 2-19 = data (18 visible rows), Rows 20+ = keyboard (BG3).
- **Column layout:** Cols 0-1 = row numbers (gray), Col 2 = separator (colon tile, gray), Cols 3-26 = cell data (3 tiles per column, 8 columns).
- **Active cell:** Rendered with highlight palette (PPP=1, yellow on dark blue). Blinking underscore cursor at edit position.
- **Input:** D-pad navigates between cells. Mouse click selects cell (pixel→grid coordinate mapping). Keyboard chars append to active cell (max 8 chars, 3 displayed). ENTER moves down, Backspace deletes last char, DEL clears cell.
- **Scrolling:** `sheet_scroll_y` tracks first visible row. Auto-adjusts when cursor exits visible area.
- **Init:** `sheet_initialized` flag checked each frame; first frame calls `spreadsheet_init` which uploads font + 3 palettes, clears tilemaps/buffer, shows keyboard, starts fade.

### Save / Load System (Phase 6)
- **SRAM:** 32 KB at `$70:0000–$70:7FFF`, accessed via long addressing (`$700000.l,X`)
- **Header:** 16 bytes at `$70:0000` — magic "SOFA", format version, file count
- **Directory:** 8 slots × 16 bytes at `$70:0010`. Each entry: flags (in-use + type), data size, 12-char filename
- **Data area:** 8 fixed slots of $0F60 bytes each starting at `$70:0100`
- **File menu:** Right-click in editors opens overlay (Save/Save As/Close) on BG3 rows 8-14
- **Dirty check:** Close option checks `doc_dirty`/`sheet_dirty`; shows "SAVE CHANGES? YES/NO/CANCEL" dialog
- **Save As:** Prompts for filename via on-screen keyboard, finds first free slot
- **File browser:** `STATE_FILE_BRW` shows real SRAM directory. Left-click loads file, right-click on occupied slot opens delete confirm, right-click on empty space goes back
- **Init:** `sram_init` called during boot; checks magic "SOFA" signature, formats SRAM on first boot
- **Variables:** DP `$9E-$B7` for save system state (current_slot, file_type, menus, dialogs, filename buffer)

### Color Math & HDMA Sky Gradient
- `CGWSEL=$02`: sub-screen source = fixed color.
- `CGADSUB=$20`: add fixed color to backdrop.
- HDMA channel 7 writes to `COLDATA` ($2132) per-scanline using transfer mode 2 (write same register twice — one for blue channel intensity, one for green/red).
- HDMA table defined in `gfx/title.asm` as `title_hdma_gradient`.

## File Structure

| File | Purpose |
|------|---------|
| `src/main.s` | Master include file, memory map directives |
| `src/hdr.asm` | ROM header (LoROM, SRAM) + interrupt vectors |
| `src/snes.asm` | All hardware register defines (`$2100-$421F`, DMA channels, button masks) |
| `src/constants.asm` | VRAM layout, shadow addresses, game variables, screen constants, tile indices |
| `src/utils.asm` | `clear_vram`, `clear_cgram`, `clear_oam`, `wait_vblank`, `EmptyHandler` |
| `src/init.asm` | Boot sequence: native mode, hardware init, PPU config, cursor graphics upload, enters main loop |
| `src/nmi.asm` | VBlank handler: OAM DMA, shadow flush, scroll writes |
| `src/input.asm` | Manual serial mouse read + joypad with edge detection + unified click |
| `src/cursor.asm` | OAM entry 0: writes cursor position into shadow buffer |
| `src/states.asm` | Main loop + state dispatch jump table |
| `src/title.asm` | Title screen: init (graphics upload, HDMA, icons), per-frame update (fade, menu hover, click) |
| `src/keyboard.asm` | On-screen keyboard: show/hide, BG3 tilemap, click/d-pad input, char output |
| `src/menu.asm` | Type selection submenu + file browser stub |
| `src/textdoc.asm` | Text document editor: init, state handler, insert/backspace/delete, render, cursor blink |
| `src/spreadsheet.asm` | Spreadsheet editor: init, state handler, cell editing, grid render, cursor blink |
| `src/save.asm` | SRAM save/load: init, save/load/delete, file menu overlay, dirty dialogs, filename entry |
| `src/dma.asm` | Deferred DMA queue (stub — init and flush are no-ops) |
| `gfx/cursor.asm` | 16x16 arrow sprite tiles (4bpp) + palette data |
| `gfx/title.asm` | Font tiles, scene tiles, icon sprites, palettes, HDMA gradient table, tilemap row data |
| `gfx/keyboard.asm` | 2bpp font tiles (A-Z, 0-9, symbols), keyboard palette, key layout + char map tables |
| `gfx/textfont.asm` | 4bpp text font (MAKE_4BPP_TILE macro), ASCII-to-tile table, font palette |

## PPU Configuration (Mode 1)

| Setting | Value | Notes |
|---------|-------|-------|
| BG Mode | 1 | 3 BG layers (BG1/BG2 4bpp, BG3 2bpp) |
| Sprite size | 8x8 / 16x16 | OBJSEL sss=000 |
| BG1 | Content/text | Chr at `$0000`, map at `$7000` |
| BG2 | Scene/UI chrome | Chr at `$2000`, map at `$7400` |
| BG3 | Overlays (future) | Chr at `$4000`, map at `$7800` |
| Sprites | Cursor + icons | Chr at `$6000` |

## Title Screen Details (Phase 2)

- **BG1:** "SUPER" (row 4, per-letter color palettes: red S, green P, blue E, orange U, red R) + "OFFICE APP" (row 6, white) + menu text (rows 21, 23)
- **BG2:** Building silhouettes (rows 10-14) + desk edge (row 15) + desk surface fill (rows 16-27)
- **Sprites:** 4 desk icons (doc, spreadsheet, floppy, coffee mug) at OAM entries 1-4 with individual palettes
- **HDMA:** Channel 7 sky gradient on COLDATA, blue-to-light-blue
- **Menu:** "CREATE NEW" / "OPEN FILE" with cursor hit-box detection and selection arrow sprite
- **Fade:** Brightness ramp 0→15 on init, 15→0 on menu click

## Testing

- **Primary emulator:** Mesen (cycle-accurate, mouse emulation, PPU debugger)
- **Secondary:** bsnes-plus (accuracy reference)
- Enable SNES Mouse in emulator input settings for mouse testing
