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
.import menu_handle_events, menu_invert_row, menu_update_current_row

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; Constants
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.include "c64.inc"                      ; c64 constants
.include "myconstants.inc"

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; .segment "CODE"
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
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
        jsr main_init_menu_song + 3

        cli

main_loop:
        jsr menu_handle_events

        lda sync_timer_irq
        beq main_loop

        dec sync_timer_irq

music_play_addr = * + 1
        jsr MUSIC_PLAY

        inc song_tick
        bne :+
        inc song_tick+1
:
        jsr check_end_of_song

        jmp main_loop
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; check_end_of_song
;   if (song_tick >= song_durations[current_song]) do_next_song();
;   temp: uses $fc,$fd
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc check_end_of_song
        lda current_song                ; x = current_song * 2
        asl                             ; (song_durations is a word array)
        tax

        lda song_durations,x            ; pointer to song durations
        sta $fc
        lda song_durations+1,x
        sta $fd

        ; unsigned comparison per byte
        lda song_tick+1   ; compare high bytes
        cmp $fd
        bcc end           ; if MSB(song_tick) < MSB(song_duration) then
                          ;     song_tick < song_duration
        bne :+            ; if MSB(song_tick) <> MSB(song_duration) then
                          ;     song_tick > song_duration (so song_tick >= song_duration)

        lda song_tick     ; compare low bytes
        cmp $fc
        bcc end           ; if LSB(song_tick) < LSB(song_duration) then
                          ;     song_tick < song_duration
:
        jsr do_next_song
end:
        rts
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
; void main_init_menu_light()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc main_init_menu_light
        jsr menu_invert_row                     ; turn off previous menu
        lda MENU_CURRENT_ITEM                   ; save last used item
        sta menu_song_last_idx

        lda #2                                  ; setup the global variables
        sta MENU_MAX_ITEMS                      ; needed for the menu code
        lda #5
        sta MENU_ITEM_LEN
        lda #40
        sta MENU_BYTES_BETWEEN_ITEMS
        ldx #<(SCREEN0_BASE + 40 * 16 + 0)
        ldy #>(SCREEN0_BASE + 40 * 16 + 0)
        stx MENU_CURRENT_ROW_ADDR
        sty MENU_CURRENT_ROW_ADDR+1
        lda menu_light_last_idx
        sta MENU_CURRENT_ITEM
        jsr menu_update_current_row

        ldx #<main_light_exec
        ldy #>main_light_exec
        stx MENU_EXEC_ADDR
        sty MENU_EXEC_ADDR+1

        ldx #<main_init_menu_song
        ldy #>main_init_menu_song
        stx MENU_NEXT_ADDR
        sty MENU_NEXT_ADDR+1

        ldx #<main_nothing_exec
        ldy #>main_nothing_exec
        stx MENU_PREV_ADDR
        sty MENU_PREV_ADDR+1

        jmp menu_invert_row
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void main_init_menu_song()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc main_init_menu_song
        jsr menu_invert_row                     ; turn off previous menu

boot = *
        lda #9                                  ; setup the global variables
        sta MENU_MAX_ITEMS                      ; needed for the menu code
        lda #25
        sta MENU_ITEM_LEN
        lda #40
        sta MENU_BYTES_BETWEEN_ITEMS
        ldx #<(SCREEN0_BASE + 40 * 16 + 8)
        ldy #>(SCREEN0_BASE + 40 * 16 + 8)
        stx MENU_CURRENT_ROW_ADDR
        sty MENU_CURRENT_ROW_ADDR+1
        lda menu_song_last_idx
        sta MENU_CURRENT_ITEM
        jsr menu_update_current_row

        ldx #<main_song_exec
        ldy #>main_song_exec
        stx MENU_EXEC_ADDR
        sty MENU_EXEC_ADDR+1

        ldx #<main_init_menu_dimmer
        ldy #>main_init_menu_dimmer
        stx MENU_NEXT_ADDR
        sty MENU_NEXT_ADDR+1

        ldx #<main_init_menu_light
        ldy #>main_init_menu_light
        stx MENU_PREV_ADDR
        sty MENU_PREV_ADDR+1

        jmp menu_invert_row
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void main_init_menu_dimmer()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc main_init_menu_dimmer

        jsr menu_invert_row                     ; turn off previous menu
        lda MENU_CURRENT_ITEM                   ; save last used item
        sta menu_song_last_idx

        lda #5                                  ; setup the global variables
        sta MENU_MAX_ITEMS                      ; needed for the menu code
        lda #5
        sta MENU_ITEM_LEN
        lda #40
        sta MENU_BYTES_BETWEEN_ITEMS
        ldx #<(SCREEN0_BASE + 40 * 16 + 33)
        ldy #>(SCREEN0_BASE + 40 * 16 + 33)
        stx MENU_CURRENT_ROW_ADDR
        sty MENU_CURRENT_ROW_ADDR+1
        lda menu_dimmer_last_idx
        sta MENU_CURRENT_ITEM
        jsr menu_update_current_row

        ldx #<main_dimmer_exec
        ldy #>main_dimmer_exec
        stx MENU_EXEC_ADDR
        sty MENU_EXEC_ADDR+1

        ldx #<main_nothing_exec
        ldy #>main_nothing_exec
        stx MENU_NEXT_ADDR
        sty MENU_NEXT_ADDR+1

        ldx #<main_init_menu_song
        ldy #>main_init_menu_song
        stx MENU_PREV_ADDR
        sty MENU_PREV_ADDR+1

        jmp menu_invert_row
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void main_song_exec()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc main_song_exec
        lda MENU_CURRENT_ITEM
        bne :+
        jmp do_stop_song

