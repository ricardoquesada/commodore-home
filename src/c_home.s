;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
;
; Commodore Home: Home Automation for the masses, not the classes
;
; main
;
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; Macros
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.macpack cbm                            ; adds support for scrcode

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; Imports/Exports
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.import decrunch                        ; exomizer decrunch
.import get_crunched_byte               ; needed for exomizer decruncher
.import _crunched_byte_lo, _crunched_byte_hi
.import menu_handle_events, menu_invert_row

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; Constants
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.include "c64.inc"                      ; c64 constants
.include "myconstants.inc"

.segment "CODE"

.proc main
        sei

        lda #$35
        sta $01                         ; no basic/kernal

        ldx #$ff                        ; reset stack... just in case
        txs

        lda #0
        sta $d01a                       ; no raster interrups


        lda #$00                        ; background & border color
        sta $d020
        sta $d021

        lda #$7f                        ; turn off cia interrups
        sta $dc0d
        sta $dd0d

        lda $dc0d                       ; clear interrupts and ACK irq
        lda $dd0d
        asl $d019

        lda #$00                        ; turn off volume
        sta SID_Amp
                                        ; multicolor mode + extended color causes

        ldx #<irq_vector
        ldy #>irq_vector
        stx $fffe
        sty $ffff

        jsr init_screen
        jsr main_init_menu

        cli

main_loop:
        jsr menu_handle_events
        lda sync_timer_irq
        beq main_loop

        dec sync_timer_irq
        jsr MUSIC_PLAY

        inc song_tick
        bne :+
        inc song_tick+1
:
        jmp main_loop
.endproc

.segment "HICODE"

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; irq vectors
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc irq_vector
        pha                             ; saves A, X, Y
        txa
        pha
        tya
        pha

        asl $d019                       ; clears raster interrupt
        bcs raster

        lda $dc0d                       ; clears CIA interrupts, in particular timer A
        inc sync_timer_irq
        bne end                         ; A will never be 0. Jump to end

raster:
        inc sync_raster_irq
end:
        pla                             ; restores A, X, Y
        tay
        pla
        tax
        pla
        rti                             ; restores previous PC, status
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; init_screen
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc init_screen
                                        ; turn off video
        lda #%01011011                  ; the bug that blanks the screen
        sta $d011                       ; extended color mode: on
        lda #%00011000
        sta $d016                       ; turn on multicolor

        dec $01                         ; $34: RAM 100%

        ldx #<screen_ram_eod            ; decrunch in $0400
        ldy #>screen_ram_eod
        stx _crunched_byte_lo
        sty _crunched_byte_hi
        jsr decrunch

        inc $01                         ; $35: RAM + IO ($D000-$DFFF)

        ldx #0                          ; read data from $0400
l1:                                     ; and update the color ram
        lda $0400 + $0000,x
        tay
        lda screen_colors,y
        sta $d800 + $0000,x

        lda $0400 + $0100,x
        tay
        lda screen_colors,y
        sta $d800 + $0100,x

        lda $0400 + $0200,x
        tay
        lda screen_colors,y
        sta $d800 + $0200,x

        lda $0400 + $02e8,x
        tay
        lda screen_colors,y
        sta $d800 + $02e8,x

        inx
        bne l1

        lda $dd00                       ; Vic bank 0: $0000-$3FFF
        and #$fc
        ora #3
        sta $dd00

        lda #%00011110                  ; charset at $3800, screen at $0400
        sta $d018
                                        ; turn VIC on again
        lda #%00011011                  ; charset mode, default scroll-Y position, 25-rows
        sta $d011                       ; extended color mode: off
        lda #%00001000                  ; no scroll, hires (mono color), 40-cols
        sta $d016                       ; turn off multicolor

        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; init_crunch_data
