# SUPER OFFICE APP — Project Plan

An SNES "productivity application" ROM featuring a text document editor and a
spreadsheet viewer/editor, driven by the SNES Mouse with joypad d-pad fallback
and an on-screen virtual keyboard for text entry.

---

## 1. Hardware & Toolchain Decisions

| Decision          | Choice                | Rationale                                                      |
|-------------------|-----------------------|----------------------------------------------------------------|
| ROM layout        | LoROM, SlowROM        | Matches Mario Paint; simplest bank mapping for a UI-heavy app  |
| ROM size          | 1 MB (8 Mbit)         | Plenty of room for font tiles, UI chrome, and code             |
| SRAM              | 32 KB                 | Enough for multiple document save slots                        |
| BG mode           | Mode 1 (3 BG layers)  | BG1 = content area, BG2 = UI chrome/menus, BG3 = overlays     |
| Assembler/linker  | WLA-DX (wla-65816)    | Used by all three reference codebases; best documented         |
| Primary input     | SNES Mouse (port 1)   | Mario Paint codebase provides complete protocol reference       |
| Fallback input    | Standard joypad       | D-pad moves cursor, A=click, B=back, etc.                     |
| Text entry        | On-screen keyboard    | Sprite or BG3 overlay; mouse click or d-pad to select chars   |

### Reference Codebases We'll Draw From

- **Mario Paint** — Mouse protocol, cursor sprite, panel-based UI, DMA
  queues, OAM management, state machine, SRAM save/load, screen fades
- **WW2 (Koutetsu no Kishi)** — NTT keypad protocol (if we add numpad
  support later), complex HDMA, task scheduler, RLE decompression
- **B.O.B.** — Clean project template, cooperative multitasking (NINSYS),
  full build pipeline, joypad input with edge detection

---

## 2. Application State Machine

```
                    ┌──────────┐
         RESET ───→│  BOOT    │
                    └────┬─────┘
                         │
                    ┌────▼─────┐
                    │  TITLE   │  "SUPER OFFICE APP" splash
                    │  SCREEN  │  Mouse cursor appears
                    └────┬─────┘
                         │  click menu item
                    ┌────▼─────┐
                    │  MAIN    │  "Create New" / "Open File"
                    │  MENU    │
                    └──┬────┬──┘
            Create New │    │ Open File
                  ┌────▼┐  ┌▼────────┐
                  │TYPE │  │  FILE   │  List saved docs from SRAM
                  │SEL  │  │ BROWSER │
                  └──┬──┘  └──┬──────┘
                     │        │  select file
          ┌──────────▼────────▼──────────┐
          │                              │
     ┌────▼─────┐                  ┌─────▼──────┐
     │ TEXT DOC │                  │SPREADSHEET │
     │  EDITOR  │                  │   EDITOR   │
     └──────────┘                  └────────────┘
```

Each state is a top-level mode with its own `Update` and `Draw` logic,
dispatched from the main loop via a jump table (pattern from Mario Paint
`bank0.asm` L001FC4).

---

## 3. BG Layer Plan (Mode 1)

| Layer | Bit depth | Purpose                                    |
|-------|-----------|--------------------------------------------|
| BG1   | 4bpp      | Main content: document text / spreadsheet cells |
| BG2   | 4bpp      | UI chrome: title bar, menu bar, status bar, borders |
| BG3   | 2bpp      | Overlays: on-screen keyboard, dialog boxes, tooltips |

**Sprite layer:** Mouse cursor (1 sprite, 16×16), plus optional highlight
sprites for active cell borders or selection indicators.

### VRAM Layout (tentative)

```
$0000–$1FFF  BG1 character data (font tiles, 4bpp)
$2000–$3FFF  BG2 character data (UI chrome tiles, 4bpp)
$4000–$47FF  BG3 character data (keyboard/overlay tiles, 2bpp)
$5000–$57FF  Sprite character data (cursor, icons)
$6000–$67FF  BG1 tilemap (32×32 or 64×32)
$6800–$6FFF  BG2 tilemap
$7000–$73FF  BG3 tilemap
```

Exact addresses will be finalized during implementation; these are starting
estimates based on tile counts.

---

## 4. Input System Design

### 4.1 Mouse (Primary)

Follows the Mario Paint protocol exactly:

