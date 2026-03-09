; spc/driver.asm -- SPC700 Sound Driver (hand-assembled binary)
; Uploaded to SPC700 RAM at $0200 via IPL protocol
;
; This file contains .db byte blocks encoding SPC700 machine code.
; Each line shows the SPC700 address, mnemonic, and operands.
;
; Voice allocation: 0=melody, 1=bass, 2=pad1, 3=pad2, 4=arpeggio, 5=SFX
; Timer 0: 125 Hz (~8ms/tick). Music data at SPC $1000+.
; Sample directory at $2000, BRR samples at $2100+.
;
; Direct Page Variables ($00-$2B):
;   $00       cmd_byte
;   $01       cmd_param
;   $02       last_cmd_id
;   $03       music_playing (0/1/2)
;   $04       current_song
;   $05       master_vol
;   $06       tick_counter
;   $07       tempo_div
;   $08-$0C   voice 0-4 duration counters
;   $0D-$11   voice 0-4 seq ptr low
;   $12-$16   voice 0-4 seq ptr high
;   $17       sfx_active
;   $18       sfx_duration
;   $19       sfx_step
;   $1A       kon_shadow
;   $1B       koff_shadow
;   $1C-$20   voice 0-4 loop ptr low
;   $21-$25   voice 0-4 loop ptr high
;   $26       temp_ptr_lo
;   $27       temp_ptr_hi
;   $28       temp_note
;   $29       temp (pitch_hi)
;   $2A       temp (pitch_lo)
;   $2B       temp (DSP base)

; =====================================================================
; INIT — $0200
; =====================================================================
spc_driver_start:

.db $CD, $EF                       ; $0200: MOV X, #$EF  ; stack at $01EF
.db $BD                            ; $0202: MOV SP, X
; --- Clear direct page $00-$2B ---
.db $E8, $00                       ; $0203: MOV A, #$00
.db $CD, $00                       ; $0205: MOV X, #$00
.db $C6                            ; $0207: MOV (X), A
.db $3D                            ; $0208: INC X
.db $C8, $2C                       ; $0209: CMP X, #$2C
.db $D0, $FA                       ; $020B: BNE _clear_dp
.db $8F, $28, $05                  ; $020D: MOV $05, #$28  ; master_vol = 40
; --- DSP init ---
.db $8F, $6C, $F2                  ; $0210: MOV $F2, #$6C  ; FLG: echo off, mute/reset OFF
.db $8F, $20, $F3                  ; $0213: MOV $F3, #$20
.db $8F, $0C, $F2                  ; $0216: MOV $F2, #$0C  ; MVOLL=40
.db $8F, $28, $F3                  ; $0219: MOV $F3, #$28
.db $8F, $1C, $F2                  ; $021C: MOV $F2, #$1C  ; MVOLR=40
.db $8F, $28, $F3                  ; $021F: MOV $F3, #$28
.db $8F, $2C, $F2                  ; $0222: MOV $F2, #$2C  ; EVOLL=0
.db $8F, $00, $F3                  ; $0225: MOV $F3, #$00
.db $8F, $3C, $F2                  ; $0228: MOV $F2, #$3C  ; EVOLR=0
.db $8F, $00, $F3                  ; $022B: MOV $F3, #$00
.db $8F, $5D, $F2                  ; $022E: MOV $F2, #$5D  ; DIR=$20
.db $8F, $20, $F3                  ; $0231: MOV $F3, #$20
.db $8F, $6D, $F2                  ; $0234: MOV $F2, #$6D  ; ESA=$40
.db $8F, $40, $F3                  ; $0237: MOV $F3, #$40
.db $8F, $7D, $F2                  ; $023A: MOV $F2, #$7D  ; EDL=0
.db $8F, $00, $F3                  ; $023D: MOV $F3, #$00
.db $8F, $3D, $F2                  ; $0240: MOV $F2, #$3D  ; NON=0
.db $8F, $00, $F3                  ; $0243: MOV $F3, #$00
.db $8F, $4D, $F2                  ; $0246: MOV $F2, #$4D  ; EON=0
.db $8F, $00, $F3                  ; $0249: MOV $F3, #$00
.db $8F, $5C, $F2                  ; $024C: MOV $F2, #$5C  ; KOFF all
.db $8F, $FF, $F3                  ; $024F: MOV $F3, #$FF
; --- Clear voice volumes ---
.db $CD, $00                       ; $0252: MOV X, #$00
.db $7D                            ; $0254: MOV A, X
.db $C4, $F2                       ; $0255: MOV $F2, A  ; VOLL
.db $8F, $00, $F3                  ; $0257: MOV $F3, #$00
.db $7D                            ; $025A: MOV A, X
.db $08, $01                       ; $025B: OR A, #$01
.db $C4, $F2                       ; $025D: MOV $F2, A  ; VOLR
.db $8F, $00, $F3                  ; $025F: MOV $F3, #$00
.db $60                            ; $0262: CLRC
.db $7D                            ; $0263: MOV A, X
.db $88, $10                       ; $0264: ADC A, #$10
.db $5D                            ; $0266: MOV X, A
.db $C8, $80                       ; $0267: CMP X, #$80
.db $D0, $E9                       ; $0269: BNE _clr_vol
; --- Timer 0 ---
.db $8F, $40, $FA                  ; $026B: MOV $FA, #$40  ; 125 Hz
.db $8F, $01, $F1                  ; $026E: MOV $F1, #$01  ; T0 on, IPL off
; --- Clear ports ---
.db $8F, $00, $F4                  ; $0271: MOV $F4, #$00
.db $8F, $00, $F5                  ; $0274: MOV $F5, #$00
.db $8F, $00, $F6                  ; $0277: MOV $F6, #$00
.db $E4, $FD                       ; $027A: MOV A, $FD  ; clear T0OUT

; =====================================================================
; MAIN LOOP — $027C
; =====================================================================

