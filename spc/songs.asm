; spc/songs.asm — Music Sequence Data
; Uploaded to SPC700 RAM at $1000
;
; Sequence format (note/duration pairs):
;   $00-$7F = MIDI note number, followed by duration byte
;   $80     = rest, followed by duration byte
;   $FE     = loop point marker (loop back to here on $FF)
;   $FF     = end — loops back to most recent $FE, or stops if none
;
; Duration values (in sequence steps):
;   Song 0 (tempo_div=8):  1 step ≈ 64ms.  Quarter=4, Half=8, Whole=16
;   Song 1 (tempo_div=10): 1 step ≈ 80ms.  Quarter=4, Half=8, Whole=16
;
; MIDI note reference:
;   C2=36  D2=38  E2=40  F2=41  G2=43  A2=45  Bb2=46  B2=47
;   C3=48  D3=50  E3=52  F3=53  G3=55  A3=57  Bb3=58  B3=59
;   C4=60  D4=62  E4=64  F4=65  G4=67  A4=69  Bb4=70  B4=71
;   C5=72  D5=74  E5=76  F5=77  G5=79
;   A1=33  Bb1=34  B1=35  G1=31  F1=29  D1=26
;
; Song header format (12 bytes):
;   .db num_voices, tempo_div
;   .dw voice0_ptr, voice1_ptr, voice2_ptr, voice3_ptr, voice4_ptr
;
; Voice assignment:
;   Voice 0 = melody    (sample 0: square 50%)
;   Voice 1 = bass      (sample 2: triangle)
;   Voice 2 = pad 1     (sample 3: sawtooth)
;   Voice 3 = pad 2     (sample 3: sawtooth)
;   Voice 4 = arpeggio  (sample 0: square 50%)

; =====================================================================
; Song 0: "Office Hours" — Title Screen
; ~100 BPM, bossa nova / elevator muzak feel
; Progression: Cmaj | Amin | Dmin | G7 (repeat)
; tempo_div=8 → quarter=4, half=8, whole=16, eighth=2
; =====================================================================

spc_song_headers:

; Song 0 header (at SPC $1000, 12 bytes)
.db $05, $08                                        ; 5 voices, tempo divider 8
.dw _s0v0 - spc_song_headers + $1000                ; voice 0 (melody)
.dw _s0v1 - spc_song_headers + $1000                ; voice 1 (bass)
.dw _s0v2 - spc_song_headers + $1000                ; voice 2 (pad 1)
.dw _s0v3 - spc_song_headers + $1000                ; voice 3 (pad 2)
.dw _s0v4 - spc_song_headers + $1000                ; voice 4 (arpeggio)

; Song 1 header (at SPC $100C, 12 bytes)
.db $05, $0A                                        ; 5 voices, tempo divider 10
.dw _s1v0 - spc_song_headers + $1000                ; voice 0 (melody)
.dw _s1v1 - spc_song_headers + $1000                ; voice 1 (bass)
.dw _s1v2 - spc_song_headers + $1000                ; voice 2 (pad 1)
.dw _s1v3 - spc_song_headers + $1000                ; voice 3 (pad 2)
.dw _s1v4 - spc_song_headers + $1000                ; voice 4 (arpeggio)

; =====================================================================
; Song 0 Voice Data — "Office Hours"
; =====================================================================

; --- Voice 0: Melody (Square 50%) ---
; Gentle, lilting melody over the chord changes
; Mostly quarter and half notes, with rests for breathing room
_s0v0:
.db $FE                         ; loop point
; Bar 1: Cmaj — ascending thirds
.db 64, $04                     ; E4 quarter
.db 67, $04                     ; G4 quarter
.db 72, $08                     ; C5 half
; Bar 2: Amin — descending
.db 69, $04                     ; A4 quarter
.db 67, $04                     ; G4 quarter
.db 64, $08                     ; E4 half
; Bar 3: Dmin — stepwise motion
.db 62, $04                     ; D4 quarter
.db 65, $04                     ; F4 quarter
.db 69, $04                     ; A4 quarter
.db $80, $04                    ; rest quarter
; Bar 4: G7 — resolution approach
.db 67, $04                     ; G4 quarter
.db 71, $04                     ; B4 quarter
.db 72, $08                     ; C5 half
; Bar 5: Cmaj — variation
.db 72, $04                     ; C5 quarter
.db $80, $02                    ; rest eighth
.db 71, $02                     ; B4 eighth
.db 69, $04                     ; A4 quarter
.db 67, $04                     ; G4 quarter
; Bar 6: Amin — held note
.db 69, $08                     ; A4 half
.db 64, $08                     ; E4 half
; Bar 7: Dmin — pick up
.db 65, $04                     ; F4 quarter
.db 62, $04                     ; D4 quarter
.db $80, $08                    ; rest half
; Bar 8: G7 — leading back
.db 67, $06                     ; G4 dotted quarter
.db 65, $02                     ; F4 eighth
.db 64, $04                     ; E4 quarter
.db $80, $04                    ; rest quarter
.db $FF                         ; loop back

