;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
;
; Commodore Home: Home Automation for the masses, not the classes
; https://github.com/ricardoquesada/c64-home
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
.import ut_get_key
.import song_1_eod, song_2_eod, song_3_eod, song_4_eod
.import song_5_eod, song_6_eod, song_7_eod, song_8_eod
.import mainscreen_charset_exo, mainscreen_map_exo
.import paln_freq_table_lo, paln_freq_table_hi, ntsc_freq_table_lo, ntsc_freq_table_hi
.import ut_vic_video_type


;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; Constants
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.include "c64.inc"                      ; c64 constants
.include "myconstants.inc"

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; .segment "CODE"
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.segment "CODE"

.export main_init
.proc main_init
        sei

        lda #$35
        sta $01                         ; no basic/kernal

        ldx #$ff                        ; reset stack... just in case
        txs

        lda #0
        sta $d01a                       ; no raster interrups

        sta VIC_SPR_ENA                 ; no sprites


        lda #$00                        ; background & border color
        sta $d020
        sta $d021

        lda #$00                        ; turn off volume
        sta SID_Amp
                                        ; multicolor mode + extended color causes

        jsr init_interrupts
        jsr init_screen
        jsr init_vars

;        lda #1                         ; test the alarm?
;        sta alarm_enabled
;        jmp do_alarm_trigger

        cli

main_loop:
        jsr menu_handle_events
        jsr unijoysticle_handle_events

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
; void unijoysticle_handle_events()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc unijoysticle_handle_events
        lda #%00011111
        sta $dc00

        lda $dc00
        and #%00011111
        eor #%00011111

        cmp last_uni_command                    ; avoid duplicates
        beq end

        sta last_uni_command

        tay                                     ; so commands want to know
                                                ; which command was called
                                                ; useful when multiple commands use
                                                ; one dispatch function

        asl
        tax
        lda uni_commands,x
        sta $fa
        lda uni_commands+1,x
        sta $fb
        jmp ($fa)

end:
        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; check_end_of_song
;   if (song_tick >= song_durations[current_song]) do_song_next();
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
        jsr do_song_next
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
; init_interrupts
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc init_interrupts
        lda #$7f                        ; turn off cia interrups
        sta $dc0d
        sta $dd0d

        lda $dc0d                       ; clear interrupts and ACK irq
        lda $dd0d
        asl $d019

        ldx #<irq_vector
        ldy #>irq_vector
        stx $fffe
        sty $ffff

                                        ; setup speed for timer
        ldx #<$4cc7                     ; default: PAL
        ldy #>$4cc7

        lda ut_vic_video_type
        cmp #$01                        ; PAL?
        beq store
        cmp #$2f                        ; PAL-N?
        beq do_paln

do_ntsc:                                ; fall through: NTSC
        ldx #<$4fb2
        ldy #>$4fb2
        bne store

do_paln:
        ldx #<$4fc1
        ldy #>$4fc1

store:
        stx $dc04
        sty $dc05

        rts
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

        ldx #<mainscreen_map_exo        ; decrunch in $0400
        ldy #>mainscreen_map_exo
        stx _crunched_byte_lo
        sty _crunched_byte_hi
        jsr decrunch

        ldx #<mainscreen_charset_exo    ; decrunch in $3800
        ldy #>mainscreen_charset_exo
        stx _crunched_byte_lo
        sty _crunched_byte_hi
        jsr decrunch

        inc $01                         ; $35: RAM + IO ($D000-$DFFF)

        jsr mainscreen_paint_colors

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

        jmp main_init_menu_song + 3     ; skip invert row row
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; init_vars
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc init_vars
        ldx #(VAR_ZERO_TOTAL-1)
        lda #0

l0:
        sta VAR_ZERO_BEGIN,x
        dex
        bpl l0

        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; mainscreen_paint_colors
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc mainscreen_paint_colors
        ldx #0                          ; read data from $0400
l1:                                     ; and update the color ram
        lda SCREEN0_BASE + $0000,x
        tay
        lda screen_colors,y
        sta $d800 + $0000,x

        lda SCREEN0_BASE + $0100,x
        tay
        lda screen_colors,y
        sta $d800 + $0100,x

        lda SCREEN0_BASE + $0200,x
        tay
        lda screen_colors,y
        sta $d800 + $0200,x

        lda SCREEN0_BASE + $02e8,x
        tay
        lda screen_colors,y
        sta $d800 + $02e8,x

        inx
        bne l1

        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; alarmcreen_paint_colors
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc alarmscreen_paint_colors
        ldx #0                          ; read data from $0400