.db $E4, $FD                       ; $027C: MOV A, $FD  ; read T0OUT
.db $F0, $03                       ; $027E: BEQ _skip_tick
.db $3F, $CA, $04                  ; $0280: CALL !tick_handler
.db $E4, $F4                       ; $0283: MOV A, $F4  ; read CPUIO0
.db $64, $02                       ; $0285: CMP A, $02  ; vs last_cmd_id
.db $F0, $F3                       ; $0287: BEQ _main_loop
; --- New command (port 0=counter, port 1=cmd, port 2=param) ---
.db $C4, $02                       ; $0289: MOV $02, A  ; last_cmd_id = counter
.db $C4, $F6                       ; $028B: MOV $F6, A  ; ack via port 2 out
.db $E4, $F6                       ; $028D: MOV A, $F6  ; read port 2 in = param
.db $C4, $01                       ; $028F: MOV $01, A  ; cmd_param
.db $E4, $F5                       ; $0291: MOV A, $F5  ; read port 1 = cmd byte
.db $C4, $00                       ; $0293: MOV $00, A  ; cmd_byte
.db $00, $00                       ; $0295: NOP; NOP     ; pad (same size)
; --- Dispatch ---
.db $F0, $34                       ; $0297: BEQ _done  ; NOP
.db $68, $01                       ; $0299: CMP A, #$01  ; play_music
.db $D0, $03                       ; $029B: BNE +3
.db $3F, $D0, $02                  ; $029D: CALL !cmd_play_music
.db $E4, $00                       ; $02A0: MOV A, $00
.db $68, $02                       ; $02A2: CMP A, #$02  ; stop_music
.db $D0, $03                       ; $02A4: BNE +3
.db $3F, $D4, $03                  ; $02A6: CALL !cmd_stop_music
.db $E4, $00                       ; $02A9: MOV A, $00
.db $68, $03                       ; $02AB: CMP A, #$03  ; pause_music
.db $D0, $03                       ; $02AD: BNE +3
.db $3F, $1A, $04                  ; $02AF: CALL !cmd_pause_music
.db $E4, $00                       ; $02B2: MOV A, $00
.db $68, $04                       ; $02B4: CMP A, #$04  ; resume
.db $D0, $03                       ; $02B6: BNE +3
.db $3F, $24, $04                  ; $02B8: CALL !cmd_resume
.db $E4, $00                       ; $02BB: MOV A, $00
.db $68, $10                       ; $02BD: CMP A, #$10  ; play_sfx
.db $D0, $03                       ; $02BF: BNE +3
.db $3F, $64, $04                  ; $02C1: CALL !cmd_play_sfx
.db $E4, $00                       ; $02C4: MOV A, $00
.db $68, $20                       ; $02C6: CMP A, #$20  ; set_volume
.db $D0, $03                       ; $02C8: BNE +3
.db $3F, $BB, $04                  ; $02CA: CALL !cmd_set_volume
.db $5F, $7C, $02                  ; $02CD: JMP !_main_loop

; === CMD_PLAY_MUSIC — $02D0 ===
; Song header at $1000+songID*12: [nvoices, tempo, 5x ptr_lo/hi]

