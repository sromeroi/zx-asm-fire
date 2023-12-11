;----------------------------------------------------------------------
;-- Z80 ASM test 2023 - fire.asm
;-- A tribute to Jare's fire demo published on 1993 for PC/MSDOS.
;-- Dec-2023 - Santiago Romero <sromero@gmail.com>
;----------------------------------------------------------------------

    ORG $8000

;----------------------------------------------------------------------
;-- Constants
;----------------------------------------------------------------------
BORDCR          EQU 0x5C48
SEED            EQU 23670

FG_BLACK        EQU 0
FG_BLUE         EQU 1
FG_RED          EQU 2
FG_MAGENTA      EQU 3
FG_GREEN        EQU 4
FG_CYAN         EQU 5
FG_YELLOW       EQU 6
FG_WHITE        EQU 7
BG_BLACK        EQU 0
BG_BLUE         EQU (1<<3)
BG_RED          EQU (2<<3)
BG_MAGENTA      EQU (3<<3)
BG_GREEN        EQU (4<<3)
BG_CYAN         EQU (5<<3)
BG_YELLOW       EQU (6<<3)
BG_WHITE        EQU (7<<3)
COLOR_BRIGHT    EQU 64


;----------------------------------------------------------------------
;-- MAIN PROGRAM (ENTRY POINT)
;----------------------------------------------------------------------
main:
    ; Prepare screen with black border+screen and a bg pattern
    call set_black_border
    call fill_pattern
    call clear_attributes

mainloop:
    call add_flames          ; add flames to fire bottom
    call animate_fire        ; animate the fire (calculate next frame)
    call render_fire         ; render fire "array" to screen (attributes)
    jp mainloop


;----------------------------------------------------------------------
;-- Set border to black colour
;----------------------------------------------------------------------
set_black_border:
    xor a
    ld (BORDCR), a
    out ($fe), a              ; set border 0 (black)
    ret


;----------------------------------------------------------------------
;-- Set screen attributes to 0 (BLACK)
;----------------------------------------------------------------------
clear_attributes:
    ld hl, $4000+(192*32)
    ld de, $4000+(192*32)+1
    ld bc, (32*24)-1
    xor a
    ld (hl), a
    ldir                     ; Clear entire attribute area (768 bytes)
    ret


;----------------------------------------------------------------------
;-- Fill the screen with a 10101010b pattern for even lines and
;-- a 01010101b pattern for odd lines.
;----------------------------------------------------------------------
fill_pattern:
    ld hl, $4000
    ld b, 192                ; scanlines to draw

.loop_line:
    ld a, 10101010b          ; default value for EVEN lines
    bit 0, h                 ; bit 0 of H (Y's LSB) selects pattern value
    jr z, .draw_scanline
    ld a, 01010101b          ; alternate value for ODD lines (when H's LSB is 1)

.draw_scanline:
    REPT 32
    ld (hl), a               ; store A in HL (paint first 8 pixels of scanline)
    inc hl
    ENDR

    djnz .loop_line          ; Repeat for 192 scanlines
    ret


;----------------------------------------------------------------------
;-- Add some "hot spots" at the bottom of the fire.
;-- Fill the last line of the fire with random values.
;----------------------------------------------------------------------
add_flames:
    ld hl, fire+(32*23)
    ld b, 32

.loop:
    call random              ; Get a random number 0-256
    rrca
    rrca
    rrca
    rrca                     ; Divide by 16 (now is 0-16)
    and 00001111b            ; Ensure bits 7-4 are 0
    add 2                    ; Increase the resulting value
    cp 16
    jp m, .is_within_palette_range
    ld a, 15
.is_within_palette_range
    ;cp 5
    ;jp nc, .is_bigger_than_minimum
    ;ld a, 5
;.is_bigger_than_minimum:
    ld (hl), a               ; Add "flame" to our fire
    inc hl

    djnz .loop
    ret


;----------------------------------------------------------------------
;-- Calculate next fire frame:
;-- Each pixel is calculated with its value and the 3 pixels below it,
;-- calculating the average, and substracting some value (to make the
;-- fire vanish slowly). We also ensure that "pixel" is <= 15 always.
;----------------------------------------------------------------------
animate_fire:
    ld ix, fire+32           ; use IX as the pointer to each fire "pixel"
    ld b, 22                 ; repeat for 23 lines

.loop_fire_line:
    ld c, 32                 ; for each line, repeat for 32 characters

.loop_fire_pixel:
    ld a, (ix)
    add a, (ix+1)
    add a, (ix+32-1)
    add a, (ix+32)
    add a, (ix+32+1)         ; sum all 4 values
    rrca                     ; divide by 4
    rrca
    and 00001111b
    cp 2
    jr c, .skip_substract
    sub 2                    ; if value >= 2, reduce fire

.skip_substract:
    ld (ix), a               ; Store calculated value
    inc ix
    dec c
    jr nz, .loop_fire_pixel

    djnz .loop_fire_line     ; Repeat for the 23 lines
    ret


;----------------------------------------------------------------------
;-- Render Fire
;----------------------------------------------------------------------
render_fire:
    ;halt                    ; VSYNC => enable if you want to limit framerate

    ld hl, fire              ; HL = source (fire)
    ld de, $4000+6144        ; DE = destination (attributes memory block)

.render_fire_line:

    REPT 32*23               ; unroll loop for 768 times
    ld a, (hl)               ; Read "fire" value
    inc hl
    ld ix, hl                ; backup hl

    ld hl, palette           ; use HL+BC as palette[bc] to get color palette A
    ld b, 0
    ld c, a
    add hl, bc
    ld a, (hl)               ; A = palette[ fire[n] ]

    ld hl, ix

    ld (de), a               ; Write "pixel" (fire attribute) in the screen
    inc de
    ENDR

    ret


;----------------------------------------------------------------------
;-- Generate a random number
;-- Output: 0<=a<=255
;-- all registers are preserved except: af
;-- Pseudorandom number generator featured in Ion by Joe Wingbermuehle
;----------------------------------------------------------------------
random:
    push hl
    push de
    ld hl, (SEED)
    ld a, r
    ld d, a
    ld e, (hl)
    add hl, de
    add a, l
    xor h
    ld (SEED), hl
    pop de
    pop hl
    ret


;----------------------------------------------------------------------
;-- Variables
;----------------------------------------------------------------------

fire DS (32*24), 0           ; Our fire representation (32x24)

palette:                     ; 16 colours black=>reds=>yellows=>white
    DB FG_BLACK + BG_BLACK
    DB FG_BLACK + BG_RED
    DB FG_BLACK + BG_RED
    DB FG_RED + BG_BLACK + COLOR_BRIGHT
    DB FG_RED + BG_BLACK + COLOR_BRIGHT
    DB FG_RED + BG_RED
    DB FG_RED + BG_RED
    DB FG_RED + BG_RED + COLOR_BRIGHT
    DB FG_RED + BG_RED + COLOR_BRIGHT
    DB FG_RED + BG_YELLOW
    DB FG_RED + BG_YELLOW + COLOR_BRIGHT
    DB FG_YELLOW + BG_YELLOW
    DB FG_YELLOW + BG_WHITE
    DB FG_YELLOW + BG_YELLOW + COLOR_BRIGHT
    DB FG_YELLOW + BG_WHITE + COLOR_BRIGHT
    DB FG_WHITE + BG_WHITE + COLOR_BRIGHT


;----------------------------------------------------------------------
program_length = $-main

    include     TapLib.asm
    MakeTape ZXSPECTRUM48, "fire.tap", "Fire", main, program_length, main