l1:                                     ; and update the color ram
        lda SCREEN1_BASE + $0000,x
        tay
        lda screen_colors,y
        sta $d800 + $0000,x

        lda SCREEN1_BASE + $0100,x
        tay
        lda screen_colors,y
        sta $d800 + $0100,x

        lda SCREEN1_BASE + $0200,x
        tay
        lda screen_colors,y
        sta $d800 + $0200,x

        lda SCREEN1_BASE + $02e8,x
        tay
        lda screen_colors,y
        sta $d800 + $02e8,x

        inx
        bne l1

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
; void main_init_menu_alarm()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc main_init_menu_alarm
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
        lda menu_alarm_last_idx
        sta MENU_CURRENT_ITEM
        jsr menu_update_current_row

        ldx #<main_alarm_exec
        ldy #>main_alarm_exec
        stx MENU_EXEC_ADDR
        sty MENU_EXEC_ADDR+1

        ldx #<main_init_menu_song_from_alarm
        ldy #>main_init_menu_song_from_alarm
        stx MENU_NEXT_ADDR
        sty MENU_NEXT_ADDR+1

        ldx #<main_nothing_exec
        ldy #>main_nothing_exec
        stx MENU_PREV_ADDR
        sty MENU_PREV_ADDR+1

        jmp menu_invert_row
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void main_init_menu_song_from_dimmer()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc main_init_menu_song_from_dimmer
        lda MENU_CURRENT_ITEM
        sta menu_dimmer_last_idx
        jmp main_init_menu_song
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void main_init_menu_song_from_alarm()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc main_init_menu_song_from_alarm
        lda MENU_CURRENT_ITEM
        sta menu_alarm_last_idx
        jmp main_init_menu_song
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void main_init_menu_song()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc main_init_menu_song
        jsr menu_invert_row                     ; turn off previous menu

boot = *
        lda #8                                  ; setup the global variables
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

        ldx #<main_init_menu_alarm
        ldy #>main_init_menu_alarm
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

        ldx #<main_init_menu_song_from_dimmer
        ldy #>main_init_menu_song_from_dimmer
        stx MENU_PREV_ADDR
        sty MENU_PREV_ADDR+1

        jmp menu_invert_row
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void main_song_exec()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc main_song_exec
        lda MENU_CURRENT_ITEM
        sta current_song

        jsr song_menu_update            ; display arrow

        jmp do_song_play
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void main_dimmer_exec()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc main_dimmer_exec
        lda MENU_CURRENT_ITEM
        sta current_dimmer_value
        jsr dimmer_menu_update            ; display arrow
        jmp dimmer_perform
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void main_alarm_exec()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc main_alarm_exec
        lda MENU_CURRENT_ITEM
        sta alarm_enabled
        jmp alarm_menu_update
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void main_nothing_exec()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc main_nothing_exec
        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void dimmer_perform()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc dimmer_perform
        ldy current_dimmer_value

        lda printer_header_lo,y
        sta fname_lo
        lda printer_header_hi,y
        sta fname_hi

        inc $01                         ; $36: kernal in

                                        ; OPEN 3,4,0
        lda #3                          ; fd
        ldx #4                          ; printer
        ldy #0                          ; upper graphics... who cares.
        jsr $ffba                       ; call SETLFS

        jsr $ffc0                       ; call OPEN

        ldx #3
        jsr $ffc9                       ; call CHKOUT
        bne @error

        ldx #0
@l0:    lda fname,x
        jsr $ffd2                       ; call CHROUT
        inx
        cpx #FILENAME_LEN
        bne @l0

        lda #3                          ; CLOSE 3
        jsr $ffc3                       ; call CLOSE

        dec $01                         ; $35: kernal out
        rts
@error:
        ; Accumulator contains BASIC error code

        ; most likely errors:
        ; A = $05 (DEVICE NOT PRESENT)
        ; A = $04 (FILE NOT FOUND)
        ; A = $1D (LOAD ERROR)
        ; A = $00 (BREAK, RUN/STOP has been pressed during loading)

        lda #3
        jsr $ffc3                       ; call CLOSE

        inc $d020
        dec $01                         ; $35: kernal out
        rts

fname:  .byte 16                        ; chr$(16) -> command for the printer. move the header
fname_hi:
        .byte $30                       ; '0'