.db $8F, $5C, $F2                  ; $02D0: MOV $F2, #$5C
.db $8F, $1F, $F3                  ; $02D3: MOV $F3, #$1F  ; KOFF 0-4
.db $E4, $01                       ; $02D6: MOV A, $01
.db $C4, $04                       ; $02D8: MOV $04, A  ; current_song
.db $8D, $0C                       ; $02DA: MOV Y, #$0C
.db $CF                            ; $02DC: MUL YA
.db $5D                            ; $02DD: MOV X, A  ; header offset
.db $F5, $01, $10                  ; $02DE: MOV A, !$1001+X  ; tempo
.db $C4, $07                       ; $02E1: MOV $07, A
.db $C4, $06                       ; $02E3: MOV $06, A
.db $F5, $02, $10                  ; $02E5: MOV A, !$1002+X  ; v0 ptr lo
.db $C4, $0D                       ; $02E8: MOV $0D, A
.db $C4, $1C                       ; $02EA: MOV $1C, A  ; loop lo
.db $F5, $03, $10                  ; $02EC: MOV A, !$1003+X  ; v0 ptr hi
.db $C4, $12                       ; $02EF: MOV $12, A
.db $C4, $21                       ; $02F1: MOV $21, A  ; loop hi
.db $F5, $04, $10                  ; $02F3: MOV A, !$1004+X  ; v1 ptr lo
.db $C4, $0E                       ; $02F6: MOV $0E, A
.db $C4, $1D                       ; $02F8: MOV $1D, A  ; loop lo
.db $F5, $05, $10                  ; $02FA: MOV A, !$1005+X  ; v1 ptr hi
.db $C4, $13                       ; $02FD: MOV $13, A
.db $C4, $22                       ; $02FF: MOV $22, A  ; loop hi
.db $F5, $06, $10                  ; $0301: MOV A, !$1006+X  ; v2 ptr lo
.db $C4, $0F                       ; $0304: MOV $0F, A
.db $C4, $1E                       ; $0306: MOV $1E, A  ; loop lo
.db $F5, $07, $10                  ; $0308: MOV A, !$1007+X  ; v2 ptr hi
.db $C4, $14                       ; $030B: MOV $14, A
.db $C4, $23                       ; $030D: MOV $23, A  ; loop hi
.db $F5, $08, $10                  ; $030F: MOV A, !$1008+X  ; v3 ptr lo
.db $C4, $10                       ; $0312: MOV $10, A
.db $C4, $1F                       ; $0314: MOV $1F, A  ; loop lo
.db $F5, $09, $10                  ; $0316: MOV A, !$1009+X  ; v3 ptr hi
.db $C4, $15                       ; $0319: MOV $15, A
.db $C4, $24                       ; $031B: MOV $24, A  ; loop hi
.db $F5, $0A, $10                  ; $031D: MOV A, !$100A+X  ; v4 ptr lo
.db $C4, $11                       ; $0320: MOV $11, A
.db $C4, $20                       ; $0322: MOV $20, A  ; loop lo
.db $F5, $0B, $10                  ; $0324: MOV A, !$100B+X  ; v4 ptr hi
.db $C4, $16                       ; $0327: MOV $16, A
.db $C4, $25                       ; $0329: MOV $25, A  ; loop hi
.db $8F, $01, $08                  ; $032B: MOV $08, #$01  ; dur=1
.db $8F, $01, $09                  ; $032E: MOV $09, #$01  ; dur=1
.db $8F, $01, $0A                  ; $0331: MOV $0A, #$01  ; dur=1
.db $8F, $01, $0B                  ; $0334: MOV $0B, #$01  ; dur=1
.db $8F, $01, $0C                  ; $0337: MOV $0C, #$01  ; dur=1
; V0 melody
.db $8F, $04, $F2                  ; $033A: MOV $F2, #$04
.db $8F, $00, $F3                  ; $033D: MOV $F3, #$00  ; SRCN
.db $8F, $05, $F2                  ; $0340: MOV $F2, #$05
.db $8F, $BA, $F3                  ; $0343: MOV $F3, #$BA  ; ADSR1
.db $8F, $06, $F2                  ; $0346: MOV $F2, #$06
.db $8F, $AA, $F3                  ; $0349: MOV $F3, #$AA  ; ADSR2
.db $8F, $00, $F2                  ; $034C: MOV $F2, #$00
.db $8F, $20, $F3                  ; $034F: MOV $F3, #$20  ; VOLL
.db $8F, $01, $F2                  ; $0352: MOV $F2, #$01
.db $8F, $20, $F3                  ; $0355: MOV $F3, #$20  ; VOLR
; V1 bass
.db $8F, $14, $F2                  ; $0358: MOV $F2, #$14
.db $8F, $02, $F3                  ; $035B: MOV $F3, #$02  ; SRCN
.db $8F, $15, $F2                  ; $035E: MOV $F2, #$15
.db $8F, $E8, $F3                  ; $0361: MOV $F3, #$E8  ; ADSR1
.db $8F, $16, $F2                  ; $0364: MOV $F2, #$16
.db $8F, $C8, $F3                  ; $0367: MOV $F3, #$C8  ; ADSR2
.db $8F, $10, $F2                  ; $036A: MOV $F2, #$10
.db $8F, $28, $F3                  ; $036D: MOV $F3, #$28  ; VOLL
.db $8F, $11, $F2                  ; $0370: MOV $F2, #$11
.db $8F, $28, $F3                  ; $0373: MOV $F3, #$28  ; VOLR
; V2 pad1
.db $8F, $24, $F2                  ; $0376: MOV $F2, #$24
.db $8F, $03, $F3                  ; $0379: MOV $F3, #$03  ; SRCN
.db $8F, $25, $F2                  ; $037C: MOV $F2, #$25
.db $8F, $E6, $F3                  ; $037F: MOV $F3, #$E6  ; ADSR1
.db $8F, $26, $F2                  ; $0382: MOV $F2, #$26
.db $8F, $A6, $F3                  ; $0385: MOV $F3, #$A6  ; ADSR2
.db $8F, $20, $F2                  ; $0388: MOV $F2, #$20
.db $8F, $18, $F3                  ; $038B: MOV $F3, #$18  ; VOLL
.db $8F, $21, $F2                  ; $038E: MOV $F2, #$21
.db $8F, $18, $F3                  ; $0391: MOV $F3, #$18  ; VOLR
; V3 pad2
.db $8F, $34, $F2                  ; $0394: MOV $F2, #$34
.db $8F, $03, $F3                  ; $0397: MOV $F3, #$03  ; SRCN
.db $8F, $35, $F2                  ; $039A: MOV $F2, #$35
.db $8F, $E6, $F3                  ; $039D: MOV $F3, #$E6  ; ADSR1
.db $8F, $36, $F2                  ; $03A0: MOV $F2, #$36
.db $8F, $A6, $F3                  ; $03A3: MOV $F3, #$A6  ; ADSR2
.db $8F, $30, $F2                  ; $03A6: MOV $F2, #$30
.db $8F, $18, $F3                  ; $03A9: MOV $F3, #$18  ; VOLL
.db $8F, $31, $F2                  ; $03AC: MOV $F2, #$31
.db $8F, $18, $F3                  ; $03AF: MOV $F3, #$18  ; VOLR
; V4 arp
.db $8F, $44, $F2                  ; $03B2: MOV $F2, #$44
.db $8F, $00, $F3                  ; $03B5: MOV $F3, #$00  ; SRCN
.db $8F, $45, $F2                  ; $03B8: MOV $F2, #$45
.db $8F, $CC, $F3                  ; $03BB: MOV $F3, #$CC  ; ADSR1
.db $8F, $46, $F2                  ; $03BE: MOV $F2, #$46
.db $8F, $6C, $F3                  ; $03C1: MOV $F3, #$6C  ; ADSR2
.db $8F, $40, $F2                  ; $03C4: MOV $F2, #$40
.db $8F, $18, $F3                  ; $03C7: MOV $F3, #$18  ; VOLL
.db $8F, $41, $F2                  ; $03CA: MOV $F2, #$41
.db $8F, $18, $F3                  ; $03CD: MOV $F3, #$18  ; VOLR
.db $8F, $01, $03                  ; $03D0: MOV $03, #$01  ; playing=1
.db $6F                            ; $03D3: RET

; === CMD_STOP_MUSIC — $03D4 ===