; --- Voice 1: Bass (Triangle) ---
; Steady root notes, whole notes per bar
_s0v1:
.db $FE                         ; loop point
; Bars 1-8: root notes, whole notes
.db 48, $10                     ; C3 whole  (Cmaj)
.db 45, $10                     ; A2 whole  (Amin)
.db 38, $10                     ; D2 whole  (Dmin)
.db 43, $10                     ; G2 whole  (G7)
.db 48, $10                     ; C3 whole  (Cmaj)
.db 45, $10                     ; A2 whole  (Amin)
.db 38, $10                     ; D2 whole  (Dmin)
.db 43, $10                     ; G2 whole  (G7)
.db $FF                         ; loop back

; --- Voice 2: Pad 1 (Sawtooth) ---
; Upper chord tones, sustained whole notes
_s0v2:
.db $FE                         ; loop point
; Bars 1-8: third of each chord
.db 64, $10                     ; E4 whole  (Cmaj: 3rd)
.db 60, $10                     ; C4 whole  (Amin: 3rd)
.db 65, $10                     ; F4 whole  (Dmin: 3rd)
.db 65, $10                     ; F4 whole  (G7: 7th)
.db 64, $10                     ; E4 whole  (Cmaj: 3rd)
.db 60, $10                     ; C4 whole  (Amin: 3rd)
.db 65, $10                     ; F4 whole  (Dmin: 3rd)
.db 65, $10                     ; F4 whole  (G7: 7th)
.db $FF                         ; loop back

; --- Voice 3: Pad 2 (Sawtooth) ---
; Lower chord tones, sustained whole notes
_s0v3:
.db $FE                         ; loop point
; Bars 1-8: fifth of each chord
.db 67, $10                     ; G4 whole  (Cmaj: 5th)
.db 64, $10                     ; E4 whole  (Amin: 5th)
.db 69, $10                     ; A4 whole  (Dmin: 5th)
.db 67, $10                     ; G4 whole  (G7: root)
.db 67, $10                     ; G4 whole  (Cmaj: 5th)
.db 64, $10                     ; E4 whole  (Amin: 5th)
.db 69, $10                     ; A4 whole  (Dmin: 5th)
.db 67, $10                     ; G4 whole  (G7: root)
.db $FF                         ; loop back