fname_lo:
        .byte $30                       ; '0'
        .byte 46                        ; '.'
        .byte 13
FILENAME_LEN = * - fname

printer_header_hi:
        .byte $30                       ; 00
        .byte $32                       ; 20
        .byte $34                       ; 40
        .byte $36                       ; 60
        .byte $37                       ; 79
printer_header_lo:
        .byte $30                       ; 00
        .byte $30                       ; 20
        .byte $30                       ; 40
        .byte $30                       ; 60
        .byte $39                       ; 79
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
;
; UniJoystiCle entry points
;
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; do_nothing
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc do_nothing
        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; do_alarm_on
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc do_alarm_on
        lda #1
        sta alarm_enabled
        jmp alarm_menu_update
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; do_alarm_off
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc do_alarm_off
        lda #0
        sta alarm_enabled
        jmp alarm_menu_update
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; do_alarm_trigger
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc do_alarm_trigger

        lda alarm_enabled
        bne :+
        rts

:
        sei
        lda #%11001110                  ; charset at $3800, screen at $3000
        sta $d018

        jsr alarmscreen_paint_colors

        lda #$7f                        ; turn off cia interrups
        sta $dc0d

        lda $dc0d                       ; ack possible interrupts
        lda $dd0d
        asl $d019

        ldx #<irq_vector_play
        ldy #>irq_vector_play
        stx $fffe
        sty $ffff

        lda #1                          ; enable raster irq
        sta $d01a

        ldx #$1c                        ; clean SID
        lda #0
l0:     sta SID,x
        dex
        bpl l0

        lda #$0f                        ; max volume
        sta SID_Amp

        lda #$a5
        sta SID_AD1                     ; A=9, D=5
        lda #$55
        sta SID_SUR1                    ; S=5, R=5

        cli
main_loop:
        jsr ut_get_key
        bcc main_loop


        jmp main_init
        rts

irq_vector_play:
        pha                             ; saves A, X, Y
        txa
        pha
        tya
        pha

        asl $d019                       ; clears raster interrupt

try_delay_note:
        lda curr_delay_note
        beq try_delay_release
        dec curr_delay_note
        bne :+
        lda #16                        ; release Gate sawtooth
        sta SID_Ctl1
:       jmp end

try_delay_release:
        lda curr_delay_release
        beq play_next_note
        dec curr_delay_release
        jmp end

play_next_note:

        ldx notes_idx
        lda notes,x
        cmp #$ff
        bne play

        ldx #0
        stx notes_idx
        lda notes
play:
        tay
        lda paln_freq_table_lo,y
        sta SID_S1Lo
        lda paln_freq_table_hi,y
        sta SID_S1Hi
        lda #17                         ; Gate sawtooth
        sta SID_Ctl1

        lda delays_note,x
        sta curr_delay_note
        lda delays_release,x
        sta curr_delay_release

        inc notes_idx

        txa
        lsr
        bcc :+
        lda #0
        beq change_color
:       lda #2
change_color:
        sta $d020
        sta $d021
end:
        pla                             ; restores A, X, Y
        tay
        pla
        tax
        pla
        rti                             ; restores previous PC, status

notes_idx:
        .byte 0
notes:
        .byte 64,76,64,76,64,76,64,76
        .byte $ff
delays_note:
        .byte $18,$18,$18,$18,$18,$18,$18,$18
delays_release:
        .byte $04,$04,$04,$04,$04,$04,$04,$04
curr_delay_note: .byte 0
curr_delay_release: .byte 0

.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; do_dimmer_?
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
do_dimmer_100:
do_dimmer_75:
do_dimmer_50:
do_dimmer_25:
do_dimmer_0:

        tya                             ; Y = current command

        sec
        sbc #15                         ; dimmer_0 = 15.
                                        ; so, change offset to 0
        sta current_dimmer_value
        jsr dimmer_menu_update
        jmp dimmer_perform


;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; do_song_?
; entry:
;       Y = command
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
do_song_0:
do_song_1:
do_song_2:
do_song_3:
do_song_4:
do_song_5:
do_song_6:
do_song_7:
        dey                             ; songs are "command - 1"
        sty current_song

        tya
        jsr song_menu_update

        jmp do_song_play

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; do_song_stop
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc do_song_stop
        sei

        lda #$7f                        ; turn off cia interrups
        sta $dc0d

        lda #$00
        sta SID_Amp

        lda $dc0d                       ; ack possible interrupts
        lda $dd0d
        asl $d019

        cli

        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; do_song_pause
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc do_song_pause
        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; do_song_resume
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc do_song_resume
        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; do_song_next
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc do_song_next
        ldx current_song
        inx
        cpx #TOTAL_SONGS
        bne l0

        ldx #0
