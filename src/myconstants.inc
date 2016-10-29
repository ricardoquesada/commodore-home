;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
;
; Commodore Home: Home Automation for the masses, not the classes
; https://github.com/ricardoquesada/c64-home
;
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
;
; Global Enums and constants
;
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;

MUSIC_INIT = $1000
MUSIC_PLAY = $1003

SCREEN0_BASE = $0400
SCREEN1_BASE = $3000

BANK_BASE = 0
SPRITES_BASE = BANK_BASE + $2800                        ; Sprite 0 at $2400
                                                        ; reserved space for 32 sprites
                                                        ; from $2800 to $3000
SPRITES_POINTER = <((SPRITES_BASE .MOD $4000) / 64)     ; Sprite 0 at 144
SPRITES_PTR0 = SCREEN0_BASE + 1016                      ; right after the screen, at $7f8


;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
;
; ZP variables
;
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; WARNING: Using KERNAL routines like LOAD/SAVE and overwritting ZP is tricky
; just don't modify the variables used by those routines. 
; As a general rule, don't use variables above $90
; And don't use variables in the range of $2a0+
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; Used by menu.s
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
MENU_MAX_ITEMS = $41                                    ; .byte  total number of items
MENU_CURRENT_ITEM = $42                                 ; .byte  item idx  0<idx<max_items
MENU_BYTES_BETWEEN_ITEMS = $43                          ; .byte  40 for one after another
MENU_ITEM_LEN = $44                                     ; .byte  40 for complete line
MENU_CURRENT_ROW_ADDR = $45 ; and $46                   ; 2 .bytes  screen ptr to current item
MENU_EXEC_ADDR = $47  ; and $48                         ; 2 .bytes  When button is pressed, what to do
MENU_PREV_ADDR = $49  ; and $4a                         ; 2 .bytes  When "next" menu is pressed, what to do
MENU_NEXT_ADDR = $4b  ; and $4c                         ; 2 .bytes  When "prev" menu is pressed, what to do

