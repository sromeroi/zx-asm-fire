;----------------------------------------------------------------------
;-- Z80 ASM test 2023 - fire.asm for the Sinclair ZX Spectrum.
;-- A tribute to Jare's fire demo published on 1993 for PC/MSDOS.
;-- Dec-2023 - Santiago Romero <sromero@gmail.com>
;-- Last updated version at: https://github.com/sromeroi/zx-asm-fire
;----------------------------------------------------------------------

    ORG 35000                ; Set it to 27000 for 16K models


;----------------------------------------------------------------------
;-- Constants
;----------------------------------------------------------------------

BORDCR          EQU $5C48    ; Spectrum's system variable address: BORDER color
SEED            EQU $5C76    ; Spectrum's system variable address: RND seed
VRAM_PIXELS     EQU $4000    ; VideoRam for pixels/bitmap starts here
VRAM_ATTRIB     EQU $5800    ; VideoRam for colours/attributes starts here

FG_BLACK        EQU 0
FG_BLUE         EQU 1
FG_RED          EQU 2
FG_MAGENTA      EQU 3
FG_GREEN        EQU 4
FG_CYAN         EQU 5
FG_YELLOW       EQU 6
FG_WHITE        EQU 7
BG_BLACK        EQU 0
BG_BLUE         EQU (FG_BLUE << 3)
BG_RED          EQU (FG_RED << 3)
BG_MAGENTA      EQU (FG_MAGENTA << 3)
BG_GREEN        EQU (FG_GREEN << 3)
BG_CYAN         EQU (FG_CYAN << 3)
BG_YELLOW       EQU (FG_YELLOW << 3)
BG_WHITE        EQU (FG_WHITE << 3)
COLOR_BRIGHT    EQU 64

; Fire never reaches top, so it's ok to reduce the "fire" array and just
; render the top-left corner of the fire on a lower Y screen coordinate
FIRE_HEIGHT     EQU 20
FIRE_START      EQU (24-FIRE_HEIGHT)*32


;----------------------------------------------------------------------
;-- MAIN PROGRAM (ENTRY POINT)
;----------------------------------------------------------------------
main:
        call SetBlackBorder      ; Prepare screen with black border,
        call ClearAttributes     ; black INK/PAPER, and a bg pattern by
        call FillPattern         ; alternating 01010101b/10101010b each line
                                 ; to allow extra colors with "dithering"

mainloop:
        call AddFlames           ; add flames to fire bottom
        call AnimateFire         ; animate the fire (calculate next frame)
        call RenderFire          ; render fire "array" to screen (attributes)
        jr mainloop              ; you'll never return to BASIC :)


;----------------------------------------------------------------------
;-- Set border to black colour
;----------------------------------------------------------------------
SetBlackBorder:
        xor a
        ld (BORDCR), a
        out ($fe), a              ; set border 0 (black)
        ret


;----------------------------------------------------------------------
;-- Set screen attributes to 0 (BLACK)
;----------------------------------------------------------------------
ClearAttributes:
        ld hl, VRAM_ATTRIB
        ld de, VRAM_ATTRIB+1
        ld bc, (32*24)-1
        xor a
        ld (hl), a
        ldir                     ; Clear entire attribute area (768 bytes)
        ret


;----------------------------------------------------------------------
;-- Fill the screen with a 10101010b pattern for even lines and
;-- a 01010101b pattern for odd lines.
;----------------------------------------------------------------------
FillPattern:
        ld hl, VRAM_PIXELS
        ld b, 192                ; scanlines to draw

