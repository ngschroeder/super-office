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
    .dw state_boot

state_boot:
    jsr read_input
    rts
