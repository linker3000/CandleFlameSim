; Flicker.ASM
; Candle flame simulator
;     by Phred Nees
; Version 1.0 - October 2004
; Version 1.02 - February 2014 by N. Kendrick
;
; NK changes/comments:
;   * Phred Nees is acknowledged as the original author of this code.
;   * Originally published here: 
;     http://www.horrorseek.com/home/halloween/wolfstone/Flicker/flksof_SoftwareFlicker.html#Phredog
;   * Added config line for chip 
;   * 'list' and 'include' lines tweaked to make them compatible with mpasm
;   * Minor code change in the way that the oscillator calibration value is used/set - now uses
;     variable definition from the .inc file.
;   * 500mS delay at start before output driven to allow PIC to initialise before we try
;     to drive any heavy loads (eg: 12V lamps), which may cause the power rails
;     to sag and cause PIC startup problems.
;   * Minor comments added/changed.
;
; Phredog originally used PIC12C parts but this code works fine with 12F508 and 12F509.
;
; I have used this circuit with a discrete Darlington transistor pair with a power 
; transistor to drive two 55W 12V amber car rear indicator lamps. With heavy loads like
; that, make sure the power supply will cope - if there's too much sag on the power rail,
; the microprocessor may lock up. 
;
; nigel.kendrick@gmail.com
;
; End of NK changes/comments:

; You may direct questions or comments to Phredog@Yahoo.com
; A legitimate question would be something like, "Can I use some surplus PIC12C508?" (Yes
; you can).  A legitimate comment would be something like, "I changed xxx, and got a more
; realistic flicker effect".  If you don't genuinely need help, or have something to con-
; tribute please don't contact me.

;For Technical Assistance:
; Please consult the data sheets and technical information at www.Microchip.com for tech-
; nical assistance with the PIC12C509(A) device, and programming.

;For parts:
; Blank PIC12C509A chips, and programming hardware can be obtained from www.digikey.com,
; etc. Other parts like resistors, IC sockets, and LED's may be purchased from www.digikey.com,
; www.mouser.com, Radio Shack, Frys Electronics, etc.

;Disclaimer:
; The author is not responsible for damages, etc.  The author is not affiliated with Microchip,
; Digikey, Mouser, Fry's Electronics, or Radio Shack, etc.  The author does not sell, or program
; parts.  This software is distributed without warrantee.

;Freeware:
; No product containing this software may be sold for any commercial enterprise.  Non-profit
; organizations such as churches, Boy Scouts etc, may sell products containing this software as
; a fund raiser.  You may build products containing this software as a hobby.  You may give them
; away as gifts if you wish to do so.