; --- Voice 4: Arpeggio (Square 50%) ---
; Quick arpeggiated chord tones, eighth notes
; Gives a bossa nova rhythmic feel
_s0v4:
.db $FE                         ; loop point
; Bar 1: Cmaj arpeggio
.db 60, $02                     ; C4 eighth
.db 64, $02                     ; E4 eighth
.db 67, $02                     ; G4 eighth
.db 72, $02                     ; C5 eighth
.db 67, $02                     ; G4 eighth
.db 64, $02                     ; E4 eighth
.db 60, $02                     ; C4 eighth
.db $80, $02                    ; rest eighth
; Bar 2: Amin arpeggio
.db 57, $02                     ; A3 eighth
.db 60, $02                     ; C4 eighth
.db 64, $02                     ; E4 eighth
.db 69, $02                     ; A4 eighth
.db 64, $02                     ; E4 eighth
.db 60, $02                     ; C4 eighth
.db 57, $02                     ; A3 eighth
.db $80, $02                    ; rest eighth
; Bar 3: Dmin arpeggio
.db 62, $02                     ; D4 eighth
.db 65, $02                     ; F4 eighth
.db 69, $02                     ; A4 eighth
.db 74, $02                     ; D5 eighth
.db 69, $02                     ; A4 eighth
.db 65, $02                     ; F4 eighth
.db 62, $02                     ; D4 eighth
.db $80, $02                    ; rest eighth
; Bar 4: G7 arpeggio
.db 55, $02                     ; G3 eighth
.db 59, $02                     ; B3 eighth
.db 62, $02                     ; D4 eighth
.db 65, $02                     ; F4 eighth
.db 62, $02                     ; D4 eighth
.db 59, $02                     ; B3 eighth
.db 55, $02                     ; G3 eighth
.db $80, $02                    ; rest eighth
; Bar 5: Cmaj arpeggio (variation — descending start)
.db 72, $02                     ; C5 eighth
.db 67, $02                     ; G4 eighth
.db 64, $02                     ; E4 eighth
.db 60, $02                     ; C4 eighth
.db 64, $02                     ; E4 eighth
.db 67, $02                     ; G4 eighth
.db 72, $02                     ; C5 eighth
.db $80, $02                    ; rest eighth
; Bar 6: Amin arpeggio (variation)
.db 69, $02                     ; A4 eighth
.db 64, $02                     ; E4 eighth
.db 60, $02                     ; C4 eighth
.db 57, $02                     ; A3 eighth
.db 60, $02                     ; C4 eighth
.db 64, $02                     ; E4 eighth
.db 69, $02                     ; A4 eighth
.db $80, $02                    ; rest eighth
; Bar 7: Dmin arpeggio (sparse)
.db 62, $02                     ; D4 eighth
.db 65, $02                     ; F4 eighth
.db 69, $02                     ; A4 eighth
.db $80, $02                    ; rest eighth
.db $80, $02                    ; rest eighth
.db 69, $02                     ; A4 eighth
.db 65, $02                     ; F4 eighth
.db 62, $02                     ; D4 eighth
; Bar 8: G7 arpeggio (leading back)
.db 55, $02                     ; G3 eighth
.db 59, $02                     ; B3 eighth
.db 62, $02                     ; D4 eighth
.db 67, $02                     ; G4 eighth
.db 71, $02                     ; B4 eighth
.db 67, $02                     ; G4 eighth
.db 62, $02                     ; D4 eighth
.db $80, $02                    ; rest eighth
.db $FF                         ; loop back

; =====================================================================
; Song 1 Voice Data — "Desk Work" (Editor BGM)
; ~80 BPM, subdued and unobtrusive
; Progression: Fmaj | Dm7 | Bbmaj | C7 (repeat)
; tempo_div=10 → quarter=4, half=8, whole=16
; =====================================================================

; --- Voice 0: Melody (Square 50%) ---
; Very sparse — mostly rests with occasional gentle phrases
_s1v0:
.db $FE                         ; loop point
; Bar 1: Fmaj — simple opening
.db $80, $08                    ; rest half
.db 65, $04                     ; F4 quarter
.db 69, $04                     ; A4 quarter
; Bar 2: Dm7 — sustained
.db 74, $08                     ; D5 half
.db $80, $08                    ; rest half
; Bar 3: Bbmaj — gentle descent
.db $80, $08                    ; rest half
.db 72, $04                     ; C5 quarter
.db 70, $04                     ; Bb4 quarter
; Bar 4: C7 — resolve
.db 69, $04                     ; A4 quarter
.db 67, $04                     ; G4 quarter
.db $80, $08                    ; rest half
; Bar 5: Fmaj — variation
.db 72, $04                     ; C5 quarter
.db $80, $04                    ; rest quarter
.db 69, $04                     ; A4 quarter
.db $80, $04                    ; rest quarter
; Bar 6: Dm7 — held
.db 65, $10                     ; F4 whole
; Bar 7: Bbmaj — rest
.db $80, $10                    ; rest whole
; Bar 8: C7 — pickup
.db $80, $08                    ; rest half
.db 64, $04                     ; E4 quarter
.db 65, $04                     ; F4 quarter
.db $FF                         ; loop back

