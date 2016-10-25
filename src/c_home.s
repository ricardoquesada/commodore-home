;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
;
; UniJoystiCle test for the C64
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
.export get_crunched_byte               ; needed for exomizer decruncher

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; Constants
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.include "c64.inc"                      ; c64 constants

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

        jsr init_screen

        cli

main_loop:
        jmp main_loop
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
; get_crunched_byte
; The decruncher jsr:s to the get_crunched_byte address when it wants to
; read a crunched byte. This subroutine has to preserve x and y register
; and must not modify the state of the carry flag.
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
get_crunched_byte:
        lda _crunched_byte_lo
        bne @byte_skip_hi
        dec _crunched_byte_hi
@byte_skip_hi:

        dec _crunched_byte_lo
_crunched_byte_lo = * + 1
_crunched_byte_hi = * + 2
        lda song_end_addrs              ; self-modyfing. needs to be set correctly before
        rts                             ; decrunch_file is called.

; song order
; 1, 2, 3, 4, 5, 6, 7
song_names:
        .addr song_1_name
        .addr song_2_name
        .addr song_3_name
        .addr song_4_name
        .addr song_5_name
        .addr song_6_name
TOTAL_SONGS = (* - song_names) / 2

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

song_1_name:
        scrcode "Carito"
        .byte $ff
song_2_name:
        scrcode "Pop Goes The World"
        .byte $ff
song_3_name:
        scrcode "Droga Cumbia"
        .byte $ff
song_4_name:
        scrcode "Mama Killa"
        .byte $ff
song_5_name:
        scrcode "Paesaggio"
        .byte $ff
song_6_name:
        scrcode "Supremacy"
        .byte $ff


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
