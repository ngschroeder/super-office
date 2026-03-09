; spc/sfx.asm — Sound Effect Definitions
; Referenced by the SPC700 driver when triggered from the 65816 side.
;
; Each SFX entry = 9 bytes:
;   sample_id, pitch_lo, pitch_hi, adsr1, adsr2, duration, pitch2_lo, pitch2_hi, dur2
;
; ADSR1 format: 1DDD_AAAA  (bit 7=1 enables ADSR mode)
;   A = attack rate  (0-15, higher = faster)
;   D = decay rate   (0-7, higher = faster)
;
; ADSR2 format: SSSR_RRRR
;   S = sustain level (0-7, 0=1/8 .. 7=full)
;   R = release rate  (0-31, higher = faster)
;
; Pitch: 14-bit value in SPC700 DSP P(L)/P(H) registers.
;   $1000 ≈ base sample rate (32 kHz playback at native pitch)
;   Doubling pitch = +1 octave.
;
; Duration: frames at ~60 Hz (1 = ~16ms). $00 in note2 fields = single-note SFX.
;
; Pitch reference (approximate, assuming 32-sample waveform):
;   C3=$0800  D3=$08E0  E3=$0A14  F3=$0A98  G3=$0BE8
;   A3=$0D34  B3=$0ED0
;   C4=$1000  D4=$11C0  E4=$1428  F4=$1530  G4=$17D0
;   A4=$1A68  B4=$1DA0
;   C5=$2000  D5=$2380  E5=$2850  F5=$2A60  G5=$2FA0
;   A5=$34D0

; =====================================================================
; SFX ID constants — defined in src/audio.asm (SFX_MENU_SEL, etc.)
; SFX_COUNT used only here for size reference
; =====================================================================
; SFX Table — 5 entries x 9 bytes = 45 bytes
; =====================================================================

spc_sfx_table:

; --- SFX 0: Menu Select ---
; Two-note ascending chirp: C5 → E5
; Square 50%, fast attack, quick decay
; sample  pitch_lo  pitch_hi  adsr1  adsr2  dur  pitch2_lo  pitch2_hi  dur2
.db $00,    $00,      $20,     $FF,   $0F,  $04,   $50,       $28,     $04
;   sq50    C5=$2000           D=7,A=15     4fr    E5=$2850            4fr
;                              S=0,R=15

; --- SFX 1: Key Click ---
; Short noise burst — single note, fast release
; Noise sample, no second note
.db $04,    $00,      $10,     $BF,   $1F,  $03,   $00,       $00,     $00
;   noise   $1000              D=3,A=15     3fr    (no note 2)
;                              S=0,R=31

; --- SFX 2: Save Confirm ---
; Ascending chime: G4 → C5
; Sine wave, moderate attack, gentle sustain
.db $05,    $D0,      $17,     $DC,   $8A,  $08,   $00,       $20,     $08
;   sine    G4=$17D0           D=5,A=12     8fr    C5=$2000            8fr
;                              S=4,R=10

; --- SFX 3: Error / Cancel ---
; Low harsh buzz — single sustained note
; Square 25% for thin, nasal quality
.db $01,    $14,      $0A,     $DF,   $14,  $0A,   $00,       $00,     $00
;   sq25    E3=$0A14           D=5,A=15     10fr   (no note 2)
;                              S=0,R=20

; --- SFX 4: Delete Confirm ---
; Descending thud: two noise hits, lower second
; Noise sample, percussive
.db $04,    $00,      $0C,     $FF,   $0F,  $06,   $00,       $08,     $06
;   noise   $0C00              D=7,A=15     6fr    $0800               6fr
;                              S=0,R=15

spc_sfx_table_end:

; Total size: 45 bytes
