; ============================================================================
; audio.asm — 65816-Side Audio System
;
; Provides:
;   - IPL upload routine to transfer SPC700 driver + data to audio RAM
;   - Public API for music, SFX, and volume control
;
; Data labels (defined in spc/*.asm, same bank):
;   spc_driver_start / spc_driver_end   — driver binary (target: SPC $0200)
;   spc_song_headers / spc_songs_end    — music data (target: SPC $1000)
;   spc_sample_dir / spc_sample_data_end — samples (target: SPC $2000)
;
; Command protocol (post-boot):
;   Port 0 ($2140): command counter (SPC700 detects changes)
;   Port 1 ($2141): command byte
;   Port 2 ($2142): parameter byte
;   Port 3 ($2143): unused by CPU; SPC700 echoes counter here
; ============================================================================

; --- SPC700 target addresses ---
.define SPC_DRIVER_DEST  $0200       ; Driver code destination in SPC RAM
.define SPC_SONG_DEST    $1000       ; Song data destination in SPC RAM
.define SPC_SAMPLE_DEST  $2000       ; Sample dir + data destination in SPC RAM
.define SPC_EXEC_ADDR    $0200       ; Driver entry point in SPC RAM

; --- Audio command bytes ---
.define CMD_PLAY_MUSIC   $01
.define CMD_STOP_MUSIC   $02
.define CMD_PLAY_SFX     $10
.define CMD_SET_VOLUME   $20

; --- SFX IDs ---
.define SFX_MENU_SEL     0
.define SFX_KEY_CLICK    1
.define SFX_SAVE_OK      2
.define SFX_ERROR        3
.define SFX_DELETE        4

; --- Song IDs ---
.define SONG_TITLE       0
.define SONG_EDITOR      1

; --- Audio variable (DP) ---
; Uses $E2 — first free byte after bg1_scroll_y ($E1)
.define audio_cmd_ctr    $E2         ; Command counter (SPC700 detects changes)

; ============================================================================
; audio_init — Upload driver + data to SPC700 and start execution
;
; Uploads three blocks via the IPL boot protocol:
;   Block 1: spc_driver_start → SPC $0200  (driver + SFX/pitch tables)
;   Block 2: spc_song_headers → SPC $1000  (music sequence data)
;   Block 3: spc_sample_dir   → SPC $2000  (sample directory + BRR data)
; Then issues execute command at SPC $0200.
;
; Entry: 8-bit A, 8-bit X/Y
; Exit:  8-bit A, 8-bit X/Y
; Clobbers: all registers
; ============================================================================
audio_init:
    .ACCU 8
    .INDEX 8

    ; Reset command counter
    stz audio_cmd_ctr.w

    ; ---- Step 1: Wait for SPC700 IPL ready ($BBAA) ----
    rep #$30
    .ACCU 16
    .INDEX 16
    lda #$BBAA
@wait_ready:
    cmp APUIO0.w
    bne @wait_ready

    sep #$20
    .ACCU 8

    ; ---- Step 2: Upload block 1 — Driver → SPC $0200 ----
    ldx #spc_driver_start            ; ROM source address (16-bit)
    ldy #(spc_driver_end - spc_driver_start)  ; byte count (16-bit)
    lda #<SPC_DRIVER_DEST            ; SPC dest low
    sta APUIO2.w
    lda #>SPC_DRIVER_DEST            ; SPC dest high
    sta APUIO3.w
    lda #$01                         ; Non-zero = data follows
    sta APUIO1.w
    lda #$CC                         ; Initial counter (must differ from $AA)
    sta APUIO0.w
@wait_ack1:
    cmp APUIO0.w                     ; Wait for SPC700 to echo counter
    bne @wait_ack1

    ; Transfer block 1 bytes
    jsr _apu_transfer_block

    ; ---- Step 3: Upload block 2 — Songs → SPC $1000 ----
    ldx #spc_song_headers
    ldy #(spc_songs_end - spc_song_headers)
    lda #<SPC_SONG_DEST
    sta APUIO2.w
    lda #>SPC_SONG_DEST
    sta APUIO3.w
    ; Port 1 must be non-zero for data block
    lda #$01
    sta APUIO1.w
    ; Increment counter from last value + 2 (must differ, and non-zero low nibble)
    lda APUIO0.w                     ; Read current echo
    clc
    adc #$02
    bne +
    adc #$01                         ; Skip zero — counter must be non-zero start
+
    sta APUIO0.w
@wait_ack2:
    cmp APUIO0.w
    bne @wait_ack2

    ; Transfer block 2 bytes
    jsr _apu_transfer_block

    ; ---- Step 4: Upload block 3 — Samples → SPC $2000 ----
    ldx #spc_sample_dir
    ldy #(spc_sample_data_end - spc_sample_dir)
    lda #<SPC_SAMPLE_DEST
    sta APUIO2.w
    lda #>SPC_SAMPLE_DEST
    sta APUIO3.w
    lda #$01
    sta APUIO1.w
    lda APUIO0.w
    clc
    adc #$02
    bne +
    adc #$01
+
    sta APUIO0.w
@wait_ack3:
    cmp APUIO0.w
    bne @wait_ack3

    ; Transfer block 3 bytes
    jsr _apu_transfer_block

    ; ---- Step 5: Execute at SPC $0200 ----
    lda #<SPC_EXEC_ADDR
    sta APUIO2.w
    lda #>SPC_EXEC_ADDR
    sta APUIO3.w
    stz APUIO1.w                     ; Zero = execute (no more data)
    lda APUIO0.w                     ; Read current echo
    clc
    adc #$02
    bne +
    adc #$01
+
    sta APUIO0.w
@wait_exec:
    cmp APUIO0.w
    bne @wait_exec

    ; Restore 8-bit X/Y
    sep #$10
    .INDEX 8

    rts

; ============================================================================
; _apu_transfer_block — Transfer bytes to SPC700 via IPL protocol
;
; Entry: X (16-bit) = ROM source address
;        Y (16-bit) = byte count
;        SPC700 is waiting for data (initial handshake done)
;        8-bit A, 16-bit X/Y
; Exit:  X advanced past data, Y = 0
;        A = last counter value written to APUIO0
; Clobbers: A, X, Y
;
; Protocol: For each byte, write data to port 1, counter to port 0,
;           wait for echo on port 0, then increment counter.
; ============================================================================
_apu_transfer_block:
    .ACCU 8
    .INDEX 16

    ; Y = bytes remaining, X = source pointer
    ; Counter starts at 0 for first byte in this block
    lda #$00                         ; Byte counter starts at 0
    pha                              ; Save counter on stack

    ; We'll iterate: read byte from ROM[X], write to port 1,
    ; write counter to port 0, wait for echo, inc counter, inc X, dec Y
@xfer_loop:
    cpy #$0000
    beq @xfer_done

    lda $0000.w,X                    ; Read byte from ROM (bank 0)
    sta APUIO1.w                     ; Write data to port 1

    pla                              ; Pull counter
    sta APUIO0.w                     ; Write counter to port 0
@wait_echo:
    cmp APUIO0.w                     ; Wait for SPC700 to echo
    bne @wait_echo

    clc
    adc #$01                         ; Increment counter
    pha                              ; Save updated counter

    inx                              ; Advance source pointer
    dey                              ; Decrement byte count
    bra @xfer_loop

@xfer_done:
    pla                              ; Clean up counter from stack
    rts

; ============================================================================
; _audio_send_cmd — Send a command to the SPC700 driver
;
; Entry: A = command byte, X = parameter byte
;        8-bit A, 8-bit X/Y
; Exit:  8-bit A, 8-bit X/Y
; Clobbers: A
;
; Protocol: Write param to port 2, cmd to port 1, increment counter
;           and write to port 0. Fire-and-forget (no echo wait).
; ============================================================================
_audio_send_cmd:
    .ACCU 8
    .INDEX 8

    sta APUIO1.w                     ; Command byte
    stx APUIO2.w                     ; Parameter byte
    inc audio_cmd_ctr.w              ; Increment command counter
    lda audio_cmd_ctr.w
    sta APUIO0.w                     ; Trigger: SPC700 sees counter change
    rts

; ============================================================================
; play_music — Start background music
;
; Entry: A = song ID (SONG_TITLE, SONG_EDITOR, etc.)
;        8-bit A, 8-bit X/Y
; Exit:  8-bit A, 8-bit X/Y
; ============================================================================
play_music:
    .ACCU 8
    .INDEX 8

    tax                              ; Parameter = song ID
    lda #CMD_PLAY_MUSIC              ; Command byte
    jsr _audio_send_cmd
    rts

; ============================================================================
; stop_music — Stop background music
;
; Entry: 8-bit A, 8-bit X/Y
; Exit:  8-bit A, 8-bit X/Y
; ============================================================================
stop_music:
    .ACCU 8
    .INDEX 8

    ldx #$00                         ; No parameter
    lda #CMD_STOP_MUSIC
    jsr _audio_send_cmd
    rts

; ============================================================================
; play_sfx — Play a sound effect
;
; Entry: A = SFX ID (SFX_MENU_SEL, SFX_KEY_CLICK, etc.)
;        8-bit A, 8-bit X/Y
; Exit:  8-bit A, 8-bit X/Y
; ============================================================================
play_sfx:
    .ACCU 8
    .INDEX 8

    tax                              ; Parameter = SFX ID
    lda #CMD_PLAY_SFX                ; Command byte
    jsr _audio_send_cmd
    rts

; ============================================================================
; set_volume — Set master volume
;
; Entry: A = volume level (0-127, where 0=silent, 127=max)
;        8-bit A, 8-bit X/Y
; Exit:  8-bit A, 8-bit X/Y
; ============================================================================
set_volume:
    .ACCU 8
    .INDEX 8

    tax                              ; Parameter = volume
    lda #CMD_SET_VOLUME              ; Command byte
    jsr _audio_send_cmd
    rts