.db $8F, $5C, $F2                  ; $03D4: MOV $F2, #$5C
.db $8F, $1F, $F3                  ; $03D7: MOV $F3, #$1F  ; KOFF 0-4
.db $8F, $00, $F2                  ; $03DA: MOV $F2, #$00
.db $8F, $00, $F3                  ; $03DD: MOV $F3, #$00  ; V0VOLL=0
.db $8F, $01, $F2                  ; $03E0: MOV $F2, #$01
.db $8F, $00, $F3                  ; $03E3: MOV $F3, #$00  ; V0VOLR=0
.db $8F, $10, $F2                  ; $03E6: MOV $F2, #$10
.db $8F, $00, $F3                  ; $03E9: MOV $F3, #$00  ; V1VOLL=0
.db $8F, $11, $F2                  ; $03EC: MOV $F2, #$11
.db $8F, $00, $F3                  ; $03EF: MOV $F3, #$00  ; V1VOLR=0
.db $8F, $20, $F2                  ; $03F2: MOV $F2, #$20
.db $8F, $00, $F3                  ; $03F5: MOV $F3, #$00  ; V2VOLL=0
.db $8F, $21, $F2                  ; $03F8: MOV $F2, #$21
.db $8F, $00, $F3                  ; $03FB: MOV $F3, #$00  ; V2VOLR=0
.db $8F, $30, $F2                  ; $03FE: MOV $F2, #$30
.db $8F, $00, $F3                  ; $0401: MOV $F3, #$00  ; V3VOLL=0
.db $8F, $31, $F2                  ; $0404: MOV $F2, #$31
.db $8F, $00, $F3                  ; $0407: MOV $F3, #$00  ; V3VOLR=0
.db $8F, $40, $F2                  ; $040A: MOV $F2, #$40
.db $8F, $00, $F3                  ; $040D: MOV $F3, #$00  ; V4VOLL=0
.db $8F, $41, $F2                  ; $0410: MOV $F2, #$41
.db $8F, $00, $F3                  ; $0413: MOV $F3, #$00  ; V4VOLR=0
.db $8F, $00, $03                  ; $0416: MOV $03, #$00  ; stopped
.db $6F                            ; $0419: RET

; === CMD_PAUSE_MUSIC — $041A ===

.db $8F, $5C, $F2                  ; $041A: MOV $F2, #$5C
.db $8F, $1F, $F3                  ; $041D: MOV $F3, #$1F  ; KOFF 0-4
.db $8F, $02, $03                  ; $0420: MOV $03, #$02  ; paused
.db $6F                            ; $0423: RET

; === CMD_RESUME — $0424 ===

.db $8F, $00, $F2                  ; $0424: MOV $F2, #$00
.db $8F, $20, $F3                  ; $0427: MOV $F3, #$20  ; V0VOLL
.db $8F, $01, $F2                  ; $042A: MOV $F2, #$01
.db $8F, $20, $F3                  ; $042D: MOV $F3, #$20  ; V0VOLR
.db $8F, $10, $F2                  ; $0430: MOV $F2, #$10
.db $8F, $28, $F3                  ; $0433: MOV $F3, #$28  ; V1VOLL
.db $8F, $11, $F2                  ; $0436: MOV $F2, #$11
.db $8F, $28, $F3                  ; $0439: MOV $F3, #$28  ; V1VOLR
.db $8F, $20, $F2                  ; $043C: MOV $F2, #$20
.db $8F, $18, $F3                  ; $043F: MOV $F3, #$18  ; V2VOLL
.db $8F, $21, $F2                  ; $0442: MOV $F2, #$21
.db $8F, $18, $F3                  ; $0445: MOV $F3, #$18  ; V2VOLR
.db $8F, $30, $F2                  ; $0448: MOV $F2, #$30
.db $8F, $18, $F3                  ; $044B: MOV $F3, #$18  ; V3VOLL
.db $8F, $31, $F2                  ; $044E: MOV $F2, #$31
.db $8F, $18, $F3                  ; $0451: MOV $F3, #$18  ; V3VOLR
.db $8F, $40, $F2                  ; $0454: MOV $F2, #$40
.db $8F, $18, $F3                  ; $0457: MOV $F3, #$18  ; V4VOLL
.db $8F, $41, $F2                  ; $045A: MOV $F2, #$41
.db $8F, $18, $F3                  ; $045D: MOV $F3, #$18  ; V4VOLR
.db $8F, $01, $03                  ; $0460: MOV $03, #$01  ; playing=1
.db $6F                            ; $0463: RET

; === CMD_PLAY_SFX — $0464 ===
; Voice 5, 9-byte SFX table entries