l0:
        stx current_song

        txa
        jsr song_menu_update

        jmp do_song_play
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; do_song_prev
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc do_song_prev
        ldx current_song
        dex
        bpl l0

        ldx #(TOTAL_SONGS-1)
l0:
        stx current_song

        txa
        jsr song_menu_update

        jmp do_song_play
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; do_song_play
; decrunches real song, and initializes white song
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc do_song_play
        sei

        lda #0
        sta song_tick                   ; reset song tick
        sta song_tick+1

        lda #$7f                        ; turn off cia interrups
        sta $dc0d

        lda #$00                        ; no volume
        sta SID_Amp

        lda current_song                ; x = current_song * 2
        asl
        tax

        lda song_init_addr,x            ; update music init addr
        sta music_init_addr
        lda song_init_addr+1,x
        sta music_init_addr+1

        lda song_play_addr,x            ; update music play addr
        sta main_init::music_play_addr
        lda song_play_addr+1,x
        sta main_init::music_play_addr+1

        jsr init_crunch_data            ; requires x

        dec $01                         ; $34: RAM 100%

        jsr decrunch                    ; copy song

        inc $01                         ; $35: RAM + IO ($D000-$DF00)

        jsr update_freq_table

        lda #0
        tax
        tay
music_init_addr = * + 1
        jsr MUSIC_INIT

        lda #$81                        ; turn on cia interrups
        sta $dc0d

        lda #$11
        sta $dc0e                       ; start timer interrupt A

        cli
        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; song_menu_update(A = idx to select)
; uses temp: $fa, $fb, $fc, $fd, $fe
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc song_menu_update
        sta $fc

        ldx #<(SCREEN0_BASE + 40 * 16 + 8)
        ldy #>(SCREEN0_BASE + 40 * 16 + 8)
        stx $fa
        sty $fb

        lda #24
        sta $fd                         ; item lenght

        lda #8
        sta $fe

        jmp update_menu_arrows
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; dimmer_menu_update(A = idx to select)
; uses temp: $fa, $fb, $fc, $fd, $fe
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc dimmer_menu_update
        sta $fc                         ; item to display arrow

        ldx #<(SCREEN0_BASE + 40 * 16 + 33)
        ldy #>(SCREEN0_BASE + 40 * 16 + 33)
        stx $fa
        sty $fb

        lda #4                          ; item lenght - 1
        sta $fd                         ; 4 means a lenght of 5

        lda #5                          ; total items
        sta $fe

        jmp update_menu_arrows
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; alarm_menu_update(A = idx to select)
; uses temp: $fa, $fb, $fc, $fd, $fe
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc alarm_menu_update
        sta $fc                         ; item to display arrow

        ldx #<(SCREEN0_BASE + 40 * 16 + 0)
        ldy #>(SCREEN0_BASE + 40 * 16 + 0)
        stx $fa
        sty $fb

        lda #4                          ; item lenght - 1
        sta $fd                         ; 4 means a lenght of 5

        lda #2                          ; total items
        sta $fe

        jmp update_menu_arrows
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; update_menu_arrows
; uses $fa, $fb, $fc, $fd, $fe
; $fa,$fb:  screen ptr
; $fc: item to have the arrow
; $fd: item len
; $fe: number of items
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc update_menu_arrows

        ldx #0                          ; items

l0:
        cpx $fc                         ; item to place the arrow
        bne space

        ldy #0
        lda ($fa),y
        and #%10000000
        ora #30                         ; arrow ->
        sta ($fa),y

        ldy $fd                         ; item lenght
        ora #1                          ; arrow <-
        sta ($fa),y
        jmp next

space:
        ldy #0
        lda ($fa),y
        and #%10000000
        ora #$20
        sta ($fa),y

        ldy $fd                         ; item lenght
        sta ($fa),y

next:
        clc
        lda $fa
        adc #40
        sta $fa
        bcc :+
        inc $fb
:

        inx
        cpx $fe                        ; 7 = total items
        bne l0

        rts