.loop_line:
        ld a, %10101010          ; default value for EVEN lines
        bit 0, h                 ; bit 0 of H (Y's LSB) selects pattern value
        jr z, .draw_scanline
        ld a, %01010101          ; alternate value for ODD lines (when H's LSB is 1)

.draw_scanline:
        ld c, 32                 ; each scanline is 32 "pixels" (attributes)

.draw_block
        ld (hl), a               ; store A in HL (paint first 8 pixels of scanline)
        inc hl                   ; advance to next attribute

        dec c
        jr nz, .draw_block       ; Repeat for all 32 horizontal "pixels"

        djnz .loop_line          ; Repeat for 192 scanlines
        ret


;----------------------------------------------------------------------
;-- Add some "hot spots" at the bottom of the fire.
;-- Fill the last line of the fire with random values.
;----------------------------------------------------------------------
AddFlames:
        ld hl, fire+(32*(FIRE_HEIGHT-1))
        ld b, 32

.loop:
        call Random              ; Get a random number 0-256

        REPT 4
        rrca                     ; rotate right 4 times (divide by 16)
        ENDR

        and %00001111            ; Clears bits 7-4 (old LSB's)
        add a, 2                 ; Increase a bit the resulting value
        cp 16
        jr c, .is_within_palette_range
        ld a, 15
.is_within_palette_range
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
AnimateFire:
        ld ix, fire              ; use IX as the pointer to each fire "pixel"
        ld hl, fire              ; use HL also for (IX+0) (7 cicles vs 19 cicles)
        ld b, FIRE_HEIGHT        ; repeat for FIRE_HEIGHT lines -1

.loop_fire_line:
        ld c, 32                 ; for each line, repeat for 32 characters

.loop_fire_pixel:
        ld a, (hl)               ; Get IX+0 using HL
        add a, (hl)              ; Pixel next to current one (right) use IX+1
        add a, (ix+32-1)         ; For the pixels below use IX+N
        add a, (ix+32)
        add a, (ix+32+1)         ; sum all 4 values
        rrca                     ; divide by 4
        rrca
        and %00001111
        cp 2
        jr c, .skip_substract
        sub 2                    ; if value >= 2, reduce fire

.skip_substract:
        ld (hl), a               ; Store calculated value
        inc ix
        inc hl
        dec c
        jr nz, .loop_fire_pixel

        djnz .loop_fire_line     ; Repeat for the 23 lines
        ret


;----------------------------------------------------------------------
;-- Render Fire
;----------------------------------------------------------------------
RenderFire:

        ; Calc BC for fast 16 bits loop
        ; (See https://map.grauw.nl/articles/fast_loops.php)
        ld de, 32*(FIRE_HEIGHT-1)
        ld b, e
        dec de
        inc d                    ; Calculate DE value (destroys B, D and E)
        ld c, d                  ; Now CB = 32*23 prepared for the 16 bits loop.

        ld hl, fire              ; HL = source (fire)

        ; DE = destination (attributes memory block), + jump 1 line
        ld de, VRAM_ATTRIB+FIRE_START

        halt                     ; VSYNC => enable if you want to limit framerate
                                 ; Not really required on Z80@3.5Mhz

.render_fire_line:
        ld a, (hl)               ; Read "fire" value
        inc hl

        push de                  ; backup de

        ld de, palette           ; de = points to palette[0]
        and %00001111            ; ensure A is <= 15
        or e                     ; A = A + E
        ld e, a                  ; DE = points to palette[A]

        ld a, (de)               ; A = palette[A] = palette[fire[n]]

        pop de                   ; restore de

        ld (de), a               ; Write "pixel" (fire attribute) in the screen
        inc de

        ; Loop for (32*23) times, with BC previously calculated for this "trick"
        djnz .render_fire_line
        dec c
        jr nz, .render_fire_line

        ret


;----------------------------------------------------------------------
;-- Generate a random number
;-- Output: 0<=a<=255
;-- all registers are preserved except: af
;-- Pseudorandom number generator featured in Ion by Joe Wingbermuehle
;----------------------------------------------------------------------
Random:
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

; Our fire representation (32x24)
fire DS (32*FIRE_HEIGHT), 0

        ALIGN 16
; 16 colours black=>reds=>yellows=>white
; Align palette[0] to 16 to quick lookup
palette:
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

    include TapLib.asm
    MakeTape ZXSPECTRUM48, "fire.tap", "Fire", main, program_length, main
