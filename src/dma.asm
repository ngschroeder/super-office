; ============================================================================
; dma.asm — Deferred DMA Queue (Stub for Phase 1)
; Phase 1: just provides the interface. Real implementation in later phases.
; ============================================================================

; ============================================================================
; dma_queue_init — Zero the DMA command queue
; ============================================================================
dma_queue_init:
    ; Nothing to do in Phase 1
    rts

; ============================================================================
; dma_queue_flush — Process queued DMA commands during VBlank
; Called by the NMI handler. No-op in Phase 1.
; ============================================================================
dma_queue_flush:
    rts