1. Auto-joypad read captures bytes 1–2 (signature + buttons)
2. Detect mouse via signature nibble `$01` in JOYnL
3. Manual serial read of 16 bits for X/Y displacement (bytes 3–4)
4. Convert signed-magnitude deltas to two's complement
5. Accumulate into cursor position with screen-edge clamping
6. Set sensitivity to medium (one cycle of the latch strobe)

Key reference: `mariopaint/bank1.asm` L00D9E1 (line 10900)

### 4.2 Joypad Fallback

If no mouse detected (signature ≠ $01), fall back to joypad mode:

- D-pad moves cursor at a configurable pixel speed (accelerating if held)
- A button = left click
- B button = back / cancel / close keyboard
- X button = open on-screen keyboard
- Y button = delete / backspace
- Start = open file menu (save, close, etc.)
- L/R = switch between open documents (stretch goal)

Use B.O.B.'s joypad code pattern for edge detection (new/held/released).
Reference: `bob/joypad.asm`

### 4.3 On-Screen Keyboard

A compact grid of character tiles displayed on BG3 in the bottom ~35–40%
of the screen, leaving ~60–65% for the document/spreadsheet content above.
The keyboard uses a 3-row layout to minimize vertical space:

```
┌─────────────────────────────────────────────────────┐
│ 1 2 3 4 5 6 7 8 9 0 Q W E R T Y U I O P  ←  DEL  │
│ A S D F G H J K L Z X C V B N M  ,  .  /  ENTER   │
│ SYM  SHIFT  [        SPACE BAR        ]    SYM     │
└─────────────────────────────────────────────────────┘
```

Punctuation and special characters (`;  '  [  ]  -  =` etc.) are accessed
via the SYM modifier key, which swaps the letter grid for a symbol grid.

- Mouse click on a key → insert character
- D-pad to navigate key highlight + A to press
- SHIFT toggles upper/lowercase; SYM toggles symbol layer
- ← key = backspace, DEL = delete forward
- ENTER = newline (text doc) or confirm cell (spreadsheet)
- B button = dismiss keyboard

The keyboard occupies ~8 tile rows on BG3 (3 key rows + border/padding),
taking roughly the bottom 35% of the 224-line display. A thin separator
line divides the content area from the keyboard. When hidden, BG3 is
disabled via the TM register shadow.

---

## 5. Text Document Editor

### Features (MVP)

- **Display area**: 28 columns × 24 rows of visible text (using 8×8 font)
- **Cursor**: Blinking underscore at current insert position
- **Scrolling**: Vertical scroll when text exceeds visible area
- **Character set**: A–Z, a–z, 0–9, basic punctuation, space, newline
- **Operations**: Insert character, backspace, newline, scroll up/down

### Data Model

```
doc_buffer:    2 KB WRAM buffer for document text (plain bytes, 0-terminated lines)
doc_cursor_x:  column position (0–27)
doc_cursor_y:  row position (absolute, not screen-relative)
doc_scroll_y:  first visible row
doc_length:    total character count
doc_dirty:     modified-since-save flag
```

### Rendering

BG1 tilemap is updated when text changes. Only the dirty rows need
re-uploading via the deferred DMA queue (pattern from Mario Paint
`bank1.asm` L00CDE1). The font is a simple 8×8 monospace tileset stored
in VRAM as 4bpp characters (using only 2 colors from the palette for a
clean look, leaving room for syntax-highlight-style color in the future).

---

## 6. Spreadsheet Editor

### Features (MVP)

- **Grid**: 8 columns (A–H) × 32 rows, with column/row headers
- **Cell content**: Up to 8 characters per cell (text or number)
- **Active cell**: Highlighted border (sprite overlay or BG2 window)
- **Navigation**: Mouse click on cell, or d-pad to move selection
- **Entry**: Click cell → on-screen keyboard opens → type → ENTER confirms
- **Display**: Cell values rendered as text in the grid

### Stretch Goals (post-MVP)

- Basic formulas: `=SUM(A1:A8)`, `=A1+B1`
- Column width adjustment
- Copy/paste cells
- Auto-fill (drag handle)

### Data Model

```
sheet_cells:   8 × 32 × 9 bytes = 2,304 bytes (8 chars + type flag per cell)
sheet_cursor:  col (0–7), row (0–31)
sheet_scroll:  first visible row
sheet_dirty:   modified-since-save flag
```

### Rendering