;Abstract:
; The LED(s) will flicker much like a candle flame.  The actual flash rate is 61 times per second
; (well beyond the persistence of human vision.  The on/off ratio of the LED will affect the
; perceived brightness.  The brightness will change at just over 12 times per second.

;Ok, now for the details:
;
;                    PINOUT :
;                _______  _______
;               |  *    \/       |
;     +5V Vcc --+ 1            8 +-- Ground
;               |                |
;   Not used  --+ 2            7 +-- Pattern select 0
;               |                |
;   Not used  --+ 3            6 +-- Pattern select 1
;               |                |
;      Delta  --+ 4            5 +-- LED out
;               |                |
;               +----------------+

;
;         Pin 5 =  Output (to drive LED(s))
;       Pin 4 =  Delta (Low = 4 bit, High = 5 bit)
; Pins 6, and 7 =  Tie these pins low or leave them open to select one of 4 unique flicker sequences.
;

;And now we get more detailed:
; Every 66mS a six bit random number is generated using a 31 bit feedback shift register.  The starting
; seed may be changed as desired.  Also pins 6, and 7 are used to modify the starting seed value.  Four
; unique flicker patterns are possible without changing the IC.

; Pin 4 will affect the delta used every 66mS.  If the pin is left open 5 bits are used to adjust the
; brightness each cycle.  If the pin is tied low only 4 bits are used.  The lower choice might be de-
; sired if this chip is used to simulare an oil lamp which has a more steady light than a candle.

; The 8 bit rtc is used to time the pulse width modulation of pin 5.  When the rtc reaches count 0, pin
; five is driven high.  When the brightness count (ZCROSS) is reached, the pin is driven low for the re-
; mainder of the timing cycle.  If the current brightness count (ZCROSS) is say 128, then pin 5 will be
; driven high for about 50% of the time.

; Master clock = 4 Mhz
; CPU clock = 1Mhz
; RTC frequency = 15.625 Khz
; RTC Rollover = 61.03Hz
; Brightness will Change @ 15.26Hz

; Configuration
;    CODE PROTECTION = OFF
;    WDT   = ON
;    RESET = INTERNAL
;    CLOCK = INTERNAL RC

; list    p=12f508,        f=inhx8m
; #include p12f508.inc

; NK V1.01 lines added...
    list    p=12f508
    #include <p12f508.inc>

; NK V1.01 line added...
 __config _CP_OFF & _WDT_ON & _MCLRE_OFF & _IntRC_OSC

;Register definitions

rtc            EQU     01
pc             EQU     02
status         EQU     03
fsr            EQU     04

;Software registers

RND0    EQU    07H    ; rnd shift reg byte 0
RND1    EQU    08H    ; rnd shift reg byte 1
RND2    EQU    09H    ; rnd shift reg byte 2
RND3    EQU    0AH    ; rnd shift reg byte 3
TEMP    EQU    0BH    ; temporary storage for XOR feedback calculation
ZCROSS  EQU    0CH    ; current PWM zero crossing point
NEW     EQU    0DH    ; new random number
COUNT   EQU    0EH    ; loop counter
COUNT1  EQU    0FH    ; loop counter for random number gen

;Bit definitions

cy      EQU    0
dc      EQU    1
z       EQU    2
w       EQU    0
f       EQU    1


delta   EQU    3
led     EQU    2

; NK V1.01 - changed coding - added lines ...

       UDATA
dc1     res 1               ; delay loop counters
dc2     res 1

;***** RC CALIBRATION - SET CORRECT VECTOR if changing PIC type
RCCAL   CODE    0x1FF       ; 12F508 processor reset vector
;RCCAL   CODE    0x3FF       ; 12F509 processor reset vector

        res 1               ; holds internal RC cal value, as a movlw k

;***** RESET VECTOR *****************************************************
RESET   CODE    0x000       ; effective reset vector

; NK V1.01 - end of added lines
;
;******************************************************************************
;Init ports
;This is pretty straight forward.  Just look at the Microchip data sheet for explanation.
;
start

; NK V1.01 - changed incorrect coding was movlw   oscal
    movwf   OSCCAL       ;Calibrate osc

    clrf    GPIO        ;Clear port A
    movlw    3Bh        ;Send to
    tris    GPIO        ;tris reg (Port 2 is output, all others are input)


    movlw   05h         ;Set RTC to /64, and pullups on GPIO
    option            ;

;NK V1.01 - 500ms delay before we flash anything to ensure that PIC
;is stable before we drive any big loads and cause voltage sags...

        ; delay 500ms
        movlw   .244            ; outer loop: 244 x (1023 + 1023 + 3) + 2
        movwf   dc2             ;   = 499,958 cycles
        clrf    dc1             ; inner loop: 256 x 4 - 1
dly1    clrwdt                  ; inner loop 1 = 1023 cycles. Satisfy the wdt
        decfsz  dc1,f
        goto    dly1
dly2    nop                     ; inner loop 2 = 1023 cycles
        decfsz  dc1,f
        goto    dly2
        decfsz  dc2,f
        goto    dly1

;NK V1.01 - end of 500ms delay

;
;******************************************************************************
;Setup
;
    movlw    09FH        ;Preset shift register with..
    movwf    RND0        ;the random seed 0x9F50A31
    movlw    050H

    movwf    RND1        ;The seed value can be any number.
    movlw    00AH        ;Zero is possible, but has not been tried.
    movwf    RND2
    movlw    031H
    movwf    RND3

    movf    GPIO,0        ;Get the GPIO
    andlw    0Bh        ;Mask off all but pins 3,6, and 7
    xorwf    RND0,f        ;So they can affect the..
    xorwf    RND2,f        ;seed value.  2 bits = 4 possible values

    call    rand        ;Get a 6 bit random number for the starting value
    bsf    NEW,5        ;Set bit 5 (Value is 32-63)
    movf    NEW,w        ;Get it
    movwf    ZCROSS        ;Post it

    movlw    4        ;Preset the..
    movwf    COUNT        ;count
;
;******************************************************************************
;First we clear the rtc.  Next we drive the output high. We check to see if it
;is time to re-calculate ZCROSS, then we wait.  Once ZCROSS is reached we drive
;the output low.  Once the rtc rolls over, we repeat the cycle.
;
pwm_begin    ;Start with the RTC at zero

    clrf    rtc        ;Zero the RTC

pwm_loop    ;Turn the LED on  (This happens 61 times per second)
        ;We have at least 2.048mS to do our math.

    bsf    GPIO,led    ;LED on
    clrwdt            ;Satisfy the wdt

    ;See if we have used this pulse width at least 5 times
    decfsz    COUNT,f        ;Count the number of cycles
    goto    on_loop        ;continue if not done

    ;We have used this pulse width 4 times, so get a new ZCROSS
    movlw    4        ;Reset..
    movwf    COUNT        ;the count
    call    get_new        ;Get new zcross

on_loop    ;Wait until the rtc reaches ZCROSS, then turn off pin 5.

    movf    ZCROSS,0    ;Get the crossover point
    xorwf    rtc,0        ;Compare to the rtc
    btfss    status,z    ;Yes?
    goto    on_loop        ;No, try again

    bcf    GPIO,led    ;Pin 5 off

off_loop    ;Wait for the rtc to rollover
        ;This could take up to 14.9mS

    movf    rtc,0        ;Test for rollover
    btfss    status,z    ;Yes?
    goto    off_loop    ;No, try again

      ;One complete loop at 61Hz has completed

    goto    pwm_loop    ;Do it again
;
;******************************************************************************
;Adjust ZCROSS (an 8 bit number between 32 and 240) by 0-32 in normal mode.
;Adjust by 0-16 in low delta mode. Brightness range is from 12.5% and 93.7%).
;
get_new
    call    rand        ;Get 6 random bits (5 + sign)
    btfss    GPIO,delta    ;If delta is high, then don't remove the msb
    rrf    NEW,f        ;/2

    rrf    NEW,w        ;Get the value in w
    btfss    status,cy    ;Test bit 0
    goto    subtract

    ;Going up - Add the 5 bit offset, and make sure it didn't overflow
       andlw    01FH        ;Use only 5 bits (or 4)
       addwf    ZCROSS,1    ;Add it
    ;Max vlaue must be 224, so make sure 5, 6, and 7 are not all set.
       btfss    ZCROSS,5    ;Did we overflow?
    retlw    00        ;No, go
       btfss    ZCROSS,6    ;Did we overflow?
    retlw    00        ;No, go
       btfss    ZCROSS,7    ;Did we overflow?
    retlw    00        ;No, go
    ;None of the three are set... overflow! so max it out
    movlw    0E0H        ;Make it
    movwf    ZCROSS        ;224!
    retlw    00        ;Bye