.db $8F, $5C, $F2                  ; $0464: MOV $F2, #$5C
.db $8F, $20, $F3                  ; $0467: MOV $F3, #$20  ; KOFF v5
.db $E4, $01                       ; $046A: MOV A, $01  ; sfx ID
.db $8D, $09                       ; $046C: MOV Y, #$09
.db $CF                            ; $046E: MUL YA
.db $5D                            ; $046F: MOV X, A
.db $F5, $D0, $06                  ; $0470: MOV A, !$06D0+X
.db $8F, $54, $F2                  ; $0473: MOV $F2, #$54
.db $C4, $F3                       ; $0476: MOV $F3, A  ; V5SRCN
.db $3D                            ; $0478: INC X
.db $F5, $D0, $06                  ; $0479: MOV A, !$06D0+X
.db $8F, $52, $F2                  ; $047C: MOV $F2, #$52
.db $C4, $F3                       ; $047F: MOV $F3, A  ; V5PITCHL
.db $3D                            ; $0481: INC X
.db $F5, $D0, $06                  ; $0482: MOV A, !$06D0+X
.db $8F, $53, $F2                  ; $0485: MOV $F2, #$53
.db $C4, $F3                       ; $0488: MOV $F3, A  ; V5PITCHH
.db $3D                            ; $048A: INC X
.db $F5, $D0, $06                  ; $048B: MOV A, !$06D0+X
.db $8F, $55, $F2                  ; $048E: MOV $F2, #$55
.db $C4, $F3                       ; $0491: MOV $F3, A  ; V5ADSR1
.db $3D                            ; $0493: INC X
.db $F5, $D0, $06                  ; $0494: MOV A, !$06D0+X
.db $8F, $56, $F2                  ; $0497: MOV $F2, #$56
.db $C4, $F3                       ; $049A: MOV $F3, A  ; V5ADSR2
.db $3D                            ; $049C: INC X
.db $F5, $D0, $06                  ; $049D: MOV A, !$06D0+X
.db $C4, $18                       ; $04A0: MOV $18, A  ; sfx_duration
.db $8F, $50, $F2                  ; $04A2: MOV $F2, #$50
.db $8F, $30, $F3                  ; $04A5: MOV $F3, #$30  ; V5VOLL
.db $8F, $51, $F2                  ; $04A8: MOV $F2, #$51
.db $8F, $30, $F3                  ; $04AB: MOV $F3, #$30  ; V5VOLR
.db $8F, $01, $17                  ; $04AE: MOV $17, #$01  ; sfx_active=1
.db $8F, $00, $19                  ; $04B1: MOV $19, #$00  ; sfx_step=0
.db $8F, $4C, $F2                  ; $04B4: MOV $F2, #$4C
.db $8F, $20, $F3                  ; $04B7: MOV $F3, #$20  ; KON v5
.db $6F                            ; $04BA: RET

; === CMD_SET_VOLUME — $04BB ===

.db $E4, $01                       ; $04BB: MOV A, $01
.db $C4, $05                       ; $04BD: MOV $05, A  ; master_vol
.db $8F, $0C, $F2                  ; $04BF: MOV $F2, #$0C
.db $C4, $F3                       ; $04C2: MOV $F3, A  ; MVOLL
.db $8F, $1C, $F2                  ; $04C4: MOV $F2, #$1C
.db $C4, $F3                       ; $04C7: MOV $F3, A  ; MVOLR
.db $6F                            ; $04C9: RET

; === TICK_HANDLER — $04CA ===
; Called ~125 Hz. Processes SFX timing and music sequencing.

; --- SFX ---
.db $E4, $17                       ; $04CA: MOV A, $17  ; sfx_active
.db $F0, $4C                        ; $04CC: BEQ _skip_sfx
.db $8B, $18                       ; $04CE: DEC $18  ; sfx_duration--
.db $D0, $48                        ; $04D0: BNE _skip_sfx
.db $E4, $19                       ; $04D2: MOV A, $19  ; sfx_step
.db $D0, $3B                        ; $04D4: BNE _sfx_stop
.db $E4, $01                       ; $04D6: MOV A, $01  ; sfx ID
.db $8D, $09                       ; $04D8: MOV Y, #$09
.db $CF                            ; $04DA: MUL YA
.db $60                            ; $04DB: CLRC
.db $88, $06                       ; $04DC: ADC A, #$06  ; offset to pitch2_lo
.db $5D                            ; $04DE: MOV X, A
.db $F5, $D0, $06                  ; $04DF: MOV A, !$06D0+X
.db $C4, $28                       ; $04E2: MOV $28, A
.db $3D                            ; $04E4: INC X
.db $F5, $D0, $06                  ; $04E5: MOV A, !$06D0+X
.db $C4, $29                       ; $04E8: MOV $29, A
.db $08, $00                       ; $04EA: OR A, #$00
.db $D0, $04                        ; $04EC: BNE _sfx_note2
.db $E4, $28                       ; $04EE: MOV A, $28
.db $F0, $1F                        ; $04F0: BEQ _sfx_stop
.db $E4, $28                       ; $04F2: MOV A, $28  ; pitch2_lo
.db $8F, $52, $F2                  ; $04F4: MOV $F2, #$52
.db $C4, $F3                       ; $04F7: MOV $F3, A  ; V5PITCHL
.db $E4, $29                       ; $04F9: MOV A, $29  ; pitch2_hi
.db $8F, $53, $F2                  ; $04FB: MOV $F2, #$53
.db $C4, $F3                       ; $04FE: MOV $F3, A  ; V5PITCHH
.db $3D                            ; $0500: INC X
.db $F5, $D0, $06                  ; $0501: MOV A, !$06D0+X
.db $C4, $18                       ; $0504: MOV $18, A  ; sfx_duration
.db $8F, $01, $19                  ; $0506: MOV $19, #$01  ; sfx_step=1
.db $8F, $4C, $F2                  ; $0509: MOV $F2, #$4C
.db $8F, $20, $F3                  ; $050C: MOV $F3, #$20  ; KON v5
.db $2F, $09                        ; $050F: BRA _skip_sfx
.db $8F, $5C, $F2                  ; $0511: MOV $F2, #$5C
.db $8F, $20, $F3                  ; $0514: MOV $F3, #$20  ; KOFF v5
.db $8F, $00, $17                  ; $0517: MOV $17, #$00  ; sfx_active=0