.endproc

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; void update_freq_table()
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc update_freq_table
        ;   $01 --> PAL
        ;   $2F --> PAL-N
        ;   $28 --> NTSC
        ;   $2e --> NTSC-OLD
        lda ut_vic_video_type 
        cmp #$01                                        ; PAL? don't update it then
        bne l0
        rts

l0:
        cmp #$2f                                        ; PAL-N ?
        bne l2                                          ; if so, use PAL-N tables

        ldx #<ntsc_freq_table_lo
        ldy #>ntsc_freq_table_lo
        stx src_lo
        sty src_lo+1
        ldx #<ntsc_freq_table_hi
        ldy #>ntsc_freq_table_hi
        stx src_hi
        sty src_hi+1


l2:
        lda current_song
        asl
        tax

        lda song_table_freq_addrs_lo,x
        sta dst_lo
        lda song_table_freq_addrs_lo+1,x
        sta dst_lo+1

        lda song_table_freq_addrs_hi,x
        sta dst_hi
        lda song_table_freq_addrs_hi+1,x
        sta dst_hi+1


        ldx #96                                         ; copy one less
                                                        ; since sidwizard table
src_lo = *+1                                            ; seems to be moved
l1:     lda ntsc_freq_table_lo,x
dst_lo = *+1
        sta $1000,x                                     ; self modifying

src_hi = *+1
        lda ntsc_freq_table_hi,x
dst_hi = *+1
        sta $1000,x                                     ; self modifying

        dex
        bpl l1

        rts
.endproc
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; variables
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
VAR_ZERO_BEGIN = *
current_song:           .byte 0
sync_timer_irq:         .byte 0
sync_raster_irq:        .byte 0
song_tick:              .word 0
menu_song_last_idx:     .byte 0
menu_dimmer_last_idx:   .byte 0
menu_alarm_last_idx:    .byte 0
current_menu:           .byte 0
current_dimmer_value:   .byte 0
last_uni_command:       .byte 0
alarm_enabled:          .byte 0
VAR_ZERO_TOTAL = * - VAR_ZERO_BEGIN

uni_commands:
        .addr do_nothing                ; 0
        .addr do_song_0                 ; 1
        .addr do_song_1                 ; 2
        .addr do_song_2                 ; 3
        .addr do_song_3                 ; 4
        .addr do_song_4                 ; 5
        .addr do_song_5                 ; 6
        .addr do_song_6                 ; 7
        .addr do_song_7                 ; 8
        .addr do_song_stop              ; 9
        .addr do_song_play              ; 10
        .addr do_song_pause             ; 11
        .addr do_song_resume            ; 12
        .addr do_song_next              ; 13
        .addr do_song_prev              ; 14
        .addr do_dimmer_0               ; 15
        .addr do_dimmer_25              ; 16
        .addr do_dimmer_50              ; 17
        .addr do_dimmer_75              ; 18
        .addr do_dimmer_100             ; 19
        .addr do_alarm_off              ; 20
        .addr do_alarm_on               ; 21
        .addr do_alarm_trigger          ; 22
        .addr do_nothing                ; 23
        .addr do_nothing                ; 24
        .addr do_nothing                ; 25
        .addr do_nothing                ; 26
        .addr do_nothing                ; 27
        .addr do_nothing                ; 28
        .addr do_nothing                ; 29
        .addr do_nothing                ; 30
        .addr do_nothing                ; 31
TOTAL_COMMANDS = (* - uni_commands) / 2
        ; Assert( TOTAL_COMMANDS == 32)


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

song_init_addr:
        .word $1000
        .word $1000
        .word $1000
        .word $1000
        .word $1000
        .word $0fe0
        .word $1000
        .word $1000

song_play_addr:
        .word $1006
        .word $1003
        .word $1003
        .word $1003
        .word $1003
        .word $0ff3
        .word $1003
        .word $1003

song_table_freq_addrs_lo:
        .addr $1564
        .addr $14fd
        .addr $1635
        .addr $151b
        .addr $151b
        .addr $151b
        .addr $16ea
        .addr $17eb
        .addr $1779
        .addr $1404                             ; easteregg song

song_table_freq_addrs_hi:
        .addr $15c4
        .addr $149d
        .addr $1695
        .addr $14bb
        .addr $14bb
        .addr $14bb
        .addr $1682
        .addr $1783
        .addr $1711
        .addr $1464                             ; easteregg song

screen_colors:
        .incbin "mainscreen-colors.bin"

