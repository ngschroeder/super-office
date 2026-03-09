# Super Office App — Sound Plan (Phase 7)

## Overview

Add SPC700 audio: lo-fi office background music and UI sound effects. All audio uses synthetic BRR waveforms (no external samples needed). The aesthetic is calm, unobtrusive office elevator muzak — think hold music crossed with early-90s game menu themes.

## Architecture

### SPC700 Sound Driver

A minimal custom sound driver uploaded to SPC700 RAM on boot via IPL transfer protocol.

**Components:**
1. **IPL upload routine** (65816 side) — transfers driver + sample data to SPC700 RAM via ports `$2140-$2143`
2. **Driver core** (SPC700 side) — main loop that processes commands from the 65816
3. **Sequencer** — reads note data from a pattern table, drives DSP voices
4. **SFX player** — plays one-shot sounds on a dedicated voice, interrupting if needed

**Memory map (SPC700 64 KB RAM):**
| Range | Purpose |
|-------|---------|
| `$0000-$00FF` | Direct page (driver variables, DSP shadow) |
| `$0100-$01FF` | Stack |
| `$0200-$0FFF` | Driver code (~3.5 KB) |
| `$1000-$1FFF` | Music sequence data (~4 KB) |
| `$2000-$3FFF` | BRR sample directory + samples (~8 KB) |
| `$4000-$FFBF` | Free / expansion |
| `$FFC0-$FFFF` | IPL ROM (overwritten after boot) |

### DSP Voice Allocation

The SPC700 DSP has 8 voices (0-7):

| Voice | Purpose |
|-------|---------|
| 0 | Music — melody |
| 1 | Music — bass |
| 2 | Music — chord/pad |
| 3 | Music — chord/pad (2nd voice) |
| 4 | Music — arpeggio/counter-melody |
| 5 | SFX — UI sounds (menu select, key click, save confirm) |
| 6 | Reserved / expansion |
| 7 | Reserved / expansion |

SFX on voice 5 plays independently of music voices 0-4. No voice stealing needed.

### Communication Protocol (65816 ↔ SPC700)

Commands sent via APU I/O ports `$2140-$2143`:

| Port | Direction | Purpose |
|------|-----------|---------|
| `$2140` | 65816 → SPC | Command byte |
| `$2141` | 65816 → SPC | Parameter byte |
| `$2142` | SPC → 65816 | Status / acknowledgment |
| `$2143` | SPC → 65816 | Reserved |

**Command set:**
| Cmd | Name | Param | Description |
|-----|------|-------|-------------|
| `$00` | NOP | — | No operation |
| `$01` | PLAY_MUSIC | song ID | Start background music loop |
| `$02` | STOP_MUSIC | — | Fade out and stop music |
| `$03` | PAUSE_MUSIC | — | Pause music (voices silent, position held) |
| `$04` | RESUME_MUSIC | — | Resume from pause |
| `$10` | PLAY_SFX | sfx ID | Trigger one-shot sound effect |
| `$20` | SET_VOLUME | 0-127 | Master volume |

## BRR Samples

### Waveform Generation

All samples are single-cycle waveforms generated as BRR data in assembly. Each BRR block is 9 bytes (1 header + 8 bytes = 16 nybbles = 16 PCM samples).

**Planned waveforms:**

| ID | Waveform | Loops | Use | Size |
|----|----------|-------|-----|------|
| 0 | Square 50% | Yes | Melody, arpeggio | ~36 bytes (4 BRR blocks) |
| 1 | Square 25% | Yes | Chiptune accent | ~36 bytes |
| 2 | Triangle | Yes | Bass, soft melody | ~36 bytes |
| 3 | Sawtooth | Yes | Pads, chords | ~36 bytes |
| 4 | Noise burst | No | Key click SFX | ~18 bytes (2 blocks) |
| 5 | Sine approx | Yes | Gentle tones, save confirm | ~36 bytes |

Total sample data: ~200 bytes + 32 bytes for sample directory (4 bytes per entry × 8 entries).

**BRR encoding details:**
- Header byte: `range` (shift, 0-12), `filter` (0-3), `loop` flag, `end` flag
- Filter 0 (no prediction) is simplest and sufficient for clean waveforms
- Loop point set to sample start for continuous tones
- Single-cycle loops: 16 or 32 samples per period, pitch register controls frequency

### Sample Directory

Located at a 256-byte-aligned address. DSP register `$5D` (DIR) points to it. Each entry is 4 bytes: start address (word) + loop address (word).

## Music

### Style: Lo-Fi Office Muzak

- **Tempo:** ~90-110 BPM (relaxed, not rushed)
- **Key:** C major or F major (bright, pleasant)
- **Feel:** Bossa nova / smooth jazz / elevator music
- **Dynamics:** Soft, no sudden loud notes
- **Loop length:** 16-32 bars, seamless loop

### Song List

| ID | Name | Use | Description |
|----|------|-----|-------------|
| 0 | "Office Hours" | Title screen | Gentle bossa nova feel. Triangle bass walks a I-vi-ii-V progression. Square melody plays a simple, repeating 8-bar phrase. Saw pad holds chord tones. |
| 1 | "Desk Work" | Text editor / Spreadsheet | Even more subdued. Slower tempo (~80 BPM). Sparse melody, emphasis on soft pad chords. Designed to not distract while typing. |

### Sequence Format

Simple bytecode interpreted by the SPC700 sequencer:

```
Note byte:    $00-$7F = note (MIDI-style: $3C = middle C)
              $80     = rest
              $81     = tie (extend previous note)
              $FE     = loop point marker
              $FF     = end / loop back

Duration byte: follows every note byte
              $01-$FF = duration in ticks (1 tick = ~16ms at 60Hz)
              Common: $0C = eighth note, $18 = quarter, $30 = half

Volume byte:  $Vx where x = velocity (only at start or on changes)

Channel header: sample ID, initial volume, pan position
```

Each music voice has its own sequence stream. The sequencer reads all active streams in parallel.

### Chord Progression — "Office Hours"

```
| C maj | A min | D min | G7    |  (repeat)
| I     | vi    | ii    | V7    |

Bass (triangle):  C2  A1  D2  G1
Melody (square):  E4-G4-C5 phrases over changes
Pad (sawtooth):   Holds chord tones (2 voices for triads)
```

### Chord Progression — "Desk Work"

```
| F maj | Dm7   | Bb maj | C7    |  (repeat)
| I     | vi7   | IV     | V7    |

Bass (triangle):  F2  D2  Bb1  C2
Pad (sawtooth):   Sustained chord voicings, very soft
Melody:           Minimal, occasional quarter notes
```

## Sound Effects

All SFX play on voice 5, using short ADSR envelopes for snappy response.

### SFX List

| ID | Name | Trigger | Sample | ADSR | Description |
|----|------|---------|--------|------|-------------|
| 0 | Menu Select | Menu item clicked | Square 50% | A=15,D=7,S=0,R=15 | Quick bright chirp. Two notes: C5→E5 rapid (2 frames each). Cheerful, not shrill. |
| 1 | Key Click | On-screen keyboard press | Noise burst | A=15,D=3,S=0,R=31 | Very short percussive tap. Like a typewriter key. Minimal pitch, mostly attack transient. |
| 2 | Save Confirm | File saved successfully | Sine approx | A=12,D=5,S=4,R=10 | Gentle two-tone chime: G4→C5, each ~6 frames. Warm and reassuring. |
| 3 | Error/Cancel | Dialog cancel, invalid action | Square 25% | A=15,D=5,S=0,R=20 | Low single tone: E3, ~8 frames. Not harsh — just a soft "nope." |
| 4 | Delete Confirm | File deleted | Noise burst | A=15,D=7,S=0,R=15 | Slightly longer noise sweep, pitched down. Definitive but not alarming. |

### ADSR Register Encoding

DSP voices use two ADSR bytes:
- **ADSR1** (`$x5`): `1DDDAAAA` — enable ADSR, decay rate (0-7), attack rate (0-15)
- **ADSR2** (`$x6`): `SSSRRRRR` — sustain level (0-7), release rate (0-31)

SFX envelopes are designed for fast attack (A=15 or 12) and quick release to keep sounds snappy and unobtrusive.

## Implementation Plan

### File Structure

| File | Purpose |
|------|---------|
| `src/audio.asm` | 65816-side: IPL upload, command API (play_sfx, play_music, etc.) |
| `spc/driver.asm` | SPC700 driver source (assembled separately or as binary blob) |
| `spc/samples.asm` | BRR waveform data (generated mathematically) |
| `spc/songs.asm` | Music sequence data for both songs |
| `spc/sfx.asm` | SFX definitions (sample + pitch + ADSR + duration) |

### Integration Points

1. **Boot (`init.asm`):** After PPU init, call `audio_init` to upload driver + data to SPC700
2. **Title screen (`title.asm`):** `play_music(0)` on fade-in, `stop_music` on fade-out
3. **Editor states (`textdoc.asm`, `spreadsheet.asm`):** `play_music(1)` on init
4. **Keyboard (`keyboard.asm`):** `play_sfx(SFX_KEYCLICK)` on key press
5. **Menu (`menu.asm`, `title.asm`):** `play_sfx(SFX_MENUSEL)` on menu item click
6. **Save (`save.asm`):** `play_sfx(SFX_SAVE)` on successful save
7. **State transitions:** `stop_music` before fade-out, `play_music` after fade-in

### Build Considerations

**Option A — Inline SPC700 binary:**
- Hand-assemble SPC700 driver to binary, embed as `.db` blocks in `spc/driver.asm`
- Simpler build (no separate assembler needed), WLA-DX handles everything
- SPC700 uses a different instruction set than 65816, so code is written as raw bytes with comments

**Option B — WLA-DX SPC700 support:**
- WLA-DX has `wla-spc700` for native SPC700 assembly
- Would need a separate assembly step and binary inclusion
- Cleaner source code but more complex build

**Recommendation:** Start with Option A (inline binary) for simplicity. The driver is small (~1-2 KB of SPC700 code). Migrate to Option B later if the driver grows complex.

### Implementation Order

1. **Step 1:** BRR waveform generation (square, triangle, noise) as data tables
2. **Step 2:** IPL upload routine (65816 side) — transfer driver blob to SPC700
3. **Step 3:** Minimal SPC700 driver — accept commands, play single notes
4. **Step 4:** SFX system — implement all 5 sound effects
5. **Step 5:** Music sequencer — implement pattern playback
6. **Step 6:** Compose "Office Hours" and "Desk Work" sequences
7. **Step 7:** Integration — hook into all game states

### Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| SPC700 timing bugs | Start with simplest possible driver, add features incrementally |
| IPL upload failure | Implement with strict handshake protocol, verify echo bytes |
| BRR artifacts | Use filter 0 (no prediction) for clean waveforms; test in Mesen's APU debugger |
| Music too loud/distracting | Default to low master volume (~40/127), can adjust |
| Driver too large | Budget 3.5 KB for code, 4 KB for sequences, 8 KB for samples — well within 64 KB |