; --- Voice 1: Bass (Triangle) ---
; Steady root notes, whole notes
_s1v1:
.db $FE                         ; loop point
.db 41, $10                     ; F2 whole  (Fmaj)
.db 38, $10                     ; D2 whole  (Dm7)
.db 34, $10                     ; Bb1 whole (Bbmaj)
.db 36, $10                     ; C2 whole  (C7)
.db 41, $10                     ; F2 whole  (Fmaj)
.db 38, $10                     ; D2 whole  (Dm7)
.db 34, $10                     ; Bb1 whole (Bbmaj)
.db 36, $10                     ; C2 whole  (C7)
.db $FF                         ; loop back

; --- Voice 2: Pad 1 (Sawtooth) ---
; Third of each chord, very soft sustained
_s1v2:
.db $FE                         ; loop point
.db 69, $10                     ; A4 whole  (Fmaj: 3rd)
.db 65, $10                     ; F4 whole  (Dm7: 3rd)
.db 62, $10                     ; D4 whole  (Bbmaj: 3rd)
.db 64, $10                     ; E4 whole  (C7: 3rd)
.db 69, $10                     ; A4 whole  (Fmaj: 3rd)
.db 65, $10                     ; F4 whole  (Dm7: 3rd)
.db 62, $10                     ; D4 whole  (Bbmaj: 3rd)
.db 64, $10                     ; E4 whole  (C7: 3rd)
.db $FF                         ; loop back

; --- Voice 3: Pad 2 (Sawtooth) ---
; Fifth of each chord, sustained
_s1v3:
.db $FE                         ; loop point
.db 72, $10                     ; C5 whole  (Fmaj: 5th)
.db 69, $10                     ; A4 whole  (Dm7: 5th)
.db 65, $10                     ; F4 whole  (Bbmaj: 5th)
.db 70, $10                     ; Bb4 whole (C7: 7th)
.db 72, $10                     ; C5 whole  (Fmaj: 5th)
.db 69, $10                     ; A4 whole  (Dm7: 5th)
.db 65, $10                     ; F4 whole  (Bbmaj: 5th)
.db 70, $10                     ; Bb4 whole (C7: 7th)
.db $FF                         ; loop back

; --- Voice 4: Arpeggio (Square 50%) ---
; Minimal — sparse eighth-note patterns with lots of rests
_s1v4:
.db $FE                         ; loop point
; Bar 1: Fmaj — gentle pulse
.db 60, $02                     ; C4 eighth
.db $80, $02                    ; rest
.db 65, $02                     ; F4 eighth
.db $80, $02                    ; rest
.db 69, $02                     ; A4 eighth
.db $80, $02                    ; rest
.db $80, $04                    ; rest quarter
; Bar 2: Dm7 — sparse
.db $80, $04                    ; rest quarter
.db 62, $02                     ; D4 eighth
.db $80, $02                    ; rest
.db 65, $02                     ; F4 eighth
.db $80, $02                    ; rest
.db $80, $04                    ; rest quarter
; Bar 3: Bbmaj — gentle pulse
.db 58, $02                     ; Bb3 eighth
.db $80, $02                    ; rest
.db 62, $02                     ; D4 eighth
.db $80, $02                    ; rest
.db 65, $02                     ; F4 eighth
.db $80, $02                    ; rest
.db $80, $04                    ; rest quarter
; Bar 4: C7 — sparse
.db $80, $04                    ; rest quarter
.db 60, $02                     ; C4 eighth
.db $80, $02                    ; rest
.db 64, $02                     ; E4 eighth
.db $80, $02                    ; rest
.db $80, $04                    ; rest quarter
; Bars 5-8: mostly rest for contrast
; Bar 5: Fmaj
.db $80, $08                    ; rest half
.db 65, $02                     ; F4 eighth
.db 69, $02                     ; A4 eighth
.db $80, $04                    ; rest quarter
; Bar 6: Dm7
.db $80, $10                    ; rest whole
; Bar 7: Bbmaj
.db $80, $08                    ; rest half
.db 58, $02                     ; Bb3 eighth
.db 62, $02                     ; D4 eighth
.db $80, $04                    ; rest quarter
; Bar 8: C7
.db $80, $10                    ; rest whole
.db $FF                         ; loop back

spc_songs_end:

; Total song data size: spc_songs_end - spc_song_headers
; Must fit within $1000-$1FFF (4 KB max)