:
        tax
        dex
        stx current_song

        jmp do_play_song
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void main_dimmer_exec()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc main_dimmer_exec
        lda MENU_CURRENT_ITEM
        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void main_light_exec()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc main_light_exec
        lda MENU_CURRENT_ITEM
        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void main_nothing_exec()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc main_nothing_exec
        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; do_stop_song
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc do_stop_song
        sei

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
; do_pause_song
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc do_pause_song
        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; do_resume_song
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc do_resume_song
        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; do_next_song
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc do_next_song
        ldx current_song
        inx
        cpx #TOTAL_SONGS
        bne l0

        ldx #0
l0:
        stx current_song

        jmp do_play_song
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; do_prev_song
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc do_prev_song
        ldx current_song
        dex
        bpl l0

        ldx #(TOTAL_SONGS-1)
l0:
        stx current_song

        jmp do_play_song
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; do_play_song
; decrunches real song, and initializes white song
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc do_play_song
        sei

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

        lda song_init_addr,x            ; update music init addr
        sta music_init_addr
        lda song_init_addr+1,x
        sta music_init_addr+1

        lda song_play_addr,x            ; update music play addr
        sta main::music_play_addr
        lda song_play_addr+1,x
        sta main::music_play_addr+1

        jsr init_crunch_data            ; requires x

        dec $01                         ; $34: RAM 100%

        jsr decrunch                    ; copy song

        inc $01                         ; $35: RAM + IO ($D000-$DF00)


        ldx #<$4cc7                     ; init timer
        ldy #>$4cc7                     ; sync with PAL
        stx $dc04                       ; it plays at 50.125hz
        sty $dc05                       ; we have to call this everytime

        lda #0
        tax
        tay
music_init_addr = * + 1
        jsr MUSIC_INIT

        lda #$81                        ; turn on cia interrups
        sta $dc0d

        cli
        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; variables
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
current_song:           .byte 0
sync_timer_irq:         .byte 0
sync_raster_irq:        .byte 0
song_tick:              .word 0
menu_song_last_idx:     .byte 0
menu_dimmer_last_idx:   .byte 0
menu_light_last_idx:    .byte 0
current_menu:           .byte 0

song_end_addrs:
        .addr song_1_eod
        .addr song_2_eod
        .addr song_3_eod
        .addr song_4_eod
        .addr song_5_eod
        .addr song_6_eod
        .addr song_7_eod
        .addr song_8_eod
TOTAL_SONGS = (* - song_end_addrs) / 2

; Ashes to Ashes:  3:43
; Final Countdown: 3:09
; Pop Goes the World: 3:31
; Jump: 1:35
; Enola Gay: 3:25
; Billie Jean: 3:58
; Another Day In Paradise: 2:24
; Wind of Change: 3:35
song_durations:                                 ; measured in "cycles ticks"
        .word (3*60+43) * 50                    ; #1 3:43
        .word (3*60+09) * 50                    ; #2 3:09
        .word (3*60+31) * 50                    ; #3 3:31
        .word (1*60+35) * 50                    ; #4 1:35
        .word (3*60+25) * 50                    ; #5 3:25
        .word (3*60+58) * 50                    ; #6 3:58
        .word (2*60+24) * 50                    ; #7 2:24
        .word (3*60+35) * 50                    ; #8 3:35

song_init_addr:                                 ; measured in "cycles ticks"
        .word $1000
        .word $1000
        .word $1000
        .word $1000
        .word $1000
        .word $0fe0
        .word $1000
        .word $1000

song_play_addr:                                 ; measured in "cycles ticks"
        .word $1006
        .word $1003
        .word $1003
        .word $1003
        .word $1003
        .word $0ff3
        .word $1003
        .word $1003

screen_colors:
        .incbin "mainscreen-colors.bin"

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
;.segment "CHARSET"
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.segment "CHARSET"
        .incbin "mainscreen-charset.bin"


;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
;.segment "COMPRESSED"
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.segment "COMPRESSED"

        .incbin "Ashes_to_Ashes.exo"
song_1_eod:

        .incbin "Final_Countdown.exo"
song_2_eod:

        .incbin "Pop_Goes_the_World.exo"
song_3_eod:

        .incbin "Jump.exo"
song_4_eod:

        .incbin "Enola_Gay.exo"
song_5_eod:

        .incbin "Billie_Jean_8bit_Style.exo"
song_6_eod:

        .incbin "Another_Day_in_Paradise.exo"
song_7_eod:

        .incbin "Wind_of_Change.exo"
song_8_eod:


.incbin "mainscreen-map.bin.exo"
screen_ram_eod:

.byte 0                 ; ignore


.segment "SID"
; reserved for SIDs