; initializes the data needed by get_crunched_byte
; entry:
;       x = index of the table (current song * 2)
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc init_crunch_data
        lda song_end_addrs,x
        sta _crunched_byte_lo
        lda song_end_addrs+1,x
        sta _crunched_byte_hi
        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void main_init_menu()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc main_init_menu
        lda #7                                  ; setup the global variables
        sta MENU_MAX_ITEMS                      ; needed for the menu code
        lda #0
        sta MENU_CURRENT_ITEM
        lda #18
        sta MENU_ITEM_LEN
        lda #40
        sta MENU_BYTES_BETWEEN_ITEMS
        ldx #<(SCREEN0_BASE + 40 * 17 + 22)
        ldy #>(SCREEN0_BASE + 40 * 17 + 22)
        stx MENU_CURRENT_ROW_ADDR
        sty MENU_CURRENT_ROW_ADDR+1
        ldx #<mainmenu_exec
        ldy #>mainmenu_exec
        stx MENU_EXEC_ADDR
        sty MENU_EXEC_ADDR+1

        jmp menu_invert_row
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void mainmenu_exec()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc mainmenu_exec
        lda MENU_CURRENT_ITEM
        bne :+
        jmp do_stop_song

:
        tax
        dex
        stx current_song

        jmp do_init_song
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; do_stop_song
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc do_stop_song
        sei

        lda #0
        sta is_playing                  ; is_playing = false

        lda #$7f                        ; turn off cia interrups
        sta $dc0d

        lda #$00
        sta $d418                       ; no volume

        lda $dc0d                       ; ack possible interrupts
        lda $dd0d
        asl $d019

        cli

        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; do_init_song
; decrunches real song, and initializes white song
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc do_init_song
        sei

        lda #1
        sta is_playing                  ; is_playing = true

        lda #1
        sta is_already_loaded           ; is_already_loaded = true

        lda #0
        sta song_tick                   ; reset song tick
        sta song_tick+1

        lda #$7f                        ; turn off cia interrups
        sta $dc0d
        lda #$00
        sta $d418                       ; no volume

;        jsr print_names_empty

        lda current_song                ; x = current_song * 2
        asl
        tax
        jsr init_crunch_data            ; requires x

        dec $01                         ; $34: RAM 100%

        jsr decrunch                    ; copy song

        inc $01                         ; $35: RAM + IO ($D000-$DF00)

        lda #0
        tax
        tay
        jsr MUSIC_INIT

        ldx #<$4cc7                     ; init timer
        ldy #>$4cc7                     ; sync with PAL
        stx $dc04                       ; it plays at 50.125hz
        sty $dc05                       ; we have to call this everytime

        lda #$81                        ; turn on cia interrups
        sta $dc0d

        cli
        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; variables
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
current_song:           .byte 0
is_playing:             .byte 0
is_already_loaded:      .byte 0
sync_timer_irq:         .byte 0
sync_raster_irq:        .byte 0
song_tick:              .word 0


song_end_addrs:
        .addr song_1_eod
        .addr song_2_eod
        .addr song_3_eod
        .addr song_4_eod
        .addr song_5_eod
        .addr song_6_eod

song_durations:                                 ; measured in "cycles ticks"
        .word (3*60+13) * 50                    ; #1 3:13
        .word (3*60+31) * 50                    ; #2 3:31
        .word (2*60+25) * 50                    ; #3 2:25
        .word (2*60+30) * 50                    ; #4 2:30
        .word (3*60+04) * 50                    ; #5 3:04
        .word (3*60+51) * 50                    ; #6 3:51

screen_colors:
        .incbin "mainscreen-colors.bin"

.segment "CHARSET"
        .incbin "mainscreen-charset.bin"


.segment "COMPRESSED"
.incbin "Carito.exo"
song_1_eod:

.incbin "Pop_Goes_the_World.exo"
song_2_eod:

.incbin "Drogacumbia.exo"
song_3_eod:

.incbin "Mama_Killa.exo"
song_4_eod:

.incbin "Paesaggio.exo"
song_5_eod:

.incbin "Supremacy.exo"
song_6_eod:


.incbin "mainscreen-map.bin.exo"
screen_ram_eod:

.byte 0                 ; ignore


.segment "SID"
; reserved for SIDs