; --- Music ---
.db $E4, $03                       ; $051A: MOV A, $03
.db $68, $01                       ; $051C: CMP A, #$01
.db $D0, $39                        ; $051E: BNE _tick_ret
.db $8B, $06                       ; $0520: DEC $06  ; tick_counter--
.db $D0, $35                        ; $0522: BNE _tick_ret
.db $E4, $07                       ; $0524: MOV A, $07
.db $C4, $06                       ; $0526: MOV $06, A  ; reload
.db $8F, $00, $1A                  ; $0528: MOV $1A, #$00  ; kon=0
.db $8F, $00, $1B                  ; $052B: MOV $1B, #$00  ; koff=0
; Process voices
.db $CD, $00                       ; $052E: MOV X, #$00  ; voice 0
.db $3F, $5A, $05                  ; $0530: CALL !process_voice
.db $CD, $01                       ; $0533: MOV X, #$01  ; voice 1
.db $3F, $5A, $05                  ; $0535: CALL !process_voice
.db $CD, $02                       ; $0538: MOV X, #$02  ; voice 2
.db $3F, $5A, $05                  ; $053A: CALL !process_voice
.db $CD, $03                       ; $053D: MOV X, #$03  ; voice 3
.db $3F, $5A, $05                  ; $053F: CALL !process_voice
.db $CD, $04                       ; $0542: MOV X, #$04  ; voice 4
.db $3F, $5A, $05                  ; $0544: CALL !process_voice
; Apply KON/KOFF
.db $E4, $1B                       ; $0547: MOV A, $1B
.db $F0, $05                       ; $0549: BEQ +5
.db $8F, $5C, $F2                  ; $054B: MOV $F2, #$5C
.db $C4, $F3                       ; $054E: MOV $F3, A  ; KOFF
.db $E4, $1A                       ; $0550: MOV A, $1A
.db $F0, $05                       ; $0552: BEQ +5
.db $8F, $4C, $F2                  ; $0554: MOV $F2, #$4C
.db $C4, $F3                       ; $0557: MOV $F3, A  ; KON
.db $6F                            ; $0559: RET

; === PROCESS_VOICE — $055A ===
; X = voice (0-4). Reads sequence, sets KON/KOFF bits.

.db $D8, $2B                       ; $055A: MOV $2B, X  ; save voice num
.db $F4, $08                       ; $055C: MOV A, $08+X  ; duration
.db $9C                            ; $055E: DEC A
.db $D4, $08                       ; $055F: MOV $08+X, A
.db $D0, $59                        ; $0561: BNE _pv_ret
; Read sequence byte
.db $F4, $0D                       ; $0563: MOV A, $0D+X
.db $C4, $26                       ; $0565: MOV $26, A
.db $F4, $12                       ; $0567: MOV A, $12+X
.db $C4, $27                       ; $0569: MOV $27, A
.db $8D, $00                       ; $056B: MOV Y, #$00
.db $F7, $26                       ; $056D: MOV A, [$26]+Y  ; note byte
.db $C4, $28                       ; $056F: MOV $28, A
.db $68, $FF                       ; $0571: CMP A, #$FF
.db $D0, $0D                        ; $0573: BNE _not_ff
.db $F4, $1C                       ; $0575: MOV A, $1C+X
.db $D4, $0D                       ; $0577: MOV $0D+X, A  ; lo=loop
.db $F4, $21                       ; $0579: MOV A, $21+X
.db $D4, $12                       ; $057B: MOV $12+X, A  ; hi=loop
.db $E8, $01                       ; $057D: MOV A, #$01
.db $D4, $08                       ; $057F: MOV $08+X, A  ; dur=1
.db $6F                            ; $0581: RET
.db $68, $FE                       ; $0582: CMP A, #$FE
.db $D0, $16                        ; $0584: BNE _not_fe
.db $E4, $26                       ; $0586: MOV A, $26
.db $60                            ; $0588: CLRC
.db $88, $01                       ; $0589: ADC A, #$01
.db $D4, $0D                       ; $058B: MOV $0D+X, A
.db $D4, $1C                       ; $058D: MOV $1C+X, A  ; loop lo
.db $E4, $27                       ; $058F: MOV A, $27
.db $88, $00                       ; $0591: ADC A, #$00
.db $D4, $12                       ; $0593: MOV $12+X, A
.db $D4, $21                       ; $0595: MOV $21+X, A  ; loop hi
.db $E8, $01                       ; $0597: MOV A, #$01
.db $D4, $08                       ; $0599: MOV $08+X, A
.db $6F                            ; $059B: RET
.db $E4, $28                       ; $059C: MOV A, $28
.db $68, $80                       ; $059E: CMP A, #$80
.db $D0, $1B                        ; $05A0: BNE _not_rest
; Rest: KOFF this voice
.db $F5, $0B, $06                  ; $05A2: MOV A, !$060B+X
.db $04, $1B                       ; $05A5: OR A, $1B
.db $C4, $1B                       ; $05A7: MOV $1B, A  ; koff |= bit
.db $8D, $01                       ; $05A9: MOV Y, #$01
.db $F7, $26                       ; $05AB: MOV A, [$26]+Y  ; duration
.db $D4, $08                       ; $05AD: MOV $08+X, A
.db $E4, $26                       ; $05AF: MOV A, $26
.db $60                            ; $05B1: CLRC
.db $88, $02                       ; $05B2: ADC A, #$02
.db $D4, $0D                       ; $05B4: MOV $0D+X, A
.db $E4, $27                       ; $05B6: MOV A, $27
.db $88, $00                       ; $05B8: ADC A, #$00
.db $D4, $12                       ; $05BA: MOV $12+X, A
.db $6F                            ; $05BC: RET

