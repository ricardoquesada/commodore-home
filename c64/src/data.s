;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
;
; Commodore Home: Home Automation for the masses, not the classes
; https://github.com/ricardoquesada/c64-home
;
; data
;
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
;.segment "CHARSET"
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.segment "CHARSET"
        .res 2048,0

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
;.segment "SCREEN1"
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.segment "SCREEN1"
        .incbin "alarm-map.bin"

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
;.segment "COMPRESSED"
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.segment "COMPRESSED"

        .incbin "Ashes_to_Ashes.exo"
.export song_1_eod
song_1_eod:

        .incbin "Final_Countdown.exo"
.export song_2_eod
song_2_eod:

        .incbin "Pop_Goes_the_World.exo"
.export song_3_eod
song_3_eod:

        .incbin "Jump.exo"
.export song_4_eod
song_4_eod:

        .incbin "Enola_Gay.exo"
.export song_5_eod
song_5_eod:

        .incbin "Billie_Jean_8bit_Style.exo"
.export song_6_eod
song_6_eod:

        .incbin "Another_Day_in_Paradise.exo"
.export song_7_eod
song_7_eod:

        .incbin "Wind_of_Change.exo"
.export song_8_eod
song_8_eod:

        .incbin "Take_My_Breath_Away.exo"
.export song_9_eod
song_9_eod:

        .incbin "mainscreen-map.bin.exo"
.export mainscreen_map_exo
mainscreen_map_exo:

        .incbin "mainscreen-charset.bin.exo"
.export mainscreen_charset_exo
mainscreen_charset_exo:

        ; export it at 0x0400
        .incbin "src/intro-map.bin.exo"
.export intro_map_exo
intro_map_exo:

        ; export it at 0x3800
        .incbin "src/intro-charset.bin.exo"
.export intro_charset_exo
intro_charset_exo:

.byte 0                 ; ignore

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
;segment "SID"
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.segment "SID"
; reserved for SIDs

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
;segment "SPRITES"
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.segment "SPRITES"
        .incbin "src/sprites.bin"

