; ============================================================================
; states.asm — Application State Machine
; ============================================================================

main_loop:
    jsr wait_vblank

    sep #$30                     ; 8-bit A/X/Y
    .ACCU 8
    .INDEX 8

    ; --- Dispatch to current state handler ---
    lda current_state.w
    asl A
    tax
    jsr (_state_table.w,X)

    ; --- Update cursor sprite in OAM shadow ---
    jsr cursor_update

    jmp main_loop

_state_table:
    .dw state_boot               ; 0: boot → init title
    .dw state_title              ; 1: title screen
    .dw state_type_sel           ; 2: type selection submenu
    .dw state_file_brw           ; 3: file browser
    .dw state_textdoc            ; 4: text doc editor (Phase 4)
    .dw state_sheet              ; 5: spreadsheet editor
    .dw state_fmenu              ; 6: file menu overlay (Phase 6)

; ============================================================================
; state_boot — One-shot: initialize title screen, then switch to STATE_TITLE
; ============================================================================
state_boot:
    ; Reset keyboard state
    stz kbd_visible.w
    stz kbd_shift.w

    ; Reset editor init flags
    stz doc_initialized.w
    stz sheet_initialized.w

    ; Reset save system state
    lda #$FF
    sta current_slot.w
    stz fmenu_visible.w
    stz dialog_visible.w
    stz fb_initialized.w

    jsr title_init

    lda #STATE_TITLE
    sta current_state.w
    rts

; ============================================================================
; state_stub_init — Initialize editor stub: set up a blank screen + keyboard
; ============================================================================
state_stub_init:
    .ACCU 8
    .INDEX 8

    ; Force blank
    lda #$8F
    sta INIDISP.w

    ; Disable HDMA
    stz SHADOW_HDMAEN.w
    stz HDMAEN.w

    ; Clear OAM
    jsr clear_oam

    ; Disable color math
    stz SHADOW_CGWSEL.w
    stz CGWSEL.w
    stz SHADOW_CGADSUB.w
    stz CGADSUB.w

    ; Set backdrop to dark blue
    stz CGADD.w
    lda #$00
    sta CGDATA.w
    lda #$28
    sta CGDATA.w

    ; Only sprites on main screen for now (kbd_show will add BG3)
    lda #%00010000               ; OBJ only
    sta SHADOW_TM.w
    sta TM.w

    ; Standard Mode 1
    lda #$01
    sta SHADOW_BGMODE.w
    sta BGMODE.w

    ; Show keyboard
    jsr kbd_show

    ; Fade in
    lda #FADE_IN
    sta fade_dir.w
    stz fade_level.w
    stz SHADOW_INIDISP.w
    stz INIDISP.w

    rts


; ============================================================================
; state_stub — Placeholder for unimplemented editor states (Phase 4/5)
; Shows keyboard overlay as a demo. Press B to go back to title.
; ============================================================================
state_stub:
    .ACCU 8
    .INDEX 8

    ; Check if we need to init (kbd_visible == 0 means first frame)
    lda kbd_visible.w
    bne @stub_running
    jsr state_stub_init
    rts

@stub_running:
    jsr read_input

    ; Handle fade
    lda fade_dir.w
    beq @stub_no_fade

    cmp #FADE_IN
    bne @stub_fade_out
    lda fade_level.w
    cmp #$0F
    bcs @stub_fade_in_done
    inc A
    sta fade_level.w
    sta SHADOW_INIDISP.w
    rts
@stub_fade_in_done:
    stz fade_dir.w
    bra @stub_no_fade

@stub_fade_out:
    lda fade_level.w
    beq @stub_fade_out_done
    dec A
    sta fade_level.w
    sta SHADOW_INIDISP.w
    rts
@stub_fade_out_done:
    stz fade_dir.w
    jsr kbd_hide
    lda #STATE_BOOT
    sta current_state.w
    rts

@stub_no_fade:
    jsr kbd_update

    ; Right-click = go back to title
    lda rclick_new.w
    beq @stub_done
    lda #FADE_OUT
    sta fade_dir.w
@stub_done:
    rts


; ============================================================================
; state_fmenu — File menu overlay state (dispatched from main loop)
; This state runs the underlying editor + file menu/dialog overlay.
; Assumes: 8-bit A/X/Y
; ============================================================================
state_fmenu:
    .ACCU 8
    .INDEX 8

    jsr read_input

    ; Handle fade (for close transitions)
    lda fade_dir.w
    beq @sfm_no_fade

    cmp #FADE_IN
    bne @sfm_fade_out

    lda fade_level.w
    cmp #$0F
    bcs @sfm_fade_in_done
    inc A
    sta fade_level.w
    sta SHADOW_INIDISP.w
    rts
@sfm_fade_in_done:
    stz fade_dir.w
    bra @sfm_no_fade

@sfm_fade_out:
    lda fade_level.w
    beq @sfm_fade_out_done
    dec A
    sta fade_level.w
    sta SHADOW_INIDISP.w
    rts
@sfm_fade_out_done:
    stz fade_dir.w
    jsr stop_music
    jsr kbd_hide
    ; Reset editor init flags for clean re-entry
    stz doc_initialized.w
    stz sheet_initialized.w
    lda #STATE_BOOT
    sta current_state.w
    rts

@sfm_no_fade:
    ; If dialog is visible, handle dialog
    lda dialog_visible.w
    beq @sfm_no_dialog

    ; Which dialog type?
    lda dialog_type.w
    bne @sfm_name_dialog
    ; Dirty confirmation dialog
    jsr _dialog_update_dirty
    bra @sfm_update_blink

@sfm_name_dialog:
    ; Filename entry dialog — keyboard still active
    jsr kbd_update
    jsr _dialog_update_name
    bra @sfm_update_blink

@sfm_no_dialog:
    ; File menu visible?
    lda fmenu_visible.w
    beq @sfm_no_menu

    jsr fmenu_update
    bra @sfm_update_blink

@sfm_no_menu:
    ; No overlay visible — return to editor state
    lda file_type.w
    bne @sfm_back_sheet
    lda #STATE_TEXTDOC
    sta current_state.w
    rts
@sfm_back_sheet:
    lda #STATE_SHEET
    sta current_state.w
    rts

@sfm_update_blink:
    ; Still update cursor blink in the editor
    lda file_type.w
    bne @sfm_sheet_blink
    jsr _textdoc_blink_cursor
    rts
@sfm_sheet_blink:
    jsr _sheet_blink_cursor
    rts
