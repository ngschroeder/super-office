; spc/samples.asm — BRR Sample Data + Sample Directory
; Uploaded to SPC700 RAM at $2000
;
; BRR format: 9 bytes per block (1 header + 8 data = 16 samples)
; Header: RRRR_FFLE  R=range/shift, F=filter, L=loop point, E=end flag
; All waveforms use filter 0 (no prediction) for clean synthetic tones.
; Looping samples: block1 L=1 E=0, block2 L=1 E=1
; Non-looping:     block1 L=0 E=0, block2 L=0 E=1
;
; Sample directory must be 256-byte aligned (DIR register = page number).
; Directory at $2000 (DIR=$20), sample data at $2020.

; =====================================================================
; Sample Directory — 8 entries x 4 bytes = 32 bytes
; Format: start_lo, start_hi, loop_lo, loop_hi
; =====================================================================

spc_sample_dir:
;             start         loop
.db $20, $20, $20, $20      ; 0: Square 50%  — start $2020, loop $2020
.db $32, $20, $32, $20      ; 1: Square 25%  — start $2032, loop $2032
.db $44, $20, $44, $20      ; 2: Triangle    — start $2044, loop $2044
.db $56, $20, $56, $20      ; 3: Sawtooth    — start $2056, loop $2056
.db $68, $20, $68, $20      ; 4: Noise burst  — start $2068, loop $2068 (non-looping)
.db $7A, $20, $7A, $20      ; 5: Sine approx — start $207A, loop $207A
.db $20, $20, $20, $20      ; 6: (unused, points to sample 0)
.db $20, $20, $20, $20      ; 7: (unused, points to sample 0)

; =====================================================================
; Sample Data — 6 waveforms, 18 bytes each = 108 bytes
; All use range=11 ($B) for good amplitude: decoded = nibble << 11
;   +7 << 11 = +14336,  -8 << 11 = -16384
; =====================================================================

spc_sample_data:

; --- Sample 0: Square 50% (at $2020) ---
; 32 samples: 16 high (+7), 16 low (-8)
; Classic square wave, good for melody and arpeggio
spc_samp_square50:
.db $B2                                             ; block 1: range=11, filt=0, loop=1, end=0
.db $77, $77, $77, $77, $77, $77, $77, $77         ;   16 samples of +7
.db $B3                                             ; block 2: range=11, filt=0, loop=1, end=1
.db $88, $88, $88, $88, $88, $88, $88, $88         ;   16 samples of -8

; --- Sample 1: Square 25% (at $2032) ---
; 32 samples: 8 high, 24 low — thinner, nasal tone
; Good for chiptune accent voices
spc_samp_square25:
.db $B2                                             ; block 1: range=11, filt=0, loop=1, end=0
.db $77, $77, $77, $77, $88, $88, $88, $88         ;   8 hi (+7), 8 lo (-8)
.db $B3                                             ; block 2: range=11, filt=0, loop=1, end=1
.db $88, $88, $88, $88, $88, $88, $88, $88         ;   16 lo (-8)

; --- Sample 2: Triangle (at $2044) ---
; 32 samples: linear ramp up 0→+7, down through 0 to -7, back to 0
; Smooth, mellow — good for bass lines
spc_samp_triangle:
.db $B2                                             ; block 1: range=11, filt=0, loop=1, end=0
.db $01, $23, $45, $67, $76, $54, $32, $10         ;   0,1,2,3,4,5,6,7,7,6,5,4,3,2,1,0
.db $B3                                             ; block 2: range=11, filt=0, loop=1, end=1
.db $0F, $ED, $CB, $A9, $9A, $BC, $DE, $F0         ;   0,-1,-2,-3,-4,-5,-6,-7,-7,-6,-5,-4,-3,-2,-1,0

; --- Sample 3: Sawtooth (at $2056) ---
; 32 samples: linear ramp from -8 to +7
; Bright, harmonically rich — good for pads and chords
spc_samp_sawtooth:
.db $B2                                             ; block 1: range=11, filt=0, loop=1, end=0
.db $89, $AB, $CD, $EF, $01, $23, $45, $67         ;   -8,-7,-6,-5,-4,-3,-2,-1,0,1,2,3,4,5,6,7
.db $B3                                             ; block 2: range=11, filt=0, loop=1, end=1
.db $89, $AB, $CD, $EF, $01, $23, $45, $67         ;   same ramp (seamless loop)

; --- Sample 4: Noise Burst (at $2068) ---
; 32 samples of pseudo-random data, non-looping
; Used for key click and percussive SFX
spc_samp_noise:
.db $B0                                             ; block 1: range=11, filt=0, loop=0, end=0
.db $79, $38, $A5, $6C, $B7, $42, $D8, $15         ;   random noise, full amplitude
.db $91                                             ; block 2: range=9, filt=0, loop=0, end=1
.db $53, $A7, $21, $84, $36, $12, $00, $00         ;   decaying noise (lower range)

; --- Sample 5: Sine Approximation (at $207A) ---
; 32 samples: smooth sine-like curve
; Clean tone for chimes and confirmation sounds
spc_samp_sine:
.db $B2                                             ; block 1: range=11, filt=0, loop=1, end=0
.db $03, $57, $77, $53, $0D, $B9, $99, $BD         ;   0,3,5,7,7,5,0,-3,-5,-7,-7,-5,-3
                                                    ;   (first half of sine: rise and fall)
.db $B3                                             ; block 2: range=11, filt=0, loop=1, end=1
.db $03, $57, $77, $53, $0D, $B9, $99, $BD         ;   same shape (symmetric sine, seamless loop)

spc_sample_data_end:

; Total size: 32 (directory) + 108 (samples) = 140 bytes
; SPC700 address range: $2000-$208B