subtract    ;Subtract the 5 bit offset, and make sure we didn't underflow
       andlw    01FH        ;Use only 5 bits (or 4)
       subwf    ZCROSS,1    ;Subtract it
    ;Min vlaue must be 32, so make sure bit 5, 6, or 7 is set.
       btfsc    ZCROSS,5    ;Did we underflow?
    retlw    00        ;No, go
       btfsc    ZCROSS,6    ;Did we underflow?
    retlw    00        ;No, go
       btfsc    ZCROSS,7    ;Did we underflow?
    retlw    00        ;No, go
    ;None of the three are set... underflow! so make in min
    movlw    020h        ;Make it
    movwf    ZCROSS        ;32!
    retlw    00        ;Bye
;
;******************************************************************************
; Make a 6 bit random number and save it in NEW.
; We are using a 31 bit feedback shift register (0x7FFFFFFF possible states)
;
rand
    clrf    NEW        ;Pre-zero the result

    movlw    06h        ;Qty of
    movwf    COUNT1        ;bits to get

rand1    ;Loop here
    swapf    RND3,W        ;Bit27 -> TEMP Bit7
    movwf    TEMP
    rlf    RND3,w        ;Bit30 -> W Bit7
    xorwf    TEMP,f
    rlf    TEMP,f        ;cy = Bit27 Bit30
    rlf    RND0,f        ;Shift it..
    rlf    RND1,f        ;down..
    rlf    RND2,f        ;down..
    rlf    RND3,f        ;down..
    rlf    NEW,f        ;Save the bit in NEW Bit0

    decfsz    COUNT1,1     ;Done?
    goto    rand1        ;No, try again

    retlw    00

    END
;
;******************************************************************************
;
;LED(s):
; I used Radio Shack part # 276-351, with a 120 Ohm current limiting resistor.  I had
; better results using two in series with a 33 Ohm current limiting resistor.  You
; may want to experiment some.  Just make sure you do not exceed the maximum current
; rating of the LED. Also a small 5.8v (1.2W) flashlight bulb may work well assuming
; you use the transistor circuit described below.  The bulb will never be fully lit so
; the light may appear to be slightly yellow like a real candle flame.

;Drive transistor:
; I used a 2N3904 with the base driven though a 1.2k resistor.  The transistor would
; drive the LED(s)or bulbs.  That way, the LED(s) could be much brighter.  Also con-
; sider the fact that the transistor can easily drive a 200 mA load.  The PIC device
; can only drive up to 25 mA per pin, and 100 mA maximum.

;For best candle effect:
; Pick the brightest yellow or amber LED(s) you can find.  Also LED(s) are not linear
; over their full range of applied current.  Increasing the current drive by 10% may not
; produce 10% greater light output.  Some LED(s) may be much more liner at 1/3 of their
; maximum current rating, while others may be liner near their maximum.  Try different
; value resistors until you are happy with the results you get.  Thankfully LED(s) are
; not very expensive.  Also try sanding the Epoxy package of the LED(s) themselves.  I
; found that the light scatters better.  Finally, don't look right at the LED(s).  Put
; them down a frosted glass candle holder, or reflect the light off some shiny foil.
; The resulting flicker will look much more like a real candle flame.

;Power source:
; Although this circuit is supposed to work at 5v, it will work on 3V (Two penlight cells)
; if change the current limiting resistor to about 10 ohms, and drive a high efficiency
; LED.  It may also be powered by voltages above five, however use of an LM7805 voltage
; regulator is recommended.

;About white LED's
; Most white LED's have a blue tint to the emitted light.  Such a tint tends not to make
; a very effective candle.  I have not yet tried covering the candle with a yellow tint.
; I will try to use two LED's (one yellow, and one white).  I have also noted that
; almost all white LED's have a forward voltage drop of about 3.6v.  This may create a
; problem if you plan to run the LED's in series, or if you plan to operate on only 3v.