The grid is drawn on BG1 using the same monospace font as the text editor.
Column headers (A–H) and row numbers (1–32) are rendered on BG2 so they
stay fixed while the content area scrolls. The active cell highlight can
be either:

- A sprite-based rectangle (4 sprites forming a border), or
- A PPU window effect masking BG1 to invert/highlight the active cell

We'll prototype both and pick whichever looks cleaner.

---

## 7. Save / Load System

### SRAM Layout

With 32 KB of SRAM mapped at `$70:0000–$70:7FFF`:

```
$70:0000–$70:000F  Header: magic bytes, version, file count
$70:0010–$70:001F  File directory (up to 8 slots)
                   Each slot: 2 bytes offset, 1 byte type, 1 byte name_len,
                              12 bytes name
$70:0100–$70:7FFF  File data area (~31.5 KB)
                   Text docs: raw byte stream, null-terminated
                   Spreadsheets: cell array dump (type + 8 chars per cell)
```

### Operations

- **Save**: Serialize current doc/sheet to SRAM at the slot's offset
- **Load**: Copy SRAM data into WRAM working buffers
- **Delete**: Mark slot as free, compact if needed
- **New file**: Allocate next free slot, initialize empty buffer

Reference for SRAM access: Mario Paint `bank0.asm` L00366C

---

## 8. Title Screen

The title screen draws inspiration from the attached pixel-art concept:

- title-example.png
- Blue gradient sky background (HDMA color gradient on BG2 or fixed color)
- City skyline silhouette (BG2 tiles, dark palette)
- Desk surface along the bottom (BG2 tiles, brown/orange)
- "SUPER OFFICE APP" title text (BG1 or sprites, colorful/bold)
- Doc icon and spreadsheet icon (sprites, animated idle wobble)
- Coffee mug and floppy disk as decorative sprites
- Mouse cursor active; two clickable menu items:
  - **"Create New"**
  - **"Open File"**

The title screen palette uses the full 256-color capability: dedicated
subpalettes for the sky gradient, cityscape, desk objects, and title text.

### HDMA Effect

A single HDMA channel writes to COLDATA ($2132) each scanline to produce
a smooth blue-to-light-blue sky gradient behind the cityscape. Reference:
`ww2/bank15.asm` HDMA setup patterns.

---

## 9. Phased Build Order

### Phase 1 — Skeleton & Input (get something on screen)

- [ ] Project setup: directory structure, Makefile, ROM header, linker config
- [ ] Boot / init sequence (from programming-patterns §1)
- [ ] Main loop + NMI handler with shadow registers
- [ ] Mouse detection and reading (port from Mario Paint protocol)
- [ ] Joypad fallback with edge detection
- [ ] Cursor sprite: 16×16 arrow, tracks mouse/d-pad position
- [ ] Blank screen with working cursor — proof of life

### Phase 2 — Title Screen

- [ ] Design and convert title screen tile graphics (cityscape, desk, icons)
- [ ] BG2 tilemap for background scene
- [ ] BG1 or sprite-based title text
- [ ] Sprite-based doc/spreadsheet icons and decorations
- [ ] HDMA sky gradient
- [ ] Menu item hit detection (mouse click on "Create New" / "Open File")
- [ ] Screen fade transition to next state

### Phase 3 — Menu System & On-Screen Keyboard

- [ ] File type selection submenu (Text Doc / Spreadsheet)
- [ ] File browser: list saved files from SRAM directory
- [ ] On-screen keyboard: tile design, BG3 tilemap, show/hide toggle
- [ ] Keyboard input logic: mouse click detection on key grid
- [ ] D-pad navigation of keyboard with highlight cursor
- [ ] Character output buffer connected to text/sheet editors

### Phase 4 — Text Document Editor

- [ ] Font tileset: 8×8 monospace, full printable ASCII
- [ ] WRAM text buffer and cursor management
- [ ] BG1 tilemap rendering of text content
- [ ] Insert, backspace, newline operations
- [ ] Vertical scrolling when buffer exceeds screen
- [ ] Dirty-row tracking and deferred DMA updates
- [ ] UI chrome on BG2: title bar showing filename, status bar

### Phase 5 — Spreadsheet Editor

- [ ] Cell grid rendering on BG1 (8 cols × visible rows)
- [ ] Fixed headers on BG2 (column letters, row numbers)
- [ ] Active cell highlight (sprite border or window effect)
- [ ] Cell selection via mouse click with coordinate mapping
- [ ] Cell editing: keyboard opens, value stored on ENTER
- [ ] Scroll through rows beyond visible area