; Note: look up pitch, configure DSP
.db $E4, $28                       ; $05BD: MOV A, $28  ; MIDI note
.db $60                            ; $05BF: CLRC
.db $88, $E8                       ; $05C0: ADC A, #$E8  ; A = note - 24
.db $1C                            ; $05C2: ASL A  ; * 2 for word index
.db $FD                            ; $05C3: MOV Y, A  ; Y = pitch table offset
.db $F6, $10, $06                  ; $05C4: MOV A, !$0610+Y  ; pitch lo
.db $C4, $2A                       ; $05C7: MOV $2A, A  ; save pitch_lo
.db $F6, $11, $06                  ; $05C9: MOV A, !$0611+Y  ; pitch hi (base+1)
.db $C4, $29                       ; $05CC: MOV $29, A  ; save pitch_hi
.db $F8, $2B                       ; $05CE: MOV X, $2B  ; voice num
.db $7D                            ; $05D0: MOV A, X
.db $1C                            ; $05D1: ASL A
.db $1C                            ; $05D2: ASL A
.db $1C                            ; $05D3: ASL A
.db $1C                            ; $05D4: ASL A
.db $C4, $2B                       ; $05D5: MOV $2B, A  ; DSP base
.db $08, $02                       ; $05D7: OR A, #$02
.db $C4, $F2                       ; $05D9: MOV $F2, A
.db $E4, $2A                       ; $05DB: MOV A, $2A
.db $C4, $F3                       ; $05DD: MOV $F3, A  ; PITCHL
.db $E4, $2B                       ; $05DF: MOV A, $2B
.db $08, $03                       ; $05E1: OR A, #$03
.db $C4, $F2                       ; $05E3: MOV $F2, A
.db $E4, $29                       ; $05E5: MOV A, $29
.db $C4, $F3                       ; $05E7: MOV $F3, A  ; PITCHH
.db $E4, $2B                       ; $05E9: MOV A, $2B  ; DSP base
.db $5C                            ; $05EB: LSR A
.db $5C                            ; $05EC: LSR A
.db $5C                            ; $05ED: LSR A
.db $5C                            ; $05EE: LSR A
.db $5D                            ; $05EF: MOV X, A  ; voice num recovered
.db $F5, $0B, $06                  ; $05F0: MOV A, !$060B+X
.db $04, $1A                       ; $05F3: OR A, $1A
.db $C4, $1A                       ; $05F5: MOV $1A, A  ; kon |= bit
.db $8D, $01                       ; $05F7: MOV Y, #$01
.db $F7, $26                       ; $05F9: MOV A, [$26]+Y  ; duration
.db $D4, $08                       ; $05FB: MOV $08+X, A
.db $E4, $26                       ; $05FD: MOV A, $26
.db $60                            ; $05FF: CLRC
.db $88, $02                       ; $0600: ADC A, #$02
.db $D4, $0D                       ; $0602: MOV $0D+X, A
.db $E4, $27                       ; $0604: MOV A, $27
.db $88, $00                       ; $0606: ADC A, #$00
.db $D4, $12                       ; $0608: MOV $12+X, A
.db $6F                            ; $060A: RET

; === BITMASK TABLE — $060B ===
.db $01, $02, $04, $08, $10        ; $060B: bitmask: 1,2,4,8,16

; === PITCH TABLE — $0610 ===
; 96 entries (MIDI 24-119), 2 bytes each (lo, hi)