### Phase 6 — Save / Load

- [ ] SRAM header and directory structure initialization
- [ ] Save current document to SRAM slot
- [ ] Load document from SRAM into WRAM
- [ ] File browser reads real SRAM directory
- [ ] "Save" option in file menu (Start button)
- [ ] Dirty flag prompts "save before closing?" dialog

### Phase 7 — Polish & Stretch

- [ ] Sound effects: menu select, key click, save confirm, error buzz
- [ ] Screen transitions (fade or wipe between states)
- [ ] Title screen sprite animations (icon wobble, steam from coffee mug)
- [ ] Spreadsheet formulas (=SUM, basic arithmetic)
- [ ] Copy/paste in text editor
- [ ] Multiple open documents with L/R switching
- [ ] SPC700 background music (lo-fi office muzak?)

---

## 10. File & Directory Structure

```
super-office-app/
├── Makefile
├── linkfile                 # WLA-DX linker configuration
├── PLAN.md                  # This file
│
├── src/
│   ├── main.s               # Master include file
│   ├── hdr.asm              # ROM header, memory map, vectors
│   ├── snes.asm             # Hardware register definitions
│   ├── constants.asm        # App-wide constants and equates
│   ├── init.asm             # Boot / initialization
│   ├── nmi.asm              # NMI handler, DMA flush, shadow regs
│   ├── input.asm            # Mouse protocol + joypad fallback
│   ├── cursor.asm           # Cursor sprite positioning and animation
│   ├── states.asm           # Top-level state machine dispatch
│   ├── title.asm            # Title screen logic
│   ├── menu.asm             # Main menu + file browser
│   ├── keyboard.asm         # On-screen keyboard logic
│   ├── textdoc.asm          # Text document editor
│   ├── spreadsheet.asm      # Spreadsheet editor
│   ├── save.asm             # SRAM save/load routines
│   ├── dma.asm              # Deferred DMA queue system
│   └── utils.asm            # Shared utilities (math, string ops)
│
├── gfx/
│   ├── font8x8.png          # Monospace font source graphic
│   ├── title_bg.png         # Title screen background
│   ├── ui_chrome.png        # Menu bars, borders, buttons
│   ├── keyboard.png         # On-screen keyboard tiles
│   ├── cursor.png           # Mouse cursor sprite
│   ├── icons.png            # Doc/spreadsheet/floppy/mug sprites
│   └── convert.sh           # bmp2chr / png2snes conversion script
│
├── audio/
│   ├── spc700.asm           # SPC700 audio driver (Phase 7)
│   └── sfx/                 # BRR-encoded sound effects
│
└── tools/
    └── bmp2chr              # Graphics conversion tool (from ref codebases)
```

---

## 11. Key Technical Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Mouse protocol timing edge cases | Input drops, jittery cursor | Port Mario Paint's exact code; test on Mesen and bsnes-plus with cycle accuracy |
| VRAM bandwidth for full-screen text redraws | Visible tearing or incomplete updates | Dirty-row tracking; only DMA changed rows; use deferred queue pattern |
| On-screen keyboard covers content | Poor UX when typing | Bottom screen split (~35/65): compact 3-row keyboard in bottom 8 tile rows, content stays visible above a separator line |
| 32 KB SRAM limits document size | Can't save large docs | Cap text docs at ~4 KB each; 8 save slots; display remaining space in UI |
| Spreadsheet formulas are complex to parse | Scope creep in Phase 7 | MVP has no formulas — cells are just text/numbers; formulas are a stretch goal |
| Tile/palette count pressure in Mode 1 | Running out of VRAM or palette slots | Font only needs ~96 tiles; keep UI chrome tile-efficient; reuse palette subgroups |

---

## 12. Emulator Testing Notes

- **Primary**: Mesen (cycle-accurate, has mouse and joypad emulation, memory viewer, PPU debugger)
- **Secondary**: bsnes-plus (accuracy reference, VRAM viewer)
- Both support SNES Mouse emulation — enable in input settings
- Test SRAM persistence by saving, closing, and reopening ROM
- Use Mesen's trace logger to debug mouse serial read timing

---

*This plan will evolve as we build. Each phase may surface design changes
that feed back into later phases. The phased checklist in §9 is our
primary tracking mechanism.*