; Octave 1
.db $00, $02                       ; $0610: $0200  ; MIDI 24 C1
.db $1E, $02                       ; $0612: $021E  ; MIDI 25 C#1
.db $3F, $02                       ; $0614: $023F  ; MIDI 26 D1
.db $61, $02                       ; $0616: $0261  ; MIDI 27 D#1
.db $85, $02                       ; $0618: $0285  ; MIDI 28 E1
.db $AB, $02                       ; $061A: $02AB  ; MIDI 29 F1
.db $D4, $02                       ; $061C: $02D4  ; MIDI 30 F#1
.db $FF, $02                       ; $061E: $02FF  ; MIDI 31 G1
.db $2D, $03                       ; $0620: $032D  ; MIDI 32 G#1
.db $5D, $03                       ; $0622: $035D  ; MIDI 33 A1
.db $90, $03                       ; $0624: $0390  ; MIDI 34 A#1
.db $C6, $03                       ; $0626: $03C6  ; MIDI 35 B1
; Octave 2
.db $00, $04                       ; $0628: $0400  ; MIDI 36 C2
.db $3D, $04                       ; $062A: $043D  ; MIDI 37 C#2
.db $7D, $04                       ; $062C: $047D  ; MIDI 38 D2
.db $C2, $04                       ; $062E: $04C2  ; MIDI 39 D#2
.db $0A, $05                       ; $0630: $050A  ; MIDI 40 E2
.db $57, $05                       ; $0632: $0557  ; MIDI 41 F2
.db $A8, $05                       ; $0634: $05A8  ; MIDI 42 F#2
.db $FE, $05                       ; $0636: $05FE  ; MIDI 43 G2
.db $59, $06                       ; $0638: $0659  ; MIDI 44 G#2
.db $BA, $06                       ; $063A: $06BA  ; MIDI 45 A2
.db $20, $07                       ; $063C: $0720  ; MIDI 46 A#2
.db $8D, $07                       ; $063E: $078D  ; MIDI 47 B2
; Octave 3
.db $00, $08                       ; $0640: $0800  ; MIDI 48 C3
.db $7A, $08                       ; $0642: $087A  ; MIDI 49 C#3
.db $FB, $08                       ; $0644: $08FB  ; MIDI 50 D3
.db $83, $09                       ; $0646: $0983  ; MIDI 51 D#3
.db $14, $0A                       ; $0648: $0A14  ; MIDI 52 E3
.db $AE, $0A                       ; $064A: $0AAE  ; MIDI 53 F3
.db $50, $0B                       ; $064C: $0B50  ; MIDI 54 F#3
.db $FC, $0B                       ; $064E: $0BFC  ; MIDI 55 G3
.db $B3, $0C                       ; $0650: $0CB3  ; MIDI 56 G#3
.db $74, $0D                       ; $0652: $0D74  ; MIDI 57 A3
.db $41, $0E                       ; $0654: $0E41  ; MIDI 58 A#3
.db $1A, $0F                       ; $0656: $0F1A  ; MIDI 59 B3
; Octave 4
.db $00, $10                       ; $0658: $1000  ; MIDI 60 C4
.db $F3, $10                       ; $065A: $10F3  ; MIDI 61 C#4
.db $F5, $11                       ; $065C: $11F5  ; MIDI 62 D4
.db $07, $13                       ; $065E: $1307  ; MIDI 63 D#4
.db $28, $14                       ; $0660: $1428  ; MIDI 64 E4
.db $5B, $15                       ; $0662: $155B  ; MIDI 65 F4
.db $A0, $16                       ; $0664: $16A0  ; MIDI 66 F#4
.db $F9, $17                       ; $0666: $17F9  ; MIDI 67 G4
.db $65, $19                       ; $0668: $1965  ; MIDI 68 G#4
.db $E8, $1A                       ; $066A: $1AE8  ; MIDI 69 A4
.db $82, $1C                       ; $066C: $1C82  ; MIDI 70 A#4
.db $34, $1E                       ; $066E: $1E34  ; MIDI 71 B4
; Octave 5
.db $FF, $1F                       ; $0670: $1FFF  ; MIDI 72 C5
.db $E6, $21                       ; $0672: $21E6  ; MIDI 73 C#5
.db $EA, $23                       ; $0674: $23EA  ; MIDI 74 D5
.db $0D, $26                       ; $0676: $260D  ; MIDI 75 D#5
.db $50, $28                       ; $0678: $2850  ; MIDI 76 E5
.db $B6, $2A                       ; $067A: $2AB6  ; MIDI 77 F5
.db $40, $2D                       ; $067C: $2D40  ; MIDI 78 F#5
.db $F1, $2F                       ; $067E: $2FF1  ; MIDI 79 G5
.db $CB, $32                       ; $0680: $32CB  ; MIDI 80 G#5
.db $D0, $35                       ; $0682: $35D0  ; MIDI 81 A5
.db $03, $39                       ; $0684: $3903  ; MIDI 82 A#5
.db $67, $3C                       ; $0686: $3C67  ; MIDI 83 B5
; Octave 6
.db $FF, $3F                       ; $0688: $3FFF  ; MIDI 84 C6
.db $FF, $3F                       ; $068A: $3FFF  ; MIDI 85 C#6
.db $FF, $3F                       ; $068C: $3FFF  ; MIDI 86 D6
.db $FF, $3F                       ; $068E: $3FFF  ; MIDI 87 D#6
.db $FF, $3F                       ; $0690: $3FFF  ; MIDI 88 E6
.db $FF, $3F                       ; $0692: $3FFF  ; MIDI 89 F6
.db $FF, $3F                       ; $0694: $3FFF  ; MIDI 90 F#6
.db $FF, $3F                       ; $0696: $3FFF  ; MIDI 91 G6
.db $FF, $3F                       ; $0698: $3FFF  ; MIDI 92 G#6
.db $FF, $3F                       ; $069A: $3FFF  ; MIDI 93 A6
.db $FF, $3F                       ; $069C: $3FFF  ; MIDI 94 A#6
.db $FF, $3F                       ; $069E: $3FFF  ; MIDI 95 B6
; Octave 7
.db $FF, $3F                       ; $06A0: $3FFF  ; MIDI 96 C7
.db $FF, $3F                       ; $06A2: $3FFF  ; MIDI 97 C#7
.db $FF, $3F                       ; $06A4: $3FFF  ; MIDI 98 D7
.db $FF, $3F                       ; $06A6: $3FFF  ; MIDI 99 D#7
.db $FF, $3F                       ; $06A8: $3FFF  ; MIDI 100 E7
.db $FF, $3F                       ; $06AA: $3FFF  ; MIDI 101 F7
.db $FF, $3F                       ; $06AC: $3FFF  ; MIDI 102 F#7
.db $FF, $3F                       ; $06AE: $3FFF  ; MIDI 103 G7
.db $FF, $3F                       ; $06B0: $3FFF  ; MIDI 104 G#7
.db $FF, $3F                       ; $06B2: $3FFF  ; MIDI 105 A7
.db $FF, $3F                       ; $06B4: $3FFF  ; MIDI 106 A#7
.db $FF, $3F                       ; $06B6: $3FFF  ; MIDI 107 B7
; Octave 8
.db $FF, $3F                       ; $06B8: $3FFF  ; MIDI 108 C8
.db $FF, $3F                       ; $06BA: $3FFF  ; MIDI 109 C#8
.db $FF, $3F                       ; $06BC: $3FFF  ; MIDI 110 D8
.db $FF, $3F                       ; $06BE: $3FFF  ; MIDI 111 D#8
.db $FF, $3F                       ; $06C0: $3FFF  ; MIDI 112 E8
.db $FF, $3F                       ; $06C2: $3FFF  ; MIDI 113 F8
.db $FF, $3F                       ; $06C4: $3FFF  ; MIDI 114 F#8
.db $FF, $3F                       ; $06C6: $3FFF  ; MIDI 115 G8
.db $FF, $3F                       ; $06C8: $3FFF  ; MIDI 116 G#8
.db $FF, $3F                       ; $06CA: $3FFF  ; MIDI 117 A8
.db $FF, $3F                       ; $06CC: $3FFF  ; MIDI 118 A#8
.db $FF, $3F                       ; $06CE: $3FFF  ; MIDI 119 B8

; === SFX TABLE — $06D0 ===
; 5 x 9 bytes: sample, pitchL, pitchH, ADSR1, ADSR2, dur, p2L, p2H, d2

.db $00, $00, $20, $FF, $0F, $04, $50, $28, $04 ; $06D0: SFX 0  ; Menu Select: C5->E5
.db $04, $00, $10, $7F, $1F, $02, $00, $00, $00 ; $06D9: SFX 1  ; Key Click
.db $05, $F9, $17, $BC, $8A, $08, $00, $20, $08 ; $06E2: SFX 2  ; Save Confirm: G4->C5
.db $01, $14, $0A, $BF, $14, $0A, $00, $00, $00 ; $06EB: SFX 3  ; Error: E3
.db $04, $00, $18, $FF, $0F, $06, $00, $0C, $06 ; $06F4: SFX 4  ; Delete

spc_driver_end:
; Driver size: 1277 bytes ($0200-$06FC)
